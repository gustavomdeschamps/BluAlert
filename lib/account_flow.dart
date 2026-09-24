import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'backend_client.dart';
import 'emergency.dart';

const _deepBlue = Color(0xFF061C35);
const _orange = Color(0xFFFF6328);
const _paper = Color(0xFFF3F6F8);
const _ink = Color(0xFF102433);
const _muted = Color(0xFF60717B);
const _green = Color(0xFF14815A);
final _privacyUrl = Uri.parse(
    'https://gustavomdeschamps.github.io/BluAlert/privacy.html');

Future<void> _openPrivacyPolicy() async {
  await launchUrl(_privacyUrl, mode: LaunchMode.externalApplication);
}

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
  static const _pendingEmailKey = 'pending_confirmation_email_v1';

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
      await p.remove(_pendingEmailKey);
    } else {
      await _storage.delete(key: _profileKey);
      await _storage.delete(key: _legacyProfileKey);
      await _storage.delete(key: _pendingEmailKey);
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
    if (mounted) {
      setState(() {
        profile = resident;
        state = _GateState.account;
      });
    }
  }

  Future<void> _remove() async {
    // Remover o perfil precisa encerrar a sessão também: caso contrário o
    // token continuaria no cofre e o próximo acesso restauraria a conta que a
    // pessoa acabou de pedir para apagar deste aparelho.
    await backend.signOut();
    await vault.clear();
    if (mounted) {
      setState(() {
        profile = null;
        state = _GateState.account;
      });
    }
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
            onUnlocked: (restoredProfile) async {
              if (restoredProfile != null) {
                await vault.save(restoredProfile);
              }
              if (mounted) {
                setState(() {
                  profile = restoredProfile ?? profile;
                  state = _GateState.unlocked;
                });
              }
            },
            onReset: _remove),
        // `profile` só é nulo aqui se a restauração tiver corrido mal; nesse
        // caso voltamos ao acesso em vez de derrubar o aplicativo.
        _GateState.unlocked => profile == null
            ? AccountRecoveryScreen(
                key: const ValueKey('recovery'),
                onRestart: _remove,
              )
            : widget.builder(
                profile!,
                () => setState(() {
                  state = _GateState.account;
                }),
                _remove,
              ),
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
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..forward();
    timer = Timer(const Duration(milliseconds: 3000), widget.onComplete);
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
              final logo = const Interval(.10, .56, curve: Curves.easeOutBack)
                  .transform(value);
              final title = const Interval(.46, .76, curve: Curves.easeOutCubic)
                  .transform(value);
              final phrase =
                  const Interval(.64, .94, curve: Curves.easeOutCubic)
                      .transform(value);
              final protection =
                  const Interval(.34, .82, curve: Curves.easeOutCubic)
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
                              child: Transform.translate(
                                  offset: Offset(0, 26 * (1 - logo)),
                                  child: Transform.scale(
                                      scale: .78 + logo * .22,
                                      child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                                width: 230 + protection * 18,
                                                height: 230 + protection * 18,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: .16 *
                                                                    (1 -
                                                                        protection))))),
                                            Container(
                                                width: 206,
                                                height: 206,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: .045),
                                                    boxShadow: [
                                                      BoxShadow(
                                                          color: _orange
                                                              .withValues(
                                                                  alpha: .10 +
                                                                      protection *
                                                                          .20),
                                                          blurRadius: 54,
                                                          spreadRadius: 4 +
                                                              protection * 8)
                                                    ])),
                                            Hero(
                                                tag: 'blualert-mark',
                                                child: Image.asset(
                                                    'assets/brand/blualert_mark_v2.png',
                                                    width: 196,
                                                    height: 196,
                                                    fit: BoxFit.contain,
                                                    semanticLabel:
                                                        'Símbolo do BluAlert')),
                                          ])))),
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
    final ridge = Path()
      ..moveTo(0, size.height * .44)
      ..lineTo(size.width * .20, size.height * .31)
      ..lineTo(size.width * .38, size.height * .42)
      ..lineTo(size.width * .61, size.height * .27)
      ..lineTo(size.width * .82, size.height * .40)
      ..lineTo(size.width, size.height * .32)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(ridge, Paint()..color = const Color(0x3D0A3157));

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
    final pulseProgress = ((progress - .34) / .52).clamp(0.0, 1.0);
    for (var ring = 0; ring < 2; ring++) {
      final ringProgress = (pulseProgress - ring * .16).clamp(0.0, 1.0);
      canvas.drawCircle(
          Offset(size.width * .5, size.height * .42),
          92 + ringProgress * 66,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = _orange.withValues(alpha: .22 * (1 - ringProgress)));
    }
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
  final Future<void> Function(ResidentProfile?) onUnlocked;
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
  final referenceAddress = TextEditingController();
  late final AnimationController shakeController;
  Timer? resendTimer;
  bool saving = false, loginMode = false;
  bool awaitingConfirmation = false;
  int resendSeconds = 0;
  String pendingPassword = '';
  String? message;
  @override
  void initState() {
    super.initState();
    // Uma nova visita sempre começa com a entrada limpa. A confirmação só
    // aparece imediatamente depois de um cadastro nesta sessão.
    loginMode = widget.profile != null;
    shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
  }

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    password.dispose();
    phone.dispose();
    referenceAddress.dispose();
    resendTimer?.cancel();
    shakeController.dispose();
    super.dispose();
  }

  Future<void> createAccount() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.onRegistered(
          ResidentProfile(
              email: email.text.trim().toLowerCase(),
              fullName: fullName.text.trim(),
              phone: phone.text.trim(),
              referenceAddress: referenceAddress.text.trim()),
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
    pendingPassword = password.text;
    setState(() {
      saving = false;
      awaitingConfirmation = true;
      message = null;
    });
    _startResendCountdown();
  }

  void _startResendCountdown() {
    resendTimer?.cancel();
    setState(() => resendSeconds = 60);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => resendSeconds = 0);
        return;
      }
      setState(() => resendSeconds--);
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
        _startResendCountdown();
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

  Future<void> confirmAndEnter() async {
    if (pendingPassword.isEmpty) {
      setState(() {
        awaitingConfirmation = false;
        loginMode = true;
        message = 'Digite sua senha para concluir a entrada.';
      });
      return;
    }
    setState(() {
      saving = true;
      message = null;
    });
    try {
      await backend.signIn(email: email.text, password: pendingPassword);
      pendingPassword = '';
      if (mounted) await widget.onUnlocked(null);
    } catch (error) {
      if (mounted) {
        setState(() {
          saving = false;
          message = error.toString().replaceFirst('BackendUnavailable: ', '');
        });
      }
    }
  }

  Future<void> unlock() async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim()) ||
        password.text.isEmpty) {
      setState(() => message = 'Informe seu e-mail e sua senha.');
      return;
    }
    setState(() {
      saving = true;
      message = null;
    });
    try {
      await backend.signIn(email: email.text, password: password.text);
      final remote = await backend.fetchMyProfile();
      final restoredProfile = ResidentProfile(
        email: email.text.trim().toLowerCase(),
        fullName: remote['full_name'] as String,
        phone: remote['phone'] as String,
        referenceAddress: remote['reference_address'] as String? ?? '',
        latitude: (remote['reference_latitude'] as num?)?.toDouble(),
        longitude: (remote['reference_longitude'] as num?)?.toDouble(),
      );
      if (mounted) await widget.onUnlocked(restoredProfile);
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
                        child: Image.asset('assets/brand/blualert_mark_v2.png',
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
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(.06, 0),
                                      end: Offset.zero)
                                  .animate(animation),
                              child: child)),
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
                  onPressed: saving ? null : confirmAndEnter,
                  style: FilledButton.styleFrom(backgroundColor: _orange),
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.verified_user_outlined),
                  label: const Text('Já confirmei meu e-mail'))),
          const SizedBox(height: 8),
          Center(
              child: TextButton(
                  onPressed:
                      saving || resendSeconds > 0 ? null : resendConfirmation,
                  child: Text(resendSeconds > 0
                      ? 'Reenviar em ${resendSeconds}s'
                      : 'Reenviar confirmação'))),
        ],
      );

  Widget _buildLogin() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'Entre no BluAlert',
            style: TextStyle(
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
          onChanged: (_) => setState(() => message = null),
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
                onPressed: saving
                    ? null
                    : () => setState(() {
                          loginMode = false;
                          message = null;
                          password.clear();
                        }),
                child: const Text('Ainda não tenho cadastro'))),
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
            const Text('Crie sua conta. O local de cada ocorrência será obtido pelo GPS quando você a registrar.',
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
                controller: referenceAddress,
                label: 'Endereço de referência (opcional)',
                hint: 'Ex.: bairro e rua onde você mora',
                icon: Icons.location_on_outlined,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done),
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
                'Projeto escolar em teste. O envio não aciona automaticamente a Defesa Civil. Leia como seus dados são usados antes de criar a conta.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11, height: 1.4)),
            const Center(
                child: TextButton(
                    onPressed: _openPrivacyPolicy,
                    child: Text('Aviso de privacidade'))),
            const SizedBox(height: 8),
            Center(
                child: TextButton(
                    onPressed: saving
                        ? null
                        : () => setState(() {
                              loginMode = true;
                              message = null;
                              password.clear();
                            }),
                    child: const Text('Já tenho cadastro'))),
          ]));
}

/// Saída segura para o caso em que a conta existe mas o perfil não pôde ser
/// carregado — por exemplo, um usuário criado em `auth.users` sem linha
/// correspondente em `profiles`.
///
/// A regra é não travar e não adivinhar: explicamos o que aconteceu, mantemos o
/// caminho de emergência à vista e oferecemos uma ação concreta.
class AccountRecoveryScreen extends StatelessWidget {
  const AccountRecoveryScreen({required this.onRestart, super.key});

  final Future<void> Function() onRestart;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _paper,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.person_off_outlined,
                      size: 46, color: _orange),
                  const SizedBox(height: 18),
                  const Text(
                    'Não foi possível carregar seu perfil',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.6),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sua conta existe, mas os dados do perfil não chegaram a '
                    'este aparelho. Entre novamente para recarregá-los. Se o '
                    'problema continuar, o cadastro precisa ser refeito.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  const PilotNotice(),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRestart,
                    style: FilledButton.styleFrom(backgroundColor: _orange),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Entrar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
