import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'account_flow.dart';

const _navy = Color(0xFF0B2748);
const _orange = Color(0xFFF06432);
const _orangeDark = Color(0xFFC6431F);
const _ink = Color(0xFF162632);
const _muted = Color(0xFF5C6B74);
const _danger = Color(0xFFC92B35);
const _success = Color(0xFF16845B);

enum EvidenceKind { photo, video }

class OccurrenceEvidence {
  const OccurrenceEvidence({required this.file, required this.kind});
  final XFile file;
  final EvidenceKind kind;
}

class OccurrenceReceipt {
  const OccurrenceReceipt({required this.id, required this.receivedAt});
  final String id;
  final DateTime receivedAt;
}

class OccurrenceService {
  static const nativeApiBase = String.fromEnvironment('BLUALERT_API_BASE');

  Future<OccurrenceReceipt> send({
    required ResidentProfile resident,
    required String category,
    required String description,
    required Position position,
    required List<OccurrenceEvidence> evidence,
  }) async {
    final endpoint = kIsWeb
        ? Uri.base.resolve('/api/ocorrencias')
        : nativeApiBase.isEmpty
            ? null
            : Uri.parse('$nativeApiBase/api/ocorrencias');
    if (endpoint == null) {
      throw StateError(
        'A central precisa ser configurada neste aparelho antes do envio.',
      );
    }

    final attachments = <Map<String, Object?>>[];
    for (final item in evidence) {
      final bytes = await item.file.readAsBytes();
      if (bytes.length > 18 * 1024 * 1024) {
        throw StateError('${item.file.name} ultrapassa o limite de 18 MB.');
      }
      attachments.add({
        'name': item.file.name,
        'mimeType': item.file.mimeType ??
            (item.kind == EvidenceKind.photo ? 'image/jpeg' : 'video/mp4'),
        'kind': item.kind.name,
        'base64': base64Encode(bytes),
      });
    }

    final response = await http
        .post(
          endpoint,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'resident': {
              'fullName': resident.fullName,
              'phone': resident.phone,
            },
            'category': category,
            'description': description,
            'location': {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracy': position.accuracy,
            },
            'attachments': attachments,
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      throw StateError(
        body?['error'] as String? ?? 'A central recusou o envio.',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return OccurrenceReceipt(
      id: body['id'] as String,
      receivedAt: DateTime.parse(body['receivedAt'] as String),
    );
  }
}

class OccurrenceScreen extends StatefulWidget {
  const OccurrenceScreen({required this.profile, super.key});
  final ResidentProfile profile;

  @override
  State<OccurrenceScreen> createState() => _OccurrenceScreenState();
}

class _OccurrenceScreenState extends State<OccurrenceScreen> {
  final picker = ImagePicker();
  final description = TextEditingController();
  final evidence = <OccurrenceEvidence>[];
  final service = OccurrenceService();
  final categories = const [
    ('Alagamento', Icons.water_rounded),
    ('Deslizamento', Icons.landscape_rounded),
    ('Árvore ou via', Icons.park_rounded),
    ('Risco estrutural', Icons.home_work_rounded),
    ('Outro risco', Icons.warning_amber_rounded),
  ];
  String category = 'Alagamento';
  Position? position;
  bool locating = false;
  bool sending = false;
  String? error;
  OccurrenceReceipt? receipt;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> pickPhoto(ImageSource source) async {
    try {
      final file = await picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (file != null && mounted) {
        setState(() {
          evidence
              .add(OccurrenceEvidence(file: file, kind: EvidenceKind.photo));
          error = null;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() => error = 'Não foi possível abrir a câmera ou galeria.');
    }
  }

  Future<void> pickVideo(ImageSource source) async {
    try {
      final file = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
      if (file != null && mounted) {
        setState(() {
          evidence
              .add(OccurrenceEvidence(file: file, kind: EvidenceKind.video));
          error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Não foi possível capturar o vídeo.');
    }
  }

  Future<void> locate() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException('Permissão negada');
      }
      final found = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) setState(() => position = found);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Ative a localização e permita o acesso para enviar a ocorrência.');
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> send() async {
    if (evidence.isEmpty) {
      setState(() => error = 'Adicione pelo menos uma foto ou um vídeo.');
      return;
    }
    if (description.text.trim().length < 15) {
      setState(() => error = 'Descreva o risco com pelo menos 15 caracteres.');
      return;
    }
    if (position == null) {
      setState(() => error = 'Confirme a localização da ocorrência.');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final sent = await service.send(
        resident: widget.profile,
        category: category,
        description: description.text.trim(),
        position: position!,
        evidence: evidence,
      );
      if (mounted) setState(() => receipt = sent);
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = exception.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void reset() {
    setState(() {
      evidence.clear();
      description.clear();
      position = null;
      category = categories.first.$1;
      receipt = null;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (receipt != null) return _buildSuccess();
    return Material(
      color: const Color(0xFFF3F6F8),
      child: Column(
        children: [
          const OccurrenceHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
              children: [
                const EmergencyStrip(),
                const SizedBox(height: 22),
                Text(
                  'Registre o que está acontecendo',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'A imagem mostra o risco. A descrição e o GPS ajudam a equipe a localizar.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 20),
                const FormLabel(number: '1', text: 'Tipo de ocorrência'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((item) {
                    final selected = item.$1 == category;
                    return ChoiceChip(
                      selected: selected,
                      onSelected: (_) => setState(() => category = item.$1),
                      avatar: Icon(item.$2,
                          size: 17, color: selected ? Colors.white : _navy),
                      label: Text(item.$1),
                      selectedColor: _navy,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      side: const BorderSide(color: Color(0xFFD8E0E5)),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                const FormLabel(number: '2', text: 'Foto ou vídeo do risco'),
                const SizedBox(height: 10),
                EvidenceComposer(
                  evidence: evidence,
                  onPhoto: () => pickPhoto(ImageSource.camera),
                  onGallery: () => pickPhoto(ImageSource.gallery),
                  onVideo: () => pickVideo(ImageSource.camera),
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
                    hintText:
                        'Ex.: água subindo rapidamente na rua, alcançando a entrada das casas...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                const FormLabel(number: '4', text: 'Localização da ocorrência'),
                const SizedBox(height: 10),
                OccurrenceLocationCard(
                  position: position,
                  locating: locating,
                  onTap: locate,
                ),
                if (error != null) ...[
                  const SizedBox(height: 14),
                  ErrorNotice(text: error!),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: sending ? null : send,
                    style: FilledButton.styleFrom(
                      backgroundColor: _orangeDark,
                      minimumSize: const Size.fromHeight(56),
                    ),
                    icon: sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(sending
                        ? 'Enviando evidências...'
                        : 'Revisar e enviar'),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Em risco imediato, não espere o envio: ligue 199 ou 193.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() => ColoredBox(
        color: const Color(0xFFF3F6F8),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: .65, end: 1),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: const BoxDecoration(
                        color: _success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 58),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ocorrência recebida',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'As evidências e a localização chegaram à central configurada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCE4E8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: _navy),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Identificador do envio',
                                  style:
                                      TextStyle(color: _muted, fontSize: 11)),
                              SelectableText(
                                receipt!.id,
                                style: const TextStyle(
                                    color: _ink, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: reset,
                      style: FilledButton.styleFrom(backgroundColor: _navy),
                      child: const Text('Registrar outra ocorrência'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class OccurrenceHeader extends StatelessWidget {
  const OccurrenceHeader({super.key});
  @override
  Widget build(BuildContext context) => Container(
        color: _navy,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Image.asset('assets/brand/blualert_mark.png',
                  width: 48, height: 48),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nova ocorrência',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    Text('Evidências para localizar e avaliar o risco',
                        style:
                            TextStyle(color: Color(0xFFBFD0DE), fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class EmergencyStrip extends StatelessWidget {
  const EmergencyStrip({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFECE7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFC4B5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.phone_in_talk_rounded, color: _danger),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Perigo imediato? Ligue 199 (Defesa Civil) ou 193 (Bombeiros).',
                style: TextStyle(
                    color: _ink, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
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
  const EvidenceComposer(
      {required this.evidence,
      required this.onPhoto,
      required this.onGallery,
      required this.onVideo,
      required this.onRemove,
      super.key});
  final List<OccurrenceEvidence> evidence;
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
                      onTap: onPhoto)),
              const SizedBox(width: 8),
              Expanded(
                  child: CaptureButton(
                      icon: Icons.videocam_rounded,
                      label: 'Gravar vídeo',
                      onTap: onVideo)),
              const SizedBox(width: 8),
              Expanded(
                  child: CaptureButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Galeria',
                      onTap: onGallery)),
            ],
          ),
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
                  onRemove: () => onRemove(index),
                ),
              ),
            ),
          ],
        ],
      );
}

class CaptureButton extends StatelessWidget {
  const CaptureButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      super.key});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 13),
          side: const BorderSide(color: Color(0xFFD5DEE3)),
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

class EvidenceTile extends StatelessWidget {
  const EvidenceTile(
      {required this.evidence, required this.onRemove, super.key});
  final OccurrenceEvidence evidence;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 104,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: evidence.kind == EvidenceKind.video
                    ? const ColoredBox(
                        color: _navy,
                        child: Center(
                            child: Icon(Icons.play_circle_fill_rounded,
                                color: Colors.white, size: 42)),
                      )
                    : FutureBuilder<Uint8List>(
                        future: evidence.file.readAsBytes(),
                        builder: (context, snapshot) => snapshot.hasData
                            ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                            : const ColoredBox(
                                color: Color(0xFFE4EAED),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              ),
                      ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filled(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xCC061C35),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      );
}

class OccurrenceLocationCard extends StatelessWidget {
  const OccurrenceLocationCard(
      {required this.position,
      required this.locating,
      required this.onTap,
      super.key});
  final Position? position;
  final bool locating;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: position == null ? Colors.white : const Color(0xFFE8F5EF),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: locating ? null : onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: position == null ? const Color(0xFFD5DEE3) : _success),
            ),
            child: Row(
              children: [
                if (locating)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _orange),
                  )
                else
                  Icon(
                      position == null
                          ? Icons.my_location_rounded
                          : Icons.gps_fixed_rounded,
                      color: position == null ? _orangeDark : _success),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        position == null
                            ? 'Capturar GPS agora'
                            : 'Localização confirmada',
                        style: const TextStyle(
                            color: _ink, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        position == null
                            ? 'Use o ponto exato de onde o risco foi registrado.'
                            : 'Precisão aproximada: ${position!.accuracy.round()} m',
                        style: const TextStyle(color: _muted, fontSize: 11),
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
          children: [
            const Icon(Icons.error_outline_rounded, color: _danger),
            const SizedBox(width: 9),
            Expanded(
                child: Text(text,
                    style: const TextStyle(color: _ink, fontSize: 12))),
          ],
        ),
      );
}
