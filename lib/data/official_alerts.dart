import 'package:flutter/foundation.dart';

import 'measurement.dart';

/// Estágio publicado pela Defesa Civil para uma região administrativa.
@immutable
class RegionalStatus {
  const RegionalStatus({required this.region, required this.stage});

  /// Região administrativa de Blumenau: Central, Leste, Norte, Oeste ou Sul.
  final String region;

  /// Estágio publicado, exatamente como a fonte escreve.
  final String stage;

  /// Se o estágio significa ausência de risco informado.
  ///
  /// "Normalidade" é uma **afirmação oficial de que não há risco informado** —
  /// não é o mesmo que "sem dados". A interface precisa distinguir os dois.
  bool get isNormal => stage.toLowerCase().startsWith('normalidade');
}

/// Avisos oficiais ativos publicados pela autoridade municipal.
@immutable
class OfficialAlerts {
  const OfficialAlerts({
    required this.weatherByRegion,
    required this.publishedAt,
    required this.fetchedAt,
    required this.origin,
    this.riverStage,
  });

  /// Estágio do rio conforme a Defesa Civil.
  final String? riverStage;

  /// Condições meteorológicas por região administrativa.
  final List<RegionalStatus> weatherByRegion;

  /// Quando a autoridade publicou esta situação.
  final DateTime publishedAt;
  final DateTime fetchedAt;
  final DataOrigin origin;

  /// Regiões com estágio diferente de normalidade.
  List<RegionalStatus> get elevated =>
      weatherByRegion.where((item) => !item.isNormal).toList();

  /// Verdadeiro quando a autoridade publicou normalidade em tudo.
  ///
  /// Distinto de "sem dados": aqui houve manifestação oficial.
  bool get allNormal =>
      weatherByRegion.isNotEmpty &&
      elevated.isEmpty &&
      (riverStage == null ||
          riverStage!.toLowerCase().startsWith('normalidade'));
}

/// Provedor de avisos oficiais.
///
/// Implementação real: `BluAlertSituationProvider`, que lê a publicação da
/// Defesa Civil de Blumenau através da função `situation`.
abstract class OfficialAlertsProvider {
  Future<ProviderResult<OfficialAlerts>> loadOfficialAlerts({
    bool forceRefresh = false,
  });
}
