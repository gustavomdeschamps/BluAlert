import 'package:drift/drift.dart';

import 'queue_models.dart';

part 'queue_database.g.dart';

/// Ocorrências aguardando envio.
///
/// `id` é o UUID gerado no cliente e usado como chave de idempotência no
/// servidor — a mesma linha nunca vira duas ocorrências, mesmo que o envio seja
/// repetido depois de uma queda no meio do caminho.
class OutboxOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get category => text()();
  TextColumn get description => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracyM => real().nullable()();
  DateTimeColumn get locationCapturedAt => dateTime()();

  /// Origem da coordenada. Ver `LocationSource` em `queue_models.dart`.
  /// Padrão `gps` (índice 0) para as ocorrências gravadas antes do esquema 2.
  IntColumn get locationSource =>
      intEnum<LocationSource>().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get status => intEnum<QueueStatus>()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get protocol => text().nullable()();
  DateTimeColumn get receivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Evidências copiadas para o diretório privado do aplicativo.
class OutboxEvidence extends Table {
  TextColumn get id => text()();
  TextColumn get occurrenceId =>
      text().references(OutboxOccurrences, #id, onDelete: KeyAction.cascade)();
  IntColumn get kind => intEnum<EvidenceKind>()();
  TextColumn get localPath => text()();
  TextColumn get mimeType => text()();
  IntColumn get byteSize => integer()();
  TextColumn get sha256 => text()();
  DateTimeColumn get uploadedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [OutboxOccurrences, OutboxEvidence])
class QueueDatabase extends _$QueueDatabase {
  QueueDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          // Esquema 2 acrescenta a origem da coordenada. A migração é
          // incremental e preserva ocorrências que já estavam na fila do
          // aparelho — perder um registro pendente aqui significaria perder o
          // pedido de ajuda de alguém.
          if (from < 2) {
            await migrator.addColumn(
              outboxOccurrences,
              outboxOccurrences.locationSource,
            );
          }
        },
        beforeOpen: (details) async {
          // Sem isto o SQLite ignora as chaves estrangeiras e uma evidência
          // poderia sobreviver à ocorrência que a originou.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
