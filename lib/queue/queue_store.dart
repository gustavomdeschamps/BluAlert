import 'dart:async';

import 'queue_models.dart';
import 'queue_store_io.dart' if (dart.library.js_interop) 'queue_store_web.dart'
    as platform;

/// Persistência da fila de ocorrências.
///
/// Existem duas implementações: SQLite (via drift) no Android, que é o destino
/// real do piloto, e memória no navegador, usado apenas para demonstração. A
/// diferença é exposta em [isDurable] para que a interface possa dizer a
/// verdade sobre o que sobrevive ao fechamento do aplicativo, em vez de
/// prometer persistência que não existe.
abstract class QueueStore {
  /// Verdadeiro quando a fila sobrevive ao encerramento do aplicativo.
  bool get isDurable;

  Future<void> insert(QueuedOccurrence occurrence);

  /// Atualiza **apenas** os campos da ocorrência.
  ///
  /// A lista de evidências do objeto recebido é ignorada de propósito. O motor
  /// da fila trabalha sobre um retrato tirado antes dos uploads; se este método
  /// gravasse esse retrato inteiro, apagaria as marcas de envio feitas por
  /// [markEvidenceUploaded] no meio do caminho — e uma retomada reenviaria
  /// arquivos que já estavam no Storage, gastando os dados de quem está numa
  /// emergência. Evidência só muda por [markEvidenceUploaded].
  Future<void> update(QueuedOccurrence occurrence);

  Future<void> markEvidenceUploaded(String evidenceId, DateTime uploadedAt);

  Future<QueuedOccurrence?> byId(String id);

  Future<List<QueuedOccurrence>> all();

  /// Ocorrências que a fila pode tentar avançar agora, da mais antiga para a
  /// mais recente — quem esperou mais é atendido primeiro.
  Future<List<QueuedOccurrence>> ready(DateTime now);

  /// Emite a lista completa a cada mudança, para a interface acompanhar sem
  /// consultar em laço.
  Stream<List<QueuedOccurrence>> watch();

  Future<void> delete(String id);

  Future<void> close();
}

/// Abre a fila da plataforma atual.
Future<QueueStore> openQueueStore() => platform.openQueueStore();

/// Implementação em memória, usada no navegador e nos testes.
///
/// Mantém exatamente o mesmo contrato da versão persistente, mas declara
/// [isDurable] como falso: fechar a aba perde a fila.
class MemoryQueueStore implements QueueStore {
  final Map<String, QueuedOccurrence> _items = {};
  final StreamController<List<QueuedOccurrence>> _changes =
      StreamController<List<QueuedOccurrence>>.broadcast();

  @override
  bool get isDurable => false;

  List<QueuedOccurrence> get _sorted {
    final list = _items.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(list);
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(_sorted);
  }

  @override
  Future<void> insert(QueuedOccurrence occurrence) async {
    _items[occurrence.id] = occurrence;
    _emit();
  }

  @override
  Future<void> update(QueuedOccurrence occurrence) async {
    // Preserva as evidências já registradas, como faz a versão em SQLite —
    // que atualiza somente a linha da ocorrência. Ver o contrato em
    // [QueueStore.update].
    final existing = _items[occurrence.id];
    _items[occurrence.id] = existing == null
        ? occurrence
        : occurrence.copyWith(evidence: existing.evidence);
    _emit();
  }

  @override
  Future<void> markEvidenceUploaded(
      String evidenceId, DateTime uploadedAt) async {
    for (final entry in _items.entries) {
      final index =
          entry.value.evidence.indexWhere((item) => item.id == evidenceId);
      if (index < 0) continue;
      final evidence = [...entry.value.evidence];
      evidence[index] = evidence[index].copyWith(uploadedAt: uploadedAt);
      _items[entry.key] = entry.value.copyWith(evidence: evidence);
      _emit();
      return;
    }
  }

  @override
  Future<QueuedOccurrence?> byId(String id) async => _items[id];

  @override
  Future<List<QueuedOccurrence>> all() async => _sorted;

  @override
  Future<List<QueuedOccurrence>> ready(DateTime now) async =>
      _sorted.where((item) => item.isReady(now)).toList();

  @override
  Stream<List<QueuedOccurrence>> watch() async* {
    yield _sorted;
    yield* _changes.stream;
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
    _emit();
  }

  @override
  Future<void> close() async {
    await _changes.close();
  }
}
