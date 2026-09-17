import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'evidence_files.dart';

Future<EvidenceFileStore> openEvidenceFiles() async {
  final support = await getApplicationSupportDirectory();
  final root = Directory(p.join(support.path, 'evidence'));
  await root.create(recursive: true);
  return DirectoryEvidenceFileStore(root);
}

/// Evidências no diretório privado do aplicativo.
///
/// Fica em `getApplicationSupportDirectory`, e não em cache nem em
/// armazenamento externo: o sistema não limpa este diretório sozinho e outros
/// aplicativos não têm acesso a ele — as fotos podem mostrar o interior da casa
/// de quem pediu ajuda.
class DirectoryEvidenceFileStore implements EvidenceFileStore {
  DirectoryEvidenceFileStore(this.root);

  final Directory root;

  @override
  Future<String> save({
    required String occurrenceId,
    required String evidenceId,
    required String extension,
    required Uint8List bytes,
  }) async {
    final directory = Directory(p.join(root.path, occurrenceId));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, '$evidenceId.$extension'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<Uint8List> read(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const EvidenceFileMissing(
        'A foto desta ocorrência não está mais no aparelho. '
        'Registre novamente com uma nova foto.',
      );
    }
    return file.readAsBytes();
  }

  @override
  Future<void> deleteForOccurrence(String occurrenceId) async {
    final directory = Directory(p.join(root.path, occurrenceId));
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
