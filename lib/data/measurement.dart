import 'package:flutter/foundation.dart';

/// De onde veio um dado e como ele deve ser lido na interface.
///
/// A distinção entre medição e previsão é obrigatória: uma leitura de régua
/// limnimétrica e um número saído de um modelo de grade não podem aparecer com
/// o mesmo peso para quem decide sair de casa.
enum DataNature {
  /// Valor medido por um instrumento real, numa estação identificada.
  measurement,

  /// Valor calculado por um modelo para uma coordenada. Não é medição local.
  forecast,

  /// Estado publicado por autoridade competente (ex.: estágio de alerta).
  officialStatement,
}

/// Estado de disponibilidade de um dado ou de um bloco da interface.
///
/// São tratados separadamente de propósito: "não há estação", "a fonte caiu" e
/// "não há risco informado" significam coisas diferentes para quem opera.
enum DataState {
  /// Consulta em andamento, sem valor anterior.
  loading,

  /// Valor recém-obtido, dentro da validade.
  fresh,

  /// Valor de cache ainda dentro da validade declarada.
  cachedValid,

  /// Valor de cache fora da validade. Só pode aparecer com selo de
  /// "última leitura disponível" e horário destacado.
  stale,

  /// Parte das fontes respondeu, parte não.
  partial,

  /// Sem conexão no aparelho.
  offline,

  /// A fonte respondeu com erro, timeout ou recusa.
  sourceDown,

  /// A fonte respondeu, mas o conteúdo não pôde ser interpretado.
  invalidResponse,

  /// A fonte está no ar e simplesmente não há estação ou previsão para o ponto.
  noDataAvailable,

  /// A permissão de localização é necessária e não foi concedida.
  locationDenied;

  /// Se há algum valor exibível associado a este estado.
  bool get hasValue =>
      this == fresh || this == cachedValid || this == stale || this == partial;

  /// Se o valor exibido precisa de aviso de desatualização.
  bool get needsStaleWarning => this == stale;
}

/// Identificação da origem física de um dado.
@immutable
class DataOrigin {
  const DataOrigin({
    required this.sourceName,
    required this.officialUrl,
    this.stationCode,
    this.stationName,
    this.latitude,
    this.longitude,
    this.note,
  });

  /// Nome da instituição responsável, como deve aparecer na tela.
  final String sourceName;

  /// Endereço oficial para a pessoa conferir por conta própria.
  final String officialUrl;

  /// Código da estação, quando o dado for uma medição.
  final String? stationCode;
  final String? stationName;

  /// Coordenada de referência, quando o dado for previsão de grade.
  final double? latitude;
  final double? longitude;

  /// Ressalva específica desta origem (ex.: distância da coordenada pedida).
  final String? note;

  /// Descrição curta do ponto de referência, para exibir junto do valor.
  String get referenceLabel {
    if (stationName != null) {
      final code = stationCode == null ? '' : ' ($stationCode)';
      return 'Estação $stationName$code';
    }
    if (latitude != null && longitude != null) {
      return 'Coordenada ${latitude!.toStringAsFixed(4)}, '
          '${longitude!.toStringAsFixed(4)}';
    }
    return sourceName;
  }
}

/// Um valor único, com tudo o que a interface precisa para não mentir sobre ele.
@immutable
class Measurement<T> {
  const Measurement({
    required this.value,
    required this.unit,
    required this.measuredAt,
    required this.fetchedAt,
    required this.origin,
    required this.nature,
    required this.validFor,
  });

  final T value;

  /// Unidade já normalizada para exibição (ex.: `m`, `°C`, `mm`, `%`).
  final String unit;

  /// Instante a que o valor se refere — não o instante em que foi baixado.
  ///
  /// Nunca escreva "agora" quando este campo existir: mostre o horário.
  final DateTime measuredAt;

  /// Instante em que a consulta foi feita.
  final DateTime fetchedAt;

  final DataOrigin origin;
  final DataNature nature;

  /// Por quanto tempo este valor pode ser reaproveitado antes de virar antigo.
  final Duration validFor;

  /// Idade do valor em relação ao instante de referência.
  Duration ageAt(DateTime now) => now.difference(measuredAt);

  bool isExpiredAt(DateTime now) => now.difference(fetchedAt) > validFor;

  /// Estado derivado apenas do tempo. A camada de repositório pode rebaixar
  /// este resultado, nunca promovê-lo.
  DataState stateAt(DateTime now) =>
      isExpiredAt(now) ? DataState.stale : DataState.fresh;

  Measurement<R> map<R>(R Function(T) transform, {String? unit}) =>
      Measurement<R>(
        value: transform(value),
        unit: unit ?? this.unit,
        measuredAt: measuredAt,
        fetchedAt: fetchedAt,
        origin: origin,
        nature: nature,
        validFor: validFor,
      );
}

/// Resultado de uma consulta a um provedor: valor **ou** motivo da ausência.
///
/// Existe para que a falha de uma fonte não apague as outras. Um erro no nível
/// do rio não pode esconder a previsão do tempo.
@immutable
class ProviderResult<T> {
  const ProviderResult._({
    required this.state,
    this.data,
    this.message,
    this.attemptedAt,
    this.origin,
  });

  factory ProviderResult.success(T data, {DataState state = DataState.fresh}) =>
      ProviderResult._(state: state, data: data);

  /// Falha com motivo legível. Detalhe técnico vai para o log, não para a tela.
  factory ProviderResult.failure(
    DataState state, {
    required String message,
    DateTime? attemptedAt,
    DataOrigin? origin,
  }) =>
      ProviderResult._(
        state: state,
        message: message,
        attemptedAt: attemptedAt,
        origin: origin,
      );

  final DataState state;
  final T? data;

  /// Mensagem compreensível por quem não é técnico.
  final String? message;

  /// Horário da última tentativa, exibido junto do botão "Atualizar".
  final DateTime? attemptedAt;
  final DataOrigin? origin;

  bool get hasData => data != null && state.hasValue;

  ProviderResult<T> asStale() => ProviderResult._(
        state: DataState.stale,
        data: data,
        message: message,
        attemptedAt: attemptedAt,
        origin: origin,
      );
}

/// Intervalos aceitáveis para descartar leitura absurda antes de exibir.
///
/// Uma fonte pode devolver sentinela (-9999) ou um valor corrompido; mostrar
/// isso como nível do rio seria pior do que mostrar indisponível.
class PlausibleRange {
  const PlausibleRange(this.min, this.max, this.description);

  final double min;
  final double max;
  final String description;

  bool accepts(double value) => value >= min && value <= max;

  /// Nível do Itajaí-Açu em Blumenau. O recorde histórico de 1984 foi de
  /// 15,34 m; abaixo de zero não existe leitura válida na régua.
  static const riverLevelMeters =
      PlausibleRange(0, 20, 'nível do rio em metros');

  /// Temperatura do ar em Blumenau, com folga confortável nas duas pontas.
  static const airTemperatureCelsius =
      PlausibleRange(-10, 55, 'temperatura em graus Celsius');

  static const relativeHumidityPercent =
      PlausibleRange(0, 100, 'umidade relativa em porcento');

  /// Precipitação acumulada em uma janela curta.
  static const precipitationMillimeters =
      PlausibleRange(0, 500, 'precipitação em milímetros');

  static const windSpeedKmh = PlausibleRange(0, 250, 'vento em km/h');
}
