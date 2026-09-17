import 'dart:convert';

import 'package:http/http.dart' as http;

import '../backend_client.dart';
import 'hydrology.dart';
import 'measurement.dart';
import 'official_alerts.dart';

/// Lê a função `situation`, que reúne a telemetria da ANA e a publicação da
/// Defesa Civil de Blumenau.
///
/// Por que passar pelo backend em vez de consultar direto:
///
/// - nenhuma das duas fontes envia cabeçalho de CORS, o que impede a build web;
/// - o servidor da Prefeitura entrega uma cadeia TLS incompleta, que Dart não
///   consegue completar sozinho (ver `supabase/functions/_shared/sectigo.ts`);
/// - a normalização e o cache ficam num lugar só, servindo Android e web.
///
/// Uma única resposta alimenta o [HydrologyProvider] e o
/// [OfficialAlertsProvider]; por isso a chamada é compartilhada e memorizada
/// por um curto intervalo, para não consultar duas vezes a mesma coisa.
class BluAlertSituationProvider
    implements HydrologyProvider, OfficialAlertsProvider {
  BluAlertSituationProvider({
    http.Client? httpClient,
    this.trendCalculator = const RiverTrendCalculator(),
    DateTime Function()? clock,
  })  : _http = httpClient ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final http.Client _http;
  final RiverTrendCalculator trendCalculator;
  final DateTime Function() _clock;

  static const _timeout = Duration(seconds: 15);

  /// Telemetria da ANA é horária; meia hora mantém o dado fresco.
  static const validity = Duration(minutes: 30);

  static const anaOfficialUrl = 'https://www.snirh.gov.br/hidrotelemetria/';
  static const alertaBluUrl =
      'https://defesacivil.blumenau.sc.gov.br/d/nivel-do-rio';
  static const criteriaUrl =
      'https://defesacivil.blumenau.sc.gov.br/c/meteorologia/legenda_nivel_rio';

  Future<Map<String, dynamic>>? _inFlight;
  Map<String, dynamic>? _cached;
  DateTime? _cachedAt;

  Future<Map<String, dynamic>> _load({bool forceRefresh = false}) {
    final cachedAt = _cachedAt;
    if (!forceRefresh &&
        _cached != null &&
        cachedAt != null &&
        _clock().difference(cachedAt) < validity) {
      return Future.value(_cached);
    }
    // Uma chamada em voo atende hidrologia e alertas ao mesmo tempo.
    final existing = _inFlight;
    if (existing != null && !forceRefresh) return existing;

    final future = _fetch();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<Map<String, dynamic>> _fetch() async {
    final supabaseUrl = BackendClient.supabaseUrl;
    final anonKey = BackendClient.anonKey;
    if (supabaseUrl.isEmpty || anonKey.isEmpty) {
      throw const _SituationUnavailable(
        DataState.sourceDown,
        'O canal de dados oficiais ainda não foi configurado neste aplicativo.',
      );
    }
    late final http.Response response;
    try {
      response = await _http.get(
        Uri.parse('$supabaseUrl/functions/v1/situation'),
        headers: {'apikey': anonKey},
      ).timeout(_timeout);
    } catch (_) {
      throw const _SituationUnavailable(
        DataState.sourceDown,
        'Não foi possível falar com o serviço de dados oficiais.',
      );
    }
    if (response.statusCode != 200 && response.statusCode != 503) {
      throw const _SituationUnavailable(
        DataState.sourceDown,
        'O serviço de dados oficiais respondeu com erro.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const _SituationUnavailable(
        DataState.invalidResponse,
        'O serviço de dados oficiais devolveu um formato inesperado.',
      );
    }
    _cached = decoded;
    _cachedAt = _clock();
    return decoded;
  }

  @override
  Future<ProviderResult<RiverSituation>> loadRiverSituation({
    bool forceRefresh = false,
  }) async {
    final attemptedAt = _clock();
    Map<String, dynamic> body;
    try {
      body = await _load(forceRefresh: forceRefresh);
    } on _SituationUnavailable catch (problem) {
      return ProviderResult.failure(problem.state,
          message: problem.message, attemptedAt: attemptedAt);
    } catch (_) {
      return ProviderResult.failure(DataState.sourceDown,
          message: 'Não foi possível obter o nível do rio.',
          attemptedAt: attemptedAt);
    }

    final telemetry = body['telemetry'];
    final municipal = body['municipal'];
    final fetchedAt =
        DateTime.tryParse('${body['fetchedAt']}')?.toLocal() ?? attemptedAt;

    // Estágio e nível publicados pelo município, quando existirem.
    Measurement<String>? officialStage;
    Measurement<double>? municipalLevel;
    if (municipal is Map<String, dynamic> && municipal['available'] == true) {
      final publishedAt =
          _parseBrazilianDate('${municipal['publishedAt']}') ?? fetchedAt;
      const municipalOrigin = DataOrigin(
        sourceName: 'Defesa Civil de Blumenau — AlertaBlu',
        officialUrl: alertaBluUrl,
        note: 'Publicação municipal',
      );
      final stage = municipal['riverStage'];
      if (stage is String && stage.trim().isNotEmpty) {
        officialStage = Measurement<String>(
          value: stage.trim(),
          unit: '',
          measuredAt: publishedAt,
          fetchedAt: fetchedAt,
          origin: municipalOrigin,
          nature: DataNature.officialStatement,
          validFor: const Duration(hours: 12),
        );
      }
      final level = municipal['levelMeters'];
      if (level is num &&
          PlausibleRange.riverLevelMeters.accepts(level.toDouble())) {
        municipalLevel = Measurement<double>(
          value: level.toDouble(),
          unit: 'm',
          measuredAt: publishedAt,
          fetchedAt: fetchedAt,
          origin: municipalOrigin,
          nature: DataNature.officialStatement,
          validFor: const Duration(hours: 12),
        );
      }
    }

    if (telemetry is! Map<String, dynamic> || telemetry['available'] != true) {
      // Sem telemetria não há série nem tendência. Se o município publicou o
      // nível, ainda mostramos esse valor — degradado, mas verdadeiro.
      if (municipalLevel != null) {
        return ProviderResult.success(
          RiverSituation(
            level: municipalLevel,
            trend: RiverTrendResult(
              trend: RiverTrend.unavailable,
              window: trendCalculator.window,
              reason: 'A telemetria horária não respondeu; sem série não é '
                  'possível calcular tendência.',
            ),
            series: const [],
            officialStage: officialStage,
            municipalLevel: municipalLevel,
          ),
          state: DataState.partial,
        );
      }
      return ProviderResult.failure(
        DataState.sourceDown,
        message: 'O nível do rio não está disponível agora.',
        attemptedAt: attemptedAt,
      );
    }

    final station = telemetry['station'] as Map<String, dynamic>?;
    final origin = DataOrigin(
      sourceName: '${telemetry['source']}',
      officialUrl: '${telemetry['officialUrl'] ?? anaOfficialUrl}',
      stationCode: '${station?['code'] ?? ''}',
      stationName: '${station?['name'] ?? ''}',
      latitude: (station?['latitude'] as num?)?.toDouble(),
      longitude: (station?['longitude'] as num?)?.toDouble(),
    );

    final series = <RiverReading>[];
    for (final entry in (telemetry['readings'] as List? ?? const [])) {
      if (entry is! Map) continue;
      final at = DateTime.tryParse('${entry['at']}');
      final meters = (entry['meters'] as num?)?.toDouble();
      if (at == null || meters == null) continue;
      if (!PlausibleRange.riverLevelMeters.accepts(meters)) continue;
      series.add(RiverReading(at: at, meters: meters));
    }
    if (series.isEmpty) {
      return ProviderResult.failure(
        DataState.noDataAvailable,
        message: 'A estação não tem leituras recentes.',
        attemptedAt: attemptedAt,
        origin: origin,
      );
    }
    series.sort((a, b) => a.at.compareTo(b.at));
    final latest = series.last;

    return ProviderResult.success(
      RiverSituation(
        level: Measurement<double>(
          value: latest.meters,
          unit: 'm',
          measuredAt: latest.at,
          fetchedAt: fetchedAt,
          origin: origin,
          nature: DataNature.measurement,
          validFor: validity,
        ),
        trend: trendCalculator.calculate(series, _clock()),
        series: List.unmodifiable(series),
        officialStage: officialStage,
        municipalLevel: municipalLevel,
      ),
      state: municipal is Map && municipal['available'] == true
          ? DataState.fresh
          : DataState.partial,
    );
  }

  @override
  Future<ProviderResult<OfficialAlerts>> loadOfficialAlerts({
    bool forceRefresh = false,
  }) async {
    final attemptedAt = _clock();
    Map<String, dynamic> body;
    try {
      body = await _load(forceRefresh: forceRefresh);
    } on _SituationUnavailable catch (problem) {
      return ProviderResult.failure(problem.state,
          message: problem.message, attemptedAt: attemptedAt);
    } catch (_) {
      return ProviderResult.failure(DataState.sourceDown,
          message: 'Não foi possível obter os avisos oficiais.',
          attemptedAt: attemptedAt);
    }

    final municipal = body['municipal'];
    if (municipal is! Map<String, dynamic> || municipal['available'] != true) {
      return ProviderResult.failure(
        DataState.sourceDown,
        message: 'A publicação da Defesa Civil não respondeu agora.',
        attemptedAt: attemptedAt,
      );
    }
    final publishedAt =
        _parseBrazilianDate('${municipal['publishedAt']}') ?? attemptedAt;
    final regions = <RegionalStatus>[];
    final raw = municipal['regions'];
    if (raw is Map) {
      raw.forEach((key, value) {
        regions.add(RegionalStatus(
          region: '$key',
          stage: '$value',
        ));
      });
      regions.sort((a, b) => a.region.compareTo(b.region));
    }
    return ProviderResult.success(
      OfficialAlerts(
        riverStage: municipal['riverStage'] as String?,
        weatherByRegion: List.unmodifiable(regions),
        publishedAt: publishedAt,
        fetchedAt: attemptedAt,
        origin: const DataOrigin(
          sourceName: 'Defesa Civil de Blumenau — AlertaBlu',
          officialUrl: alertaBluUrl,
        ),
      ),
    );
  }

  /// A publicação municipal usa dd/MM/yyyy.
  static DateTime? _parseBrazilianDate(String raw) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw.trim());
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
  }
}

class _SituationUnavailable implements Exception {
  const _SituationUnavailable(this.state, this.message);
  final DataState state;
  final String message;
}
