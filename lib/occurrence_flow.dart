import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'account_flow.dart';
import 'backend_client.dart';
import 'emergency.dart';
import 'location_picker.dart';
import 'queue/evidence_compressor.dart';
import 'queue/queue_controller.dart';
import 'queue/queue_models.dart';

const _navy = Color(0xFF0B2748);
const _orange = Color(0xFFF06432);
const _orangeDark = Color(0xFFC6431F);
const _ink = Color(0xFF162632);
const _muted = Color(0xFF5C6B74);
const _danger = Color(0xFFC92B35);
const _success = Color(0xFF16845B);
const _waiting = Color(0xFF8A6D1F);
const _line = Color(0xFFD5DEE3);

const _categories = [
  ('flood', 'Alagamento', Icons.water_rounded),
  ('landslide', 'Deslizamento', Icons.landscape_rounded),
  ('tree_or_road', 'Árvore ou via', Icons.park_rounded),
  ('structural_risk', 'Risco estrutural', Icons.home_work_rounded),
  ('other', 'Outro risco', Icons.warning_amber_rounded),
];

String categoryLabel(String code) => _categories
    .firstWhere((item) => item.$1 == code, orElse: () => _categories.last)
    .$2;

/// Cor de cada estado da fila.
///
/// Verde só para confirmação real e vermelho só para o que exige ação — as
/// duas cores que a pessoa lê rápido não podem aparecer em estado intermediário.
Color statusColor(QueueStatus status) => switch (status) {
      QueueStatus.receivedByCentral => _success,
      QueueStatus.actionRequired => _danger,
      QueueStatus.uploadingMedia || QueueStatus.awaitingConfirmation => _navy,
      QueueStatus.savedOnDevice || QueueStatus.waitingConnection => _waiting,
    };

IconData statusIcon(QueueStatus status) => switch (status) {
      QueueStatus.savedOnDevice => Icons.save_outlined,
      QueueStatus.waitingConnection => Icons.cloud_off_rounded,
      QueueStatus.uploadingMedia => Icons.cloud_upload_outlined,
      QueueStatus.awaitingConfirmation => Icons.hourglass_top_rounded,
      QueueStatus.receivedByCentral => Icons.check_circle_rounded,
      QueueStatus.actionRequired => Icons.error_outline_rounded,
    };

class OccurrenceScreen extends StatefulWidget {
  const OccurrenceScreen({
    required this.profile,
    required this.queue,
    super.key,
  });

  final ResidentProfile profile;
  final QueueController queue;

  @override
  State<OccurrenceScreen> createState() => _OccurrenceScreenState();
}

class _OccurrenceScreenState extends State<OccurrenceScreen> {
  static const _maximumGpsAge = Duration(minutes: 2);
  final picker = ImagePicker();
  final description = TextEditingController();
  final evidence = <QueuedEvidence>[];
  final backend = BackendClient();

  late String occurrenceId;
  String category = _categories.first.$1;
  /// Coordenada confirmada pela pessoa no mapa. Enquanto for nula, o ponto
  /// ainda não foi conferido e o envio não é liberado.
  ConfirmedLocation? confirmedLocation;
  bool locating = false;
  bool preparing = false;
  bool submitting = false;
  String? error;

  /// Identificador da ocorrência recém-enviada, para acompanhar o estado real.
  String? trackingId;

  @override
  void initState() {
    super.initState();
    occurrenceId = backend.uuid();
  }

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> _addPhoto(ImageSource source) async {
    setState(() {
      preparing = true;
      error = null;
    });
    try {
      final file = await picker.pickImage(source: source);
      if (file == null) return;
      final original = await file.readAsBytes();
      final prepared = await widget.queue.preparePhoto(
        occurrenceId: occurrenceId,
        evidenceId: backend.uuid(),
        original: original,
      );
      if (mounted) setState(() => evidence.add(prepared));
    } on PhotoTooLarge catch (problem) {
      if (mounted) setState(() => error = problem.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Não foi possível abrir a câmera ou a galeria.');
      }
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  Future<void> _addVideo() async {
    setState(() {
      preparing = true;
      error = null;
    });
    try {
      final file = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 20),
      );
      if (file == null) return;
      final original = await file.readAsBytes();
      final prepared = await widget.queue.prepareVideo(
        occurrenceId: occurrenceId,
        evidenceId: backend.uuid(),
        original: original,
      );
      if (mounted) setState(() => evidence.add(prepared));
    } on PhotoTooLarge catch (problem) {
      if (mounted) setState(() => error = problem.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Não foi possível gravar o vídeo.');
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  Future<void> _locate() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationProblem(
          'A localização do aparelho está desligada. Ative para registrar o '
          'ponto exato do risco.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationProblem(
          'A permissão de localização foi bloqueada. Libere nas configurações '
          'do aparelho para registrar o ponto do risco.',
        );
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationProblem(
          'Sem a permissão de localização não é possível informar onde está o '
          'risco. Em perigo imediato, ligue 199.',
        );
      }
      final found = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final capturedAt = found.timestamp;
      if (DateTime.now().difference(capturedAt) > _maximumGpsAge) {
        throw const _LocationProblem(
          'O aparelho devolveu uma posição antiga. Atualize o GPS e tente novamente.',
        );
      }
      setState(() {
        confirmedLocation = null;
      });
      // Quem está no local é a única pessoa capaz de dizer se o ponto do GPS
      // corresponde ao risco. A confirmação é obrigatória.
      await _confirmOnMap(
          found.latitude, found.longitude, found.accuracy, capturedAt);
    } on _LocationProblem catch (problem) {
      if (mounted) setState(() => error = problem.message);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'O GPS não respondeu a tempo. Tente de novo em área aberta.');
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _confirmOnMap(
    double latitude,
    double longitude,
    double? accuracy,
    DateTime capturedAt, {
    LocationSource initialSource = LocationSource.gps,
  }) async {
    final result = await Navigator.of(context).push<ConfirmedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: latitude,
          initialLongitude: longitude,
          gpsAccuracyM: accuracy,
          capturedAt: capturedAt,
          initialSource: initialSource,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      confirmedLocation = result;
      error = null;
    });
  }

  /// Reabre o mapa para revisar o ponto já confirmado.
  Future<void> _reviewLocation() async {
    final current = confirmedLocation;
    if (current == null) return;
    await _confirmOnMap(
      current.latitude,
      current.longitude,
      current.source.isManual ? null : current.accuracyM,
      current.capturedAt,
      initialSource: current.source,
    );
  }

  String? _validate() {
    if (!evidence.any((item) => item.kind == EvidenceKind.photo)) {
      return 'Inclua pelo menos uma foto do risco.';
    }
    if (description.text.trim().length < 15) {
      return 'Descreva o risco com pelo menos 15 caracteres.';
    }
    if (confirmedLocation == null) {
      return 'Confirme a localização da ocorrência no mapa.';
    }
    final location = confirmedLocation!;
    if (location.source == LocationSource.gps &&
        DateTime.now().difference(location.capturedAt) > _maximumGpsAge) {
      return 'A localização já tem mais de 2 minutos. Atualize o GPS e confirme o ponto novamente.';
    }
    return null;
  }

  Future<void> _review() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => OccurrenceReviewSheet(
        category: category,
        description: description.text.trim(),
        location: confirmedLocation!,
        evidence: evidence,
        queue: widget.queue,
      ),
    );
    if (confirmed == true) await _submit();
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    final confirmed = confirmedLocation!;
    final occurrence = QueuedOccurrence(
      id: occurrenceId,
      // O mesmo UUID serve de chave de idempotência: se este envio for repetido
      // depois de uma queda, o servidor reconhece e não cria uma segunda.
      idempotencyKey: occurrenceId,
      category: category,
      description: description.text.trim(),
      latitude: confirmed.latitude,
      longitude: confirmed.longitude,
      // Nula quando o ponto foi ajustado à mão: o raio do GPS não descreve
      // mais aquela coordenada.
      accuracyM: confirmed.accuracyM,
      locationCapturedAt: confirmed.capturedAt,
      locationSource: confirmed.source,
      createdAt: DateTime.now(),
      status: QueueStatus.savedOnDevice,
      attempts: 0,
      evidence: List.unmodifiable(evidence),
    );
    await widget.queue.submit(occurrence);
    if (!mounted) return;
    setState(() {
      submitting = false;
      trackingId = occurrenceId;
    });
  }

  void _startAnother() {
    setState(() {
      occurrenceId = backend.uuid();
      evidence.clear();
      description.clear();
      confirmedLocation = null;
      category = _categories.first.$1;
      trackingId = null;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (trackingId != null) {
      return OccurrenceTrackingView(
        occurrenceId: trackingId!,
        queue: widget.queue,
        onStartAnother: _startAnother,
      );
    }
    return Material(
      color: const Color(0xFFF3F6F8),
      child: Column(
        children: [
          const OccurrenceHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
              children: [
                const EmergencyCallout(),
                const SizedBox(height: 20),
                PendingQueueBanner(queue: widget.queue),
                Text(
                  'Registre o que está acontecendo',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'A imagem mostra o risco. A descrição e o GPS ajudam a equipe '
                  'a localizar.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 20),
                const FormLabel(number: '1', text: 'Tipo de ocorrência'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((item) {
                    final selected = item.$1 == category;
                    return ChoiceChip(
                      selected: selected,
                      onSelected: (_) => setState(() => category = item.$1),
                      avatar: Icon(item.$3,
                          size: 17, color: selected ? Colors.white : _navy),
                      label: Text(item.$2),
                      selectedColor: _navy,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      side: const BorderSide(color: _line),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                const FormLabel(
                    number: '2', text: 'Foto do risco (obrigatória)'),
                const SizedBox(height: 10),
                EvidenceComposer(
                  evidence: evidence,
                  queue: widget.queue,
                  busy: preparing,
                  onPhoto: () => _addPhoto(ImageSource.camera),
                  onGallery: () => _addPhoto(ImageSource.gallery),
                  onVideo: _addVideo,
                  onRemove: (index) => setState(() => evidence.removeAt(index)),
                ),
                const SizedBox(height: 22),
                const FormLabel(number: '3', text: 'Descrição'),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  maxLines: 5,
                  maxLength: 600,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Ex.: água subindo rapidamente na rua, '
                        'alcançando a entrada das casas...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                const FormLabel(number: '4', text: 'Localização da ocorrência'),
                const SizedBox(height: 10),
                OccurrenceLocationCard(
                  location: confirmedLocation,
                  locating: locating,
                  onCapture: _locate,
                  onReview: confirmedLocation == null ? null : _reviewLocation,
                ),
                if (error != null) ...[
                  const SizedBox(height: 14),
                  ErrorNotice(text: error!),
                ],
                const SizedBox(height: 18),
                const PilotNotice(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: submitting || preparing ? null : _review,
                    style: FilledButton.styleFrom(
                      backgroundColor: _orangeDark,
                      minimumSize: const Size.fromHeight(56),
                    ),
                    icon: submitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.fact_check_outlined),
                    label: Text(submitting ? 'Guardando...' : 'Revisar envio'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationProblem implements Exception {
  const _LocationProblem(this.message);
  final String message;
}

/// Passo 6: revisão antes do envio.
class OccurrenceReviewSheet extends StatelessWidget {
  const OccurrenceReviewSheet({
    required this.category,
    required this.description,
    required this.location,
    required this.evidence,
    required this.queue,
    super.key,
  });

  final String category;
  final String description;
  final ConfirmedLocation location;
  final List<QueuedEvidence> evidence;
  final QueueController queue;

  @override
  Widget build(BuildContext context) {
    final photos =
        evidence.where((item) => item.kind == EvidenceKind.photo).length;
    final videos = evidence.length - photos;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Confira antes de enviar',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              const Text(
                'Estes dados vão para o sistema junto com as evidências.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              _ReviewRow(
                icon: Icons.category_outlined,
                label: 'Tipo',
                value: categoryLabel(category),
              ),
              _ReviewRow(
                icon: Icons.photo_library_outlined,
                label: 'Evidências',
                value: '$photos foto${photos == 1 ? '' : 's'}'
                    '${videos > 0 ? ' e $videos vídeo${videos == 1 ? '' : 's'}' : ''}',
              ),
              _ReviewRow(
                icon: Icons.description_outlined,
                label: 'Descrição',
                value: description,
              ),
              _ReviewRow(
                icon: location.source.isManual
                    ? Icons.edit_location_alt_outlined
                    : Icons.my_location_rounded,
                label: 'Localização',
                // Precisão exibida como o GPS informou, sem arredondar para
                // baixo: a equipe precisa saber o raio real de busca. Com o
                // ponto ajustado à mão, dizemos isso em vez de repetir um
                // raio que não descreve mais aquela coordenada.
                value: '${location.latitude.toStringAsFixed(5)}, '
                    '${location.longitude.toStringAsFixed(5)}\n'
                    '${location.source.label}'
                    '${location.accuracyM == null ? '' : ' · precisão de ${location.accuracyM!.round()} m'}'
                    ' · ${TimeOfDay.fromDateTime(location.capturedAt).format(context)}',
              ),
              const SizedBox(height: 8),
              if (!queue.isDurable)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ErrorNotice(
                    text: 'No navegador, a ocorrência não confirmada se perde '
                        'ao fechar a aba. Para uso em campo, use o aplicativo '
                        'no celular.',
                  ),
                ),
              const PilotNotice(dense: true),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _orangeDark,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Confirmar e enviar'),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Voltar e corrigir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: _navy),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 11, color: _muted)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          color: _ink, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Passo 8: acompanhamento do estado real, sem prometer o que não aconteceu.
class OccurrenceTrackingView extends StatelessWidget {
  const OccurrenceTrackingView({
    required this.occurrenceId,
    required this.queue,
    required this.onStartAnother,
    super.key,
  });

  final String occurrenceId;
  final QueueController queue;
  final VoidCallback onStartAnother;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFF3F6F8),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: queue,
            builder: (context, _) {
              final occurrence = queue.items
                  .where((item) => item.id == occurrenceId)
                  .firstOrNull;
              if (occurrence == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OccurrenceStatusCard(occurrence: occurrence, queue: queue),
                    const SizedBox(height: 18),
                    const PilotNotice(),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: onStartAnother,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Registrar outra ocorrência'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
}

/// Cartão com o estado de uma ocorrência da fila.
class OccurrenceStatusCard extends StatelessWidget {
  const OccurrenceStatusCard({
    required this.occurrence,
    required this.queue,
    super.key,
  });

  final QueuedOccurrence occurrence;
  final QueueController queue;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(occurrence.status);
    final confirmed = occurrence.status == QueueStatus.receivedByCentral;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon(occurrence.status), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occurrence.status.label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      categoryLabel(occurrence.category),
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (occurrence.status.isPending &&
                  occurrence.status != QueueStatus.savedOnDevice)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            occurrence.status.description,
            style: const TextStyle(color: _ink, height: 1.45, fontSize: 13),
          ),
          if (confirmed && occurrence.protocol != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _success.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: _success),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Protocolo do registro',
                            style: TextStyle(color: _muted, fontSize: 11)),
                        SelectableText(
                          occurrence.protocol!,
                          style: const TextStyle(
                              color: _ink, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (occurrence.lastError != null && !confirmed) ...[
            const SizedBox(height: 12),
            ErrorNotice(text: occurrence.lastError!),
          ],
          if (occurrence.status == QueueStatus.waitingConnection) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => queue.retry(occurrence.id),
                style: FilledButton.styleFrom(backgroundColor: _navy),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar enviar agora'),
              ),
            ),
          ],
          if (occurrence.status == QueueStatus.actionRequired) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => queue.retry(occurrence.id),
                    style: FilledButton.styleFrom(backgroundColor: _navy),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar de novo'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _confirmDiscard(context),
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ],
          if (occurrence.attempts > 0 && !confirmed) ...[
            const SizedBox(height: 10),
            Text(
              'Tentativas: ${occurrence.attempts}',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar esta ocorrência?'),
        content: const Text(
          'As fotos e a descrição serão apagadas deste aparelho e o sistema '
          'não receberá o registro. Isto não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Manter'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _danger),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await queue.discard(occurrence.id);
  }
}

/// Aviso no topo do formulário quando já existem ocorrências esperando.
class PendingQueueBanner extends StatelessWidget {
  const PendingQueueBanner({required this.queue, super.key});

  final QueueController queue;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: queue,
        builder: (context, _) {
          final pending = queue.pending.length;
          final blocked = queue.needingAction.length;
          if (pending == 0 && blocked == 0) return const SizedBox.shrink();
          final color = blocked > 0 ? _danger : _waiting;
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: color.withValues(alpha: .3)),
              ),
              child: Row(
                children: [
                  Icon(
                      blocked > 0
                          ? Icons.error_outline_rounded
                          : Icons.schedule_rounded,
                      color: color,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      blocked > 0
                          ? '$blocked ocorrência${blocked == 1 ? '' : 's'} '
                              'parada${blocked == 1 ? '' : 's'} esperando sua ação.'
                          : '$pending ocorrência${pending == 1 ? '' : 's'} '
                              'aguardando envio. Continua em segundo plano.',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

/// Lista de tudo o que está na fila deste aparelho.
class QueueScreen extends StatelessWidget {
  const QueueScreen({required this.queue, super.key});

  final QueueController queue;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFF3F6F8),
        child: Column(
          children: [
            const OccurrenceHeader(title: 'Meus registros'),
            Expanded(
              child: ListenableBuilder(
                listenable: queue,
                builder: (context, _) {
                  final items = queue.items.reversed.toList();
                  if (items.isEmpty) {
                    return const QueueEmptyState();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => OccurrenceStatusCard(
                      occurrence: items[index],
                      queue: queue,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
}

/// Estado vazio honesto: não há registros porque nenhum foi feito.
class QueueEmptyState extends StatelessWidget {
  const QueueEmptyState({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 46, color: _muted),
              const SizedBox(height: 14),
              Text('Nenhum registro ainda',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'As ocorrências que você registrar aparecem aqui, com o estado '
                'real de cada envio.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
              ),
            ],
          ),
        ),
      );
}

class OccurrenceHeader extends StatelessWidget {
  const OccurrenceHeader({this.title = 'Nova ocorrência', super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Container(
        color: _navy,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Image.asset('assets/brand/blualert_mark_v2.png',
                  width: 48, height: 48),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const Text('Evidências para localizar e avaliar o risco',
                        style:
                            TextStyle(color: Color(0xFFBFD0DE), fontSize: 10)),
                  ],
                ),
              ),
              const PilotBadge(),
            ],
          ),
        ),
      );
}

class FormLabel extends StatelessWidget {
  const FormLabel({required this.number, required this.text, super.key});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 27,
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _orange, borderRadius: BorderRadius.circular(8)),
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 9),
          Text(text,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
        ],
      );
}

class EvidenceComposer extends StatelessWidget {
  const EvidenceComposer({
    required this.evidence,
    required this.queue,
    required this.busy,
    required this.onPhoto,
    required this.onGallery,
    required this.onVideo,
    required this.onRemove,
    super.key,
  });

  final List<QueuedEvidence> evidence;
  final QueueController queue;
  final bool busy;
  final VoidCallback onPhoto;
  final VoidCallback onGallery;
  final VoidCallback onVideo;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: CaptureButton(
                      icon: Icons.photo_camera_rounded,
                      label: 'Tirar foto',
                      onTap: busy ? null : onPhoto)),
              const SizedBox(width: 8),
              Expanded(
                  child: CaptureButton(
                      icon: Icons.videocam_rounded,
                      label: 'Gravar vídeo',
                      onTap: busy ? null : onVideo)),
              const SizedBox(width: 8),
              Expanded(
                  child: CaptureButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Galeria',
                      onTap: busy ? null : onGallery)),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 9),
                Text('Preparando a evidência...',
                    style: TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ],
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: evidence.length,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (context, index) => EvidenceTile(
                  evidence: evidence[index],
                  queue: queue,
                  onRemove: () => onRemove(index),
                ),
              ),
            ),
          ],
        ],
      );
}

class CaptureButton extends StatelessWidget {
  const CaptureButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 13),
          side: const BorderSide(color: _line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _orangeDark),
            const SizedBox(height: 5),
            Text(label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class EvidenceTile extends StatefulWidget {
  const EvidenceTile({
    required this.evidence,
    required this.queue,
    required this.onRemove,
    super.key,
  });

  final QueuedEvidence evidence;
  final QueueController queue;
  final VoidCallback onRemove;

  @override
  State<EvidenceTile> createState() => _EvidenceTileState();
}

class _EvidenceTileState extends State<EvidenceTile> {
  // Lido uma única vez: reler o arquivo a cada rebuild travava a rolagem.
  Future<Uint8List>? bytes;

  @override
  void initState() {
    super.initState();
    if (widget.evidence.kind == EvidenceKind.photo) {
      bytes = widget.queue.readEvidence(widget.evidence);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 104,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: widget.evidence.kind == EvidenceKind.video
                    ? const ColoredBox(
                        color: _navy,
                        child: Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white, size: 42),
                        ),
                      )
                    : FutureBuilder<Uint8List>(
                        future: bytes,
                        builder: (context, snapshot) => snapshot.hasData
                            ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                            : const ColoredBox(
                                color: Color(0xFFE4EAED),
                                child: Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                      ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filled(
                onPressed: widget.onRemove,
                tooltip: 'Remover evidência',
                icon: const Icon(Icons.close_rounded, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xCC061C35),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xCC061C35),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${(widget.evidence.byteSize / 1024).round()} KB',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
}

class OccurrenceLocationCard extends StatelessWidget {
  const OccurrenceLocationCard({
    required this.location,
    required this.locating,
    required this.onCapture,
    required this.onReview,
    super.key,
  });

  /// Ponto já confirmado pela pessoa no mapa. Nulo enquanto não houver
  /// confirmação — e sem confirmação o envio não é liberado.
  final ConfirmedLocation? location;
  final bool locating;
  final VoidCallback onCapture;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final confirmed = location;
    final manual = confirmed?.source.isManual ?? false;
    // Acima de 50 m o ponto não identifica uma casa. Só vale para ponto de GPS:
    // num ponto escolhido à mão a precisão do GPS não descreve mais nada.
    final imprecise = confirmed != null &&
        !manual &&
        confirmed.accuracyM != null &&
        confirmed.accuracyM! > 50;
    return Material(
      color: confirmed == null ? Colors.white : const Color(0xFFE8F5EF),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: locating ? null : (confirmed == null ? onCapture : onReview),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: confirmed == null ? _line : _success),
          ),
          child: Row(
            children: [
              if (locating)
                const SizedBox.square(
                  dimension: 24,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: _orange),
                )
              else
                Icon(
                  confirmed == null
                      ? Icons.my_location_rounded
                      : (manual
                          ? Icons.edit_location_alt_outlined
                          : Icons.gps_fixed_rounded),
                  color: confirmed == null ? _orangeDark : _success,
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      confirmed == null
                          ? 'Capturar e confirmar no mapa'
                          : 'Local confirmado',
                      style: const TextStyle(
                          color: _ink, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      confirmed == null
                          ? 'Você confere o ponto no mapa antes de enviar.'
                          : '${confirmed.source.label}'
                              '${confirmed.accuracyM == null ? '' : ' · ${confirmed.accuracyM!.round()} m'}'
                              ' · ${TimeOfDay.fromDateTime(confirmed.capturedAt).format(context)}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    if (imprecise)
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text(
                          'Precisão baixa. Toque para ajustar o ponto no mapa.',
                          style: TextStyle(
                              color: _waiting,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (confirmed != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text(
                          'Toque para revisar no mapa.',
                          style: TextStyle(color: _muted, fontSize: 10.5),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice({required this.text, super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFECE7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: _danger, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text,
                  style:
                      const TextStyle(color: _ink, fontSize: 12, height: 1.4)),
            ),
          ],
        ),
      );
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
