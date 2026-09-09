import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../backend_client.dart';
import 'evidence_compressor.dart';
import 'evidence_files.dart';
import 'occurrence_queue.dart';
import 'queue_models.dart';
import 'queue_store.dart';

/// Ponto único de acesso à fila para toda a interface.
///
/// Mantém a fila viva enquanto o aplicativo estiver aberto: tenta esvaziar na
/// abertura, quando a rede volta e periodicamente, para que uma ocorrência
/// criada sem sinal saia sozinha assim que houver conexão.
class QueueController extends ChangeNotifier {
  QueueController._(this._queue, this._files, this._durable);

  static QueueController? _instance;

  final OccurrenceQueue _queue;
  final EvidenceFileStore _files;
  final bool _durable;

  StreamSubscription<List<QueuedOccurrence>>? _watch;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _ticker;

  List<QueuedOccurrence> _items = const [];

  /// Ocorrências na fila, da mais antiga para a mais recente.
  List<QueuedOccurrence> get items => _items;

  /// Se a fila sobrevive ao fechamento do aplicativo. Falso no navegador.
  bool get isDurable => _durable;

  List<QueuedOccurrence> get pending =>
      _items.where((item) => item.status.isPending).toList();

  List<QueuedOccurrence> get needingAction => _items
      .where((item) => item.status == QueueStatus.actionRequired)
      .toList();

  static Future<QueueController> instance() async {
    final existing = _instance;
    if (existing != null) return existing;

    final store = await openQueueStore();
    final files = await openEvidenceFiles();
    final backend = BackendClient();
    final queue = OccurrenceQueue(
      store: store,
      backend: backend,
      readEvidence: (evidence) => files.read(evidence.localPath),
      connectivity: _hasConnection,
    );
    final controller = QueueController._(queue, files, store.isDurable);
    await controller._start();
    _instance = controller;
    return controller;
  }

  /// Controlador para testes de widget, sem canais de plataforma.
  ///
  /// Não assina conectividade nem liga o temporizador: `connectivity_plus` e
  /// `path_provider` exigem canais que não existem no ambiente de teste.
  @visibleForTesting
  static QueueController forTesting({
    required QueueStore store,
    required EvidenceFileStore files,
    BackendClient? backend,
  }) {
    final queue = OccurrenceQueue(
      store: store,
      backend: backend ?? BackendClient(),
      readEvidence: (evidence) => files.read(evidence.localPath),
      // Sem rede nos testes: nada sai da fila sem o teste mandar.
      connectivity: () async => false,
    );
    final controller = QueueController._(queue, files, store.isDurable);
    controller._watch = queue.watch().listen((value) {
      controller._items = value;
      controller.notifyListeners();
    });
    return controller;
  }

  /// Só evita trabalho quando o sistema afirma que não há rede alguma. Um
  /// "conectado" aqui não garante internet — por isso a falha de envio continua
  /// tratada como falha comum, com nova tentativa.
  static Future<bool> _hasConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none) || result.isEmpty;
    } catch (_) {
      // Sem resposta do sistema, tenta enviar: o erro real aparece no envio.
      return true;
    }
  }

  Future<void> _start() async {
    _watch = _queue.watch().listen((value) {
      _items = value;
      notifyListeners();
    });
    _connectivity = Connectivity().onConnectivityChanged.listen((_) {
      unawaited(drain());
    });
    // Rede pode voltar sem evento (troca de torre, dado móvel instável).
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => drain());
    await drain();
  }

  Future<void> drain() => _queue.drain();

  Future<void> retry(String id) => _queue.retryNow(id);

  Future<void> discard(String id) async {
    await _queue.discard(id);
    await _files.deleteForOccurrence(id);
  }

  /// Prepara e guarda uma foto, devolvendo a evidência pronta para a fila.
  ///
  /// Comprime antes de gravar: o que fica no aparelho é exatamente o que vai
  /// subir, então o `sha256` calculado aqui é o mesmo que o servidor valida.
  Future<QueuedEvidence> preparePhoto({
    required String occurrenceId,
    required String evidenceId,
    required Uint8List original,
  }) async {
    final compressed = await const EvidenceCompressor().compressPhoto(original);
    final path = await _files.save(
      occurrenceId: occurrenceId,
      evidenceId: evidenceId,
      extension: 'jpg',
      bytes: compressed.bytes,
    );
    return QueuedEvidence(
      id: evidenceId,
      occurrenceId: occurrenceId,
      kind: EvidenceKind.photo,
      localPath: path,
      mimeType: 'image/jpeg',
      byteSize: compressed.byteSize,
      sha256: BackendClient().sha256Of(compressed.bytes),
    );
  }

  /// Prepara e guarda um vídeo, recusando antes de gastar dados se estiver
  /// acima do limite aceito pelo servidor.
  Future<QueuedEvidence> prepareVideo({
    required String occurrenceId,
    required String evidenceId,
    required Uint8List original,
  }) async {
    final problem = validateVideo(original.length);
    if (problem != null) throw PhotoTooLarge(problem);
    final path = await _files.save(
      occurrenceId: occurrenceId,
      evidenceId: evidenceId,
      extension: 'mp4',
      bytes: original,
    );
    return QueuedEvidence(
      id: evidenceId,
      occurrenceId: occurrenceId,
      kind: EvidenceKind.video,
      localPath: path,
      mimeType: 'video/mp4',
      byteSize: original.length,
      sha256: BackendClient().sha256Of(original),
    );
  }

  /// Coloca a ocorrência na fila e tenta enviar imediatamente.
  ///
  /// Devolve assim que a ocorrência estiver **gravada**. O envio segue em
  /// segundo plano: a tela acompanha o estado real em vez de prender a pessoa
  /// numa espera que pode não terminar.
  Future<QueuedOccurrence> submit(QueuedOccurrence occurrence) async {
    final queued = await _queue.enqueue(occurrence);
    unawaited(drain());
    return queued;
  }

  /// Lê os bytes de uma evidência para exibir a miniatura.
  Future<Uint8List> readEvidence(QueuedEvidence evidence) =>
      _files.read(evidence.localPath);

  @override
  void dispose() {
    _watch?.cancel();
    _connectivity?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
