import 'dart:convert';

import 'package:http/http.dart' as http;

import 'measurement.dart';
import 'neighborhoods.dart';
import 'weather.dart';

/// Previsão meteorológica pelo Open-Meteo.
///
/// **Natureza do dado.** É previsão de modelo numérico por grade (~11 km), não
/// medição municipal. Em nenhum lugar da interface pode ser apresentada como
/// leitura de estação de Blumenau. Ver `docs/fontes-de-dados.md`.
///
/// **Condições de uso.** Camada gratuita permanente, sem chave e sem cartão,
/// para uso não comercial, com limite indicado pelo provedor em torno de
/// 10.000 chamadas por dia. Enviamos os 35 bairros numa única requisição em
/// lote e usamos cache, de modo que o piloto fica na casa de dezenas de
/// chamadas por dia. Atribuição obrigatória: "Open-Meteo.com", CC BY 4.0.
class OpenMeteoWeatherProvider implements WeatherProvider {
  OpenMeteoWeatherProvider({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _host = 'api.open-meteo.com';
  static const _path = '/v1/forecast';
  static const officialUrl = 'https://open-meteo.com/';
  static const sourceName = 'Open-Meteo (previsão de modelo)';

  /// Ponto de referência do município: praça central de Blumenau.
  static const municipalLatitude = -26.9194;
  static const municipalLongitude = -49.0661;

  static const _timeout = Duration(seconds: 12);

  /// Quanto tempo uma resposta pode ser reaproveitada. O modelo é atualizado
  /// de hora em hora; 30 minutos mantém o dado fresco sem repetir chamadas.
  static const validity = Duration(minutes: 30);

  @override
  Future<ProviderResult<WeatherSituation>> loadMunicipalWeather() async {
    final attemptedAt = DateTime.now();
    final uri = Uri.https(_host, _path, {
      'latitude': '$municipalLatitude',
      'longitude': '$municipalLongitude',
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m',
      'hourly':
          'temperature_2m,precipitation_probability,precipitation,weather_code',
      'daily':
          'temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,weather_code,wind_speed_10m_max',
      'forecast_days': '5',
      'timezone': 'America/Sao_Paulo',
    });
    try {
      final response = await _http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return ProviderResult.failure(
          DataState.sourceDown,
          message: 'A previsão do tempo não respondeu agora.',
          attemptedAt: attemptedAt,
          origin: _origin(),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return ProviderResult.failure(
          DataState.invalidResponse,
          message: 'A previsão do tempo devolveu um formato inesperado.',
          attemptedAt: attemptedAt,
          origin: _origin(),
        );
      }
      final situation = _parseSituation(decoded, attemptedAt);
      if (situation == null) {
        return ProviderResult.failure(
          DataState.invalidResponse,
          message: 'A previsão do tempo veio incompleta.',
          attemptedAt: attemptedAt,
          origin: _origin(),
        );
      }
      return ProviderResult.success(situation);
    } catch (_) {
      return ProviderResult.failure(
        DataState.sourceDown,
        message: 'Não foi possível consultar a previsão do tempo.',
        attemptedAt: attemptedAt,
        origin: _origin(),
      );
    }
  }

  @override
  Future<ProviderResult<List<AreaForecast>>> loadNeighborhoodForecast(
    List<Neighborhood> neighborhoods,
  ) async {
    final attemptedAt = DateTime.now();
    if (neighborhoods.isEmpty) {
      return ProviderResult.failure(
        DataState.noDataAvailable,
        message: 'Nenhum bairro para consultar.',
        attemptedAt: attemptedAt,
      );
    }
    // Lote: uma requisição para os 35 bairros, e não 35 requisições.
    final uri = Uri.https(_host, _path, {
      'latitude': neighborhoods.map((n) => '${n.latitude}').join(','),
      'longitude': neighborhoods.map((n) => '${n.longitude}').join(','),
      'daily':
          'temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,weather_code,wind_speed_10m_max',
      'forecast_days': '3',
      'timezone': 'America/Sao_Paulo',
    });
    try {
      final response = await _http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return ProviderResult.failure(
          DataState.sourceDown,
          message: 'A previsão por bairro não respondeu agora.',
          attemptedAt: attemptedAt,
          origin: _origin(),
        );
      }
      final decoded = jsonDecode(response.body);
      // Com várias coordenadas a resposta é uma lista, na mesma ordem do pedido.
      final entries = decoded is List
          ? decoded.cast<Map<String, dynamic>>()
          : [decoded as Map<String, dynamic>];
      if (entries.length != neighborhoods.length) {
        return ProviderResult.failure(
          DataState.invalidResponse,
          message: 'A previsão por bairro veio incompleta.',
          attemptedAt: attemptedAt,
          origin: _origin(),
        );
      }
      // Agrupa pela célula que a fonte devolveu — não pela que pedimos.
      final cells = entries
          .map((e) => (
                latitude: (e['latitude'] as num).toDouble(),
                longitude: (e['longitude'] as num).toDouble(),
              ))
          .toList();
      final areas = groupByGridCell(neighborhoods, cells);

      final byCell = <String, Map<String, dynamic>>{};
      for (var i = 0; i < entries.length; i++) {
        final key = '${cells[i].latitude.toStringAsFixed(4)},'
            '${cells[i].longitude.toStringAsFixed(4)}';
        byCell.putIfAbsent(key, () => entries[i]);
      }

      final forecasts = <AreaForecast>[];
      for (final area in areas) {
        final payload = byCell[area.id];
        if (payload == null) continue;
        final days = _parseDaily(payload['daily']);
        if (days.isEmpty) continue;
        forecasts.add(AreaForecast(
          area: area,
          days: days,
          fetchedAt: attemptedAt,
          origin: _origin(
            latitude: area.gridLatitude,
            longitude: area.gridLongitude,
            note: area.isShared
                ? 'Uma célula da grade cobre '
                    '${area.neighborhoods.length} bairros.'
                : null,
          ),
        ));
      }
      if (forecasts.isEmpty) {
        return ProviderResult.failure(
          DataState.noDataAvailable,
          message: 'Não há previsão disponível para os bairros agora.',
          attemptedAt: attemptedAt,
          origin: _origin(),
        );
      }
      return ProviderResult.success(forecasts);
    } catch (_) {
      return ProviderResult.failure(
        DataState.sourceDown,
        message: 'Não foi possível consultar a previsão por bairro.',
        attemptedAt: attemptedAt,
        origin: _origin(),
      );
    }
  }

  DataOrigin _origin({double? latitude, double? longitude, String? note}) =>
      DataOrigin(
        sourceName: sourceName,
        officialUrl: officialUrl,
        latitude: latitude ?? municipalLatitude,
        longitude: longitude ?? municipalLongitude,
        note: note,
      );

  WeatherSituation? _parseSituation(
    Map<String, dynamic> body,
    DateTime fetchedAt,
  ) {
    final current = body['current'];
    if (current is! Map<String, dynamic>) return null;
    final measuredAt = DateTime.tryParse('${current['time']}');
    final temperature = _asDouble(current['temperature_2m']);
    if (measuredAt == null || temperature == null) return null;
    if (!PlausibleRange.airTemperatureCelsius.accepts(temperature)) return null;

    final gridLatitude = _asDouble(body['latitude']) ?? municipalLatitude;
    final gridLongitude = _asDouble(body['longitude']) ?? municipalLongitude;
    final origin = _origin(latitude: gridLatitude, longitude: gridLongitude);

    Measurement<double>? build(Object? raw, String unit, PlausibleRange range) {
      final value = _asDouble(raw);
      if (value == null || !range.accepts(value)) return null;
      return Measurement<double>(
        value: value,
        unit: unit,
        measuredAt: measuredAt,
        fetchedAt: fetchedAt,
        origin: origin,
        nature: DataNature.forecast,
        validFor: validity,
      );
    }

    final code = (current['weather_code'] as num?)?.toInt();
    return WeatherSituation(
      current: CurrentWeather(
        temperature: Measurement<double>(
          value: temperature,
          unit: '°C',
          measuredAt: measuredAt,
          fetchedAt: fetchedAt,
          origin: origin,
          nature: DataNature.forecast,
          validFor: validity,
        ),
        condition: WeatherCondition.fromWmoCode(code),
        conditionCode: code,
        apparentTemperature: build(current['apparent_temperature'], '°C',
            PlausibleRange.airTemperatureCelsius),
        humidity: build(current['relative_humidity_2m'], '%',
            PlausibleRange.relativeHumidityPercent),
        precipitation: build(current['precipitation'], 'mm',
            PlausibleRange.precipitationMillimeters),
        windSpeed: build(
            current['wind_speed_10m'], 'km/h', PlausibleRange.windSpeedKmh),
      ),
      hours: _parseHourly(body['hourly'], fetchedAt),
      days: _parseDaily(body['daily']),
      origin: origin,
      fetchedAt: fetchedAt,
    );
  }

  List<HourlyForecast> _parseHourly(Object? raw, DateTime now) {
    if (raw is! Map<String, dynamic>) return const [];
    final times = (raw['time'] as List?)?.cast<String>() ?? const [];
    final temps = (raw['temperature_2m'] as List?) ?? const [];
    final codes = (raw['weather_code'] as List?) ?? const [];
    final probs = (raw['precipitation_probability'] as List?) ?? const [];
    final rain = (raw['precipitation'] as List?) ?? const [];
    final result = <HourlyForecast>[];
    for (var i = 0; i < times.length; i++) {
      final time = DateTime.tryParse(times[i]);
      final temperature = i < temps.length ? _asDouble(temps[i]) : null;
      if (time == null || temperature == null) continue;
      // Só o que ainda vai acontecer.
      if (time.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      if (!PlausibleRange.airTemperatureCelsius.accepts(temperature)) continue;
      result.add(HourlyForecast(
        time: time,
        temperature: temperature,
        condition: WeatherCondition.fromWmoCode(
            i < codes.length ? (codes[i] as num?)?.toInt() : null),
        precipitationProbability:
            i < probs.length ? (probs[i] as num?)?.toInt() : null,
        precipitation: i < rain.length ? _asDouble(rain[i]) : null,
      ));
      if (result.length >= 12) break;
    }
    return result;
  }

  List<DailyForecast> _parseDaily(Object? raw) {
    if (raw is! Map<String, dynamic>) return const [];
    final times = (raw['time'] as List?)?.cast<String>() ?? const [];
    final maxima = (raw['temperature_2m_max'] as List?) ?? const [];
    final minima = (raw['temperature_2m_min'] as List?) ?? const [];
    final codes = (raw['weather_code'] as List?) ?? const [];
    final probs = (raw['precipitation_probability_max'] as List?) ?? const [];
    final sums = (raw['precipitation_sum'] as List?) ?? const [];
    final winds = (raw['wind_speed_10m_max'] as List?) ?? const [];
    final result = <DailyForecast>[];
    for (var i = 0; i < times.length; i++) {
      final date = DateTime.tryParse(times[i]);
      final maximum = i < maxima.length ? _asDouble(maxima[i]) : null;
      final minimum = i < minima.length ? _asDouble(minima[i]) : null;
      if (date == null || maximum == null || minimum == null) continue;
      if (!PlausibleRange.airTemperatureCelsius.accepts(maximum) ||
          !PlausibleRange.airTemperatureCelsius.accepts(minimum)) {
        continue;
      }
      result.add(DailyForecast(
        date: date,
        minTemperature: minimum,
        maxTemperature: maximum,
        condition: WeatherCondition.fromWmoCode(
            i < codes.length ? (codes[i] as num?)?.toInt() : null),
        precipitationProbability:
            i < probs.length ? (probs[i] as num?)?.toInt() : null,
        precipitationSum: i < sums.length ? _asDouble(sums[i]) : null,
        maxWindSpeed: i < winds.length ? _asDouble(winds[i]) : null,
      ));
    }
    return result;
  }

  static double? _asDouble(Object? raw) => raw is num
      ? raw.toDouble()
      : (raw is String ? double.tryParse(raw) : null);
}
