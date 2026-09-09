import 'package:flutter/material.dart';

import 'data/hydrology.dart';
import 'data/measurement.dart';
import 'data/neighborhoods.dart';
import 'data/official_alerts.dart';
import 'data/situation_repository.dart';
import 'data/weather.dart';

const _navy = Color(0xFF173B67);
const _navyDark = Color(0xFF0B2748);
const _orangeDark = Color(0xFFC6431F);
const _water = Color(0xFF2D7FA8);
const _ink = Color(0xFF162632);
const _muted = Color(0xFF5C6B74);
const _success = Color(0xFF16845B);
const _danger = Color(0xFFC92B35);
const _warning = Color(0xFF8A6D1F);
const _line = Color(0xFFE1E6E9);

/// Ícone vetorial para uma condição do tempo. Sem emojis, por decisão de
/// identidade e de acessibilidade — emoji varia por sistema e não tem rótulo.
IconData weatherIcon(WeatherCondition condition) => switch (condition) {
      WeatherCondition.clear => Icons.wb_sunny_outlined,
      WeatherCondition.mainlyClear => Icons.wb_sunny_outlined,
      WeatherCondition.partlyCloudy => Icons.wb_cloudy_outlined,
      WeatherCondition.overcast => Icons.cloud_outlined,
      WeatherCondition.fog => Icons.foggy,
      WeatherCondition.drizzle => Icons.grain_outlined,
      WeatherCondition.rain => Icons.water_drop_outlined,
      WeatherCondition.rainShowers => Icons.shower_outlined,
      WeatherCondition.freezingRain => Icons.severe_cold_outlined,
      WeatherCondition.snow => Icons.ac_unit_outlined,
      WeatherCondition.thunderstorm => Icons.thunderstorm_outlined,
      WeatherCondition.unknown => Icons.help_outline_rounded,
    };

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Horário no formato 24 h. Nunca escrevemos "agora" quando há horário real.
String formatTime(DateTime time) =>
    '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';

String formatDate(DateTime date) =>
    '${_twoDigits(date.day)}/${_twoDigits(date.month)}';

String formatDateTime(DateTime time) =>
    '${formatDate(time)} às ${formatTime(time)}';

/// Quão velho é o dado, em linguagem comum.
String describeAge(DateTime measuredAt, DateTime now) {
  final age = now.difference(measuredAt);
  if (age.inMinutes < 1) return 'há menos de um minuto';
  if (age.inMinutes < 60) return 'há ${age.inMinutes} min';
  if (age.inHours < 24) return 'há ${age.inHours} h';
  return 'há ${age.inDays} dia${age.inDays == 1 ? '' : 's'}';
}

/// Painel "Situação em Blumenau".
///
/// A ordem das seções é deliberada e segue a urgência de decisão: aviso
/// oficial, rio, condições agora, próximas horas, bairros e, por último, a
/// procedência de tudo.
class SituationPanel extends StatelessWidget {
  const SituationPanel({
    required this.repository,
    required this.onOpenSource,
    this.residentLatitude,
    this.residentLongitude,
    super.key,
  });

  final SituationRepository repository;
  final void Function(String url) onOpenSource;
  final double? residentLatitude;
  final double? residentLongitude;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final situation = repository.current;
        if (situation == null) {
          return const _PanelLoading();
        }
        final now = DateTime.now();
        final home = residentLatitude != null && residentLongitude != null
            ? nearestNeighborhood(residentLatitude!, residentLongitude!)
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RefreshBar(
              lastAttemptAt: situation.lastAttemptAt,
              isLoading: repository.isLoading,
              isPartial: situation.isPartial,
              onRefresh: () => repository.refresh(force: true),
            ),
            const SizedBox(height: 14),
            OfficialAlertsSection(
                result: situation.alerts, onOpenSource: onOpenSource),
            const SizedBox(height: 14),
            RiverSection(
                result: situation.river, now: now, onOpenSource: onOpenSource),
            const SizedBox(height: 14),
            CurrentWeatherSection(result: situation.weather, now: now),
            const SizedBox(height: 14),
            HourlyForecastSection(result: situation.weather),
            const SizedBox(height: 14),
            NeighborhoodForecastSection(
              result: situation.neighborhoods,
              highlighted: home,
            ),
            const SizedBox(height: 14),
            SourcesSection(situation: situation, onOpenSource: onOpenSource),
          ],
        );
      },
    );
  }
}

class _PanelLoading extends StatelessWidget {
  const _PanelLoading();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 14),
              Expanded(child: Text('Consultando as fontes oficiais...')),
            ],
          ),
        ),
      );
}

class _RefreshBar extends StatelessWidget {
  const _RefreshBar({
    required this.lastAttemptAt,
    required this.isLoading,
    required this.isPartial,
    required this.onRefresh,
  });

  final DateTime lastAttemptAt;
  final bool isLoading;
  final bool isPartial;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Última tentativa às ${formatTime(lastAttemptAt)}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                if (isPartial)
                  const Text(
                    'Parte das fontes não respondeu.',
                    style: TextStyle(
                        color: _warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: isLoading ? null : onRefresh,
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Atualizar'),
          ),
        ],
      );
}

/// Cartão padrão de uma seção, com título e conteúdo.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.accent = _navy,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 19, color: accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 14),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

/// Mensagem honesta para uma fonte que não entregou dado.
class UnavailableNotice extends StatelessWidget {
  const UnavailableNotice({required this.result, super.key});

  final ProviderResult<Object?> result;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (result.state) {
      DataState.offline => (Icons.wifi_off_rounded, 'Sem conexão'),
      DataState.locationDenied => (
          Icons.location_disabled_rounded,
          'Localização não autorizada'
        ),
      DataState.noDataAvailable => (
          Icons.help_outline_rounded,
          'Sem dado publicado'
        ),
      DataState.invalidResponse => (
          Icons.report_gmailerrorred_outlined,
          'Resposta não reconhecida'
        ),
      _ => (Icons.cloud_off_rounded, 'Fonte indisponível'),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _muted),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: _ink, fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                result.message ?? 'Não há informação para mostrar agora.',
                style:
                    const TextStyle(color: _muted, fontSize: 12, height: 1.4),
              ),
              if (result.attemptedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Tentado às ${formatTime(result.attemptedAt!)}',
                    style: const TextStyle(color: _muted, fontSize: 10.5),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Selo de dado antigo. Só aparece quando o valor exibido está fora da validade.
class StaleBadge extends StatelessWidget {
  const StaleBadge({required this.measuredAt, required this.now, super.key});

  final DateTime measuredAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _warning.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Última leitura disponível · ${formatDateTime(measuredAt)}',
          style: const TextStyle(
              color: _warning, fontSize: 10, fontWeight: FontWeight.w900),
        ),
      );
}

/// Seção 1 — avisos oficiais.
class OfficialAlertsSection extends StatelessWidget {
  const OfficialAlertsSection({
    required this.result,
    required this.onOpenSource,
    super.key,
  });

  final ProviderResult<OfficialAlerts> result;
  final void Function(String url) onOpenSource;

  @override
  Widget build(BuildContext context) {
    if (!result.hasData) {
      return _SectionCard(
        icon: Icons.campaign_outlined,
        title: 'Avisos oficiais',
        child: UnavailableNotice(result: result),
      );
    }
    final alerts = result.data!;
    final elevated = alerts.elevated;
    final accent = elevated.isEmpty ? _success : _danger;
    return _SectionCard(
      icon: Icons.campaign_outlined,
      title: 'Avisos oficiais',
      accent: accent,
      trailing: TextButton(
        onPressed: () => onOpenSource(alerts.origin.officialUrl),
        child: const Text('Ver fonte'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (elevated.isEmpty)
            const Row(
              children: [
                Icon(Icons.check_circle_outline, size: 18, color: _success),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A Defesa Civil publicou normalidade em todas as regiões.',
                    style: TextStyle(color: _ink, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            )
          else
            ...elevated.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 18, color: _danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Região ${item.region}: ${item.stage}',
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 10),
          Text(
            'Publicado pela Defesa Civil de Blumenau em '
            '${formatDate(alerts.publishedAt)}.',
            style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Seção 2 — nível do rio.
class RiverSection extends StatelessWidget {
  const RiverSection({
    required this.result,
    required this.now,
    required this.onOpenSource,
    super.key,
  });

  final ProviderResult<RiverSituation> result;
  final DateTime now;
  final void Function(String url) onOpenSource;

  @override
  Widget build(BuildContext context) {
    if (!result.hasData) {
      return _SectionCard(
        icon: Icons.water_rounded,
        title: 'Nível do Rio Itajaí-Açu',
        accent: _water,
        child: UnavailableNotice(result: result),
      );
    }
    final river = result.data!;
    final stage = river.calculatedStage;
    final stageColor = switch (stage) {
      RiverStage.normality => _success,
      RiverStage.observation => _water,
      RiverStage.attention => _warning,
      RiverStage.alert || RiverStage.maximumAlert => _danger,
    };
    return _SectionCard(
      icon: Icons.water_rounded,
      title: 'Nível do Rio Itajaí-Açu',
      accent: _water,
      trailing: TextButton(
        onPressed: () => onOpenSource(river.level.origin.officialUrl),
        child: const Text('Ver fonte'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.state.needsStaleWarning) ...[
            StaleBadge(measuredAt: river.level.measuredAt, now: now),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                river.level.value.toStringAsFixed(2).replaceAll('.', ','),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.6,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(river.level.unit,
                    style: const TextStyle(
                        color: _muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: stageColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  river.displayStage.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Medido às ${formatTime(river.level.measuredAt)} '
            '(${describeAge(river.level.measuredAt, now)}) · '
            '${river.level.origin.referenceLabel}',
            style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 12),
          _TrendRow(trend: river.trend),
          const SizedBox(height: 12),
          _StageScale(current: stage),
          if (river.stageIsOfficial) ...[
            const SizedBox(height: 8),
            Text(
              'Estágio "${river.officialStage!.value}" publicado pela Defesa '
              'Civil em ${formatDate(river.officialStage!.measuredAt)}.',
              style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
            ),
          ],
          if (river.municipalLevel != null &&
              (river.municipalLevel!.value - river.level.value).abs() > 0.005)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'O município publicou '
                '${river.municipalLevel!.value.toStringAsFixed(2).replaceAll('.', ',')} m '
                'em ${formatDate(river.municipalLevel!.measuredAt)}; a diferença '
                'é o intervalo entre as duas leituras.',
                style:
                    const TextStyle(color: _muted, fontSize: 11, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend});

  final RiverTrendResult trend;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (trend.trend) {
      RiverTrend.rising => (Icons.trending_up_rounded, _danger),
      RiverTrend.falling => (Icons.trending_down_rounded, _success),
      RiverTrend.stable => (Icons.trending_flat_rounded, _muted),
      RiverTrend.unavailable => (Icons.help_outline_rounded, _muted),
    };
    final change = trend.changeMeters;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trend.trend.label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w900, fontSize: 13),
              ),
              Text(
                trend.trend.isKnown && change != null
                    ? '${change >= 0 ? '+' : ''}'
                        '${change.toStringAsFixed(2).replaceAll('.', ',')} m em '
                        '${trend.window.inHours} h '
                        '(${trend.readingsUsed} leituras)'
                    : trend.reason ?? 'Sem série suficiente para calcular.',
                style:
                    const TextStyle(color: _muted, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Escala das cotas oficiais, com a faixa atual destacada.
class _StageScale extends StatelessWidget {
  const _StageScale({required this.current});

  final RiverStage current;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COTAS OFICIAIS DA DEFESA CIVIL',
            style: TextStyle(
                color: _muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .9),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: RiverStage.values.map((stage) {
              final active = stage == current;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? _navyDark : const Color(0xFFF0F3F5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: active ? _navyDark : _line),
                ),
                child: Text(
                  '${stage.label} · ${stage.range}',
                  style: TextStyle(
                    color: active ? Colors.white : _muted,
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
}

/// Seção 3 — chuva e condições atuais.
class CurrentWeatherSection extends StatelessWidget {
  const CurrentWeatherSection({
    required this.result,
    required this.now,
    super.key,
  });

  final ProviderResult<WeatherSituation> result;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (!result.hasData) {
      return _SectionCard(
        icon: Icons.thermostat_outlined,
        title: 'Condições agora',
        child: UnavailableNotice(result: result),
      );
    }
    final current = result.data!.current;
    return _SectionCard(
      icon: Icons.thermostat_outlined,
      title: 'Condições agora',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.state.needsStaleWarning) ...[
            StaleBadge(measuredAt: current.temperature.measuredAt, now: now),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Icon(weatherIcon(current.condition), size: 40, color: _water),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.temperature.value
                            .toStringAsFixed(1)
                            .replaceAll('.', ','),
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 34,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                      Text(current.temperature.unit,
                          style: const TextStyle(
                              color: _muted,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  Text(current.condition.label,
                      style: const TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (current.apparentTemperature != null)
                _Metric(
                  icon: Icons.device_thermostat,
                  label: 'Sensação',
                  value:
                      '${current.apparentTemperature!.value.toStringAsFixed(1).replaceAll('.', ',')}'
                      '${current.apparentTemperature!.unit}',
                ),
              if (current.humidity != null)
                _Metric(
                  icon: Icons.water_drop_outlined,
                  label: 'Umidade',
                  value:
                      '${current.humidity!.value.round()}${current.humidity!.unit}',
                ),
              if (current.precipitation != null)
                _Metric(
                  icon: Icons.umbrella_outlined,
                  label: 'Chuva recente',
                  value:
                      '${current.precipitation!.value.toStringAsFixed(1).replaceAll('.', ',')}'
                      ' ${current.precipitation!.unit}',
                ),
              if (current.windSpeed != null)
                _Metric(
                  icon: Icons.air_rounded,
                  label: 'Vento',
                  value: '${current.windSpeed!.value.round()} '
                      '${current.windSpeed!.unit}',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Referente às ${formatTime(current.temperature.measuredAt)} · '
            'previsão de modelo para a ${current.temperature.origin.referenceLabel.toLowerCase()}. '
            'Não é medição de estação em Blumenau.',
            style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _navy),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: _muted, fontSize: 9.5)),
                Text(value,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      );
}

/// Seção 4 — previsão das próximas horas.
class HourlyForecastSection extends StatelessWidget {
  const HourlyForecastSection({required this.result, super.key});

  final ProviderResult<WeatherSituation> result;

  @override
  Widget build(BuildContext context) {
    final hours = result.data?.hours ?? const <HourlyForecast>[];
    if (!result.hasData || hours.isEmpty) {
      return _SectionCard(
        icon: Icons.schedule_rounded,
        title: 'Próximas horas',
        child: result.hasData
            ? const Text('Sem previsão horária disponível agora.',
                style: TextStyle(color: _muted, fontSize: 12))
            : UnavailableNotice(result: result),
      );
    }
    return _SectionCard(
      icon: Icons.schedule_rounded,
      title: 'Próximas horas',
      child: SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: hours.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final hour = hours[index];
            return Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F8),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatTime(hour.time),
                      style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  Icon(weatherIcon(hour.condition), size: 21, color: _water),
                  Text(
                    '${hour.temperature.round()}°',
                    style: const TextStyle(
                        color: _ink, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    hour.precipitationProbability == null
                        ? '—'
                        : '${hour.precipitationProbability}%',
                    style: const TextStyle(color: _water, fontSize: 10.5),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Seção 5 — previsão por bairro, agrupada por célula de grade.
class NeighborhoodForecastSection extends StatefulWidget {
  const NeighborhoodForecastSection({
    required this.result,
    this.highlighted,
    super.key,
  });

  final ProviderResult<List<AreaForecast>> result;

  /// Bairro do endereço da pessoa, destacado na lista.
  final Neighborhood? highlighted;

  @override
  State<NeighborhoodForecastSection> createState() =>
      _NeighborhoodForecastSectionState();
}

class _NeighborhoodForecastSectionState
    extends State<NeighborhoodForecastSection> {
  final controller = TextEditingController();
  String query = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final areas = widget.result.data ?? const <AreaForecast>[];
    if (!widget.result.hasData || areas.isEmpty) {
      return _SectionCard(
        icon: Icons.location_city_rounded,
        title: 'Previsão por bairro',
        child: UnavailableNotice(result: widget.result),
      );
    }
    final visible = query.trim().isEmpty
        ? areas
        : areas
            .where(
                (area) => area.area.neighborhoods.any((n) => n.matches(query)))
            .toList();

    return _SectionCard(
      icon: Icons.location_city_rounded,
      title: 'Previsão por bairro',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A limitação é declarada antes dos números, não em nota de rodapé.
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: _navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A previsão vem de um modelo de grade de cerca de 11 km. '
                    'Os 35 bairros de Blumenau caem em ${areas.length} '
                    'células, então bairros vizinhos compartilham a mesma '
                    'previsão. Não há estação meteorológica por bairro.',
                    style: const TextStyle(
                        color: _navyDark, fontSize: 11, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Buscar bairro',
              prefixIcon: Icon(Icons.search_rounded, size: 19),
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhum bairro encontrado com esse nome.',
                  style: TextStyle(color: _muted, fontSize: 12)),
            )
          else
            ...visible.map((area) => _AreaTile(
                  forecast: area,
                  highlighted: widget.highlighted,
                  query: query,
                )),
        ],
      ),
    );
  }
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({
    required this.forecast,
    required this.query,
    this.highlighted,
  });

  final AreaForecast forecast;
  final String query;
  final Neighborhood? highlighted;

  @override
  Widget build(BuildContext context) {
    final area = forecast.area;
    final isHome = highlighted != null &&
        area.neighborhoods
            .any((n) => n.officialCode == highlighted!.officialCode);
    final today = forecast.days.first;
    final names = area.neighborhoods.map((n) => n.displayName).join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHome ? const Color(0xFFFFF4E5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHome ? _orangeDark : _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(weatherIcon(today.condition), size: 24, color: _water),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isHome)
                      const Text(
                        'PRÓXIMO DO SEU ENDEREÇO',
                        style: TextStyle(
                            color: _orangeDark,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8),
                      ),
                    Text(
                      names,
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${today.maxTemperature.round()}° / '
                    '${today.minTemperature.round()}°',
                    style: const TextStyle(
                        color: _ink, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    today.precipitationProbability == null
                        ? 'chuva —'
                        : 'chuva ${today.precipitationProbability}%',
                    style: const TextStyle(color: _water, fontSize: 10.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${today.condition.label} · '
            '${today.precipitationSum == null ? 'sem volume previsto' : '${today.precipitationSum!.toStringAsFixed(1).replaceAll('.', ',')} mm'}'
            '${today.maxWindSpeed == null ? '' : ' · vento até ${today.maxWindSpeed!.round()} km/h'}',
            style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            'Previsão para ${formatDate(today.date)}, na coordenada de '
            'referência ${area.gridLatitude.toStringAsFixed(3)}, '
            '${area.gridLongitude.toStringAsFixed(3)}.',
            style: const TextStyle(color: _muted, fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Seção 6 — fontes e horários.
class SourcesSection extends StatelessWidget {
  const SourcesSection({
    required this.situation,
    required this.onOpenSource,
    super.key,
  });

  final BlumenauSituation situation;
  final void Function(String url) onOpenSource;

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, String nature, String url, String? when})>[
      if (situation.alerts.hasData)
        (
          label: situation.alerts.data!.origin.sourceName,
          nature: 'Publicação oficial',
          url: situation.alerts.data!.origin.officialUrl,
          when: formatDate(situation.alerts.data!.publishedAt),
        ),
      if (situation.river.hasData)
        (
          label: situation.river.data!.level.origin.sourceName,
          nature: 'Medição em estação telemétrica',
          url: situation.river.data!.level.origin.officialUrl,
          when: formatDateTime(situation.river.data!.level.measuredAt),
        ),
      if (situation.weather.hasData)
        (
          label: situation.weather.data!.origin.sourceName,
          nature: 'Previsão de modelo por grade',
          url: situation.weather.data!.origin.officialUrl,
          when: formatDateTime(
              situation.weather.data!.current.temperature.measuredAt),
        ),
    ];
    return _SectionCard(
      icon: Icons.verified_outlined,
      title: 'Fontes e horários',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entries.isEmpty)
            const Text(
              'Nenhuma fonte respondeu nesta tentativa.',
              style: TextStyle(color: _muted, fontSize: 12),
            )
          else
            ...entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.label,
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                            Text(
                              '${entry.nature}'
                              '${entry.when == null ? '' : ' · ${entry.when}'}',
                              style: const TextStyle(
                                  color: _muted, fontSize: 10.5, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => onOpenSource(entry.url),
                        child: const Text('Abrir'),
                      ),
                    ],
                  ),
                )),
          const Divider(height: 18, color: _line),
          const Text(
            'Medição é leitura de instrumento em estação identificada. '
            'Previsão é cálculo de modelo para uma coordenada e pode divergir '
            'do que acontece na rua.',
            style: TextStyle(color: _muted, fontSize: 10.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}
