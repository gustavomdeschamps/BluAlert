import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'backend_client.dart';

const _pilotNavy = Color(0xFF0B2748);
const _pilotAmber = Color(0xFFB45309);
const _pilotAmberSurface = Color(0xFFFFF4E5);
const _pilotAmberBorder = Color(0xFFF0C48A);
const _emergencyRed = Color(0xFFB3261E);
const _emergencySurface = Color(0xFFFFECE7);
const _emergencyBorder = Color(0xFFFFC4B5);
const _pilotInk = Color(0xFF162632);
const _pilotMuted = Color(0xFF5C6B74);

/// Configuração operacional publicada pelo backend.
///
/// Enquanto não houver uma central humana formalmente responsável pelo canal
/// digital, `pilotMode` permanece verdadeiro e a interface precisa dizer isso
/// com todas as letras. Qualquer falha de leitura cai para o lado seguro: modo
/// piloto ligado, central não confirmada e o telefone de emergência visível.
@immutable
class PilotConfig {
  const PilotConfig({
    required this.pilotMode,
    required this.humanReceiverConfirmed,
    required this.emergencyPhone,
    required this.uploadsEnabled,
    required this.videoEnabled,
    required this.origin,
    this.weatherCacheSeconds = 1800,
    this.hydrologyCacheSeconds = 1800,
    this.neighborhoodForecastEnabled = true,
    this.landslideLayerEnabled = false,
    this.floodLayerEnabled = false,
    this.dataNotice,
    this.maintenanceNotice,
    this.mapTileUrl,
    this.mapTileAttribution,
  });

  /// Estado assumido antes de qualquer resposta do servidor e sempre que a
  /// leitura falhar. Nunca afirma que existe uma central humana atendendo.
  static const safeFallback = PilotConfig(
    pilotMode: true,
    humanReceiverConfirmed: false,
    emergencyPhone: '199',
    uploadsEnabled: true,
    videoEnabled: true,
    origin: PilotConfigOrigin.fallback,
  );

  final bool pilotMode;
  final bool humanReceiverConfirmed;
  final String emergencyPhone;
  final bool uploadsEnabled;
  final bool videoEnabled;
  final PilotConfigOrigin origin;

  /// Validade do cache, por família de dado. Permite afrouxar as consultas se
  /// a cota gratuita apertar, sem republicar o aplicativo.
  final int weatherCacheSeconds;
  final int hydrologyCacheSeconds;

  /// Desliga a previsão por bairro sem nova versão do app.
  final bool neighborhoodForecastEnabled;

  /// Camadas de risco. Permanecem desligadas enquanto não houver fonte oficial
  /// licenciada e vigente — ligar sem isso desenharia risco não validado sobre
  /// a casa de alguém.
  final bool landslideLayerEnabled;
  final bool floodLayerEnabled;

  /// Aviso sobre os dados, exibido no topo da situação quando preenchido.
  final String? dataNotice;

  /// Manutenção programada, para avisar antes de a fonte cair.
  final String? maintenanceNotice;

  /// Provedor de tiles alternativo. Vazio mantém o OpenStreetMap padrão.
  final String? mapTileUrl;
  final String? mapTileAttribution;

  Duration get weatherCache => Duration(seconds: weatherCacheSeconds);
  Duration get hydrologyCache => Duration(seconds: hydrologyCacheSeconds);

  /// O aviso de piloto some apenas quando o servidor confirmar as duas coisas:
  /// que o piloto acabou e que existe uma central humana integrada.
  bool get showsPilotNotice => pilotMode || !humanReceiverConfirmed;

  factory PilotConfig.fromJson(Map<String, dynamic> json) => PilotConfig(
        pilotMode: json['pilot_mode'] as bool? ?? true,
        humanReceiverConfirmed:
            json['human_receiver_confirmed'] as bool? ?? false,
        emergencyPhone:
            (json['emergency_phone'] as String?)?.trim().isNotEmpty == true
                ? (json['emergency_phone'] as String).trim()
                : '199',
        uploadsEnabled: json['uploads_enabled'] as bool? ?? true,
        videoEnabled: json['video_enabled'] as bool? ?? true,
        origin: PilotConfigOrigin.server,
        // Cada campo cai no padrão local seguro se vier ausente ou fora de
        // faixa: uma configuração remota corrompida não pode desconfigurar o
        // aplicativo inteiro.
        weatherCacheSeconds:
            _boundedSeconds(json['weather_cache_seconds'], 1800),
        hydrologyCacheSeconds:
            _boundedSeconds(json['hydrology_cache_seconds'], 1800),
        neighborhoodForecastEnabled:
            json['neighborhood_forecast_enabled'] as bool? ?? true,
        landslideLayerEnabled:
            json['landslide_layer_enabled'] as bool? ?? false,
        floodLayerEnabled: json['flood_layer_enabled'] as bool? ?? false,
        dataNotice: _text(json['data_notice']),
        maintenanceNotice: _text(json['maintenance_notice']),
        mapTileUrl: _text(json['map_tile_url']),
        mapTileAttribution: _text(json['map_tile_attribution']),
      );

  /// Texto opcional: string vazia vira ausência, para a interface não mostrar
  /// um aviso em branco.
  static String? _text(Object? raw) {
    final value = raw is String ? raw.trim() : '';
    return value.isEmpty ? null : value;
  }

  /// Mantém o cache entre 5 minutos e 6 horas, como o banco também exige.
  static int _boundedSeconds(Object? raw, int fallback) {
    final value = raw is num ? raw.toInt() : null;
    if (value == null || value < 300 || value > 21600) return fallback;
    return value;
  }
}

enum PilotConfigOrigin {
  /// Valor assumido: o servidor ainda não respondeu ou está indisponível.
  fallback,

  /// Valor lido do backend.
  server,
}

/// Lê a configuração do piloto e mantém o último valor conhecido.
///
/// A leitura é deliberadamente tolerante: um piloto sem rede precisa continuar
/// mostrando o 199, então uma falha nunca vira erro de tela — vira o
/// [PilotConfig.safeFallback].
class PilotConfigService {
  PilotConfigService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static final ValueNotifier<PilotConfig> current =
      ValueNotifier<PilotConfig>(PilotConfig.safeFallback);

  Future<PilotConfig> load() async {
    final supabaseUrl = BackendClient.supabaseUrl;
    final anonKey = BackendClient.anonKey;
    if (supabaseUrl.isEmpty || anonKey.isEmpty) {
      current.value = PilotConfig.safeFallback;
      return current.value;
    }
    try {
      final response = await _http.get(
        Uri.parse('$supabaseUrl/functions/v1/remote-config'),
        headers: {'apikey': anonKey},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return current.value;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return current.value;
      current.value = PilotConfig.fromJson(decoded);
    } catch (_) {
      // Mantém o último valor conhecido — ou o fallback seguro, se nunca houve.
    }
    return current.value;
  }
}

/// Resultado de uma tentativa de ligação de emergência.
///
/// A ligação nunca pode falhar em silêncio: se o discador não abrir, a pessoa
/// precisa ver o número para digitar à mão.
enum EmergencyCallOutcome { opened, failed }

Future<EmergencyCallOutcome> callEmergency(String number) async {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return EmergencyCallOutcome.failed;
  try {
    final opened = await launchUrl(
      Uri(scheme: 'tel', path: digits),
      mode: LaunchMode.externalApplication,
    );
    return opened ? EmergencyCallOutcome.opened : EmergencyCallOutcome.failed;
  } catch (_) {
    return EmergencyCallOutcome.failed;
  }
}

/// Botão de ligação de emergência com falha visível.
class EmergencyCallButton extends StatefulWidget {
  const EmergencyCallButton({
    required this.number,
    this.service = 'Defesa Civil',
    this.expanded = true,
    super.key,
  });

  final String number;
  final String service;
  final bool expanded;

  @override
  State<EmergencyCallButton> createState() => _EmergencyCallButtonState();
}

class _EmergencyCallButtonState extends State<EmergencyCallButton> {
  bool failed = false;

  Future<void> _call() async {
    final outcome = await callEmergency(widget.number);
    if (!mounted) return;
    setState(() => failed = outcome == EmergencyCallOutcome.failed);
  }

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: _call,
      style: FilledButton.styleFrom(
        backgroundColor: _emergencyRed,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
      ),
      icon: const Icon(Icons.phone_in_talk_rounded),
      label: Text('Ligar ${widget.number} — ${widget.service}'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Ligar para ${widget.number}, ${widget.service}',
          child: widget.expanded
              ? button
              : Align(alignment: Alignment.centerLeft, child: button),
        ),
        if (failed) ...[
          const SizedBox(height: 8),
          Text(
            'Não foi possível abrir o discador. Ligue manualmente para '
            '${widget.number}.',
            style: const TextStyle(
              color: _emergencyRed,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

/// Faixa de aviso do piloto, com o telefone de emergência sempre acessível.
///
/// Aparece no envio e na confirmação de ocorrência: são os dois momentos em que
/// a pessoa pode concluir, por engano, que uma equipe já foi acionada.
class PilotNotice extends StatelessWidget {
  const PilotNotice({this.dense = false, super.key});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PilotConfig>(
      valueListenable: PilotConfigService.current,
      builder: (context, config, _) {
        if (!config.showsPilotNotice) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(dense ? 12 : 14),
          decoration: BoxDecoration(
            color: _pilotAmberSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _pilotAmberBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: _pilotAmber),
                  SizedBox(width: 8),
                  Text(
                    'VERSÃO PILOTO',
                    style: TextStyle(
                      color: _pilotAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              const Text(
                'Projeto escolar em teste. Este canal não substitui a central de '
                'emergência e não é monitorado pela Defesa Civil. Nenhuma equipe '
                'é acionada automaticamente pelo aplicativo.',
                style: TextStyle(color: _pilotInk, fontSize: 12, height: 1.45),
              ),
              SizedBox(height: dense ? 10 : 12),
              EmergencyCallButton(number: config.emergencyPhone),
            ],
          ),
        );
      },
    );
  }
}

/// Faixa compacta de emergência para o topo dos fluxos de risco.
class EmergencyCallout extends StatelessWidget {
  const EmergencyCallout({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PilotConfig>(
      valueListenable: PilotConfigService.current,
      builder: (context, config, _) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _emergencySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _emergencyBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: _emergencyRed),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Perigo imediato? Não espere o envio: ligue agora.',
                style: TextStyle(
                  color: _pilotInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _InlineCallButton(number: config.emergencyPhone),
          ],
        ),
      ),
    );
  }
}

class _InlineCallButton extends StatefulWidget {
  const _InlineCallButton({required this.number});
  final String number;

  @override
  State<_InlineCallButton> createState() => _InlineCallButtonState();
}

class _InlineCallButtonState extends State<_InlineCallButton> {
  bool failed = false;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FilledButton(
            onPressed: () async {
              final outcome = await callEmergency(widget.number);
              if (!mounted) return;
              setState(() => failed = outcome == EmergencyCallOutcome.failed);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _emergencyRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(
              widget.number,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Disque ${widget.number}',
                style: const TextStyle(
                  color: _emergencyRed,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      );
}

/// Selo permanente de piloto para cabeçalhos.
class PilotBadge extends StatelessWidget {
  const PilotBadge({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PilotConfig>(
        valueListenable: PilotConfigService.current,
        builder: (context, config, _) {
          if (!config.showsPilotNotice) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF06432),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'VERSÃO PILOTO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .9,
              ),
            ),
          );
        },
      );
}

/// Rodapé que explica a origem do dado quando ele existe de verdade.
class SourceStamp extends StatelessWidget {
  const SourceStamp({
    required this.source,
    required this.updatedAt,
    super.key,
  });

  final String source;
  final String updatedAt;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_outlined, size: 14, color: _pilotNavy),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Fonte: $source · $updatedAt',
              style: const TextStyle(color: _pilotMuted, fontSize: 10.5),
            ),
          ),
        ],
      );
}
