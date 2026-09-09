import 'package:flutter/foundation.dart';

/// Configuração da fonte de tiles do mapa.
///
/// Existe para que trocar de provedor não exija reescrever a tela do mapa:
/// basta outra instância desta classe, vinda de `--dart-define` ou da
/// configuração remota.
@immutable
class MapTileSource {
  const MapTileSource({
    required this.id,
    required this.urlTemplate,
    required this.attribution,
    required this.attributionUrl,
    required this.maxZoom,
    this.subdomains = const [],
    this.apiKey,
  });

  final String id;
  final String urlTemplate;

  /// Texto de atribuição obrigatório. Nunca pode ser ocultado da tela.
  final String attribution;
  final String attributionUrl;
  final int maxZoom;
  final List<String> subdomains;
  final String? apiKey;

  bool get requiresKey => apiKey != null && apiKey!.isNotEmpty;
}

/// Provedor de tiles do mapa.
abstract class MapTileProvider {
  MapTileSource get active;
}

/// Escolhe a fonte de tiles a partir da configuração de compilação.
///
/// **Padrão: OpenStreetMap oficial.** É gratuito, permanente e não exige chave
/// nem cartão. A Tile Usage Policy da OSMF permite aplicativos de baixo volume
/// desde que haja identificação por User-Agent, cache e nenhuma pré-carga em
/// massa — condições que o piloto cumpre: o mapa carrega apenas a área visível,
/// está limitado ao município e a navegação é restrita por zoom mínimo.
///
/// Se o piloto crescer além do volume aceitável, defina `MAP_TILE_URL` (e
/// `MAP_TILE_ATTRIBUTION`) para um provedor contratado — a troca não toca no
/// código do mapa. **Nunca** use servidor público de demonstração, como o
/// `demotiles.maplibre.org`, que não é destinado a produção.
class ConfiguredMapTileProvider implements MapTileProvider {
  const ConfiguredMapTileProvider();

  static const _configuredUrl = String.fromEnvironment('MAP_TILE_URL');
  static const _configuredAttribution =
      String.fromEnvironment('MAP_TILE_ATTRIBUTION');
  static const _configuredKey = String.fromEnvironment('MAP_TILE_KEY');

  /// OpenStreetMap padrão, com atribuição obrigatória.
  static const openStreetMap = MapTileSource(
    id: 'openstreetmap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors',
    attributionUrl: 'https://www.openstreetmap.org/copyright',
    maxZoom: 19,
  );

  @override
  MapTileSource get active {
    if (_configuredUrl.isEmpty) return openStreetMap;
    return MapTileSource(
      id: 'configurado',
      urlTemplate: _configuredUrl,
      // Mesmo com outro provedor, o dado de base continua sendo do OSM na
      // maioria dos casos; a atribuição do OSM permanece somada à do provedor.
      attribution: _configuredAttribution.isEmpty
          ? '© OpenStreetMap contributors'
          : '$_configuredAttribution · © OpenStreetMap contributors',
      attributionUrl: 'https://www.openstreetmap.org/copyright',
      maxZoom: 19,
      apiKey: _configuredKey.isEmpty ? null : _configuredKey,
    );
  }
}

/// Limites de navegação do mapa, fixados no município.
///
/// O aplicativo é de Blumenau; deixar a pessoa navegar até o mapa-múndi só
/// gera confusão e consome tiles à toa. O retângulo tem folga em relação ao
/// limite municipal real (desenhado com o GeoJSON do IBGE) para que a borda do
/// município nunca fique colada na borda da tela.
class BlumenauMapBounds {
  const BlumenauMapBounds._();

  /// Centro do município, usado como posição inicial.
  static const centerLatitude = -26.9194;
  static const centerLongitude = -49.0661;

  static const southLatitude = -27.12;
  static const northLatitude = -26.68;
  static const westLongitude = -49.30;
  static const eastLongitude = -48.92;

  /// Zoom inicial: mostra a mancha urbana inteira.
  static const initialZoom = 12.0;

  /// Zoom mínimo: abaixo disso Blumenau perde o contexto e o mapa vira região.
  static const minimumZoom = 10.5;

  /// Zoom máximo: suficiente para identificar uma residência.
  static const maximumZoom = 19.0;

  static bool contains(double latitude, double longitude) =>
      latitude >= southLatitude &&
      latitude <= northLatitude &&
      longitude >= westLongitude &&
      longitude <= eastLongitude;
}
