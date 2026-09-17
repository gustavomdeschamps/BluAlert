import 'dart:typed_data';

import 'evidence_files.dart';

Future<EvidenceFileStore> openEvidenceFiles() async =>
    MemoryEvidenceFileStore();

/// Evidências em memória, no navegador.
///
/// Vale a mesma ressalva da fila em memória: o Android é o destino real do
/// piloto e persiste tudo em disco; a web serve para demonstração e perde o que
/// não foi confirmado quando a aba fecha. A interface avisa isso — ver
/// `QueueStore.isDurable`.
class MemoryEvidenceFileStore implements EvidenceFileStore {
  final Map<String, Uint8List> _files = {};

  @override
  Future<String> save({
    required String occurrenceId,
    required String evidenceId,
    required String extension,
    required Uint8List bytes,
  }) async {
    final path = 'memory://$occurrenceId/$evidenceId.$extension';
    _files[path] = bytes;
    return path;
  }

  @override
  Future<Uint8List> read(String path) async {
    final bytes = _files[path];
    if (bytes == null) {
      throw const EvidenceFileMissing(
        'A evidência não está mais disponível nesta aba do navegador. '
        'Registre novamente com uma nova foto.',
      );
    }
    return bytes;
  }

  @override
  Future<void> deleteForOccurrence(String occurrenceId) async {
    _files.removeWhere((path, _) => path.startsWith('memory://$occurrenceId/'));
  }
}
