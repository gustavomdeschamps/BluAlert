import 'dart:typed_data';

import 'evidence_files_io.dart'
    if (dart.library.js_interop) 'evidence_files_web.dart' as platform;

/// Guarda os bytes das evidências enquanto a ocorrência espera na fila.
///
/// A cópia é obrigatória e não é detalhe de implementação: o arquivo devolvido
/// pela câmera fica no cache do sistema, que o Android limpa quando o espaço
/// aperta. Sem copiar, uma ocorrência criada sem rede à noite poderia perder a
/// foto antes de conseguir enviar pela manhã.
abstract class EvidenceFileStore {
  /// Grava os bytes e devolve o caminho a ser guardado na fila.
  Future<String> save({
    required String occurrenceId,
    required String evidenceId,
    required String extension,
    required Uint8List bytes,
  });

  /// Lê os bytes de uma evidência guardada.
  Future<Uint8List> read(String path);

  /// Remove tudo o que pertence a uma ocorrência já concluída ou descartada.
  Future<void> deleteForOccurrence(String occurrenceId);
}

Future<EvidenceFileStore> openEvidenceFiles() => platform.openEvidenceFiles();

/// O arquivo da evidência não está mais no aparelho.
class EvidenceFileMissing implements Exception {
  const EvidenceFileMissing(this.message);
  final String message;
  @override
  String toString() => message;
}
