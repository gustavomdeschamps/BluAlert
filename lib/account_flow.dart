import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'address_search_service.dart';
import 'backend_client.dart';

const _deepBlue = Color(0xFF061C35);
const _orange = Color(0xFFFF6328);
const _paper = Color(0xFFF3F6F8);
const _ink = Color(0xFF102433);
const _muted = Color(0xFF60717B);
const _green = Color(0xFF14815A);

class ResidentProfile {
  const ResidentProfile(
      {required this.email,
      required this.fullName,
      required this.phone,
      required this.referenceAddress,
      this.latitude,
      this.longitude});
  final String email;
  final String fullName;
  final String phone;
  final String referenceAddress;
  final double? latitude;
  final double? longitude;
  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;
  bool get hasGpsReference => latitude != null && longitude != null;
  Map<String, Object?> toJson() => {
        'email': email,
        'fullName': fullName,
        'phone': phone,
        'referenceAddress': referenceAddress,
        'latitude': latitude,
        'longitude': longitude
      };
  factory ResidentProfile.fromJson(Map<String, dynamic> json) =>
      ResidentProfile(
        email: json['email'] as String? ?? '',
        fullName: json['fullName'] as String,
        phone: json['phone'] as String,
        referenceAddress: json['referenceAddress'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

class ProfileVault {
  const ProfileVault();
  static const _storage = FlutterSecureStorage();
  static const _profileKey = 'resident_profile_v2';
  static const _legacyProfileKey = 'resident_profile_v1';

  Future<ResidentProfile?> readProfile() async {
    final encoded = kIsWeb
        ? (await SharedPreferences.getInstance()).getString(_profileKey) ??
            (await SharedPreferences.getInstance()).getString(_legacyProfileKey)
        : await _storage.read(key: _profileKey) ??
            await _storage.read(key: _legacyProfileKey);
    if (encoded == null) return null;
    try {
      return ResidentProfile.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ResidentProfile profile) async {
    final encoded = jsonEncode(profile.toJson());
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_profileKey, encoded);
    } else {
      await _storage.write(key: _profileKey, value: encoded);
    }
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.remove(_profileKey);
      await p.remove(_legacyProfileKey);
    } else {
      await _storage.delete(key: _profileKey);
      await _storage.delete(key: _legacyProfileKey);
    }
  }
}

class AccountGate extends StatefulWidget {
  const AccountGate({required this.builder, super.key});
  final Widget Function(ResidentProfile, VoidCallback, Future<void> Function())
      builder;
  @override
  State<AccountGate> createState() => _AccountGateState();
}

enum _GateState { loading, launch, account, unlocked }

class _AccountGateState extends State<AccountGate> {
  final vault = const ProfileVault();
  final backend = BackendClient();
  _GateState state = _GateState.loading;
  ResidentProfile? profile;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      profile = await vault.readProfile();
    } catch (_) {
      profile = null;
    }
    if (mounted) setState(() => state = _GateState.launch);
  }

  Future<void> _register(ResidentProfile resident, String password) async {
    await backend.register(
      email: resident.email,
      password: password,
      fullName: resident.fullName,
      phone: resident.phone,
      referenceAddress: resident.referenceAddress,
      latitude: resident.latitude,
      longitude: resident.longitude,
    );
    await vault.save(resident);
    if (mounted)
      setState(() {
        profile = resident;
        state = _GateState.account;
      });
  }

  Future<void> _remove() async {
    await vault.clear();
    if (mounted)
      setState(() {
        profile = null;
        state = _GateState.account;
      });
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: Curves.easeOutCubic,
      child: switch (state) {
        _GateState.loading => const ColoredBox(
            key: ValueKey('loading'),
            color: _deepBlue,
            child: Center(child: CircularProgressIndicator(color: _orange))),
        _GateState.launch => SignatureLaunch(
            key: const ValueKey('launch'),
            onComplete: () => setState(() => state = _GateState.account)),
        _GateState.account => AccountAccessScreen(
            key: const ValueKey('account'),
            profile: profile,
            vault: vault,
            onRegistered: _register,
            onUnlocked: () => setState(() => state = _GateState.unlocked),
            onReset: _remove),
        _GateState.unlocked => widget.builder(profile!,
            () => setState(() => state = _GateState.account), _remove),
      },
    );
    return LayoutBuilder(
        builder: (context, c) => c.maxWidth < 700
            ? child
            : ColoredBox(
                color: const Color(0xFFDDE5EA),
                child: Center(
                    child: Container(
                        width: 430,
                        margin: const EdgeInsets.symmetric(vertical: 18),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x30061C35),
                                  blurRadius: 40,
                                  offset: Offset(0, 18))
                            ]),
                        child: child)),
              ));
  }
}

class SignatureLaunch extends StatefulWidget {
  const SignatureLaunch({required this.onComplete, super.key});
  final VoidCallback onComplete;
  @override
  State<SignatureLaunch> createState() => _SignatureLaunchState();
}

class _SignatureLaunchState extends State<SignatureLaunch>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..forward();
    timer = Timer(const Duration(milliseconds: 3600), widget.onComplete);
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void finish() {
    timer?.cancel();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final animation = reduce
        ? const AlwaysStoppedAnimation<double>(1)
        : CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    return Scaffold(
        backgroundColor: _deepBlue,
        body: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final value = animation.value;
              final logo = const Interval(0, .48, curve: Curves.easeOutBack)
                  .transform(value);
              final title = const Interval(.28, .68, curve: Curves.easeOutCubic)
                  .transform(value);
              final phrase =
                  const Interval(.50, .88, curve: Curves.easeOutCubic)
                      .transform(value);
              return Stack(children: [
                Positioned.fill(
                    child: CustomPaint(
                        painter: LaunchRiverPainter(progress: value))),
                Positioned.fill(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: RadialGradient(
                                center: const Alignment(0, -.2),
                                radius: .9,
                                colors: [
                      const Color(0xFF0D3B6B).withValues(alpha: .48),
                      _deepBlue.withValues(alpha: .08)
                    ])))),
                SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 18, 26, 24),
                        child: Column(children: [
                          Align(
                              alignment: Alignment.topRight,
                              child: TextButton(
                                  onPressed: finish,
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      minimumSize: const Size(48, 48)),
                                  child: const Text('Entrar'))),
                          const Spacer(),
                          Opacity(
                              opacity: logo.clamp(0, 1),
                              child: Transform.scale(
                                  scale: .72 + logo * .28,
                                  child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                            width: 224,
                                            height: 224,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: .13)))),
                                        Container(
                                            width: 184,
                                            height: 184,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white
                                                    .withValues(alpha: .06),
                                                boxShadow: [
                                                  BoxShadow(
                                                      color: _orange.withValues(
                                                          alpha:
                                                              .12 + logo * .14),
                                                      blurRadius: 48,
                                                      spreadRadius: 6)
                                                ])),
                                        Hero(
                                            tag: 'blualert-mark',
                                            child: Image.asset(
                                                'assets/brand/blualert_mark.png',
                                                width: 174,
                                                height: 174,
                                                fit: BoxFit.contain,
                                                semanticLabel:
                                                    'Símbolo do BluAlert')),
                                      ]))),
                          const SizedBox(height: 27),
                          Opacity(
                              opacity: title.clamp(0, 1),
                              child: Transform.translate(
                                  offset: Offset(0, 14 * (1 - title)),
                                  child: const Text('BluAlert',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 43,
                                          height: 1,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -2)))),
                          const SizedBox(height: 13),
                          Opacity(
                              opacity: phrase.clamp(0, 1),
                              child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - phrase)),
                                  child: const Text(
                                      'Blumenau mais perto. Você mais seguro.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Color(0xFFD8E6F0),
                                          fontSize: 16,
                                          height: 1.35,
                                          fontWeight: FontWeight.w600)))),
                          const Spacer(),
                          Opacity(
                              opacity: phrase.clamp(0, 1),
                              child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shield_outlined,
                                        size: 15, color: Color(0xFF91B2C9)),
                                    SizedBox(width: 7),
                                    Text('DEFESA CIVIL • BLUMENAU',
                                        style: TextStyle(
                                            color: Color(0xFF91B2C9),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2))
                                  ])),
                        ]))),
              ]);
            }));
  }
}

class LaunchRiverPainter extends CustomPainter {
  const LaunchRiverPainter({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final contour = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: .045);
    for (var i = 0; i < 7; i++) {
      final inset = i * 22.0;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(size.width * .2, size.height * .66),
              width: size.width * 1.1 - inset,
              height: 250 - inset * .45),
          contour);
    }
    final path = Path()
      ..moveTo(size.width * .76, -30)
      ..cubicTo(size.width * .42, size.height * .22, size.width * .76,
          size.height * .38, size.width * .40, size.height * .60)
      ..cubicTo(size.width * .16, size.height * .76, size.width * .46,
          size.height * .88, size.width * .25, size.height + 30);
    final metric = path.computeMetrics().first;
    final river = metric.extractPath(0, metric.length * progress.clamp(0, 1));
    canvas.drawPath(
        river,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 38
          ..color = const Color(0xFF2F8BC0).withValues(alpha: .12));
    canvas.drawPath(
        river,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3
          ..shader = const LinearGradient(colors: [
            Color(0x00FFFFFF),
            Color(0xAA6BC6F2),
            Color(0x00FFFFFF)
          ]).createShader(Offset.zero & size));
    final pulse = math.sin(progress * math.pi * 2).abs();
    canvas.drawCircle(
        Offset(size.width * .5, size.height * .42),
        108 + pulse * 8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _orange.withValues(alpha: .08));
  }

  @override
  bool shouldRepaint(LaunchRiverPainter old) => old.progress != progress;
}

class AccountAccessScreen extends StatefulWidget {
  const AccountAccessScreen(
      {required this.profile,
      required this.vault,
      required this.onRegistered,
      required this.onUnlocked,
      required this.onReset,
      super.key});
  final ResidentProfile? profile;
  final ProfileVault vault;
  final Future<void> Function(ResidentProfile, String) onRegistered;
  final VoidCallback onUnlocked;
  final Future<void> Function() onReset;
  @override
  State<AccountAccessScreen> createState() => _AccountAccessScreenState();
}

class _AccountAccessScreenState extends State<AccountAccessScreen>
    with SingleTickerProviderStateMixin {
  final backend = BackendClient();
  final formKey = GlobalKey<FormState>();
  final fullName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final phone = TextEditingController();
  final street = TextEditingController();
  final number = TextEditingController();
  final addressSearch = AddressSearchService();
  late final AnimationController shakeController;
  Timer? addressDebounce;
  AddressSuggestion? selectedAddress;
  List<AddressSuggestion> addressSuggestions = const [];
  bool searchingAddress = false, saving = false, loginMode = false;
  bool awaitingConfirmation = false;
  String? message;
  @override
  void initState() {
    super.initState();
    loginMode = widget.profile != null;
    email.text = widget.profile?.email ?? '';
    shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
  }

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    password.dispose();
    phone.dispose();
    street.dispose();
    number.dispose();
    addressDebounce?.cancel();
    shakeController.dispose();
    super.dispose();
  }

  void searchAddress(String value) {
    addressDebounce?.cancel();
    selectedAddress = null;
    if (value.trim().length < 3) {
      setState(() => addressSuggestions = const []);
      return;
    }
    addressDebounce = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted) return;
      setState(() => searchingAddress = true);
      try {
        final results = await addressSearch.searchStreets(value);
        if (mounted && street.text.trim() == value.trim()) {
          setState(() => addressSuggestions = results);
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            addressSuggestions = const [];
            message = 'A busca de ruas está indisponível. Tente novamente.';
          });
        }
      } finally {
        if (mounted) setState(() => searchingAddress = false);
      }
    });
  }

  void selectAddress(AddressSuggestion suggestion) {
    setState(() {
      selectedAddress = suggestion;
      street.text = suggestion.street;
      addressSuggestions = const [];
      message = null;
    });
    FocusScope.of(context).nextFocus();
  }

  Future<void> createAccount() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedAddress == null) {
      setState(() => message = 'Selecione uma rua nas sugestões da busca.');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onRegistered(
          ResidentProfile(
              email: email.text.trim().toLowerCase(),
              fullName: fullName.text.trim(),
              phone: phone.text.trim(),
              referenceAddress:
                  '${selectedAddress!.street}, ${number.text.trim()}${selectedAddress!.neighborhood.isEmpty ? '' : ' - ${selectedAddress!.neighborhood}'}, Blumenau - SC',
              latitude: selectedAddress!.latitude,
              longitude: selectedAddress!.longitude),
          password.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        saving = false;
        message = error.toString().replaceFirst('BackendUnavailable: ', '');
      });
      return;
    }
    if (!mounted) return;
    password.clear();
    setState(() {
      saving = false;
      awaitingConfirmation = true;
      message = null;
    });
  }

  Future<void> resendConfirmation() async {
    setState(() {
      saving = true;
      message = null;
    });
    try {
      await backend.resendConfirmation(email.text);
      if (mounted) {
        setState(() => message = 'Novo e-mail de confirmação enviado.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => message =
            error.toString().replaceFirst('BackendUnavailable: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> unlock() async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim()) ||
        password.text.length < 8) {
      setState(() => message = 'Informe seu e-mail e sua senha.');
      return;
    }
    setState(() {
      saving = true;
      message = null;
    });
    try {
      await backend.signIn(email: email.text, password: password.text);
      if (mounted) widget.onUnlocked();
      return;
    } catch (error) {
      if (mounted) {
        setState(() {
          saving = false;
          message = error.toString().replaceFirst('BackendUnavailable: ', '');
        });
      }
    }
    await shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1)
    ]).animate(
        CurvedAnimation(parent: shakeController, curve: Curves.easeInOut));
    return Scaffold(
        backgroundColor: _paper,
        body: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 48, 22, 26),
                  decoration: const BoxDecoration(
                      color: _deepBlue,
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(30))),
                  child: Row(children: [
                    Hero(
                        tag: 'blualert-mark',
                        child: Image.asset('assets/brand/blualert_mark.png',
                            width: 72, height: 72)),
                    const SizedBox(width: 15),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('BluAlert',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 29,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.2)),
                          Text(
                              loginMode
                                  ? 'Acesse seu perfil de emergência'
                                  : 'Prepare seus dados antes de precisar deles',
                              style: const TextStyle(
                                  color: Color(0xFFB9CDDB), fontSize: 12))
                        ])),
                  ]))),
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 34),
              sliver: SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      child: loginMode
                          ? AnimatedBuilder(
                              key: const ValueKey('login'),
                              animation: shake,
                              builder: (context, child) => Transform.translate(
                                  offset: Offset(shake.value, 0), child: child),
                              child: _buildLogin())
                          : awaitingConfirmation
                              ? _buildConfirmation()
                              : _buildRegistration()))),
        ]));
  }

  Widget _buildConfirmation() => Column(
        key: const ValueKey('confirmation'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                  color: Color(0xFFE8F5EF), shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_unread_outlined,
                  color: _green, size: 30)),
          const SizedBox(height: 20),
          const Text('Confirme seu e-mail',
              style: TextStyle(
                  color: _ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8)),
          const SizedBox(height: 8),
          const Text('Enviamos um link de confirmação para:',
              style: TextStyle(color: _muted)),
          const SizedBox(height: 5),
          Text(email.text,
              style: const TextStyle(
                  color: _ink, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 18),
          const Text(
              'Abra o e-mail, toque no link e volte ao BluAlert para entrar. Confira também a caixa de spam.',
              style: TextStyle(color: _muted, height: 1.5)),
          if (message != null) ...[
            const SizedBox(height: 14),
            StatusMessage(
                text: message!, success: message!.startsWith('Novo e-mail')),
          ],
          const SizedBox(height: 22),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: () => setState(() => loginMode = true),
                  style: FilledButton.styleFrom(backgroundColor: _orange),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Já confirmei, quero entrar'))),
          const SizedBox(height: 8),
          Center(
              child: TextButton(
                  onPressed: saving ? null : resendConfirmation,
                  child:
                      Text(saving ? 'Enviando...' : 'Reenviar confirmação'))),
        ],
      );

  Widget _buildLogin() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Olá, ${widget.profile?.firstName ?? 'morador'}.',
            style: const TextStyle(
                color: _ink,
                fontSize: 28,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -.8)),
        const SizedBox(height: 7),
        const Text('Entre com o e-mail confirmado e sua senha.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 24),
        AppField(
          controller: email,
          label: 'E-mail',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        AppField(
          controller: password,
          label: 'Senha',
          icon: Icons.password_rounded,
          obscureText: true,
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          StatusMessage(
              text: message!, success: message!.startsWith('Cadastro'))
        ],
        const SizedBox(height: 20),
        SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
                onPressed: saving ? null : unlock,
                style: FilledButton.styleFrom(backgroundColor: _orange),
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login_rounded),
                label: const Text('Entrar no BluAlert'))),
        const SizedBox(height: 8),
        Center(
            child: TextButton(
                onPressed: widget.onReset,
                child: const Text(
                    'Não consigo entrar ou quero refazer o cadastro'))),
      ]);

  Widget _buildRegistration() => Form(
      key: formKey,
      child: Column(
          key: const ValueKey('register'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seu cadastro',
                style: TextStyle(
                    color: _ink,
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8)),
            const SizedBox(height: 7),
            const Text('Seus dados essenciais para pedir ajuda com rapidez.',
                style: TextStyle(color: _muted, height: 1.4)),
            const SizedBox(height: 22),
            AppField(
                controller: fullName,
                label: 'Nome completo',
                icon: Icons.badge_outlined,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v ?? '').trim().split(RegExp(r'\s+')).length < 2
                        ? 'Informe nome e sobrenome'
                        : null),
            const SizedBox(height: 12),
            AppField(
                controller: email,
                label: 'E-mail de acesso',
                hint: 'seunome@email.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch((v ?? '').trim())
                    ? null
                    : 'Informe um e-mail válido'),
            const SizedBox(height: 12),
            AppField(
                controller: password,
                label: 'Senha da conta',
                hint: 'Mínimo de 8 caracteres',
                icon: Icons.password_rounded,
                obscureText: true,
                validator: (v) => (v ?? '').length < 8
                    ? 'Use pelo menos 8 caracteres'
                    : null),
            const SizedBox(height: 12),
            AppField(
                controller: phone,
                label: 'Telefone para contato',
                hint: '(47) 99999-9999',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11)
                ],
                validator: validatePhone),
            const SizedBox(height: 12),
            AppField(
                controller: street,
                label: 'Rua',
                hint: 'Comece a digitar o nome da rua',
                icon: Icons.location_on_outlined,
                textCapitalization: TextCapitalization.words,
                onChanged: searchAddress,
                suffix: searchingAddress
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : selectedAddress != null
                        ? const Icon(Icons.check_circle_rounded, color: _green)
                        : null,
                validator: (_) => selectedAddress == null
                    ? 'Escolha uma rua na lista de sugestões'
                    : null),
            if (addressSuggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              AddressSuggestionList(
                  suggestions: addressSuggestions, onSelected: selectAddress),
            ],
            const SizedBox(height: 12),
            AppField(
                controller: number,
                label: 'Número',
                hint: 'Ex.: 30 ou S/N',
                icon: Icons.pin_drop_outlined,
                textInputAction: TextInputAction.done,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Informe o número ou S/N'
                    : null),
            if (message != null) ...[
              const SizedBox(height: 12),
              StatusMessage(text: message!)
            ],
            const SizedBox(height: 20),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: saving ? null : createAccount,
                    style: FilledButton.styleFrom(backgroundColor: _orange),
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Criar cadastro'))),
            const SizedBox(height: 10),
            const Text(
                'Seus dados ficam protegidos e são usados somente no atendimento das ocorrências que você enviar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11, height: 1.4)),
          ]));
}

class AddressSuggestionList extends StatelessWidget {
  const AddressSuggestionList(
      {required this.suggestions, required this.onSelected, super.key});

  final List<AddressSuggestion> suggestions;
  final ValueChanged<AddressSuggestion> onSelected;

  @override
  Widget build(BuildContext context) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4DDE3))),
      child: Column(
          children: suggestions.indexed.map((entry) {
        final suggestion = entry.$2;
        return Column(children: [
          if (entry.$1 > 0)
            const Divider(height: 1, indent: 48, color: Color(0xFFE3E9ED)),
          ListTile(
              dense: true,
              minVerticalPadding: 10,
              leading: const Icon(Icons.signpost_outlined, color: _orange),
              title: Text(suggestion.street,
                  style: const TextStyle(
                      color: _ink, fontWeight: FontWeight.w800)),
              subtitle: suggestion.subtitle.isEmpty
                  ? null
                  : Text(suggestion.subtitle,
                      style: const TextStyle(color: _muted, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
              onTap: () => onSelected(suggestion)),
        ]);
      }).toList()));
}

class StatusMessage extends StatelessWidget {
  const StatusMessage({required this.text, this.success = false, super.key});
  final String text;
  final bool success;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: (success ? _green : _orange).withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(success ? Icons.check_circle_outline : Icons.info_outline,
            size: 19, color: success ? _green : _orange),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: success ? _green : _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)))
      ]));
}

class AppField extends StatelessWidget {
  const AppField(
      {required this.controller,
      required this.label,
      required this.icon,
      this.hint,
      this.keyboardType,
      this.inputFormatters,
      this.obscureText = false,
      this.textCapitalization = TextCapitalization.none,
      this.textInputAction,
      this.onChanged,
      this.suffix,
      this.validator,
      super.key});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: suffix));
}

String? validatePhone(String? value) =>
    (value ?? '').replaceAll(RegExp(r'\D'), '').length < 10
        ? 'Informe um telefone válido'
        : null;
