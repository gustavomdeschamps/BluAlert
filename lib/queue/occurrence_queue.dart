import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend_client.dart';
import 'queue_models.dart';
import 'queue_store.dart';

/// Lê os bytes de uma evidência guardada localmente.
///
/// Abstraído para que o motor da fila possa ser testado sem sistema de
/// arquivos e para que o navegador use outra origem.
typedef EvidenceReader = Future<Uint8List> Function(QueuedEvidence evidence);

/// Informa se há conexão utilizável. Um `false` evita gastar uma tentativa —
/// e, principalmente, evita marcar como falha o que é apenas ausência de rede.
typedef ConnectivityProbe = Future<bool> Function();

/// Motor de envio da fila.
///
/// Regras que este código existe para garantir:
///
/// - nenhum estado local é apresentado como "enviado";
/// - só `occurrence-confirm` autoriza [QueueStatus.receivedByCentral];
/// - reenviar a mesma ocorrência não a duplica (o UUID é a chave de
///   idempotência no servidor);
/// - evidência já transferida não sobe de novo numa retomada;
/// - as tentativas têm recuo exponencial e um fim.
class OccurrenceQueue {
  OccurrenceQueue({
    required this.store,
    required this.backend,
    required this.readEvidence,
    this.connectivity,
    this.policy = const RetryPolicy(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final QueueStore store;
  final BackendClient backend;
  final EvidenceReader readEvidence;
  final ConnectivityProbe? connectivity;
  final RetryPolicy policy;
  final DateTime Function() _clock;

  bool _draining = false;

  /// Ocorrências da fila, atualizadas a cada mudança.
  Stream<List<QueuedOccurrence>> watch() => store.watch();

  /// Coloca uma ocorrência na fila. Ela nasce [QueueStatus.savedOnDevice]:
  /// gravada no aparelho e ainda não enviada.
  Future<QueuedOccurrence> enqueue(QueuedOccurrence occurrence) async {
    final queued = occurrence.copyWith(status: QueueStatus.savedOnDevice);
    await store.insert(queued);
    return queued;
  }

  /// Processa tudo o que estiver pronto. Chamadas concorrentes são ignoradas
  /// para que a mesma ocorrência não seja enviada duas vezes em paralelo.
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final pending = await store.ready(_clock());
      for (final occurrence in pending) {
        await _process(occurrence);
      }
    } finally {
      _draining = false;
    }
  }

  /// Retomada manual de uma ocorrência parada em [QueueStatus.actionRequired].
  /// Zera o recuo — foi uma pessoa que pediu, não o temporizador.
  Future<void> retryNow(String id) async {
    final occurrence = await store.byId(id);
    if (occurrence == null) return;
    await store.update(occurrence.copyWith(
      status: QueueStatus.savedOnDevice,
      attempts: 0,
      clearLastError: true,
      clearNextAttempt: true,
    ));
    await drain();
  }

  /// Descarta uma ocorrência que ainda não foi recebida. Só por decisão
  /// explícita da pessoa — a fila nunca descarta sozinha.
  Future<void> discard(String id) async {
    final occurrence = await store.byId(id);
    if (occurrence == null) return;
    if (occurrence.status == QueueStatus.receivedByCentral) return;
    await store.delete(id);
  }

  Future<void> _process(QueuedOccurrence occurrence) async {
    if (connectivity != null && !await connectivity!()) {
      // Sem rede não se gasta tentativa: isto não é falha do envio.
      await store.update(occurrence.copyWith(
        status: QueueStatus.waitingConnection,
        clearNextAttempt: true,
      ));
      return;
    }

    try {
      await store.update(occurrence.copyWith(
        status: QueueStatus.uploadingMedia,
        clearLastError: true,
      ));

      final session = await _openSession(occurrence);

      // O servidor já tinha esta ocorrência como recebida: uma tentativa
      // anterior chegou ao fim sem que a resposta voltasse. Não duplica.
      final priorReceipt = session.receipt;
      if (priorReceipt != null) {
        await _markReceived(
          occurrence,
          protocol: priorReceipt.protocol,
          receivedAt: priorReceipt.receivedAt,
        );
        return;
      }

      await _uploadPending(occurrence, session.uploads);

      await store.update(occurrence.copyWith(
        status: QueueStatus.awaitingConfirmation,
      ));

      final receipt = await backend.invoke(
        'occurrence-confirm',
        {'occurrenceId': occurrence.id},
      );
      final protocol = receipt['id'] as String?;
      final receivedAtRaw = receipt['receivedAt'] as String?;
      if (protocol == null || receivedAtRaw == null) {
        // Sem protocolo não há recebimento. Fica pendente para nova tentativa
        // em vez de mostrar sucesso.
        throw const BackendUnavailable(
          'A central não devolveu o protocolo. O envio continua pendente.',
        );
      }
      await _markReceived(
        occurrence,
        protocol: protocol,
        receivedAt: DateTime.parse(receivedAtRaw),
      );
    } on PermanentQueueFailure catch (error) {
      // Erro que nenhuma nova tentativa resolve: exige ação da pessoa.
      await store.update(occurrence.copyWith(
        status: QueueStatus.actionRequired,
        lastError: error.message,
        clearNextAttempt: true,
      ));
    } catch (error) {
      await _scheduleRetry(occurrence, error);
    }
  }

  Future<void> _markReceived(
    QueuedOccurrence occurrence, {
    required String protocol,
    required DateTime receivedAt,
  }) async {
    await store.update(occurrence.copyWith(
      status: QueueStatus.receivedByCentral,
      protocol: protocol,
      receivedAt: receivedAt,
      clearLastError: true,
      clearNextAttempt: true,
    ));
  }

  Future<void> _scheduleRetry(QueuedOccurrence occurrence, Object error) async {
    final attempts = occurrence.attempts + 1;
    final message = _friendly(error);
    if (!policy.hasAttemptsLeft(attempts)) {
      await store.update(occurrence.copyWith(
        status: QueueStatus.actionRequired,
        attempts: attempts,
        lastError: message,
        clearNextAttempt: true,
      ));
      return;
    }
    await store.update(occurrence.copyWith(
      status: QueueStatus.waitingConnection,
      attempts: attempts,
      lastError: message,
      nextAttemptAt: _clock().add(policy.delayFor(attempts)),
    ));
  }

  Future<_SessionResult> _openSession(QueuedOccurrence occurrence) async {
    final media = occurrence.evidence
        .map((item) => {
              'id': item.id,
              'kind': item.kind.name,
              'mimeType': item.mimeType,
              'byteSize': item.byteSize,
              'sha256': item.sha256,
            })
        .toList();

    final response = await backend.invoke('occurrence-session', {
      'occurrenceId': occurrence.id,
      'idempotencyKey': occurrence.idempotencyKey,
      'category': occurrence.category,
      'description': occurrence.description,
      'latitude': occurrence.latitude,
      'longitude': occurrence.longitude,
      'accuracyM': occurrence.accuracyM,
      // A central precisa saber se a coordenada saiu do GPS ou foi corrigida
      // à mão: muda como a equipe interpreta a precisão ao planejar a ida.
      'locationSource': occurrence.locationSource.name,
      'isTest': occurrence.locationSource.isTest,
      'media': media,
    });

    if (response['alreadyReceived'] == true) {
      final prior = response['occurrence'] as Map<String, dynamic>?;
      final protocol = prior?['protocol'] as String?;
      final receivedAt = prior?['received_at'] as String?;
      if (protocol != null && receivedAt != null) {
        return _SessionResult.received(protocol, DateTime.parse(receivedAt));
      }
      // Recebida, mas sem protocolo legível: trata como pendente de
      // confirmação em vez de inventar um identificador.
      throw const BackendUnavailable(
        'A central registrou a ocorrência, mas o protocolo ainda não chegou.',
      );
    }

    final uploads = (response['uploads'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return _SessionResult.uploads(uploads);
  }

  Future<void> _uploadPending(
    QueuedOccurrence occurrence,
    List<Map<String, dynamic>> uploads,
  ) async {
    for (final upload in uploads) {
      final id = upload['id'] as String;
      final evidence =
          occurrence.evidence.where((item) => item.id == id).firstOrNull;
      if (evidence == null) continue;
      // Retomada: o que já subiu não sobe de novo.
      if (evidence.isUploaded) continue;

      final bytes = await readEvidence(evidence);
      await backend.upload(
        Uri.parse(upload['signedUrl'] as String),
        bytes,
        evidence.mimeType,
      );
      await store.markEvidenceUploaded(evidence.id, _clock());
    }
  }

  String _friendly(Object error) {
    if (error is BackendUnavailable) return error.message;
    if (error is EvidenceMissing) return error.message;
    return 'Não foi possível concluir o envio agora. '
        'A ocorrência continua guardada e será reenviada.';
  }
}

/// Falha que nenhuma nova tentativa resolve.
class PermanentQueueFailure implements Exception {
  const PermanentQueueFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// O arquivo da evidência sumiu do aparelho.
class EvidenceMissing implements Exception {
  const EvidenceMissing(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Comprovante de recebimento devolvido pela central.
@immutable
class QueueReceipt {
  const QueueReceipt({required this.protocol, required this.receivedAt});
  final String protocol;
  final DateTime receivedAt;
}

@immutable
class _SessionResult {
  const _SessionResult.uploads(this.uploads) : receipt = null;

  _SessionResult.received(String protocol, DateTime receivedAt)
      : receipt = QueueReceipt(protocol: protocol, receivedAt: receivedAt),
        uploads = const [];

  /// Preenchido apenas quando o servidor já tinha a ocorrência como recebida.
  final QueueReceipt? receipt;
  final List<Map<String, dynamic>> uploads;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
