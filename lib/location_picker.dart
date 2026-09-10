import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'data/map_tiles.dart';
import 'data/municipal_geo.dart';
import 'queue/queue_models.dart';

const _navy = Color(0xFF0B2748);
const _orangeDark = Color(0xFFC6431F);
const _ink = Color(0xFF162632);
const _muted = Color(0xFF5C6B74);
const _success = Color(0xFF16845B);
const _warning = Color(0xFF8A6D1F);
const _danger = Color(0xFFC92B35);
const _line = Color(0xFFD5DEE3);

/// Ponto confirmado pela pessoa, com a procedência preservada.
@immutable
class ConfirmedLocation {
  const ConfirmedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.capturedAt,
    required this.source,
  });

  final double latitude;
  final double longitude;

  /// Precisão do GPS. Fica nula quando o ponto foi ajustado à mão, porque o
  /// raio do GPS não descreve mais aquela coordenada.
  final double? accuracyM;
  final DateTime capturedAt;
  final LocationSource source;
}

/// Tela de confirmação e correção do ponto da ocorrência.
///
/// Existe porque o GPS erra: sob mata fechada, em vale ou dentro de casa o
/// desvio passa de 50 m com frequência em Blumenau. Um ponto errado manda a
/// equipe para a rua errada, e quem está no local é a única pessoa capaz de
/// corrigir isso.
///
/// O mapa é preso ao município: se o ponto cair fora de Blumenau, a tela avisa
/// em vez de aceitar em silêncio uma ocorrência que a Defesa Civil municipal
/// não pode atender.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    required this.initialLatitude,
    required this.initialLongitude,
    required this.gpsAccuracyM,
    required this.capturedAt,
    super.key,
  });

  final double initialLatitude;
  final double initialLongitude;
  final double? gpsAccuracyM;
  final DateTime capturedAt;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final mapController = MapController();
  final tileSource = const ConfiguredMapTileProvider().active;

  late LatLng point;
  late LocationSource source;

  List<List<LatLng>> boundaryRings = const [];

  static final _bounds = LatLngBounds(
    const LatLng(
      BlumenauMapBounds.southLatitude,
      BlumenauMapBounds.westLongitude,
    ),
    const LatLng(
      BlumenauMapBounds.northLatitude,
      BlumenauMapBounds.eastLongitude,
    ),
  );

  @override
  void initState() {
    super.initState();
    point = LatLng(widget.initialLatitude, widget.initialLongitude);
    source = LocationSource.gps;
    _loadBoundary();
  }

  Future<void> _loadBoundary() async {
    final result = await IbgeMunicipalGeoProvider().loadMunicipalBoundary();
    if (!mounted || !result.hasData) return;
    setState(() {
      boundaryRings = result.data!.rings
          .map((ring) =>
              ring.map((p) => LatLng(p.latitude, p.longitude)).toList())
          .toList();
    });
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  void _move(LatLng target) {
    setState(() {
      point = target;
      // A partir do primeiro ajuste, a precisão do GPS não vale mais.
      source = LocationSource.manuallyAdjusted;
    });
  }

  void _resetToGps() {
    setState(() {
      point = LatLng(widget.initialLatitude, widget.initialLongitude);
      source = LocationSource.gps;
    });
    mapController.move(point, mapController.camera.zoom);
  }

  bool get _outsideMunicipality =>
      !BlumenauMapBounds.contains(point.latitude, point.longitude);

  /// Acima de 50 m o ponto não identifica uma casa.
  bool get _lowAccuracy =>
      source == LocationSource.gps &&
      widget.gpsAccuracyM != null &&
      widget.gpsAccuracyM! > 50;

  @override
  Widget build(BuildContext context) {
    final showGpsRadius =
        source == LocationSource.gps && widget.gpsAccuracyM != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Confirmar o local do risco'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 17,
                    minZoom: BlumenauMapBounds.minimumZoom,
                    maxZoom: BlumenauMapBounds.maximumZoom,
                    cameraConstraint: CameraConstraint.contain(bounds: _bounds),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (_, target) => _move(target),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tileSource.urlTemplate,
                      userAgentPackageName: 'br.com.blualert.blualert',
                      maxZoom: tileSource.maxZoom.toDouble(),
                      panBuffer: 1,
                    ),
                    if (boundaryRings.isNotEmpty)
                      PolygonLayer(
                        polygons: [
                          for (final ring in boundaryRings)
                            Polygon(
                              points: ring,
                              borderColor: _navy.withValues(alpha: .45),
                              borderStrokeWidth: 1.5,
                              color: _navy.withValues(alpha: .03),
                            ),
                        ],
                      ),
                    // O círculo de precisão só aparece enquanto o ponto for do
                    // GPS: sobre um ponto escolhido à mão ele mentiria.
                    if (showGpsRadius)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: point,
                            radius: widget.gpsAccuracyM!.clamp(5, 200),
                            useRadiusInMeter: true,
                            color: _navy.withValues(alpha: .12),
                            borderColor: _navy.withValues(alpha: .35),
                            borderStrokeWidth: 1,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 46,
                          height: 46,
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.place_rounded,
                            size: 44,
                            color: _outsideMunicipality ? _danger : _orangeDark,
                          ),
                        ),
                      ],
                    ),
                    RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      attributions: [
                        TextSourceAttribution(tileSource.attribution),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _Hint(
                    text: source.isManual
                        ? 'Ponto ajustado por você. Toque no mapa para mover de novo.'
                        : 'Toque no mapa para corrigir o ponto, se ele não estiver onde o risco está.',
                  ),
                ),
              ],
            ),
          ),
          _Summary(
            point: point,
            source: source,
            gpsAccuracyM: widget.gpsAccuracyM,
            capturedAt: widget.capturedAt,
            outsideMunicipality: _outsideMunicipality,
            lowAccuracy: _lowAccuracy,
            onResetToGps: source.isManual ? _resetToGps : null,
            onConfirm: _outsideMunicipality
                ? null
                : () => Navigator.pop(
                      context,
                      ConfirmedLocation(
                        latitude: point.latitude,
                        longitude: point.longitude,
                        // Ajuste manual descarta a precisão do GPS.
                        accuracyM: source.isManual ? null : widget.gpsAccuracyM,
                        capturedAt: widget.capturedAt,
                        source: source,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app_outlined, size: 17, color: _navy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style:
                    const TextStyle(color: _ink, fontSize: 11.5, height: 1.35),
              ),
            ),
          ],
        ),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.point,
    required this.source,
    required this.gpsAccuracyM,
    required this.capturedAt,
    required this.outsideMunicipality,
    required this.lowAccuracy,
    required this.onResetToGps,
    required this.onConfirm,
  });

  final LatLng point;
  final LocationSource source;
  final double? gpsAccuracyM;
  final DateTime capturedAt;
  final bool outsideMunicipality;
  final bool lowAccuracy;
  final VoidCallback? onResetToGps;
  final VoidCallback? onConfirm;

  String get _clock => '${capturedAt.hour.toString().padLeft(2, '0')}:'
      '${capturedAt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _line)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    source.isManual
                        ? Icons.edit_location_alt_outlined
                        : Icons.gps_fixed_rounded,
                    size: 18,
                    color: source.isManual ? _orangeDark : _success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      source.label,
                      style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 13),
                    ),
                  ),
                  if (onResetToGps != null)
                    TextButton(
                      onPressed: onResetToGps,
                      child: const Text('Voltar ao GPS'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${point.latitude.toStringAsFixed(5)}, '
                '${point.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              Text(
                source.isManual
                    // Sem inventar um novo raio para o ponto escolhido.
                    ? 'Escolhido no mapa. A precisão do GPS não se aplica a este ponto.'
                    : gpsAccuracyM == null
                        ? 'Precisão não informada pelo aparelho.'
                        : 'Precisão de ${gpsAccuracyM!.round()} m · capturado às $_clock',
                style:
                    const TextStyle(color: _muted, fontSize: 11, height: 1.4),
              ),
              if (lowAccuracy) ...[
                const SizedBox(height: 10),
                const _Notice(
                  color: _warning,
                  icon: Icons.gps_not_fixed_rounded,
                  text: 'Precisão baixa: o ponto pode estar a mais de 50 m do '
                      'risco. Corrija no mapa se souber o local exato.',
                ),
              ],
              if (outsideMunicipality) ...[
                const SizedBox(height: 10),
                const _Notice(
                  color: _danger,
                  icon: Icons.wrong_location_outlined,
                  text: 'Este ponto está fora de Blumenau. A Defesa Civil '
                      'municipal não atende fora do município — mova o ponto '
                      'ou ligue 199.',
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: _orangeDark,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Confirmar este local'),
              ),
            ],
          ),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
