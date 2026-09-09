// Testes do mapa restrito a Blumenau e da atribuição cartográfica.
import 'package:blualert/data/map_tiles.dart';
import 'package:blualert/data/neighborhoods.dart';
import 'package:blualert/data/neighborhoods_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('limites de navegação do mapa', () {
    test('o município inteiro cabe dentro dos limites', () {
      for (final bairro in officialNeighborhoods) {
        expect(
          BlumenauMapBounds.contains(bairro.latitude, bairro.longitude),
          isTrue,
          reason: '${bairro.displayName} ficaria fora da área navegável',
        );
      }
    });

    test('pontos fora de Blumenau ficam fora dos limites', () {
      // Joinville, Florianópolis e São Paulo não podem ser alcançados.
      expect(BlumenauMapBounds.contains(-26.3044, -48.8487), isFalse);
      expect(BlumenauMapBounds.contains(-27.5954, -48.5480), isFalse);
      expect(BlumenauMapBounds.contains(-23.5505, -46.6333), isFalse);
    });

    test('o zoom mínimo impede chegar ao mapa-múndi', () {
      // Abaixo de ~10 um município vira região; 3 mostraria o continente.
      expect(BlumenauMapBounds.minimumZoom, greaterThanOrEqualTo(10));
      expect(BlumenauMapBounds.initialZoom,
          greaterThanOrEqualTo(BlumenauMapBounds.minimumZoom));
    });

    test('o zoom máximo permite localizar uma residência', () {
      expect(BlumenauMapBounds.maximumZoom, greaterThanOrEqualTo(18));
    });

    test('o centro inicial é Blumenau', () {
      expect(
        BlumenauMapBounds.contains(
          BlumenauMapBounds.centerLatitude,
          BlumenauMapBounds.centerLongitude,
        ),
        isTrue,
      );
    });

    test('a área navegável tem folga sobre a área dos bairros', () {
      // O limite real é desenhado com GeoJSON do IBGE; a caixa precisa contê-lo
      // com margem para a borda não colar na tela.
      expect(BlumenauMapBounds.southLatitude, lessThan(-27.10));
      expect(BlumenauMapBounds.northLatitude, greaterThan(-26.70));
    });
  });

  group('GPS fora de Blumenau', () {
    test('é reconhecido como fora do município', () {
      expect(isWithinBlumenauBounds(-26.3044, -48.8487), isFalse,
          reason: 'Joinville não é Blumenau');
      expect(isWithinBlumenauBounds(-26.9194, -49.0661), isTrue);
    });

    test('o bairro mais próximo continua definido mesmo fora da cidade', () {
      // Não é erro: a interface apresenta como "mais próximo", não como
      // "seu bairro".
      final found = nearestNeighborhood(-26.3044, -48.8487);
      expect(found, isNotNull);
    });
  });

  group('provedor de tiles', () {
    test('o padrão é OpenStreetMap, nunca servidor de demonstração', () {
      final source = const ConfiguredMapTileProvider().active;
      expect(source.urlTemplate, contains('tile.openstreetmap.org'));
      expect(source.urlTemplate, isNot(contains('demotiles')));
      expect(source.requiresKey, isFalse,
          reason: 'o padrão não pode exigir chave nem cartão');
    });

    test('a atribuição obrigatória está presente e não é vazia', () {
      final source = const ConfiguredMapTileProvider().active;
      expect(source.attribution, contains('OpenStreetMap'));
      expect(source.attribution.trim(), isNotEmpty);
      expect(source.attributionUrl, contains('openstreetmap.org/copyright'));
    });

    test('o zoom máximo do provedor cobre o zoom máximo do mapa', () {
      final source = const ConfiguredMapTileProvider().active;
      expect(source.maxZoom.toDouble(),
          greaterThanOrEqualTo(BlumenauMapBounds.maximumZoom));
    });
  });
}
