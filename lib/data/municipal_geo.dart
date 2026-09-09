import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'measurement.dart';

/// Um anel de coordenadas (latitude, longitude) de um polígono.
typedef GeoRing = List<({double latitude, double longitude})>;

/// Contorno oficial de uma área, pronto para desenhar.
@immutable
class GeoOutline {
  const GeoOutline({
    required this.name,
    required this.rings,
    required this.origin,
    required this.fetchedAt,
  });

  final String name;

  /// Anéis externos do polígono. Buracos não são usados no desenho do limite.
  final List<GeoRing> rings;
  final DataOrigin origin;
  final DateTime fetchedAt;
}

/// Provedor de geodados municipais.
///
/// Implementação real: [IbgeMunicipalGeoProvider], que usa a malha oficial do
/// IBGE. O limite municipal **nunca** é aproximado por um retângulo ou por um
/// polígono desenhado à mão — ou vem da fonte oficial, ou não é desenhado.
abstract class MunicipalGeoDataProvider {
  /// Limite do município de Blumenau.
  Future<ProviderResult<GeoOutline>> loadMunicipalBoundary();
}

/// Malha municipal do IBGE.
///
/// Serviço público federal, gratuito, sem chave e sem cartão, com CORS aberto —
/// pode ser consultado direto pelo Flutter, inclusive na web.
///
/// Código do município de Blumenau no IBGE: 4202404.
/// Licença: dados públicos do IBGE, uso livre com citação da fonte.
class IbgeMunicipalGeoProvider implements MunicipalGeoDataProvider {
  IbgeMunicipalGeoProvider({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const municipalityCode = '4202404';
  static const officialUrl = 'https://servicodados.ibge.gov.br/api/docs/malhas';

  /// O limite de um município praticamente não muda; um dia é conservador.
  static const validity = Duration(days: 1);

  @override
  Future<ProviderResult<GeoOutline>> loadMunicipalBoundary() async {
    final attemptedAt = DateTime.now();
    final uri = Uri.https(
      'servicodados.ibge.gov.br',
      '/api/v3/malhas/municipios/$municipalityCode',
      {'formato': 'application/vnd.geo+json', 'qualidade': 'maxima'},
    );
    try {
      final response =
          await _http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return ProviderResult.failure(
          DataState.sourceDown,
          message: 'O limite municipal não pôde ser carregado agora.',
          attemptedAt: attemptedAt,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return ProviderResult.failure(DataState.invalidResponse,
            message: 'O limite municipal veio em formato inesperado.',
            attemptedAt: attemptedAt);
      }
      final rings = _extractRings(decoded);
      if (rings.isEmpty) {
        return ProviderResult.failure(DataState.invalidResponse,
            message: 'O limite municipal veio sem geometria.',
            attemptedAt: attemptedAt);
      }
      return ProviderResult.success(GeoOutline(
        name: 'Blumenau',
        rings: rings,
        origin: const DataOrigin(
          sourceName: 'IBGE — malhas territoriais',
          officialUrl: officialUrl,
        ),
        fetchedAt: attemptedAt,
      ));
    } catch (_) {
      return ProviderResult.failure(
        DataState.sourceDown,
        message: 'Não foi possível carregar o limite municipal.',
        attemptedAt: attemptedAt,
      );
    }
  }

  /// GeoJSON traz `[longitude, latitude]`; a interface usa o par invertido.
  List<GeoRing> _extractRings(Map<String, dynamic> geojson) {
    final rings = <GeoRing>[];
    void readPolygon(List<dynamic> polygon) {
      if (polygon.isEmpty) return;
      final outer = polygon.first;
      if (outer is! List) return;
      final ring = <({double latitude, double longitude})>[];
      for (final point in outer) {
        if (point is! List || point.length < 2) continue;
        final longitude = (point[0] as num).toDouble();
        final latitude = (point[1] as num).toDouble();
        ring.add((latitude: latitude, longitude: longitude));
      }
      if (ring.length >= 3) rings.add(ring);
    }

    for (final feature in (geojson['features'] as List? ?? const [])) {
      if (feature is! Map) continue;
      final geometry = feature['geometry'];
      if (geometry is! Map) continue;
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) continue;
      switch (geometry['type']) {
        case 'Polygon':
          readPolygon(coordinates);
        case 'MultiPolygon':
          for (final polygon in coordinates) {
            if (polygon is List) readPolygon(polygon);
          }
      }
    }
    return rings;
  }
}
