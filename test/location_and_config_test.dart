// Testes da confirmação de localização e da configuração remota.
import 'package:blualert/data/hydrology.dart';
import 'package:blualert/data/map_tiles.dart';
import 'package:blualert/emergency.dart';
import 'package:blualert/location_picker.dart';
import 'package:blualert/queue/queue_models.dart';
import 'package:blualert/river_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    PilotConfigService.current.value = PilotConfig.safeFallback;
  });

  group('origem da coordenada', () {
    test('o padrão é o GPS', () {
      final occurrence = QueuedOccurrence(
        id: 'a',
        idempotencyKey: 'a',
        category: 'flood',
        description: 'Água subindo na rua e já cobrindo a calçada inteira.',
        latitude: -26.9194,
        longitude: -49.0661,
        accuracyM: 12,
        locationCapturedAt: DateTime(2026, 9, 10, 8),
        createdAt: DateTime(2026, 9, 10, 8),
        status: QueueStatus.savedOnDevice,
        attempts: 0,
      );
      expect(occurrence.locationSource, LocationSource.gps);
      expect(occurrence.locationSource.isManual, isFalse);
    });

    test('o ajuste manual sobrevive a uma mudança de estado', () {
      final occurrence = QueuedOccurrence(
        id: 'a',
        idempotencyKey: 'a',
        category: 'flood',
        description: 'Água subindo na rua e já cobrindo a calçada inteira.',
        latitude: -26.9194,
        longitude: -49.0661,
        accuracyM: null,
        locationCapturedAt: DateTime(2026, 9, 10, 8),
        createdAt: DateTime(2026, 9, 10, 8),
        status: QueueStatus.savedOnDevice,
        attempts: 0,
        locationSource: LocationSource.manuallyAdjusted,
      );
      final avancada =
          occurrence.copyWith(status: QueueStatus.awaitingConfirmation);
      expect(avancada.locationSource, LocationSource.manuallyAdjusted);
      expect(avancada.accuracyM, isNull,
          reason: 'ponto ajustado à mão não carrega precisão do GPS');
    });

    test('um ponto ajustado descarta a precisão do GPS', () {
      final manual = ConfirmedLocation(
        latitude: -26.92,
        longitude: -49.07,
        accuracyM: null,
        capturedAt: DateTime(2026, 9, 10, 8),
        source: LocationSource.manuallyAdjusted,
      );
      expect(manual.accuracyM, isNull);
      expect(manual.source.isManual, isTrue);
    });
  });

  group('gráfico do rio', () {
    testWidgets('série curta não vira linha', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RiverChart(readings: [
            RiverReading(at: DateTime(2026, 9, 10, 6), meters: 3.1),
          ]),
        ),
      ));
      // Duas leituras não descrevem tendência nem forma; melhor dizer isso.
      expect(find.textContaining('Série insuficiente'), findsOneWidget);
    });

    testWidgets('série real desenha com unidade, horários e cota',
        (tester) async {
      final readings = [
        for (var i = 0; i < 6; i++)
          RiverReading(
            at: DateTime(2026, 9, 10, 1 + i),
            meters: 2.6 + i * 0.1,
          ),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: RiverChart(readings: readings)),
      ));

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.textContaining('Nível medido (m)'), findsOneWidget);
      expect(find.textContaining('6 leituras'), findsOneWidget);
      // A cota de Observação (3 m) fica dentro da faixa desenhada.
      expect(find.textContaining('Cota oficial'), findsOneWidget);
    });
  });

  group('configuração remota das fontes', () {
    test('o padrão local é seguro quando o servidor não responde', () {
      const fallback = PilotConfig.safeFallback;
      expect(fallback.neighborhoodForecastEnabled, isTrue);
      expect(fallback.weatherCache, const Duration(minutes: 30));
      expect(fallback.hydrologyCache, const Duration(minutes: 30));
      // Camadas de risco só ligam com fonte oficial confirmada.
      expect(fallback.landslideLayerEnabled, isFalse);
      expect(fallback.floodLayerEnabled, isFalse);
      expect(fallback.mapTileUrl, isNull);
      expect(fallback.maintenanceNotice, isNull);
    });

    test('lê os campos publicados pelo backend', () {
      final config = PilotConfig.fromJson(const {
        'pilot_mode': true,
        'human_receiver_confirmed': false,
        'emergency_phone': '199',
        'weather_cache_seconds': 900,
        'hydrology_cache_seconds': 600,
        'neighborhood_forecast_enabled': false,
        'landslide_layer_enabled': true,
        'maintenance_notice': 'Manutenção da ANA às 3h.',
        'map_tile_url': 'https://tiles.exemplo/{z}/{x}/{y}.png',
        'map_tile_attribution': '© Provedor',
      });
      expect(config.weatherCache, const Duration(minutes: 15));
      expect(config.hydrologyCache, const Duration(minutes: 10));
      expect(config.neighborhoodForecastEnabled, isFalse);
      expect(config.landslideLayerEnabled, isTrue);
      expect(config.maintenanceNotice, 'Manutenção da ANA às 3h.');
    });

    test('valor de cache fora de faixa cai no padrão', () {
      // Uma configuração corrompida não pode zerar o cache e estourar a cota.
      final curto = PilotConfig.fromJson(const {'weather_cache_seconds': 1});
      final longo =
          PilotConfig.fromJson(const {'weather_cache_seconds': 999999});
      expect(curto.weatherCache, const Duration(minutes: 30));
      expect(longo.weatherCache, const Duration(minutes: 30));
    });

    test('texto vazio vira ausência, não aviso em branco', () {
      final config = PilotConfig.fromJson(const {
        'maintenance_notice': '   ',
        'data_notice': '',
        'map_tile_url': '',
      });
      expect(config.maintenanceNotice, isNull);
      expect(config.dataNotice, isNull);
      expect(config.mapTileUrl, isNull);
    });
  });

  group('provedor de tiles com configuração remota', () {
    test('sem configuração remota, mantém o OpenStreetMap', () {
      final source = const ConfiguredMapTileProvider().active;
      expect(source.urlTemplate, contains('tile.openstreetmap.org'));
      expect(source.urlTemplate, isNot(contains('demotiles')));
    });

    test('a troca remota preserva a atribuição do OpenStreetMap', () {
      PilotConfigService.current.value = const PilotConfig(
        pilotMode: true,
        humanReceiverConfirmed: false,
        emergencyPhone: '199',
        uploadsEnabled: true,
        videoEnabled: true,
        origin: PilotConfigOrigin.server,
        mapTileUrl: 'https://tiles.exemplo/{z}/{x}/{y}.png',
        mapTileAttribution: '© Provedor',
      );

      final source = const ConfiguredMapTileProvider().active;

      expect(source.urlTemplate, 'https://tiles.exemplo/{z}/{x}/{y}.png');
      expect(source.attribution, contains('Provedor'));
      // O dado de base continua sendo do OSM: a atribuição não pode sumir.
      expect(source.attribution, contains('OpenStreetMap'));
    });
  });
}
