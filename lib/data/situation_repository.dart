import 'package:flutter/foundation.dart';

import '../emergency.dart';
import 'blualert_situation_provider.dart';
import 'hydrology.dart';
import 'measurement.dart';
import 'neighborhoods.dart';
import 'neighborhoods_data.dart';
import 'official_alerts.dart';
import 'open_meteo_provider.dart';
import 'weather.dart';

/// Retrato da situação de Blumenau, com cada bloco carregando seu próprio
/// estado.
///
/// A separação é o ponto central desta classe: se o nível do rio falhar, a
/// previsão continua na tela. Um único "deu erro" para tudo esconderia
/// informação que está funcionando.
@immutable
class BlumenauSituation {
  const BlumenauSituation({
    required this.alerts,
    required this.river,
    required this.weather,
    required this.neighborhoods,
    required this.lastAttemptAt,
  });

  final ProviderResult<OfficialAlerts> alerts;
  final ProviderResult<RiverSituation> river;
  final ProviderResult<WeatherSituation> weather;
  final ProviderResult<List<AreaForecast>> neighborhoods;

  /// Horário da última tentativa de atualização, exibido junto de "Atualizar".
  final DateTime lastAttemptAt;

  /// Se pelo menos uma fonte entregou algo exibível.
  bool get hasAnyData =>
      alerts.hasData ||
      river.hasData ||
      weather.hasData ||
      neighborhoods.hasData;

  /// Se alguma fonte falhou enquanto outra funcionou.
  bool get isPartial =>
      hasAnyData &&
      (!alerts.hasData ||
          !river.hasData ||
          !weather.hasData ||
          !neighborhoods.hasData);
}

/// Reúne os provedores e guarda o último resultado bom de cada um.
///
/// Regra de cache: um valor vencido pode ser reexibido, mas **sempre** rebaixado
/// para [DataState.stale], para que a interface o marque como "última leitura
/// disponível" com o horário à vista. Dado antigo jamais aparece como atual.
class SituationRepository extends ChangeNotifier {
  SituationRepository({
    BluAlertSituationProvider? situationProvider,
    WeatherProvider? weatherProvider,
    DateTime Function()? clock,
  })  : _situation = situationProvider ?? BluAlertSituationProvider(),
        _weather = weatherProvider ?? OpenMeteoWeatherProvider(),
        _clock = clock ?? DateTime.now;

  final BluAlertSituationProvider _situation;
  final WeatherProvider _weather;
  final DateTime Function() _clock;

  BlumenauSituation? _current;
  bool _loading = false;

  BlumenauSituation? get current => _current;
  bool get isLoading => _loading;

  ProviderResult<OfficialAlerts>? _lastAlerts;
  ProviderResult<RiverSituation>? _lastRiver;
  ProviderResult<WeatherSituation>? _lastWeather;
  ProviderResult<List<AreaForecast>>? _lastNeighborhoods;

  /// Consulta todas as fontes em paralelo. Uma falha nunca derruba as outras.
  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    final attemptedAt = _clock();
    final results = await Future.wait<Object>([
      _guard(() => _situation.loadOfficialAlerts(forceRefresh: force),
          _lastAlerts, 'os avisos oficiais'),
      _guard(() => _situation.loadRiverSituation(forceRefresh: force),
          _lastRiver, 'o nível do rio'),
      _guard(
          _weather.loadMunicipalWeather, _lastWeather, 'a previsão do tempo'),
      _guard(
        () async {
          // Desligável pela configuração remota, sem republicar o aplicativo.
          if (!PilotConfigService.current.value.neighborhoodForecastEnabled) {
            return ProviderResult<List<AreaForecast>>.failure(
              DataState.noDataAvailable,
              message: 'A previsão por bairro está desativada pela operação.',
              attemptedAt: _clock(),
            );
          }
          return _weather.loadNeighborhoodForecast(officialNeighborhoods);
        },
        _lastNeighborhoods,
        'a previsão por bairro',
      ),
    ]);

    _lastAlerts = results[0] as ProviderResult<OfficialAlerts>;
    _lastRiver = results[1] as ProviderResult<RiverSituation>;
    _lastWeather = results[2] as ProviderResult<WeatherSituation>;
    _lastNeighborhoods = results[3] as ProviderResult<List<AreaForecast>>;

    _current = BlumenauSituation(
      alerts: _lastAlerts!,
      river: _lastRiver!,
      weather: _lastWeather!,
      neighborhoods: _lastNeighborhoods!,
      lastAttemptAt: attemptedAt,
    );
    _loading = false;
    notifyListeners();
  }

  /// Executa uma consulta e, se falhar, reaproveita o último bom resultado
  /// **marcado como antigo**.
  Future<ProviderResult<T>> _guard<T>(
    Future<ProviderResult<T>> Function() run,
    ProviderResult<T>? previous,
    String subject,
  ) async {
    try {
      final result = await run();
      if (result.hasData) return result;
      // Falhou agora: se havia valor anterior, mostra-o como última leitura.
      if (previous != null && previous.data != null) return previous.asStale();
      return result;
    } catch (error, stack) {
      // Detalhe técnico só no log; a tela recebe linguagem comum.
      debugPrint('Falha ao carregar $subject: $error');
      debugPrintStack(stackTrace: stack, maxFrames: 6);
      if (previous != null && previous.data != null) return previous.asStale();
      return ProviderResult<T>.failure(
        DataState.sourceDown,
        message: 'Não foi possível carregar $subject agora.',
        attemptedAt: _clock(),
      );
    }
  }

  /// Área de previsão que cobre um bairro.
  AreaForecast? forecastFor(Neighborhood neighborhood) {
    final areas = _lastNeighborhoods?.data;
    if (areas == null) return null;
    for (final area in areas) {
      if (area.area.neighborhoods
          .any((item) => item.officialCode == neighborhood.officialCode)) {
        return area;
      }
    }
    return null;
  }
}
