import 'package:flutter/foundation.dart';

import 'measurement.dart';
import 'neighborhoods.dart';

/// Condição do tempo, derivada do código WMO 4677 devolvido pela fonte.
///
/// Guardamos o código bruto junto: se aparecer um valor que não conhecemos, a
/// interface mostra "condição não classificada" em vez de escolher o ícone
/// errado.
enum WeatherCondition {
  clear('Céu limpo'),
  mainlyClear('Predomínio de sol'),
  partlyCloudy('Parcialmente nublado'),
  overcast('Encoberto'),
  fog('Nevoeiro'),
  drizzle('Garoa'),
  rain('Chuva'),
  rainShowers('Pancadas de chuva'),
  freezingRain('Chuva congelante'),
  snow('Neve'),
  thunderstorm('Trovoada'),
  unknown('Condição não classificada');

  const WeatherCondition(this.label);
  final String label;

  /// Tabela WMO 4677, usada pelo Open-Meteo.
  static WeatherCondition fromWmoCode(int? code) => switch (code) {
        0 => clear,
        1 => mainlyClear,
        2 => partlyCloudy,
        3 => overcast,
        45 || 48 => fog,
        51 || 53 || 55 || 56 || 57 => drizzle,
        61 || 63 || 65 || 66 || 67 => rain,
        80 || 81 || 82 => rainShowers,
        71 || 73 || 75 || 77 || 85 || 86 => snow,
        95 || 96 || 99 => thunderstorm,
        _ => unknown,
      };

  bool get meansRain =>
      this == drizzle ||
      this == rain ||
      this == rainShowers ||
      this == thunderstorm ||
      this == freezingRain;
}

/// Condições observadas/estimadas para o momento atual.
@immutable
class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    required this.condition,
    required this.conditionCode,
    this.apparentTemperature,
    this.humidity,
    this.precipitation,
    this.windSpeed,
  });

  final Measurement<double> temperature;
  final WeatherCondition condition;
  final int? conditionCode;

  /// Sensação térmica, só quando a fonte fornece.
  final Measurement<double>? apparentTemperature;
  final Measurement<double>? humidity;

  /// Precipitação acumulada no intervalo mais recente da fonte.
  final Measurement<double>? precipitation;
  final Measurement<double>? windSpeed;
}

/// Previsão para uma hora específica.
@immutable
class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.condition,
    this.precipitationProbability,
    this.precipitation,
  });

  final DateTime time;
  final double temperature;
  final WeatherCondition condition;
  final int? precipitationProbability;
  final double? precipitation;
}

/// Previsão para um dia.
@immutable
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.minTemperature,
    required this.maxTemperature,
    required this.condition,
    this.precipitationProbability,
    this.precipitationSum,
    this.maxWindSpeed,
  });

  final DateTime date;
  final double minTemperature;
  final double maxTemperature;
  final WeatherCondition condition;
  final int? precipitationProbability;
  final double? precipitationSum;
  final double? maxWindSpeed;
}

/// Previsão de uma área de grade, com os bairros que ela cobre.
@immutable
class AreaForecast {
  const AreaForecast({
    required this.area,
    required this.days,
    required this.fetchedAt,
    required this.origin,
  });

  final ForecastArea area;
  final List<DailyForecast> days;
  final DateTime fetchedAt;
  final DataOrigin origin;
}

/// Situação meteorológica completa do município.
@immutable
class WeatherSituation {
  const WeatherSituation({
    required this.current,
    required this.hours,
    required this.days,
    required this.origin,
    required this.fetchedAt,
  });

  final CurrentWeather current;

  /// Próximas horas, a partir da hora corrente.
  final List<HourlyForecast> hours;
  final List<DailyForecast> days;
  final DataOrigin origin;
  final DateTime fetchedAt;
}

/// Provedor de dados meteorológicos.
///
/// Implementação real: `OpenMeteoWeatherProvider`. A interface existe para
/// permitir trocar por uma fonte municipal caso a Prefeitura passe a publicar
/// telemetria meteorológica consultável.
abstract class WeatherProvider {
  /// Condições atuais e previsão para o ponto de referência do município.
  Future<ProviderResult<WeatherSituation>> loadMunicipalWeather();

  /// Previsão por área de grade, cobrindo todos os bairros informados.
  ///
  /// A implementação deve consultar as coordenadas **em lote** e agrupar pelo
  /// que a fonte devolver, para não inventar diferença entre bairros vizinhos
  /// nem estourar a cota gratuita.
  Future<ProviderResult<List<AreaForecast>>> loadNeighborhoodForecast(
    List<Neighborhood> neighborhoods,
  );
}
