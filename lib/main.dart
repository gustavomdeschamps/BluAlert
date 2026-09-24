import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_flow.dart';
import 'accessibility.dart';
import 'data/map_tiles.dart';
import 'data/municipal_geo.dart';
import 'data/situation_repository.dart';
import 'emergency.dart';
import 'occurrence_flow.dart';
import 'queue/queue_controller.dart';
import 'situation_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // A configuração do piloto é lida em segundo plano: até ela chegar vale o
  // fallback seguro (modo piloto ligado, 199 visível), então a interface nunca
  // fica bloqueada esperando o servidor.
  unawaited(PilotConfigService().load());
  unawaited(AccessibilityController.instance.load());
  runApp(const BluAlertApp());
}

const navy = Color(0xFF173B67);
const navyDark = Color(0xFF0B2748);
const orange = Color(0xFFF06432);
const orangeDark = Color(0xFFC6431F);
const canvas = Color(0xFFF4F6F7);
const ink = Color(0xFF162632);
const muted = Color(0xFF5C6B74);
const success = Color(0xFF16845B);
const danger = Color(0xFFC92B35);

final alertaBluUri = Uri.parse(
  'https://defesacivil.blumenau.sc.gov.br/c/meteorologia/aplicativo',
);
final officialRiskMapUri = Uri.parse(
  'https://defesacivil.blumenau.sc.gov.br/m/risco',
);
final officialFloodMapUri = Uri.parse(
  'https://defesacivil.blumenau.sc.gov.br/m/inundacao',
);

class BluAlertApp extends StatelessWidget {
  const BluAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    final accessibility = AccessibilityController.instance;
    return AnimatedBuilder(
      animation: accessibility,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BluAlert Blumenau',
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(accessibility.textScale),
              disableAnimations: accessibility.reduceMotion,
              highContrast: accessibility.highContrast,
            ),
            child: AppViewport(child: child!),
          );
        },
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: canvas,
          colorScheme: ColorScheme.fromSeed(
            seedColor: navy,
            primary: accessibility.highContrast ? navyDark : navy,
            secondary: orange,
            error: danger,
            surface: Colors.white,
          ),
          fontFamily: 'Arial',
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              color: ink,
              fontWeight: FontWeight.w900,
              fontSize: 30,
              height: 1.04,
              letterSpacing: -1.1,
            ),
            headlineMedium: TextStyle(
              color: ink,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              height: 1.08,
              letterSpacing: -.7,
            ),
            titleLarge: TextStyle(
              color: ink,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
            titleMedium: TextStyle(
              color: ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            bodyLarge: TextStyle(color: ink, height: 1.42),
            bodyMedium: TextStyle(color: muted, height: 1.4),
          ),
          cardTheme: CardThemeData(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE1E6E9)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD8DFE3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD8DFE3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: orange, width: 2),
            ),
          ),
        ),
        home: AccountGate(
          builder: (profile, lock, removeProfile) => AppShell(
            profile: profile,
            onLock: lock,
            onRemoveProfile: removeProfile,
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.profile,
    required this.onLock,
    required this.onRemoveProfile,
    super.key,
  });

  final ResidentProfile profile;
  final VoidCallback onLock;
  final Future<void> Function() onRemoveProfile;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  QueueController? queue;
  bool queueFailed = false;

  @override
  void initState() {
    super.initState();
    _openQueue();
  }

  Future<void> _openQueue() async {
    try {
      final controller = await QueueController.instance();
      if (mounted) setState(() => queue = controller);
    } catch (_) {
      // Sem fila local o registro de ocorrência não pode funcionar com
      // segurança, mas o 199 e as orientações continuam disponíveis.
      if (mounted) setState(() => queueFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = queue;
    final pages = [
      HomeScreen(
        profile: widget.profile,
        onNavigate: (value) => setState(() => index = value),
        onAccount: () => _showAccount(context),
        onAccessibility: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AccessibilityScreen(),
          ),
        ),
      ),
      const RealMapScreen(),
      if (controller != null)
        OccurrenceScreen(profile: widget.profile, queue: controller)
      else
        QueueUnavailableScreen(failed: queueFailed),
      const EmergencyScreen(),
      const GuidanceScreen(),
    ];

    final app = Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE0D4),
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: orangeDark),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: orangeDark),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_a_photo_outlined),
            selectedIcon: Icon(Icons.add_a_photo_rounded, color: orangeDark),
            label: 'Registrar',
          ),
          NavigationDestination(
            icon: Icon(Icons.phone_in_talk_outlined),
            selectedIcon: Icon(Icons.phone_in_talk_rounded, color: danger),
            label: 'Emergência',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded, color: orangeDark),
            label: 'Orientações',
          ),
        ],
      ),
    );

    return app;
  }

  void _showAccount(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: orange.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.badge_rounded, color: orangeDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.profile.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(widget.profile.phone),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _AccountDetail(
                icon: Icons.location_on_outlined,
                label: 'Referência',
                value: widget.profile.hasGpsReference
                    ? 'Ponto GPS salvo no aparelho'
                    : widget.profile.referenceAddress.isEmpty
                        ? 'Não informado'
                        : widget.profile.referenceAddress,
              ),
              const SizedBox(height: 12),
              if (queue != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => QueueScreen(queue: queue!),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(backgroundColor: navy),
                    icon: const Icon(Icons.inbox_rounded),
                    label: const Text('Meus registros'),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccessibilityScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.accessibility_new_rounded),
                  label: const Text('Acessibilidade'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    widget.onLock();
                  },
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Bloquear aplicativo'),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await widget.onRemoveProfile();
                },
                child: const Text('Remover perfil deste aparelho'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mostrada enquanto a fila local abre — e se ela não abrir.
///
/// Sem fila não há como garantir que a ocorrência sobreviva a uma falha de
/// rede, então preferimos bloquear o registro a aceitar algo que pode sumir.
/// O 199 continua acessível, que é o que importa em risco imediato.
class QueueUnavailableScreen extends StatelessWidget {
  const QueueUnavailableScreen({required this.failed, super.key});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    if (!failed) {
      return const Center(child: CircularProgressIndicator(color: orange));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sd_card_alert_outlined, size: 44, color: danger),
            const SizedBox(height: 16),
            Text('Registro indisponível neste aparelho',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Não foi possível preparar o armazenamento local das ocorrências. '
              'Sem ele, um registro poderia se perder antes de chegar à central.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 20),
            const PilotNotice(),
          ],
        ),
      ),
    );
  }
}

class _AccountDetail extends StatelessWidget {
  const _AccountDetail({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: navy, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 11, color: muted)),
                  Text(
                    value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: ink),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class CivilDefenseHeader extends StatelessWidget {
  const CivilDefenseHeader({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 80 : 150,
      color: navyDark,
      child: Stack(
        children: [
          Positioned(
            right: -42,
            bottom: compact ? -58 : -38,
            child: Transform.rotate(
              angle: -.16,
              child: Container(
                width: 210,
                height: 86,
                color: orange,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, compact ? 10 : 16, 18, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: compact ? 46 : 58,
                    height: compact ? 46 : 58,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.asset(
                      'assets/brand/blualert_mark_v2.png',
                      fit: BoxFit.contain,
                      semanticLabel: 'Símbolo do BluAlert',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          compact ? 'BluAlert' : 'BLUALERT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 21 : 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: compact ? -.5 : 1.8,
                          ),
                        ),
                        if (!compact)
                          const Text(
                            'BLUMENAU',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                              letterSpacing: -.8,
                            ),
                          ),
                        Text(
                          compact
                              ? 'Dados públicos e mapa local'
                              : 'PROJETO ESCOLAR • INFORMAÇÃO PARA AGIR',
                          style: const TextStyle(
                            color: Color(0xFFBFD0DE),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.profile,
    required this.onNavigate,
    required this.onAccount,
    required this.onAccessibility,
    super.key,
  });
  final ResidentProfile profile;
  final ValueChanged<int> onNavigate;
  final VoidCallback onAccount;
  final VoidCallback onAccessibility;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final repository = SituationRepository();
  Timer? _situationRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    repository.refresh();
    _situationRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => repository.refresh(force: true),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      repository.refresh(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _situationRefreshTimer?.cancel();
    repository.dispose();
    super.dispose();
  }

  Future<void> refresh() => repository.refresh(force: true);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: orange,
      onRefresh: refresh,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: CivilDefenseHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Olá, ${widget.profile.firstName}.',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            widget.profile.hasGpsReference
                                ? 'Seu ponto de referência está pronto.'
                                : 'Endereço de referência salvo no aparelho.',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Abrir configurações de acessibilidade',
                      child: IconButton.filledTonal(
                        tooltip: 'Acessibilidade',
                        onPressed: widget.onAccessibility,
                        style: IconButton.styleFrom(
                          backgroundColor: navy.withValues(alpha: .09),
                          foregroundColor: navy,
                        ),
                        icon: const Icon(Icons.accessibility_new_rounded),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: 'Abrir perfil',
                      onPressed: widget.onAccount,
                      style: IconButton.styleFrom(
                        backgroundColor: orange.withValues(alpha: .12),
                        foregroundColor: orangeDark,
                      ),
                      icon: const Icon(Icons.person_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Situação em Blumenau',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Defesa Civil de Blumenau, ANA e previsão de modelo',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SituationPanel(
                  repository: repository,
                  residentLatitude: widget.profile.latitude,
                  residentLongitude: widget.profile.longitude,
                  onOpenSource: (url) => openExternal(context, Uri.parse(url)),
                ),
                const SizedBox(height: 24),
                const SectionHeading(
                  eyebrow: 'DECIDA RÁPIDO',
                  title: 'O que você precisa?',
                ),
                const SizedBox(height: 12),
                PriorityAction(
                  icon: Icons.phone_in_talk_rounded,
                  title: 'Falar com a emergência agora',
                  detail: 'Defesa Civil, Bombeiros e SAMU em uma ligação',
                  color: danger,
                  onTap: () => widget.onNavigate(3),
                ),
                const SizedBox(height: 10),
                PriorityAction(
                  icon: Icons.my_location_rounded,
                  title: 'Ver minha localização no mapa',
                  detail: 'GPS, ruas reais e acesso às áreas oficiais de risco',
                  color: orange,
                  onTap: () => widget.onNavigate(1),
                ),
                const SizedBox(height: 10),
                PriorityAction(
                  icon: Icons.add_a_photo_rounded,
                  title: 'Registrar uma ocorrência',
                  detail: 'Envie foto, vídeo, descrição e localização',
                  color: danger,
                  onTap: () => widget.onNavigate(2),
                ),
                const SizedBox(height: 10),
                PriorityAction(
                  icon: Icons.shield_rounded,
                  title: 'Como agir com segurança',
                  detail: 'Orientações para chuva, enchente e deslizamento',
                  color: navy,
                  onTap: () => widget.onNavigate(4),
                ),
                const SizedBox(height: 22),
                const SourceNotice(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RealMapScreen extends StatefulWidget {
  const RealMapScreen({super.key});

  @override
  State<RealMapScreen> createState() => _RealMapScreenState();
}

class _RealMapScreenState extends State<RealMapScreen> {
  static const blumenauCenter = LatLng(
    BlumenauMapBounds.centerLatitude,
    BlumenauMapBounds.centerLongitude,
  );

  final mapController = MapController();
  final tileSource = const ConfiguredMapTileProvider().active;

  Position? currentPosition;
  LocationPermission? permission;
  bool locating = false;
  bool followingUser = true;
  String? locationMessage;
  StreamSubscription<Position>? positionSubscription;

  /// Limite municipal oficial. Enquanto não carregar, nada é desenhado — nunca
  /// um polígono aproximado.
  List<List<LatLng>> boundaryRings = const [];
  String? boundarySource;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => locateUser());
    _loadBoundary();
  }

  Future<void> _loadBoundary() async {
    final result = await IbgeMunicipalGeoProvider().loadMunicipalBoundary();
    if (!mounted || !result.hasData) return;
    setState(() {
      boundaryRings = result.data!.rings
          .map((ring) => ring
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList())
          .toList();
      boundarySource = result.data!.origin.sourceName;
    });
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    mapController.dispose();
    super.dispose();
  }

  Future<void> locateUser() async {
    if (!mounted) return;
    await positionSubscription?.cancel();
    positionSubscription = null;
    if (!mounted) return;
    setState(() {
      locating = true;
      locationMessage = null;
      currentPosition = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() {
          locationMessage =
              'Ative a localização do aparelho para encontrar sua posição.';
        });
        return;
      }
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          locationMessage = permission == LocationPermission.deniedForever
              ? 'A localização foi bloqueada. Libere a permissão nas configurações.'
              : 'Sem permissão, o mapa não consegue mostrar onde você está.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        currentPosition = position;
        followingUser = true;
      });
      mapController.move(LatLng(position.latitude, position.longitude), 16);

      await positionSubscription?.cancel();
      positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((nextPosition) {
        if (!mounted) return;
        setState(() {
          currentPosition = nextPosition;
          locationMessage = null;
        });
        if (followingUser) {
          mapController.move(
            LatLng(nextPosition.latitude, nextPosition.longitude),
            mapController.camera.zoom,
          );
        }
      }, onError: (_) {
        if (!mounted) return;
        setState(() {
          currentPosition = null;
          locationMessage = 'A localização ao vivo parou. Toque para tentar novamente.';
        });
      });
    } on TimeoutException {
      if (mounted) {
        setState(() => locationMessage =
            'O GPS demorou para responder. Tente novamente em área aberta.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => locationMessage =
            'Não foi possível obter sua localização agora.');
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPoint = currentPosition == null
        ? null
        : LatLng(currentPosition!.latitude, currentPosition!.longitude);
    return Column(
      children: [
        const CivilDefenseHeader(compact: true),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: const MapOptions(
                  initialCenter: blumenauCenter,
                  initialZoom: BlumenauMapBounds.initialZoom,
                  // O mapa começa em Blumenau e depois acompanha a posição real.
                  minZoom: BlumenauMapBounds.minimumZoom,
                  maxZoom: BlumenauMapBounds.maximumZoom,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: tileSource.urlTemplate,
                    // Identificação exigida pela política de uso do OSM.
                    userAgentPackageName: 'br.com.blualert.blualert',
                    maxZoom: tileSource.maxZoom.toDouble(),
                    // Carrega apenas a área visível, sem pré-carga em massa.
                    panBuffer: 1,
                  ),
                  if (boundaryRings.isNotEmpty)
                    PolygonLayer(
                      polygons: [
                        for (final ring in boundaryRings)
                          Polygon(
                            points: ring,
                            borderColor: navy.withValues(alpha: .55),
                            borderStrokeWidth: 2,
                            color: navy.withValues(alpha: .04),
                          ),
                      ],
                    ),
                  if (userPoint != null && currentPosition != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: userPoint,
                          radius: currentPosition!.accuracy.clamp(12, 80),
                          useRadiusInMeter: true,
                          color: navy.withValues(alpha: .13),
                          borderColor: navy.withValues(alpha: .35),
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),
                  if (userPoint != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: userPoint,
                          width: 44,
                          height: 44,
                          child: const UserPositionMarker(),
                        ),
                      ],
                    ),
                  // Atribuição cartográfica obrigatória. Nunca pode ser
                  // ocultada: é condição de uso do OpenStreetMap.
                  RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    attributions: [
                      TextSourceAttribution(
                        tileSource.attribution,
                        onTap: () => openExternal(
                          context,
                          Uri.parse(tileSource.attributionUrl),
                        ),
                      ),
                      if (boundarySource != null)
                        TextSourceAttribution(
                            'Limite municipal: $boundarySource'),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: MapStatusPanel(
                  position: currentPosition,
                  locating: locating,
                  message: locationMessage,
                  onRetry: locateUser,
                ),
              ),
              Positioned(
                right: 14,
                bottom: 166,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'zoomIn',
                      backgroundColor: Colors.white,
                      foregroundColor: navy,
                      onPressed: () => mapController.move(
                        mapController.camera.center,
                        mapController.camera.zoom + 1,
                      ),
                      child: const Icon(Icons.add_rounded),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'follow',
                      tooltip: followingUser
                          ? 'Pausar acompanhamento do mapa'
                          : 'Acompanhar minha posição',
                      backgroundColor: followingUser ? navy : Colors.white,
                      foregroundColor: followingUser ? Colors.white : navy,
                      onPressed: () {
                        setState(() => followingUser = !followingUser);
                        if (followingUser && currentPosition != null) {
                          mapController.move(
                            LatLng(currentPosition!.latitude,
                                currentPosition!.longitude),
                            mapController.camera.zoom,
                          );
                        }
                      },
                      child: const Icon(Icons.navigation_rounded),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'locate',
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                      onPressed: locateUser,
                      child: locating
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CAMADAS OFICIAIS DA PREFEITURA',
                          style: TextStyle(
                            color: orangeDark,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => openExternal(
                                  context,
                                  officialRiskMapUri,
                                ),
                                icon: const Icon(Icons.landscape_rounded),
                                label: const Text('Deslizamento'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => openExternal(
                                  context,
                                  officialFloodMapUri,
                                ),
                                icon: const Icon(Icons.water_rounded),
                                label: const Text('Inundação'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class UserPositionMarker extends StatefulWidget {
  const UserPositionMarker({super.key});

  @override
  State<UserPositionMarker> createState() => _UserPositionMarkerState();
}

class _UserPositionMarkerState extends State<UserPositionMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
      pulse.value = 0;
    } else if (!pulse.isAnimating) {
      pulse.repeat();
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final wave = Curves.easeOut.transform(pulse.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: .65 + wave * .55,
                child: Opacity(
                  opacity: 1 - wave,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D93C8).withValues(alpha: .36),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: navy,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.navigation_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
      );
}

class MapStatusPanel extends StatelessWidget {
  const MapStatusPanel({
    required this.position,
    required this.locating,
    required this.message,
    required this.onRetry,
    super.key,
  });

  final Position? position;
  final bool locating;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (message != null ? orange : success)
                      .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  message != null
                      ? Icons.location_disabled_rounded
                      : Icons.gps_fixed_rounded,
                  color: message != null
                      ? orangeDark
                      : success,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locating
                              ? 'Localizando você...'
                              : position != null
                                  ? 'Sua localização em tempo real'
                                  : 'Localização ainda não disponível',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, color: ink),
                    ),
                    Text(
                      message ??
                              (position == null
                                  ? 'O mapa está centralizado em Blumenau.'
                                  : 'Precisão aproximada: ${position!.accuracy.round()} m'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (message != null)
                IconButton(
                  tooltip: 'Tentar localizar novamente',
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
        ),
      );
}

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const CivilDefenseHeader(compact: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
              children: [
                Text('Emergência',
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 6),
                const Text(
                  'Escolha o serviço conforme a situação. A ligação é feita pelo telefone do aparelho.',
                ),
                const SizedBox(height: 18),
                const EmergencyCallCard(
                  number: '199',
                  service: 'Defesa Civil',
                  useWhen:
                      'Alagamento, deslizamento, interdição ou risco estrutural',
                  icon: Icons.shield_rounded,
                  color: orange,
                ),
                const SizedBox(height: 11),
                const EmergencyCallCard(
                  number: '193',
                  service: 'Corpo de Bombeiros',
                  useWhen:
                      'Incêndio, resgate, salvamento ou pessoa em risco imediato',
                  icon: Icons.local_fire_department_rounded,
                  color: danger,
                ),
                const SizedBox(height: 11),
                const EmergencyCallCard(
                  number: '192',
                  service: 'SAMU',
                  useWhen: 'Emergência médica, trauma ou pessoa inconsciente',
                  icon: Icons.medical_services_rounded,
                  color: navy,
                ),
                const SizedBox(height: 22),
                const SectionHeading(
                  eyebrow: 'OCORRÊNCIAS NÃO EMERGENCIAIS',
                  title: 'Canais disponíveis',
                ),
                const SizedBox(height: 10),
                const PilotNotice(),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Canal oficial da Prefeitura',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, color: ink),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'O AlertaBlu é o canal já integrado à estrutura municipal. Use-o sempre que precisar de um registro com encaminhamento garantido.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () =>
                                openExternal(context, alertaBluUri),
                            style: FilledButton.styleFrom(
                                backgroundColor: orangeDark),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Abrir canal oficial'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class EmergencyCallCard extends StatefulWidget {
  const EmergencyCallCard({
    required this.number,
    required this.service,
    required this.useWhen,
    required this.icon,
    required this.color,
    super.key,
  });

  final String number;
  final String service;
  final String useWhen;
  final IconData icon;
  final Color color;

  @override
  State<EmergencyCallCard> createState() => _EmergencyCallCardState();
}

class _EmergencyCallCardState extends State<EmergencyCallCard> {
  bool failed = false;

  Future<void> _call() async {
    final outcome = await callEmergency(widget.number);
    if (!mounted) return;
    setState(() => failed = outcome == EmergencyCallOutcome.failed);
  }

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _call,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(widget.icon, color: Colors.white),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.service,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, color: ink),
                          ),
                          const Spacer(),
                          Text(
                            widget.number,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: widget.color,
                            ),
                          ),
                        ],
                      ),
                      Text(widget.useWhen,
                          style: const TextStyle(fontSize: 11, color: muted)),
                      if (failed)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            'O discador não abriu. Ligue manualmente para '
                            '${widget.number}.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Icon(Icons.phone_rounded, color: widget.color),
              ],
            ),
          ),
        ),
      );
}

class GuidanceScreen extends StatelessWidget {
  const GuidanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const guides = [
      Guide(
        title: 'Chuva intensa e alagamento',
        icon: Icons.water_rounded,
        color: navy,
        steps: [
          'Não atravesse ruas alagadas a pé ou de veículo.',
          'Afaste-se de rios, ribeirões, pontes e áreas rebaixadas.',
          'Desligue a energia apenas se isso puder ser feito com segurança.',
        ],
      ),
      Guide(
        title: 'Sinais de deslizamento',
        icon: Icons.landscape_rounded,
        color: orangeDark,
        steps: [
          'Observe rachaduras novas no solo, muros ou paredes.',
          'Árvores, cercas e postes inclinados indicam movimentação do terreno.',
          'Ao notar sinais, saia da área e ligue 199 de um local seguro.',
        ],
      ),
      Guide(
        title: 'Tempestade e vendaval',
        icon: Icons.thunderstorm_rounded,
        color: Color(0xFF62529C),
        steps: [
          'Permaneça longe de janelas e estruturas metálicas.',
          'Não se abrigue sob árvores, placas ou coberturas frágeis.',
          'Retire aparelhos da tomada somente se não houver risco.',
        ],
      ),
    ];

    return Column(
      children: [
        const CivilDefenseHeader(compact: true),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
            children: [
              Text('Como agir',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 6),
              const Text(
                  'Orientações objetivas para reduzir sua exposição ao risco.'),
              const SizedBox(height: 18),
              ...guides.map((guide) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: GuideCard(guide: guide),
                  )),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => openExternal(context, alertaBluUri),
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Consultar Defesa Civil de Blumenau'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class Guide {
  const Guide({
    required this.title,
    required this.icon,
    required this.color,
    required this.steps,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<String> steps;
}

class GuideCard extends StatelessWidget {
  const GuideCard({required this.guide, super.key});
  final Guide guide;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: guide.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(guide.icon, color: guide.color),
          ),
          title: Text(
            guide.title,
            style: const TextStyle(fontWeight: FontWeight.w900, color: ink),
          ),
          children: guide.steps.indexed
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: guide.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${entry.$1 + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(entry.$2)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
}

class PriorityAction extends StatelessWidget {
  const PriorityAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, color: ink)),
                      const SizedBox(height: 2),
                      Text(detail,
                          style: const TextStyle(fontSize: 11, color: muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF8B979E)),
              ],
            ),
          ),
        ),
      );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({required this.eyebrow, required this.title, super.key});
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: orangeDark,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      );
}

class SourceNotice extends StatelessWidget {
  const SourceNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_rounded, color: navy, size: 20),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'O BluAlert identifica claramente a origem das informações. Dados operacionais sem fonte oficial não são exibidos.',
                style: TextStyle(color: navyDark, fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

Future<void> openExternal(BuildContext context, Uri uri) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o canal externo.')),
    );
  }
}

class AppViewport extends StatelessWidget {
  const AppViewport({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) return child;
        return ColoredBox(
          color: const Color(0xFFE1E7EA),
          child: Center(
            child: Container(
              width: 430,
              margin: const EdgeInsets.symmetric(vertical: 18),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x300B2748),
                    blurRadius: 36,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
