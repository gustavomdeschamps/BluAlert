// Testes das fontes de dados oficiais.
//
// A regra que estes testes protegem: nada aparece na tela sem fonte, horário e
// unidade, e nenhuma fonte inventa valor para preencher espaço.
import 'dart:convert';

import 'package:blualert/data/hydrology.dart';
import 'package:blualert/data/measurement.dart';
import 'package:blualert/data/municipal_geo.dart';
import 'package:blualert/data/neighborhoods.dart';
import 'package:blualert/data/neighborhoods_data.dart';
import 'package:blualert/data/open_meteo_provider.dart';
import 'package:blualert/data/weather.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client jsonClient(String body, {int status = 200}) =>
    MockClient((_) async => http.Response(body, status,
        headers: {'content-type': 'application/json; charset=utf-8'}));

http.Client failingClient(Object error) => MockClient((_) async => throw error);

void main() {
  group('cotas oficiais do rio', () {
    test('classificam segundo as faixas publicadas pela Defesa Civil', () {
      // Fonte: /c/meteorologia/legenda_nivel_rio
      expect(RiverStage.forLevel(2.52), RiverStage.normality);
      expect(RiverStage.forLevel(3.0), RiverStage.observation);
      expect(RiverStage.forLevel(4.0), RiverStage.attention);
      expect(RiverStage.forLevel(6.0), RiverStage.alert);
      expect(RiverStage.forLevel(8.0), RiverStage.maximumAlert);
      expect(RiverStage.forLevel(12.5), RiverStage.maximumAlert);
    });

    test('só exigem atenção a partir da faixa oficial de Atenção', () {
      expect(RiverStage.normality.demandsAttention, isFalse);
      expect(RiverStage.observation.demandsAttention, isFalse);
      expect(RiverStage.attention.demandsAttention, isTrue);
      expect(RiverStage.maximumAlert.demandsAttention, isTrue);
    });
  });

  group('tendência do rio', () {
    const calculator = RiverTrendCalculator();
    final now = DateTime(2026, 9, 9, 12);

    List<RiverReading> series(List<double> meters, {int stepMinutes = 60}) {
      final start =
          now.subtract(Duration(minutes: stepMinutes * meters.length));
      return [
        for (var i = 0; i < meters.length; i++)
          RiverReading(
            at: start.add(Duration(minutes: stepMinutes * (i + 1))),
            meters: meters[i],
          ),
      ];
    }

    test('sem leituras não afirma nada', () {
      final result = calculator.calculate(const [], now);
      expect(result.trend, RiverTrend.unavailable);
      expect(result.trend.isKnown, isFalse);
    });

    test('poucas leituras não viram "estável"', () {
      // "Estável" tranquilizaria sem base. O correto é admitir a ausência.
      final result = calculator.calculate(series([2.50, 2.50]), now);
      expect(result.trend, RiverTrend.unavailable);
      expect(result.reason, contains('leituras'));
    });

    test('série antiga não gera tendência', () {
      final old = [
        RiverReading(at: now.subtract(const Duration(hours: 20)), meters: 2.5),
        RiverReading(at: now.subtract(const Duration(hours: 19)), meters: 2.6),
        RiverReading(at: now.subtract(const Duration(hours: 18)), meters: 2.7),
      ];
      final result = calculator.calculate(old, now);
      expect(result.trend, RiverTrend.unavailable);
      expect(result.reason, contains('horas'));
    });

    test('oscilação dentro da tolerância é estável', () {
      final result =
          calculator.calculate(series([2.50, 2.52, 2.51, 2.53]), now);
      expect(result.trend, RiverTrend.stable);
      expect(result.changeMeters!.abs(), lessThanOrEqualTo(0.05));
    });

    test('subida real acima da tolerância é reconhecida', () {
      final result =
          calculator.calculate(series([2.50, 2.70, 2.95, 3.20]), now);
      expect(result.trend, RiverTrend.rising);
      expect(result.changeMeters, greaterThan(0.05));
      expect(result.readingsUsed, greaterThanOrEqualTo(3));
    });

    test('reproduz a série real da ANA de 09/09/2026: baixando', () {
      // Valores efetivamente devolvidos pela estação 83800010.
      final result =
          calculator.calculate(series([2.68, 2.62, 2.57, 2.52]), now);
      expect(result.trend, RiverTrend.falling);
      expect(result.changeMeters, closeTo(-0.16, 0.001));
    });

    test('a janela usada é declarada junto do resultado', () {
      final result = calculator.calculate(series([2.5, 2.5, 2.5, 2.5]), now);
      expect(result.window, const Duration(hours: 3));
    });
  });

  group('faixas de plausibilidade', () {
    test('recusam sentinela e valor corrompido', () {
      expect(PlausibleRange.riverLevelMeters.accepts(-9999), isFalse);
      expect(PlausibleRange.riverLevelMeters.accepts(-0.5), isFalse);
      expect(PlausibleRange.riverLevelMeters.accepts(120), isFalse);
      expect(PlausibleRange.airTemperatureCelsius.accepts(-9999), isFalse);
      expect(PlausibleRange.relativeHumidityPercent.accepts(150), isFalse);
    });

    test('aceitam os valores reais observados hoje', () {
      expect(PlausibleRange.riverLevelMeters.accepts(2.52), isTrue);
      expect(PlausibleRange.airTemperatureCelsius.accepts(19.8), isTrue);
      expect(PlausibleRange.relativeHumidityPercent.accepts(81), isTrue);
    });
  });

  group('bairros oficiais', () {
    test('são os 35 publicados pela Prefeitura', () {
      expect(officialNeighborhoods, hasLength(35));
      expect(
        officialNeighborhoods.map((n) => n.officialCode).toSet(),
        hasLength(35),
        reason: 'os códigos municipais precisam ser únicos',
      );
    });

    test('todos caem dentro do município', () {
      for (final item in officialNeighborhoods) {
        expect(
          isWithinBlumenauBounds(item.latitude, item.longitude),
          isTrue,
          reason: '${item.displayName} está fora dos limites de Blumenau',
        );
      }
    });

    test('a busca ignora acentos e caixa', () {
      final agua =
          officialNeighborhoods.firstWhere((n) => n.officialCode == '18');
      expect(agua.displayName, 'Água Verde');
      expect(agua.matches('agua'), isTrue);
      expect(agua.matches('ÁGUA'), isTrue);
      expect(agua.matches('verde'), isTrue);
      expect(agua.matches('centro'), isFalse);
    });

    test('o bairro mais próximo do centro é o Centro', () {
      final found = nearestNeighborhood(-26.9194, -49.0661);
      expect(found?.displayName, 'Centro');
    });
  });

  group('agrupamento por célula de grade', () {
    test('bairros que caem na mesma célula viram uma área só', () {
      // Comportamento real medido: 20 bairros compartilham uma célula.
      final bairros = officialNeighborhoods.take(4).toList();
      final areas = groupByGridCell(bairros, const [
        (latitude: -26.8893, longitude: -49.0909),
        (latitude: -26.8893, longitude: -49.0909),
        (latitude: -26.9596, longitude: -49.0455),
        (latitude: -26.8893, longitude: -49.0909),
      ]);
      expect(areas, hasLength(2));
      expect(areas.first.neighborhoods, hasLength(3));
      expect(areas.first.isShared, isTrue);
      expect(areas.last.isShared, isFalse);
    });

    test('a área compartilhada não se apresenta como um bairro só', () {
      final bairros = officialNeighborhoods.take(3).toList();
      final areas = groupByGridCell(bairros, const [
        (latitude: -26.8893, longitude: -49.0909),
        (latitude: -26.8893, longitude: -49.0909),
        (latitude: -26.8893, longitude: -49.0909),
      ]);
      expect(areas.single.label, contains('e mais 2 bairros'));
    });

    test('usa a célula devolvida pela fonte, não a coordenada pedida', () {
      final bairro = officialNeighborhoods.first;
      final areas = groupByGridCell(
        [bairro],
        const [(latitude: -26.8893, longitude: -49.0909)],
      );
      expect(areas.single.gridLatitude, -26.8893);
      expect(areas.single.gridLatitude, isNot(bairro.latitude));
    });
  });

  group('provedor de previsão', () {
    test('lê condições atuais com fonte, horário e unidade', () async {
      final provider = OpenMeteoWeatherProvider(
        httpClient: jsonClient(jsonEncode({
          'latitude': -26.88928,
          'longitude': -49.09091,
          'current': {
            'time': '2026-09-09T11:15',
            'temperature_2m': 19.8,
            'apparent_temperature': 21.6,
            'relative_humidity_2m': 81,
            'precipitation': 0.0,
            'weather_code': 3,
            'wind_speed_10m': 3.1,
          },
        })),
      );

      final result = await provider.loadMunicipalWeather();

      expect(result.hasData, isTrue);
      final current = result.data!.current;
      expect(current.temperature.value, 19.8);
      expect(current.temperature.unit, '°C');
      expect(current.temperature.measuredAt, DateTime(2026, 9, 9, 11, 15));
      expect(current.condition, WeatherCondition.overcast);
      expect(current.humidity!.value, 81);
      // É previsão de grade, jamais medição municipal.
      expect(current.temperature.nature, DataNature.forecast);
      expect(current.temperature.origin.latitude, -26.88928);
    });

    test('temperatura implausível é descartada em vez de exibida', () async {
      final provider = OpenMeteoWeatherProvider(
        httpClient: jsonClient(jsonEncode({
          'latitude': -26.9,
          'longitude': -49.06,
          'current': {'time': '2026-09-09T11:15', 'temperature_2m': -9999},
        })),
      );

      final result = await provider.loadMunicipalWeather();

      expect(result.hasData, isFalse);
      expect(result.state, DataState.invalidResponse);
    });

    test('valor ausente vira campo ausente, não zero', () async {
      final provider = OpenMeteoWeatherProvider(
        httpClient: jsonClient(jsonEncode({
          'latitude': -26.9,
          'longitude': -49.06,
          'current': {'time': '2026-09-09T11:15', 'temperature_2m': 19.8},
        })),
      );

      final result = await provider.loadMunicipalWeather();

      expect(result.data!.current.humidity, isNull);
      expect(result.data!.current.windSpeed, isNull);
    });

    test('fonte fora do ar devolve estado próprio e horário da tentativa',
        () async {
      final provider =
          OpenMeteoWeatherProvider(httpClient: jsonClient('{}', status: 503));

      final result = await provider.loadMunicipalWeather();

      expect(result.state, DataState.sourceDown);
      expect(result.hasData, isFalse);
      expect(result.attemptedAt, isNotNull);
      expect(result.message, isNot(contains('503')),
          reason: 'detalhe técnico fica no log, não na tela');
    });

    test('timeout é tratado como fonte indisponível', () async {
      final provider = OpenMeteoWeatherProvider(
        httpClient: failingClient(const _FakeTimeout()),
      );

      final result = await provider.loadMunicipalWeather();

      expect(result.state, DataState.sourceDown);
      expect(result.message, isNotNull);
    });

    test('resposta com estrutura alterada não quebra o aplicativo', () async {
      final provider = OpenMeteoWeatherProvider(
        httpClient: jsonClient(jsonEncode({'algo': 'inesperado'})),
      );

      final result = await provider.loadMunicipalWeather();

      expect(result.state, DataState.invalidResponse);
    });

    test('previsão por bairro agrupa pela grade devolvida', () async {
      final bairros = officialNeighborhoods.take(3).toList();
      Map<String, dynamic> entry(double lat, double lon) => {
            'latitude': lat,
            'longitude': lon,
            'daily': {
              'time': ['2026-09-09'],
              'temperature_2m_max': [23.0],
              'temperature_2m_min': [14.0],
              'weather_code': [3],
              'precipitation_probability_max': [10],
              'precipitation_sum': [0.0],
              'wind_speed_10m_max': [12.0],
            },
          };
      final provider = OpenMeteoWeatherProvider(
        httpClient: jsonClient(jsonEncode([
          entry(-26.8893, -49.0909),
          entry(-26.8893, -49.0909),
          entry(-26.9596, -49.0455),
        ])),
      );

      final result = await provider.loadNeighborhoodForecast(bairros);

      expect(result.hasData, isTrue);
      expect(result.data, hasLength(2), reason: '3 bairros, 2 células');
      final shared = result.data!.first;
      expect(shared.area.neighborhoods, hasLength(2));
      expect(shared.origin.note, contains('2 bairros'));
      expect(shared.days.single.maxTemperature, 23.0);
    });

    test('quantidade divergente de respostas é recusada', () async {
      final provider = OpenMeteoWeatherProvider(
        httpClient: jsonClient(jsonEncode([
          {'latitude': -26.88, 'longitude': -49.09, 'daily': {}},
        ])),
      );

      final result = await provider.loadNeighborhoodForecast(
        officialNeighborhoods.take(3).toList(),
      );

      expect(result.state, DataState.invalidResponse);
    });
  });

  group('limite municipal do IBGE', () {
    test('converte GeoJSON para anéis desenháveis', () async {
      final provider = IbgeMunicipalGeoProvider(
        httpClient: jsonClient(jsonEncode({
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Polygon',
                'coordinates': [
                  [
                    [-49.0572, -27.0615],
                    [-49.0627, -27.0582],
                    [-49.0633, -27.0564],
                    [-49.0572, -27.0615],
                  ]
                ],
              },
            }
          ],
        })),
      );

      final result = await provider.loadMunicipalBoundary();

      expect(result.hasData, isTrue);
      final ring = result.data!.rings.single;
      // GeoJSON é [lon, lat]; a interface precisa do par invertido.
      expect(ring.first.latitude, -27.0615);
      expect(ring.first.longitude, -49.0572);
      expect(result.data!.origin.sourceName, contains('IBGE'));
    });

    test('geometria vazia não vira polígono aproximado', () async {
      final provider = IbgeMunicipalGeoProvider(
        httpClient: jsonClient(jsonEncode({'features': []})),
      );

      final result = await provider.loadMunicipalBoundary();

      expect(result.hasData, isFalse);
      expect(result.state, DataState.invalidResponse);
    });
  });

  group('reaproveitamento de valor antigo', () {
    test('um resultado rebaixado avisa que está antigo', () {
      final fresh = ProviderResult.success(42);
      expect(fresh.state, DataState.fresh);
      expect(fresh.state.needsStaleWarning, isFalse);

      final stale = fresh.asStale();
      expect(stale.state, DataState.stale);
      expect(stale.state.needsStaleWarning, isTrue);
      expect(stale.hasData, isTrue, reason: 'ainda é exibível, mas marcado');
      expect(stale.data, 42);
    });

    test('validade é respeitada pelo instante da consulta', () {
      final medida = Measurement<double>(
        value: 2.52,
        unit: 'm',
        measuredAt: DateTime(2026, 9, 9, 9),
        fetchedAt: DateTime(2026, 9, 9, 9, 5),
        origin: const DataOrigin(
          sourceName: 'ANA',
          officialUrl: 'https://www.snirh.gov.br/hidrotelemetria/',
          stationCode: '83800010',
          stationName: 'PCH Salto Jusante',
        ),
        nature: DataNature.measurement,
        validFor: const Duration(minutes: 30),
      );

      expect(medida.isExpiredAt(DateTime(2026, 9, 9, 9, 20)), isFalse);
      expect(medida.isExpiredAt(DateTime(2026, 9, 9, 10)), isTrue);
      expect(medida.stateAt(DateTime(2026, 9, 9, 10)), DataState.stale);
      expect(medida.origin.referenceLabel, contains('83800010'));
      expect(medida.ageAt(DateTime(2026, 9, 9, 12)), const Duration(hours: 3));
    });
  });
}

class _FakeTimeout implements Exception {
  const _FakeTimeout();
}
