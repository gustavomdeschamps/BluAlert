// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_database.dart';

// ignore_for_file: type=lint
class $OutboxOccurrencesTable extends OutboxOccurrences
    with TableInfo<$OutboxOccurrencesTable, OutboxOccurrence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxOccurrencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idempotencyKeyMeta =
      const VerificationMeta('idempotencyKey');
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
      'idempotency_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _accuracyMMeta =
      const VerificationMeta('accuracyM');
  @override
  late final GeneratedColumn<double> accuracyM = GeneratedColumn<double>(
      'accuracy_m', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _locationCapturedAtMeta =
      const VerificationMeta('locationCapturedAt');
  @override
  late final GeneratedColumn<DateTime> locationCapturedAt =
      GeneratedColumn<DateTime>('location_captured_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<LocationSource, int>
      locationSource = GeneratedColumn<int>(
              'location_source', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(0))
          .withConverter<LocationSource>(
              $OutboxOccurrencesTable.$converterlocationSource);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<QueueStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<QueueStatus>($OutboxOccurrencesTable.$converterstatus);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nextAttemptAtMeta =
      const VerificationMeta('nextAttemptAt');
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>('next_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _protocolMeta =
      const VerificationMeta('protocol');
  @override
  late final GeneratedColumn<String> protocol = GeneratedColumn<String>(
      'protocol', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
      'received_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        idempotencyKey,
        category,
        description,
        latitude,
        longitude,
        accuracyM,
        locationCapturedAt,
        locationSource,
        createdAt,
        status,
        attempts,
        lastError,
        nextAttemptAt,
        protocol,
        receivedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_occurrences';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxOccurrence> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
          _idempotencyKeyMeta,
          idempotencyKey.isAcceptableOrUnknown(
              data['idempotency_key']!, _idempotencyKeyMeta));
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('accuracy_m')) {
      context.handle(_accuracyMMeta,
          accuracyM.isAcceptableOrUnknown(data['accuracy_m']!, _accuracyMMeta));
    }
    if (data.containsKey('location_captured_at')) {
      context.handle(
          _locationCapturedAtMeta,
          locationCapturedAt.isAcceptableOrUnknown(
              data['location_captured_at']!, _locationCapturedAtMeta));
    } else if (isInserting) {
      context.missing(_locationCapturedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
          _nextAttemptAtMeta,
          nextAttemptAt.isAcceptableOrUnknown(
              data['next_attempt_at']!, _nextAttemptAtMeta));
    }
    if (data.containsKey('protocol')) {
      context.handle(_protocolMeta,
          protocol.isAcceptableOrUnknown(data['protocol']!, _protocolMeta));
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxOccurrence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxOccurrence(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      idempotencyKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}idempotency_key'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude'])!,
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude'])!,
      accuracyM: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}accuracy_m']),
      locationCapturedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}location_captured_at'])!,
      locationSource: $OutboxOccurrencesTable.$converterlocationSource.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.int, data['${effectivePrefix}location_source'])!),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      status: $OutboxOccurrencesTable.$converterstatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      nextAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}next_attempt_at']),
      protocol: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}protocol']),
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}received_at']),
    );
  }

  @override
  $OutboxOccurrencesTable createAlias(String alias) {
    return $OutboxOccurrencesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LocationSource, int, int> $converterlocationSource =
      const EnumIndexConverter<LocationSource>(LocationSource.values);
  static JsonTypeConverter2<QueueStatus, int, int> $converterstatus =
      const EnumIndexConverter<QueueStatus>(QueueStatus.values);
}

class OutboxOccurrence extends DataClass
    implements Insertable<OutboxOccurrence> {
  final String id;
  final String idempotencyKey;
  final String category;
  final String description;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final DateTime locationCapturedAt;

  /// Origem da coordenada. Ver `LocationSource` em `queue_models.dart`.
  /// Padrão `gps` (índice 0) para as ocorrências gravadas antes do esquema 2.
  final LocationSource locationSource;
  final DateTime createdAt;
  final QueueStatus status;
  final int attempts;
  final String? lastError;
  final DateTime? nextAttemptAt;
  final String? protocol;
  final DateTime? receivedAt;
  const OutboxOccurrence(
      {required this.id,
      required this.idempotencyKey,
      required this.category,
      required this.description,
      required this.latitude,
      required this.longitude,
      this.accuracyM,
      required this.locationCapturedAt,
      required this.locationSource,
      required this.createdAt,
      required this.status,
      required this.attempts,
      this.lastError,
      this.nextAttemptAt,
      this.protocol,
      this.receivedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['category'] = Variable<String>(category);
    map['description'] = Variable<String>(description);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || accuracyM != null) {
      map['accuracy_m'] = Variable<double>(accuracyM);
    }
    map['location_captured_at'] = Variable<DateTime>(locationCapturedAt);
    {
      map['location_source'] = Variable<int>($OutboxOccurrencesTable
          .$converterlocationSource
          .toSql(locationSource));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    {
      map['status'] =
          Variable<int>($OutboxOccurrencesTable.$converterstatus.toSql(status));
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || protocol != null) {
      map['protocol'] = Variable<String>(protocol);
    }
    if (!nullToAbsent || receivedAt != null) {
      map['received_at'] = Variable<DateTime>(receivedAt);
    }
    return map;
  }

  OutboxOccurrencesCompanion toCompanion(bool nullToAbsent) {
    return OutboxOccurrencesCompanion(
      id: Value(id),
      idempotencyKey: Value(idempotencyKey),
      category: Value(category),
      description: Value(description),
      latitude: Value(latitude),
      longitude: Value(longitude),
      accuracyM: accuracyM == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracyM),
      locationCapturedAt: Value(locationCapturedAt),
      locationSource: Value(locationSource),
      createdAt: Value(createdAt),
      status: Value(status),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      protocol: protocol == null && nullToAbsent
          ? const Value.absent()
          : Value(protocol),
      receivedAt: receivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedAt),
    );
  }

  factory OutboxOccurrence.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxOccurrence(
      id: serializer.fromJson<String>(json['id']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      category: serializer.fromJson<String>(json['category']),
      description: serializer.fromJson<String>(json['description']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      accuracyM: serializer.fromJson<double?>(json['accuracyM']),
      locationCapturedAt:
          serializer.fromJson<DateTime>(json['locationCapturedAt']),
      locationSource: $OutboxOccurrencesTable.$converterlocationSource
          .fromJson(serializer.fromJson<int>(json['locationSource'])),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: $OutboxOccurrencesTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      protocol: serializer.fromJson<String?>(json['protocol']),
      receivedAt: serializer.fromJson<DateTime?>(json['receivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'category': serializer.toJson<String>(category),
      'description': serializer.toJson<String>(description),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'accuracyM': serializer.toJson<double?>(accuracyM),
      'locationCapturedAt': serializer.toJson<DateTime>(locationCapturedAt),
      'locationSource': serializer.toJson<int>($OutboxOccurrencesTable
          .$converterlocationSource
          .toJson(locationSource)),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer
          .toJson<int>($OutboxOccurrencesTable.$converterstatus.toJson(status)),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'protocol': serializer.toJson<String?>(protocol),
      'receivedAt': serializer.toJson<DateTime?>(receivedAt),
    };
  }

  OutboxOccurrence copyWith(
          {String? id,
          String? idempotencyKey,
          String? category,
          String? description,
          double? latitude,
          double? longitude,
          Value<double?> accuracyM = const Value.absent(),
          DateTime? locationCapturedAt,
          LocationSource? locationSource,
          DateTime? createdAt,
          QueueStatus? status,
          int? attempts,
          Value<String?> lastError = const Value.absent(),
          Value<DateTime?> nextAttemptAt = const Value.absent(),
          Value<String?> protocol = const Value.absent(),
          Value<DateTime?> receivedAt = const Value.absent()}) =>
      OutboxOccurrence(
        id: id ?? this.id,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        category: category ?? this.category,
        description: description ?? this.description,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        accuracyM: accuracyM.present ? accuracyM.value : this.accuracyM,
        locationCapturedAt: locationCapturedAt ?? this.locationCapturedAt,
        locationSource: locationSource ?? this.locationSource,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        lastError: lastError.present ? lastError.value : this.lastError,
        nextAttemptAt:
            nextAttemptAt.present ? nextAttemptAt.value : this.nextAttemptAt,
        protocol: protocol.present ? protocol.value : this.protocol,
        receivedAt: receivedAt.present ? receivedAt.value : this.receivedAt,
      );
  OutboxOccurrence copyWithCompanion(OutboxOccurrencesCompanion data) {
    return OutboxOccurrence(
      id: data.id.present ? data.id.value : this.id,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      category: data.category.present ? data.category.value : this.category,
      description:
          data.description.present ? data.description.value : this.description,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      accuracyM: data.accuracyM.present ? data.accuracyM.value : this.accuracyM,
      locationCapturedAt: data.locationCapturedAt.present
          ? data.locationCapturedAt.value
          : this.locationCapturedAt,
      locationSource: data.locationSource.present
          ? data.locationSource.value
          : this.locationSource,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      protocol: data.protocol.present ? data.protocol.value : this.protocol,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOccurrence(')
          ..write('id: $id, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('locationCapturedAt: $locationCapturedAt, ')
          ..write('locationSource: $locationSource, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('protocol: $protocol, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      idempotencyKey,
      category,
      description,
      latitude,
      longitude,
      accuracyM,
      locationCapturedAt,
      locationSource,
      createdAt,
      status,
      attempts,
      lastError,
      nextAttemptAt,
      protocol,
      receivedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxOccurrence &&
          other.id == this.id &&
          other.idempotencyKey == this.idempotencyKey &&
          other.category == this.category &&
          other.description == this.description &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.accuracyM == this.accuracyM &&
          other.locationCapturedAt == this.locationCapturedAt &&
          other.locationSource == this.locationSource &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.protocol == this.protocol &&
          other.receivedAt == this.receivedAt);
}

class OutboxOccurrencesCompanion extends UpdateCompanion<OutboxOccurrence> {
  final Value<String> id;
  final Value<String> idempotencyKey;
  final Value<String> category;
  final Value<String> description;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double?> accuracyM;
  final Value<DateTime> locationCapturedAt;
  final Value<LocationSource> locationSource;
  final Value<DateTime> createdAt;
  final Value<QueueStatus> status;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> protocol;
  final Value<DateTime?> receivedAt;
  final Value<int> rowid;
  const OutboxOccurrencesCompanion({
    this.id = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracyM = const Value.absent(),
    this.locationCapturedAt = const Value.absent(),
    this.locationSource = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.protocol = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxOccurrencesCompanion.insert({
    required String id,
    required String idempotencyKey,
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    this.accuracyM = const Value.absent(),
    required DateTime locationCapturedAt,
    this.locationSource = const Value.absent(),
    required DateTime createdAt,
    required QueueStatus status,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.protocol = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        idempotencyKey = Value(idempotencyKey),
        category = Value(category),
        description = Value(description),
        latitude = Value(latitude),
        longitude = Value(longitude),
        locationCapturedAt = Value(locationCapturedAt),
        createdAt = Value(createdAt),
        status = Value(status);
  static Insertable<OutboxOccurrence> custom({
    Expression<String>? id,
    Expression<String>? idempotencyKey,
    Expression<String>? category,
    Expression<String>? description,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? accuracyM,
    Expression<DateTime>? locationCapturedAt,
    Expression<int>? locationSource,
    Expression<DateTime>? createdAt,
    Expression<int>? status,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? protocol,
    Expression<DateTime>? receivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (locationCapturedAt != null)
        'location_captured_at': locationCapturedAt,
      if (locationSource != null) 'location_source': locationSource,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (protocol != null) 'protocol': protocol,
      if (receivedAt != null) 'received_at': receivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxOccurrencesCompanion copyWith(
      {Value<String>? id,
      Value<String>? idempotencyKey,
      Value<String>? category,
      Value<String>? description,
      Value<double>? latitude,
      Value<double>? longitude,
      Value<double?>? accuracyM,
      Value<DateTime>? locationCapturedAt,
      Value<LocationSource>? locationSource,
      Value<DateTime>? createdAt,
      Value<QueueStatus>? status,
      Value<int>? attempts,
      Value<String?>? lastError,
      Value<DateTime?>? nextAttemptAt,
      Value<String?>? protocol,
      Value<DateTime?>? receivedAt,
      Value<int>? rowid}) {
    return OutboxOccurrencesCompanion(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      category: category ?? this.category,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyM: accuracyM ?? this.accuracyM,
      locationCapturedAt: locationCapturedAt ?? this.locationCapturedAt,
      locationSource: locationSource ?? this.locationSource,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      protocol: protocol ?? this.protocol,
      receivedAt: receivedAt ?? this.receivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (accuracyM.present) {
      map['accuracy_m'] = Variable<double>(accuracyM.value);
    }
    if (locationCapturedAt.present) {
      map['location_captured_at'] =
          Variable<DateTime>(locationCapturedAt.value);
    }
    if (locationSource.present) {
      map['location_source'] = Variable<int>($OutboxOccurrencesTable
          .$converterlocationSource
          .toSql(locationSource.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
          $OutboxOccurrencesTable.$converterstatus.toSql(status.value));
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (protocol.present) {
      map['protocol'] = Variable<String>(protocol.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOccurrencesCompanion(')
          ..write('id: $id, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('locationCapturedAt: $locationCapturedAt, ')
          ..write('locationSource: $locationSource, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('protocol: $protocol, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxEvidenceTable extends OutboxEvidence
    with TableInfo<$OutboxEvidenceTable, OutboxEvidenceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEvidenceTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _occurrenceIdMeta =
      const VerificationMeta('occurrenceId');
  @override
  late final GeneratedColumn<String> occurrenceId = GeneratedColumn<String>(
      'occurrence_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES outbox_occurrences (id) ON DELETE CASCADE'));
  @override
  late final GeneratedColumnWithTypeConverter<EvidenceKind, int> kind =
      GeneratedColumn<int>('kind', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<EvidenceKind>($OutboxEvidenceTable.$converterkind);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _byteSizeMeta =
      const VerificationMeta('byteSize');
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
      'byte_size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
      'sha256', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _uploadedAtMeta =
      const VerificationMeta('uploadedAt');
  @override
  late final GeneratedColumn<DateTime> uploadedAt = GeneratedColumn<DateTime>(
      'uploaded_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        occurrenceId,
        kind,
        localPath,
        mimeType,
        byteSize,
        sha256,
        uploadedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_evidence';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxEvidenceData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('occurrence_id')) {
      context.handle(
          _occurrenceIdMeta,
          occurrenceId.isAcceptableOrUnknown(
              data['occurrence_id']!, _occurrenceIdMeta));
    } else if (isInserting) {
      context.missing(_occurrenceIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(_byteSizeMeta,
          byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta));
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(_sha256Meta,
          sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta));
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('uploaded_at')) {
      context.handle(
          _uploadedAtMeta,
          uploadedAt.isAcceptableOrUnknown(
              data['uploaded_at']!, _uploadedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEvidenceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEvidenceData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      occurrenceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}occurrence_id'])!,
      kind: $OutboxEvidenceTable.$converterkind.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}kind'])!),
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path'])!,
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type'])!,
      byteSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}byte_size'])!,
      sha256: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sha256'])!,
      uploadedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}uploaded_at']),
    );
  }

  @override
  $OutboxEvidenceTable createAlias(String alias) {
    return $OutboxEvidenceTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EvidenceKind, int, int> $converterkind =
      const EnumIndexConverter<EvidenceKind>(EvidenceKind.values);
}

class OutboxEvidenceData extends DataClass
    implements Insertable<OutboxEvidenceData> {
  final String id;
  final String occurrenceId;
  final EvidenceKind kind;
  final String localPath;
  final String mimeType;
  final int byteSize;
  final String sha256;
  final DateTime? uploadedAt;
  const OutboxEvidenceData(
      {required this.id,
      required this.occurrenceId,
      required this.kind,
      required this.localPath,
      required this.mimeType,
      required this.byteSize,
      required this.sha256,
      this.uploadedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['occurrence_id'] = Variable<String>(occurrenceId);
    {
      map['kind'] =
          Variable<int>($OutboxEvidenceTable.$converterkind.toSql(kind));
    }
    map['local_path'] = Variable<String>(localPath);
    map['mime_type'] = Variable<String>(mimeType);
    map['byte_size'] = Variable<int>(byteSize);
    map['sha256'] = Variable<String>(sha256);
    if (!nullToAbsent || uploadedAt != null) {
      map['uploaded_at'] = Variable<DateTime>(uploadedAt);
    }
    return map;
  }

  OutboxEvidenceCompanion toCompanion(bool nullToAbsent) {
    return OutboxEvidenceCompanion(
      id: Value(id),
      occurrenceId: Value(occurrenceId),
      kind: Value(kind),
      localPath: Value(localPath),
      mimeType: Value(mimeType),
      byteSize: Value(byteSize),
      sha256: Value(sha256),
      uploadedAt: uploadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadedAt),
    );
  }

  factory OutboxEvidenceData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEvidenceData(
      id: serializer.fromJson<String>(json['id']),
      occurrenceId: serializer.fromJson<String>(json['occurrenceId']),
      kind: $OutboxEvidenceTable.$converterkind
          .fromJson(serializer.fromJson<int>(json['kind'])),
      localPath: serializer.fromJson<String>(json['localPath']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      sha256: serializer.fromJson<String>(json['sha256']),
      uploadedAt: serializer.fromJson<DateTime?>(json['uploadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'occurrenceId': serializer.toJson<String>(occurrenceId),
      'kind': serializer
          .toJson<int>($OutboxEvidenceTable.$converterkind.toJson(kind)),
      'localPath': serializer.toJson<String>(localPath),
      'mimeType': serializer.toJson<String>(mimeType),
      'byteSize': serializer.toJson<int>(byteSize),
      'sha256': serializer.toJson<String>(sha256),
      'uploadedAt': serializer.toJson<DateTime?>(uploadedAt),
    };
  }

  OutboxEvidenceData copyWith(
          {String? id,
          String? occurrenceId,
          EvidenceKind? kind,
          String? localPath,
          String? mimeType,
          int? byteSize,
          String? sha256,
          Value<DateTime?> uploadedAt = const Value.absent()}) =>
      OutboxEvidenceData(
        id: id ?? this.id,
        occurrenceId: occurrenceId ?? this.occurrenceId,
        kind: kind ?? this.kind,
        localPath: localPath ?? this.localPath,
        mimeType: mimeType ?? this.mimeType,
        byteSize: byteSize ?? this.byteSize,
        sha256: sha256 ?? this.sha256,
        uploadedAt: uploadedAt.present ? uploadedAt.value : this.uploadedAt,
      );
  OutboxEvidenceData copyWithCompanion(OutboxEvidenceCompanion data) {
    return OutboxEvidenceData(
      id: data.id.present ? data.id.value : this.id,
      occurrenceId: data.occurrenceId.present
          ? data.occurrenceId.value
          : this.occurrenceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      uploadedAt:
          data.uploadedAt.present ? data.uploadedAt.value : this.uploadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEvidenceData(')
          ..write('id: $id, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('kind: $kind, ')
          ..write('localPath: $localPath, ')
          ..write('mimeType: $mimeType, ')
          ..write('byteSize: $byteSize, ')
          ..write('sha256: $sha256, ')
          ..write('uploadedAt: $uploadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, occurrenceId, kind, localPath, mimeType,
      byteSize, sha256, uploadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEvidenceData &&
          other.id == this.id &&
          other.occurrenceId == this.occurrenceId &&
          other.kind == this.kind &&
          other.localPath == this.localPath &&
          other.mimeType == this.mimeType &&
          other.byteSize == this.byteSize &&
          other.sha256 == this.sha256 &&
          other.uploadedAt == this.uploadedAt);
}

class OutboxEvidenceCompanion extends UpdateCompanion<OutboxEvidenceData> {
  final Value<String> id;
  final Value<String> occurrenceId;
  final Value<EvidenceKind> kind;
  final Value<String> localPath;
  final Value<String> mimeType;
  final Value<int> byteSize;
  final Value<String> sha256;
  final Value<DateTime?> uploadedAt;
  final Value<int> rowid;
  const OutboxEvidenceCompanion({
    this.id = const Value.absent(),
    this.occurrenceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.localPath = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxEvidenceCompanion.insert({
    required String id,
    required String occurrenceId,
    required EvidenceKind kind,
    required String localPath,
    required String mimeType,
    required int byteSize,
    required String sha256,
    this.uploadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        occurrenceId = Value(occurrenceId),
        kind = Value(kind),
        localPath = Value(localPath),
        mimeType = Value(mimeType),
        byteSize = Value(byteSize),
        sha256 = Value(sha256);
  static Insertable<OutboxEvidenceData> custom({
    Expression<String>? id,
    Expression<String>? occurrenceId,
    Expression<int>? kind,
    Expression<String>? localPath,
    Expression<String>? mimeType,
    Expression<int>? byteSize,
    Expression<String>? sha256,
    Expression<DateTime>? uploadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (kind != null) 'kind': kind,
      if (localPath != null) 'local_path': localPath,
      if (mimeType != null) 'mime_type': mimeType,
      if (byteSize != null) 'byte_size': byteSize,
      if (sha256 != null) 'sha256': sha256,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxEvidenceCompanion copyWith(
      {Value<String>? id,
      Value<String>? occurrenceId,
      Value<EvidenceKind>? kind,
      Value<String>? localPath,
      Value<String>? mimeType,
      Value<int>? byteSize,
      Value<String>? sha256,
      Value<DateTime?>? uploadedAt,
      Value<int>? rowid}) {
    return OutboxEvidenceCompanion(
      id: id ?? this.id,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      kind: kind ?? this.kind,
      localPath: localPath ?? this.localPath,
      mimeType: mimeType ?? this.mimeType,
      byteSize: byteSize ?? this.byteSize,
      sha256: sha256 ?? this.sha256,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (occurrenceId.present) {
      map['occurrence_id'] = Variable<String>(occurrenceId.value);
    }
    if (kind.present) {
      map['kind'] =
          Variable<int>($OutboxEvidenceTable.$converterkind.toSql(kind.value));
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (uploadedAt.present) {
      map['uploaded_at'] = Variable<DateTime>(uploadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEvidenceCompanion(')
          ..write('id: $id, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('kind: $kind, ')
          ..write('localPath: $localPath, ')
          ..write('mimeType: $mimeType, ')
          ..write('byteSize: $byteSize, ')
          ..write('sha256: $sha256, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$QueueDatabase extends GeneratedDatabase {
  _$QueueDatabase(QueryExecutor e) : super(e);
  $QueueDatabaseManager get managers => $QueueDatabaseManager(this);
  late final $OutboxOccurrencesTable outboxOccurrences =
      $OutboxOccurrencesTable(this);
  late final $OutboxEvidenceTable outboxEvidence = $OutboxEvidenceTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [outboxOccurrences, outboxEvidence];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('outbox_occurrences',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('outbox_evidence', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$OutboxOccurrencesTableCreateCompanionBuilder
    = OutboxOccurrencesCompanion Function({
  required String id,
  required String idempotencyKey,
  required String category,
  required String description,
  required double latitude,
  required double longitude,
  Value<double?> accuracyM,
  required DateTime locationCapturedAt,
  Value<LocationSource> locationSource,
  required DateTime createdAt,
  required QueueStatus status,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime?> nextAttemptAt,
  Value<String?> protocol,
  Value<DateTime?> receivedAt,
  Value<int> rowid,
});
typedef $$OutboxOccurrencesTableUpdateCompanionBuilder
    = OutboxOccurrencesCompanion Function({
  Value<String> id,
  Value<String> idempotencyKey,
  Value<String> category,
  Value<String> description,
  Value<double> latitude,
  Value<double> longitude,
  Value<double?> accuracyM,
  Value<DateTime> locationCapturedAt,
  Value<LocationSource> locationSource,
  Value<DateTime> createdAt,
  Value<QueueStatus> status,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime?> nextAttemptAt,
  Value<String?> protocol,
  Value<DateTime?> receivedAt,
  Value<int> rowid,
});

final class $$OutboxOccurrencesTableReferences extends BaseReferences<
    _$QueueDatabase, $OutboxOccurrencesTable, OutboxOccurrence> {
  $$OutboxOccurrencesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$OutboxEvidenceTable, List<OutboxEvidenceData>>
      _outboxEvidenceRefsTable(_$QueueDatabase db) =>
          MultiTypedResultKey.fromTable(db.outboxEvidence,
              aliasName: $_aliasNameGenerator(
                  db.outboxOccurrences.id, db.outboxEvidence.occurrenceId));

  $$OutboxEvidenceTableProcessedTableManager get outboxEvidenceRefs {
    final manager = $$OutboxEvidenceTableTableManager($_db, $_db.outboxEvidence)
        .filter(
            (f) => f.occurrenceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_outboxEvidenceRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$OutboxOccurrencesTableFilterComposer
    extends Composer<_$QueueDatabase, $OutboxOccurrencesTable> {
  $$OutboxOccurrencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get accuracyM => $composableBuilder(
      column: $table.accuracyM, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get locationCapturedAt => $composableBuilder(
      column: $table.locationCapturedAt,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<LocationSource, LocationSource, int>
      get locationSource => $composableBuilder(
          column: $table.locationSource,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<QueueStatus, QueueStatus, int> get status =>
      $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get protocol => $composableBuilder(
      column: $table.protocol, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> outboxEvidenceRefs(
      Expression<bool> Function($$OutboxEvidenceTableFilterComposer f) f) {
    final $$OutboxEvidenceTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.outboxEvidence,
        getReferencedColumn: (t) => t.occurrenceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OutboxEvidenceTableFilterComposer(
              $db: $db,
              $table: $db.outboxEvidence,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$OutboxOccurrencesTableOrderingComposer
    extends Composer<_$QueueDatabase, $OutboxOccurrencesTable> {
  $$OutboxOccurrencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get accuracyM => $composableBuilder(
      column: $table.accuracyM, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get locationCapturedAt => $composableBuilder(
      column: $table.locationCapturedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get locationSource => $composableBuilder(
      column: $table.locationSource,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get protocol => $composableBuilder(
      column: $table.protocol, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));
}

class $$OutboxOccurrencesTableAnnotationComposer
    extends Composer<_$QueueDatabase, $OutboxOccurrencesTable> {
  $$OutboxOccurrencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get accuracyM =>
      $composableBuilder(column: $table.accuracyM, builder: (column) => column);

  GeneratedColumn<DateTime> get locationCapturedAt => $composableBuilder(
      column: $table.locationCapturedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocationSource, int> get locationSource =>
      $composableBuilder(
          column: $table.locationSource, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<QueueStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get protocol =>
      $composableBuilder(column: $table.protocol, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  Expression<T> outboxEvidenceRefs<T extends Object>(
      Expression<T> Function($$OutboxEvidenceTableAnnotationComposer a) f) {
    final $$OutboxEvidenceTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.outboxEvidence,
        getReferencedColumn: (t) => t.occurrenceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OutboxEvidenceTableAnnotationComposer(
              $db: $db,
              $table: $db.outboxEvidence,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$OutboxOccurrencesTableTableManager extends RootTableManager<
    _$QueueDatabase,
    $OutboxOccurrencesTable,
    OutboxOccurrence,
    $$OutboxOccurrencesTableFilterComposer,
    $$OutboxOccurrencesTableOrderingComposer,
    $$OutboxOccurrencesTableAnnotationComposer,
    $$OutboxOccurrencesTableCreateCompanionBuilder,
    $$OutboxOccurrencesTableUpdateCompanionBuilder,
    (OutboxOccurrence, $$OutboxOccurrencesTableReferences),
    OutboxOccurrence,
    PrefetchHooks Function({bool outboxEvidenceRefs})> {
  $$OutboxOccurrencesTableTableManager(
      _$QueueDatabase db, $OutboxOccurrencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxOccurrencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxOccurrencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxOccurrencesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> idempotencyKey = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<double> latitude = const Value.absent(),
            Value<double> longitude = const Value.absent(),
            Value<double?> accuracyM = const Value.absent(),
            Value<DateTime> locationCapturedAt = const Value.absent(),
            Value<LocationSource> locationSource = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<QueueStatus> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime?> nextAttemptAt = const Value.absent(),
            Value<String?> protocol = const Value.absent(),
            Value<DateTime?> receivedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxOccurrencesCompanion(
            id: id,
            idempotencyKey: idempotencyKey,
            category: category,
            description: description,
            latitude: latitude,
            longitude: longitude,
            accuracyM: accuracyM,
            locationCapturedAt: locationCapturedAt,
            locationSource: locationSource,
            createdAt: createdAt,
            status: status,
            attempts: attempts,
            lastError: lastError,
            nextAttemptAt: nextAttemptAt,
            protocol: protocol,
            receivedAt: receivedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String idempotencyKey,
            required String category,
            required String description,
            required double latitude,
            required double longitude,
            Value<double?> accuracyM = const Value.absent(),
            required DateTime locationCapturedAt,
            Value<LocationSource> locationSource = const Value.absent(),
            required DateTime createdAt,
            required QueueStatus status,
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime?> nextAttemptAt = const Value.absent(),
            Value<String?> protocol = const Value.absent(),
            Value<DateTime?> receivedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxOccurrencesCompanion.insert(
            id: id,
            idempotencyKey: idempotencyKey,
            category: category,
            description: description,
            latitude: latitude,
            longitude: longitude,
            accuracyM: accuracyM,
            locationCapturedAt: locationCapturedAt,
            locationSource: locationSource,
            createdAt: createdAt,
            status: status,
            attempts: attempts,
            lastError: lastError,
            nextAttemptAt: nextAttemptAt,
            protocol: protocol,
            receivedAt: receivedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$OutboxOccurrencesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({outboxEvidenceRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (outboxEvidenceRefs) db.outboxEvidence
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (outboxEvidenceRefs)
                    await $_getPrefetchedData<OutboxOccurrence,
                            $OutboxOccurrencesTable, OutboxEvidenceData>(
                        currentTable: table,
                        referencedTable: $$OutboxOccurrencesTableReferences
                            ._outboxEvidenceRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$OutboxOccurrencesTableReferences(db, table, p0)
                                .outboxEvidenceRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.occurrenceId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$OutboxOccurrencesTableProcessedTableManager = ProcessedTableManager<
    _$QueueDatabase,
    $OutboxOccurrencesTable,
    OutboxOccurrence,
    $$OutboxOccurrencesTableFilterComposer,
    $$OutboxOccurrencesTableOrderingComposer,
    $$OutboxOccurrencesTableAnnotationComposer,
    $$OutboxOccurrencesTableCreateCompanionBuilder,
    $$OutboxOccurrencesTableUpdateCompanionBuilder,
    (OutboxOccurrence, $$OutboxOccurrencesTableReferences),
    OutboxOccurrence,
    PrefetchHooks Function({bool outboxEvidenceRefs})>;
typedef $$OutboxEvidenceTableCreateCompanionBuilder = OutboxEvidenceCompanion
    Function({
  required String id,
  required String occurrenceId,
  required EvidenceKind kind,
  required String localPath,
  required String mimeType,
  required int byteSize,
  required String sha256,
  Value<DateTime?> uploadedAt,
  Value<int> rowid,
});
typedef $$OutboxEvidenceTableUpdateCompanionBuilder = OutboxEvidenceCompanion
    Function({
  Value<String> id,
  Value<String> occurrenceId,
  Value<EvidenceKind> kind,
  Value<String> localPath,
  Value<String> mimeType,
  Value<int> byteSize,
  Value<String> sha256,
  Value<DateTime?> uploadedAt,
  Value<int> rowid,
});

final class $$OutboxEvidenceTableReferences extends BaseReferences<
    _$QueueDatabase, $OutboxEvidenceTable, OutboxEvidenceData> {
  $$OutboxEvidenceTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $OutboxOccurrencesTable _occurrenceIdTable(_$QueueDatabase db) =>
      db.outboxOccurrences.createAlias($_aliasNameGenerator(
          db.outboxEvidence.occurrenceId, db.outboxOccurrences.id));

  $$OutboxOccurrencesTableProcessedTableManager get occurrenceId {
    final $_column = $_itemColumn<String>('occurrence_id')!;

    final manager =
        $$OutboxOccurrencesTableTableManager($_db, $_db.outboxOccurrences)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_occurrenceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$OutboxEvidenceTableFilterComposer
    extends Composer<_$QueueDatabase, $OutboxEvidenceTable> {
  $$OutboxEvidenceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<EvidenceKind, EvidenceKind, int> get kind =>
      $composableBuilder(
          column: $table.kind,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get byteSize => $composableBuilder(
      column: $table.byteSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sha256 => $composableBuilder(
      column: $table.sha256, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get uploadedAt => $composableBuilder(
      column: $table.uploadedAt, builder: (column) => ColumnFilters(column));

  $$OutboxOccurrencesTableFilterComposer get occurrenceId {
    final $$OutboxOccurrencesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.occurrenceId,
        referencedTable: $db.outboxOccurrences,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OutboxOccurrencesTableFilterComposer(
              $db: $db,
              $table: $db.outboxOccurrences,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OutboxEvidenceTableOrderingComposer
    extends Composer<_$QueueDatabase, $OutboxEvidenceTable> {
  $$OutboxEvidenceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get byteSize => $composableBuilder(
      column: $table.byteSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sha256 => $composableBuilder(
      column: $table.sha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get uploadedAt => $composableBuilder(
      column: $table.uploadedAt, builder: (column) => ColumnOrderings(column));

  $$OutboxOccurrencesTableOrderingComposer get occurrenceId {
    final $$OutboxOccurrencesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.occurrenceId,
        referencedTable: $db.outboxOccurrences,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OutboxOccurrencesTableOrderingComposer(
              $db: $db,
              $table: $db.outboxOccurrences,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OutboxEvidenceTableAnnotationComposer
    extends Composer<_$QueueDatabase, $OutboxEvidenceTable> {
  $$OutboxEvidenceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EvidenceKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<DateTime> get uploadedAt => $composableBuilder(
      column: $table.uploadedAt, builder: (column) => column);

  $$OutboxOccurrencesTableAnnotationComposer get occurrenceId {
    final $$OutboxOccurrencesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.occurrenceId,
            referencedTable: $db.outboxOccurrences,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$OutboxOccurrencesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.outboxOccurrences,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$OutboxEvidenceTableTableManager extends RootTableManager<
    _$QueueDatabase,
    $OutboxEvidenceTable,
    OutboxEvidenceData,
    $$OutboxEvidenceTableFilterComposer,
    $$OutboxEvidenceTableOrderingComposer,
    $$OutboxEvidenceTableAnnotationComposer,
    $$OutboxEvidenceTableCreateCompanionBuilder,
    $$OutboxEvidenceTableUpdateCompanionBuilder,
    (OutboxEvidenceData, $$OutboxEvidenceTableReferences),
    OutboxEvidenceData,
    PrefetchHooks Function({bool occurrenceId})> {
  $$OutboxEvidenceTableTableManager(
      _$QueueDatabase db, $OutboxEvidenceTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxEvidenceTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxEvidenceTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEvidenceTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> occurrenceId = const Value.absent(),
            Value<EvidenceKind> kind = const Value.absent(),
            Value<String> localPath = const Value.absent(),
            Value<String> mimeType = const Value.absent(),
            Value<int> byteSize = const Value.absent(),
            Value<String> sha256 = const Value.absent(),
            Value<DateTime?> uploadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxEvidenceCompanion(
            id: id,
            occurrenceId: occurrenceId,
            kind: kind,
            localPath: localPath,
            mimeType: mimeType,
            byteSize: byteSize,
            sha256: sha256,
            uploadedAt: uploadedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String occurrenceId,
            required EvidenceKind kind,
            required String localPath,
            required String mimeType,
            required int byteSize,
            required String sha256,
            Value<DateTime?> uploadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxEvidenceCompanion.insert(
            id: id,
            occurrenceId: occurrenceId,
            kind: kind,
            localPath: localPath,
            mimeType: mimeType,
            byteSize: byteSize,
            sha256: sha256,
            uploadedAt: uploadedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$OutboxEvidenceTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({occurrenceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (occurrenceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.occurrenceId,
                    referencedTable:
                        $$OutboxEvidenceTableReferences._occurrenceIdTable(db),
                    referencedColumn: $$OutboxEvidenceTableReferences
                        ._occurrenceIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$OutboxEvidenceTableProcessedTableManager = ProcessedTableManager<
    _$QueueDatabase,
    $OutboxEvidenceTable,
    OutboxEvidenceData,
    $$OutboxEvidenceTableFilterComposer,
    $$OutboxEvidenceTableOrderingComposer,
    $$OutboxEvidenceTableAnnotationComposer,
    $$OutboxEvidenceTableCreateCompanionBuilder,
    $$OutboxEvidenceTableUpdateCompanionBuilder,
    (OutboxEvidenceData, $$OutboxEvidenceTableReferences),
    OutboxEvidenceData,
    PrefetchHooks Function({bool occurrenceId})>;

class $QueueDatabaseManager {
  final _$QueueDatabase _db;
  $QueueDatabaseManager(this._db);
  $$OutboxOccurrencesTableTableManager get outboxOccurrences =>
      $$OutboxOccurrencesTableTableManager(_db, _db.outboxOccurrences);
  $$OutboxEvidenceTableTableManager get outboxEvidence =>
      $$OutboxEvidenceTableTableManager(_db, _db.outboxEvidence);
}
