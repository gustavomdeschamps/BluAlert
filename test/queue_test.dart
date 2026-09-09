// Testes do motor da fila offline.
//
// A regra central do piloto está codificada aqui: nada é apresentado como
// recebido antes de a central devolver um protocolo. Vários destes testes
// existem para impedir exatamente isso.
import 'dart:typed_data';

import 'package:blualert/backend_client.dart';
import 'package:blualert/queue/occurrence_queue.dart';
import 'package:blualert/queue/queue_models.dart';
import 'package:blualert/queue/queue_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backend controlado pelo teste.
class FakeBackend extends BackendClient {
  FakeBackend();

  final List<String> calls = [];
  final List<Uri> uploaded = [];

  /// Respostas por função; uma exceção aqui simula indisponibilidade.
  Map<String, Object? Function(Map<String, Object?>)> handlers = {};

  @override
  Future<Map<String, dynamic>> invoke(
      String function, Map<String, Object?> body) async {
    calls.add(function);
    final handler = handlers[function];
    if (handler == null) {
      throw const BackendUnavailable('Função não configurada no teste.');
    }
    final result = handler(body);
    if (result is Exception) throw result;
    return Map<String, dynamic>.from(result! as Map);
  }

  @override
  Future<void> upload(Uri signedUrl, Uint8List bytes, String mimeType) async {
    uploaded.add(signedUrl);
    if (onUpload != null) await onUpload!(signedUrl);
  }

  Future<void> Function(Uri)? onUpload;
}

QueuedOccurrence buildOccurrence({
  String id = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
  List<QueuedEvidence>? evidence,
}) {
  final now = DateTime(2026, 9, 9, 10);
  return QueuedOccurrence(
    id: id,
    idempotencyKey: id,
    category: 'flood',
    description: 'Água subindo rapidamente e já alcançou a calçada da rua.',
    latitude: -26.9194,
    longitude: -49.0661,
    accuracyM: 12.5,
    locationCapturedAt: now,
    createdAt: now,
    status: QueueStatus.savedOnDevice,
    attempts: 0,
    evidence: evidence ??
        [
          QueuedEvidence(
            id: 'photo-1',
            occurrenceId: id,
            kind: EvidenceKind.photo,
            localPath: '/tmp/photo.jpg',
            mimeType: 'image/jpeg',
            byteSize: 1024,
            sha256: 'a' * 64,
          ),
        ],
  );
}

void main() {
  late MemoryQueueStore store;
  late FakeBackend backend;
  late DateTime now;

  OccurrenceQueue buildQueue({
    ConnectivityProbe? connectivity,
    RetryPolicy policy = const RetryPolicy(),
  }) =>
      OccurrenceQueue(
        store: store,
        backend: backend,
        readEvidence: (_) async => Uint8List.fromList([1, 2, 3]),
        connectivity: connectivity,
        policy: policy,
        clock: () => now,
      );

  void succeedSession() {
    backend.handlers['occurrence-session'] = (_) => {
          'occurrenceId': 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
          'uploads': [
            {'id': 'photo-1', 'signedUrl': 'https://storage.test/photo-1'},
          ],
        };
  }

  void succeedConfirm() {
    backend.handlers['occurrence-confirm'] = (_) => {
          'id': 'BLU-20260909-AAAAAAAA',
          'receivedAt': '2026-09-09T10:05:00.000Z',
        };
  }

  setUp(() {
    store = MemoryQueueStore();
    backend = FakeBackend();
    now = DateTime(2026, 9, 9, 10);
  });

  tearDown(() => store.close());

  group('estados nunca mentem sobre o envio', () {
    test('a ocorrência entra na fila como salva no aparelho', () async {
      final queue = buildQueue();
      final queued = await queue.enqueue(buildOccurrence());

      expect(queued.status, QueueStatus.savedOnDevice);
      expect(queued.status.label, 'Salvo no aparelho');
      expect(queued.protocol, isNull);
    });

    test('nenhum estado pendente usa a palavra "enviado"', () {
      for (final status in QueueStatus.values) {
        if (status == QueueStatus.receivedByCentral) continue;
        expect(
          status.label.toLowerCase(),
          isNot(contains('enviad')),
          reason: '${status.name} não pode sugerir que a central recebeu',
        );
      }
    });

    test('só o estado confirmado afirma recebimento', () {
      expect(QueueStatus.receivedByCentral.label, 'Recebido pela central');
      expect(QueueStatus.receivedByCentral.isPending, isFalse);
    });
  });

  group('sem conexão', () {
    test('aguarda conexão sem gastar tentativa', () async {
      final queue = buildQueue(connectivity: () async => false);
      await queue.enqueue(buildOccurrence());

      await queue.drain();

      final stored = (await store.all()).single;
      expect(stored.status, QueueStatus.waitingConnection);
      expect(stored.attempts, 0, reason: 'falta de rede não é falha de envio');
      expect(backend.calls, isEmpty);
    });

    test('envia assim que a conexão volta', () async {
      var online = false;
      final queue = buildQueue(connectivity: () async => online);
      await queue.enqueue(buildOccurrence());
      await queue.drain();
      expect((await store.all()).single.status, QueueStatus.waitingConnection);

      online = true;
      succeedSession();
      succeedConfirm();
      await queue.drain();

      final stored = (await store.all()).single;
      expect(stored.status, QueueStatus.receivedByCentral);
      expect(stored.protocol, 'BLU-20260909-AAAAAAAA');
    });
  });

  group('envio completo', () {
    test('confirma somente com protocolo do servidor', () async {
      final queue = buildQueue();
      await queue.enqueue(buildOccurrence());
      succeedSession();
      succeedConfirm();

      await queue.drain();

      final stored = (await store.all()).single;
      expect(stored.status, QueueStatus.receivedByCentral);
      expect(stored.protocol, 'BLU-20260909-AAAAAAAA');
      expect(stored.receivedAt, isNotNull);
      expect(backend.uploaded, hasLength(1));
    });

    test('sem protocolo na resposta, não marca como recebida', () async {
      final queue = buildQueue();
      await queue.enqueue(buildOccurrence());
      succeedSession();
      // Servidor responde 200 mas sem identificador: não é confirmação.
      backend.handlers['occurrence-confirm'] = (_) => {'status': 'ok'};

      await queue.drain();

      final stored = (await store.all()).single;
      expect(stored.status, isNot(QueueStatus.receivedByCentral));
      expect(stored.protocol, isNull);
      expect(stored.attempts, 1);
    });
  });

  group('idempotência', () {
    test('ocorrência já recebida no servidor não duplica', () async {
      final queue = buildQueue();
      await queue.enqueue(buildOccurrence());
      // Uma tentativa anterior chegou ao fim, mas a resposta se perdeu.
      backend.handlers['occurrence-session'] = (_) => {
            'alreadyReceived': true,
            'occurrence': {
              'protocol': 'BLU-20260909-ANTERIOR',
              'received_at': '2026-09-09T09:00:00.000Z',
            },
          };

      await queue.drain();

      final stored = (await store.all()).single;
      expect(stored.status, QueueStatus.receivedByCentral);
      expect(stored.protocol, 'BLU-20260909-ANTERIOR');
      expect(backend.uploaded, isEmpty,
          reason: 'não reenvia mídia de ocorrência já recebida');
      expect(backend.calls, isNot(contains('occurrence-confirm')));
    });

    test('a chave de idempotência acompanha a ocorrência', () async {
      final queue = buildQueue();
      final occurrence = buildOccurrence();
      await queue.enqueue(occurrence);
      Map<String, Object?>? sent;
      backend.handlers['occurrence-session'] = (body) {
        sent = body;
        return {'occurrenceId': occurrence.id, 'uploads': const []};
      };
      succeedConfirm();

      await queue.drain();

      expect(sent!['idempotencyKey'], occurrence.id);
      expect(sent!['occurrenceId'], occurrence.id);
    });
  });

  group('upload interrompido', () {
    test('a retomada não reenvia a evidência que já subiu', () async {
      final id = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
      final occurrence = buildOccurrence(evidence: [
        QueuedEvidence(
          id: 'photo-1',
          occurrenceId: id,
          kind: EvidenceKind.photo,
          localPath: '/tmp/photo.jpg',
          mimeType: 'image/jpeg',
          byteSize: 1024,
          sha256: 'a' * 64,
        ),
        QueuedEvidence(
          id: 'video-1',
          occurrenceId: id,
          kind: EvidenceKind.video,
          localPath: '/tmp/video.mp4',
          mimeType: 'video/mp4',
          byteSize: 2048,
          sha256: 'b' * 64,
        ),
      ]);
      final queue = buildQueue();
      await queue.enqueue(occurrence);
      backend.handlers['occurrence-session'] = (_) => {
            'occurrenceId': id,
            'uploads': [
              {'id': 'photo-1', 'signedUrl': 'https://storage.test/photo-1'},
              {'id': 'video-1', 'signedUrl': 'https://storage.test/video-1'},
            ],
          };
      // A conexão cai no meio do segundo arquivo.
      backend.onUpload = (url) async {
        if (url.path.endsWith('video-1')) {
          throw const BackendUnavailable('Conexão perdida durante o envio.');
        }
      };

      await queue.drain();

      var stored = (await store.all()).single;
      expect(stored.status, QueueStatus.waitingConnection);
      expect(stored.evidence.firstWhere((e) => e.id == 'photo-1').isUploaded,
          isTrue);
      expect(stored.evidence.firstWhere((e) => e.id == 'video-1').isUploaded,
          isFalse);

      // Segunda tentativa: só o vídeo sobe de novo.
      backend.onUpload = null;
      backend.uploaded.clear();
      succeedConfirm();
      now = now.add(const Duration(minutes: 5));
      await queue.drain();

      stored = (await store.all()).single;
      expect(stored.status, QueueStatus.receivedByCentral);
      expect(backend.uploaded.map((u) => u.path),
          everyElement(contains('video-1')));
      expect(backend.uploaded, hasLength(1));
    });
  });

  group('recuo e limite de tentativas', () {
    test('a espera cresce e respeita o teto', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 10),
        maxDelay: Duration(minutes: 5),
        maxAttempts: 8,
      );
      expect(policy.delayFor(1), const Duration(seconds: 10));
      expect(policy.delayFor(2), const Duration(seconds: 20));
      expect(policy.delayFor(3), const Duration(seconds: 40));
      expect(policy.delayFor(20), const Duration(minutes: 5));
      expect(policy.delayFor(500), const Duration(minutes: 5),
          reason: 'não pode estourar o inteiro nem passar do teto');
    });

    test('uma falha agenda a próxima tentativa no futuro', () async {
      final queue = buildQueue();
      await queue.enqueue(buildOccurrence());
      backend.handlers['occurrence-session'] =
          (_) => const BackendUnavailable('Servidor fora do ar.');

      await queue.drain();

      final stored = (await store.all()).single;
      expect(stored.status, QueueStatus.waitingConnection);
      expect(stored.attempts, 1);
      expect(stored.lastError, 'Servidor fora do ar.');
      expect(stored.nextAttemptAt!.isAfter(now), isTrue);
      expect(stored.isReady(now), isFalse,
          reason: 'não pode tentar antes do tempo');
    });

    test('esgotadas as tentativas, exige ação e não descarta', () async {
      final queue = buildQueue(
        policy: const RetryPolicy(
          initialDelay: Duration(seconds: 1),
          maxAttempts: 3,
        ),
      );
      await queue.enqueue(buildOccurrence());
      backend.handlers['occurrence-session'] =
          (_) => const BackendUnavailable('Servidor fora do ar.');

      for (var i = 0; i < 5; i++) {
        now = now.add(const Duration(hours: 1));
        await queue.drain();
      }

      final stored = (await store.all()).single;
      expect(stored.status, QueueStatus.actionRequired);
      expect(stored.attempts, 3, reason: 'para no limite, sem retry infinito');
      expect(await store.all(), hasLength(1),
          reason: 'a ocorrência continua guardada, nunca é descartada');
    });

    test('a retomada manual zera o recuo', () async {
      final queue = buildQueue(
        policy: const RetryPolicy(maxAttempts: 1),
      );
      final occurrence = buildOccurrence();
      await queue.enqueue(occurrence);
      backend.handlers['occurrence-session'] =
          (_) => const BackendUnavailable('Servidor fora do ar.');
      await queue.drain();
      expect((await store.all()).single.status, QueueStatus.actionRequired);

      succeedSession();
      succeedConfirm();
      await queue.retryNow(occurrence.id);

      final stored = (await store.all()).single;
      expect(stored.status, QueueStatus.receivedByCentral);
    });
  });

  group('Supabase indisponível', () {
    test('a ocorrência sobrevive e continua pendente', () async {
      final queue = buildQueue();
      await queue.enqueue(buildOccurrence());
      backend.handlers['occurrence-session'] =
          (_) => const BackendUnavailable('O canal piloto está indisponível.');

      await queue.drain();

      final stored = (await store.all()).single;
      expect(stored.status.isPending, isTrue);
      expect(stored.status, isNot(QueueStatus.receivedByCentral));
      expect(stored.lastError, contains('indisponível'));
    });
  });

  group('descarte', () {
    test('não remove ocorrência já recebida', () async {
      final queue = buildQueue();
      final occurrence = buildOccurrence();
      await queue.enqueue(occurrence);
      succeedSession();
      succeedConfirm();
      await queue.drain();

      await queue.discard(occurrence.id);

      expect(await store.all(), hasLength(1),
          reason: 'um registro confirmado é histórico, não rascunho');
    });

    test('remove ocorrência pendente a pedido da pessoa', () async {
      final queue = buildQueue(connectivity: () async => false);
      final occurrence = buildOccurrence();
      await queue.enqueue(occurrence);

      await queue.discard(occurrence.id);

      expect(await store.all(), isEmpty);
    });
  });
}
