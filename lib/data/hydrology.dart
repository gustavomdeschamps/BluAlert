import 'package:flutter/foundation.dart';

import 'measurement.dart';

/// Estágio oficial do nível do rio, conforme os "Critérios de Nível do rio"
/// publicados pela Defesa Civil de Blumenau.
///
/// Fonte: https://defesacivil.blumenau.sc.gov.br/c/meteorologia/legenda_nivel_rio
/// Faixas vigentes: Normalidade 0–3 m · Observação 3–4 m · Atenção 4–6 m ·
/// Alerta 6–8 m · Alerta Máximo acima de 8 m.
///
/// Estes limites são **publicados oficialmente**; por isso o aplicativo pode
/// classificar a leitura. Sem eles, nenhuma classificação seria feita.
enum RiverStage {
  normality('Normalidade', 0, 3),
  observation('Observação', 3, 4),
  attention('Atenção', 4, 6),
  alert('Alerta', 6, 8),
  maximumAlert('Alerta Máximo', 8, double.infinity);

  const RiverStage(this.label, this.minMeters, this.maxMeters);

  final String label;
  final double minMeters;
  final double maxMeters;

  /// Classifica um nível em metros segundo as faixas oficiais.
  static RiverStage forLevel(double meters) {
    for (final stage in values) {
      if (meters >= stage.minMeters && meters < stage.maxMeters) return stage;
    }
    return maximumAlert;
  }

  /// Se este estágio já exige atenção da população.
  bool get demandsAttention => index >= attention.index;

  String get range => maxMeters.isInfinite
      ? 'acima de ${minMeters.toStringAsFixed(0)} m'
      : '${minMeters.toStringAsFixed(0)} a ${maxMeters.toStringAsFixed(0)} m';
}

/// Direção do movimento do rio.
enum RiverTrend {
  rising('Subindo'),
  stable('Estável'),
  falling('Baixando'),

  /// Não há série suficiente para afirmar direção alguma.
  unavailable('Tendência indisponível');

  const RiverTrend(this.label);
  final String label;

  bool get isKnown => this != unavailable;
}

/// Uma leitura de nível na série histórica.
@immutable
class RiverReading {
  const RiverReading({required this.at, required this.meters});
  final DateTime at;
  final double meters;
}

/// Resultado do cálculo de tendência, com a janela usada explicitada.
@immutable
class RiverTrendResult {
  const RiverTrendResult({
    required this.trend,
    required this.window,
    this.changeMeters,
    this.readingsUsed = 0,
    this.reason,
  });

  final RiverTrend trend;

  /// Janela temporal considerada. Exibida na interface para que a tendência
  /// não seja um adjetivo solto.
  final Duration window;

  /// Variação no período, em metros. Positivo indica subida.
  final double? changeMeters;
  final int readingsUsed;

  /// Por que a tendência é desconhecida, quando for o caso.
  final String? reason;
}

/// Calcula tendência do rio **somente** a partir de medições reais.
///
/// Regras deliberadas:
///
/// - exige no mínimo [minimumReadings] leituras dentro da janela, senão devolve
///   [RiverTrend.unavailable] — nunca "estável" por falta de dado, que seria
///   uma afirmação tranquilizadora sem base;
/// - exige que a leitura mais recente não seja mais velha que [maximumAge];
/// - usa uma tolerância de [stableToleranceMeters] para não chamar de "subindo"
///   uma oscilação de sensor. 5 cm em 3 horas está dentro do ruído típico de
///   uma régua limnimétrica; acima disso o movimento é real.
class RiverTrendCalculator {
  const RiverTrendCalculator({
    this.window = const Duration(hours: 3),
    this.minimumReadings = 3,
    this.stableToleranceMeters = 0.05,
    this.maximumAge = const Duration(hours: 6),
  });

  final Duration window;
  final int minimumReadings;
  final double stableToleranceMeters;
  final Duration maximumAge;

  RiverTrendResult calculate(List<RiverReading> readings, DateTime now) {
    if (readings.isEmpty) {
      return RiverTrendResult(
        trend: RiverTrend.unavailable,
        window: window,
        reason: 'Sem leituras disponíveis.',
      );
    }
    final ordered = [...readings]..sort((a, b) => a.at.compareTo(b.at));
    final latest = ordered.last;
    if (now.difference(latest.at) > maximumAge) {
      return RiverTrendResult(
        trend: RiverTrend.unavailable,
        window: window,
        reason: 'A leitura mais recente é de mais de '
            '${maximumAge.inHours} horas atrás.',
      );
    }
    final cutoff = latest.at.subtract(window);
    final inWindow =
        ordered.where((r) => !r.at.isBefore(cutoff)).toList(growable: false);
    if (inWindow.length < minimumReadings) {
      return RiverTrendResult(
        trend: RiverTrend.unavailable,
        window: window,
        readingsUsed: inWindow.length,
        reason: 'São necessárias ao menos $minimumReadings leituras em '
            '${window.inHours} horas; há ${inWindow.length}.',
      );
    }
    final change = inWindow.last.meters - inWindow.first.meters;
    final trend = change.abs() <= stableToleranceMeters
        ? RiverTrend.stable
        : (change > 0 ? RiverTrend.rising : RiverTrend.falling);
    return RiverTrendResult(
      trend: trend,
      window: window,
      changeMeters: change,
      readingsUsed: inWindow.length,
    );
  }
}

/// Situação hidrológica completa do Itajaí-Açu em Blumenau.
@immutable
class RiverSituation {
  const RiverSituation({
    required this.level,
    required this.trend,
    required this.series,
    this.officialStage,
    this.municipalLevel,
  });

  /// Leitura mais recente, medida por estação telemétrica.
  final Measurement<double> level;

  final RiverTrendResult trend;

  /// Série usada para o gráfico e para a tendência.
  final List<RiverReading> series;

  /// Estágio publicado pela Defesa Civil, quando disponível. Tem precedência
  /// sobre a classificação calculada: é a palavra da autoridade competente.
  final Measurement<String>? officialStage;

  /// Nível publicado pelo município, quando disponível. Pode divergir alguns
  /// centímetros da telemetria por ser publicado em outro horário.
  final Measurement<double>? municipalLevel;

  /// Estágio derivado das cotas oficiais aplicadas à leitura telemétrica.
  RiverStage get calculatedStage => RiverStage.forLevel(level.value);

  /// O que exibir como estágio: a publicação oficial quando existir.
  String get displayStage => officialStage?.value ?? calculatedStage.label;

  /// Se a classificação exibida vem da autoridade e não de cálculo próprio.
  bool get stageIsOfficial => officialStage != null;
}

/// Provedor de dados hidrológicos.
///
/// Implementação real: [BluAlertHydrologyProvider], que lê a telemetria da ANA
/// e a publicação da Defesa Civil através da função `situation`.
abstract class HydrologyProvider {
  /// Situação do rio de referência do município.
  Future<ProviderResult<RiverSituation>> loadRiverSituation();
}
