import 'package:flutter/foundation.dart';

import 'neighborhoods_data.dart';

/// Um bairro oficial de Blumenau.
@immutable
class Neighborhood {
  const Neighborhood({
    required this.displayName,
    required this.officialName,
    required this.officialCode,
    required this.latitude,
    required this.longitude,
  });

  /// Nome com acentuação, para leitura.
  final String displayName;

  /// Nome exatamente como a Prefeitura publica.
  final String officialName;

  /// Código do bairro no cadastro municipal (`CD_BAIRRO`).
  final String officialCode;

  /// Coordenada de referência do bairro. Ver `neighborhoods_data.dart`.
  final double latitude;
  final double longitude;

  /// Texto sem acento e em minúsculas, para busca tolerante.
  String get searchKey => _fold('$displayName $officialName');

  bool matches(String query) {
    final term = _fold(query).trim();
    return term.isEmpty || searchKey.contains(term);
  }

  static String _fold(String value) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer.toString().toLowerCase();
  }
}

/// Um grupo de bairros que a fonte de previsão **não consegue diferenciar**.
///
/// Existe por uma limitação medida, não por conveniência: a grade do Open-Meteo
/// tem ~11 km, e os 35 bairros oficiais de Blumenau caem em apenas 8 células.
/// Vinte deles — Centro, Água Verde, Boa Vista, Bom Retiro entre outros —
/// compartilham a mesma célula.
///
/// Exibir 35 previsões distintas produziria diferenças decimais que são apenas
/// arredondamento, e daria a impressão falsa de que há medição por bairro.
/// Agrupamos e dizemos isso na interface.
@immutable
class ForecastArea {
  const ForecastArea({
    required this.gridLatitude,
    required this.gridLongitude,
    required this.neighborhoods,
  });

  /// Coordenada da célula efetivamente usada pelo modelo — devolvida pela
  /// própria API, não a que pedimos.
  final double gridLatitude;
  final double gridLongitude;

  /// Bairros cobertos por esta célula, em ordem alfabética.
  final List<Neighborhood> neighborhoods;

  /// Chave estável da célula.
  String get id =>
      '${gridLatitude.toStringAsFixed(4)},${gridLongitude.toStringAsFixed(4)}';

  /// Rótulo da área: o bairro mais conhecido não serve, porque sugeriria que a
  /// previsão é dele. Listamos quantos bairros a área cobre.
  String get label => neighborhoods.length == 1
      ? neighborhoods.single.displayName
      : '${neighborhoods.first.displayName} e mais '
          '${neighborhoods.length - 1} bairro'
          '${neighborhoods.length - 1 == 1 ? '' : 's'}';

  bool get isShared => neighborhoods.length > 1;

  /// Distância aproximada, em quilômetros, do bairro à célula que o representa.
  ///
  /// Usada para admitir na interface o quanto a previsão pode estar deslocada.
  double distanceKmFrom(Neighborhood neighborhood) {
    const kmPerDegreeLat = 111.32;
    final dLat = (neighborhood.latitude - gridLatitude) * kmPerDegreeLat;
    // Em Blumenau (~27° S) um grau de longitude vale cerca de 99 km.
    final dLon = (neighborhood.longitude - gridLongitude) * 99.1;
    return (dLat * dLat + dLon * dLon) <= 0
        ? 0
        : _sqrt(dLat * dLat + dLon * dLon);
  }

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    var guess = value;
    for (var i = 0; i < 20; i++) {
      guess = 0.5 * (guess + value / guess);
    }
    return guess;
  }
}

/// Agrupa bairros pelas células de grade realmente devolvidas pela fonte.
///
/// O agrupamento é feito com a coordenada que a API **retornou**, nunca com a
/// que enviamos: só assim o agrupamento reflete a resolução real do modelo.
List<ForecastArea> groupByGridCell(
  List<Neighborhood> neighborhoods,
  List<({double latitude, double longitude})> resolvedCells,
) {
  assert(
    neighborhoods.length == resolvedCells.length,
    'cada bairro precisa da célula que a fonte devolveu para ele',
  );
  final grouped = <String, List<Neighborhood>>{};
  final coordinates = <String, ({double latitude, double longitude})>{};
  for (var i = 0; i < neighborhoods.length; i++) {
    final cell = resolvedCells[i];
    final key = '${cell.latitude.toStringAsFixed(4)},'
        '${cell.longitude.toStringAsFixed(4)}';
    grouped.putIfAbsent(key, () => []).add(neighborhoods[i]);
    coordinates[key] = cell;
  }
  final areas = grouped.entries.map((entry) {
    final list = [...entry.value]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return ForecastArea(
      gridLatitude: coordinates[entry.key]!.latitude,
      gridLongitude: coordinates[entry.key]!.longitude,
      neighborhoods: List.unmodifiable(list),
    );
  }).toList();
  // Áreas maiores primeiro: cobrem mais gente.
  areas.sort((a, b) {
    final size = b.neighborhoods.length.compareTo(a.neighborhoods.length);
    return size != 0
        ? size
        : a.neighborhoods.first.displayName
            .compareTo(b.neighborhoods.first.displayName);
  });
  return areas;
}

/// Busca o bairro cuja coordenada de referência está mais próxima de um ponto.
///
/// Usado para destacar o bairro do endereço da pessoa. É aproximação por
/// centroide: não substitui um teste de ponto-em-polígono, e por isso a
/// interface apresenta o resultado como "bairro mais próximo do seu endereço".
Neighborhood? nearestNeighborhood(double latitude, double longitude) {
  if (officialNeighborhoods.isEmpty) return null;
  Neighborhood? best;
  var bestScore = double.infinity;
  for (final item in officialNeighborhoods) {
    final dLat = (item.latitude - latitude) * 111.32;
    final dLon = (item.longitude - longitude) * 99.1;
    final score = dLat * dLat + dLon * dLon;
    if (score < bestScore) {
      bestScore = score;
      best = item;
    }
  }
  return best;
}

/// Área aproximada do município, usada para saber se um ponto é de Blumenau.
///
/// Retângulo derivado dos centroides oficiais com folga; para desenhar o limite
/// real usamos o GeoJSON do IBGE, não este retângulo.
bool isWithinBlumenauBounds(double latitude, double longitude) =>
    latitude <= -26.65 &&
    latitude >= -27.10 &&
    longitude <= -48.95 &&
    longitude >= -49.25;
