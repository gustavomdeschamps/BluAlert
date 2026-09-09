import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'queue_database.dart';
import 'queue_models.dart';
import 'queue_store.dart';

/// Abre a fila em SQLite, no diretório privado do aplicativo.
Future<QueueStore> openQueueStore() async {
  final directory = await getApplicationSupportDirectory();
  final file = File(p.join(directory.path, 'blualert_queue.sqlite'));
  await file.parent.create(recursive: true);
  return DriftQueueStore(
    QueueDatabase(NativeDatabase.createInBackground(file)),
  );
}

/// Fila persistida em SQLite. É a implementação usada no Android — o destino
/// real do piloto — e a única que sobrevive ao fechamento do aplicativo.
class DriftQueueStore implements QueueStore {
  DriftQueueStore(this.database);

  final QueueDatabase database;

  @override
  bool get isDurable => true;

  @override
  Future<void> insert(QueuedOccurrence occurrence) async {
    await database.transaction(() async {
      await database
          .into(database.outboxOccurrences)
          .insert(_toRow(occurrence), mode: InsertMode.insertOrReplace);
      for (final item in occurrence.evidence) {
        await database
            .into(database.outboxEvidence)
            .insert(_toEvidenceRow(item), mode: InsertMode.insertOrReplace);
      }
    });
  }

  @override
  Future<void> update(QueuedOccurrence occurrence) async {
    await (database.update(database.outboxOccurrences)
          ..where((row) => row.id.equals(occurrence.id)))
        .write(_toRow(occurrence));
  }

  @override
  Future<void> markEvidenceUploaded(
      String evidenceId, DateTime uploadedAt) async {
    await (database.update(database.outboxEvidence)
          ..where((row) => row.id.equals(evidenceId)))
        .write(OutboxEvidenceCompanion(uploadedAt: Value(uploadedAt)));
  }

  @override
  Future<QueuedOccurrence?> byId(String id) async {
    final row = await (database.select(database.outboxOccurrences)
          ..where((item) => item.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _withEvidence(row);
  }

  @override
  Future<List<QueuedOccurrence>> all() async {
    final rows = await (database.select(database.outboxOccurrences)
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .get();
    return _hydrate(rows);
  }

  @override
  Future<List<QueuedOccurrence>> ready(DateTime now) async {
    final items = await all();
    return items.where((item) => item.isReady(now)).toList();
  }

  @override
  Stream<List<QueuedOccurrence>> watch() {
    // Observa as duas tabelas: marcar uma evidência como enviada também muda o
    // que a interface precisa mostrar.
    final query = database.select(database.outboxOccurrences)
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch().asyncMap(_hydrate);
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(database.outboxOccurrences)
          ..where((row) => row.id.equals(id)))
        .go();
  }

  @override
  Future<void> close() => database.close();

  Future<List<QueuedOccurrence>> _hydrate(List<OutboxOccurrence> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row.id).toList();
    // Uma consulta só para todas as evidências, em vez de uma por ocorrência.
    final evidenceRows = await (database.select(database.outboxEvidence)
          ..where((row) => row.occurrenceId.isIn(ids)))
        .get();
    final grouped = <String, List<QueuedEvidence>>{};
    for (final item in evidenceRows) {
      grouped.putIfAbsent(item.occurrenceId, () => []).add(_toEvidence(item));
    }
    return rows
        .map((row) => _toOccurrence(row, grouped[row.id] ?? const []))
        .toList();
  }

  Future<QueuedOccurrence> _withEvidence(OutboxOccurrence row) async {
    final evidenceRows = await (database.select(database.outboxEvidence)
          ..where((item) => item.occurrenceId.equals(row.id)))
        .get();
    return _toOccurrence(row, evidenceRows.map(_toEvidence).toList());
  }

  OutboxOccurrencesCompanion _toRow(QueuedOccurrence occurrence) =>
      OutboxOccurrencesCompanion(
        id: Value(occurrence.id),
        idempotencyKey: Value(occurrence.idempotencyKey),
        category: Value(occurrence.category),
        description: Value(occurrence.description),
        latitude: Value(occurrence.latitude),
        longitude: Value(occurrence.longitude),
        accuracyM: Value(occurrence.accuracyM),
        locationCapturedAt: Value(occurrence.locationCapturedAt),
        createdAt: Value(occurrence.createdAt),
        status: Value(occurrence.status),
        attempts: Value(occurrence.attempts),
        lastError: Value(occurrence.lastError),
        nextAttemptAt: Value(occurrence.nextAttemptAt),
        protocol: Value(occurrence.protocol),
        receivedAt: Value(occurrence.receivedAt),
      );

  OutboxEvidenceCompanion _toEvidenceRow(QueuedEvidence evidence) =>
      OutboxEvidenceCompanion(
        id: Value(evidence.id),
        occurrenceId: Value(evidence.occurrenceId),
        kind: Value(evidence.kind),
        localPath: Value(evidence.localPath),
        mimeType: Value(evidence.mimeType),
        byteSize: Value(evidence.byteSize),
        sha256: Value(evidence.sha256),
        uploadedAt: Value(evidence.uploadedAt),
      );

  QueuedOccurrence _toOccurrence(
    OutboxOccurrence row,
    List<QueuedEvidence> evidence,
  ) =>
      QueuedOccurrence(
        id: row.id,
        idempotencyKey: row.idempotencyKey,
        category: row.category,
        description: row.description,
        latitude: row.latitude,
        longitude: row.longitude,
        accuracyM: row.accuracyM,
        locationCapturedAt: row.locationCapturedAt,
        createdAt: row.createdAt,
        status: row.status,
        attempts: row.attempts,
        lastError: row.lastError,
        nextAttemptAt: row.nextAttemptAt,
        protocol: row.protocol,
        receivedAt: row.receivedAt,
        evidence: evidence,
      );

  QueuedEvidence _toEvidence(OutboxEvidenceData row) => QueuedEvidence(
        id: row.id,
        occurrenceId: row.occurrenceId,
        kind: row.kind,
        localPath: row.localPath,
        mimeType: row.mimeType,
        byteSize: row.byteSize,
        sha256: row.sha256,
        uploadedAt: row.uploadedAt,
      );
}
