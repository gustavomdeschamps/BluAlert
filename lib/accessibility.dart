import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityController extends ChangeNotifier {
  AccessibilityController._();

  static final instance = AccessibilityController._();
  static const _textScaleKey = 'accessibility_text_scale_v1';
  static const _contrastKey = 'accessibility_high_contrast_v1';
  static const _motionKey = 'accessibility_reduce_motion_v1';

  double textScale = 1;
  bool highContrast = false;
  bool reduceMotion = false;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    textScale = preferences.getDouble(_textScaleKey) ?? 1;
    highContrast = preferences.getBool(_contrastKey) ?? false;
    reduceMotion = preferences.getBool(_motionKey) ?? false;
    notifyListeners();
  }

  Future<void> setTextScale(double value) async {
    textScale = value;
    notifyListeners();
    await (await SharedPreferences.getInstance())
        .setDouble(_textScaleKey, value);
  }

  Future<void> setHighContrast(bool value) async {
    highContrast = value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_contrastKey, value);
  }

  Future<void> setReduceMotion(bool value) async {
    reduceMotion = value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_motionKey, value);
  }
}

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AccessibilityController.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B2748),
        foregroundColor: Colors.white,
        title: const Text('Acessibilidade'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0B2748),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: [
                  _AccessibilityIcon(),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Um BluAlert mais confortável',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 5),
                        Text(
                            'Escolha como deseja ler e navegar. As alterações são aplicadas imediatamente.',
                            style: TextStyle(
                                color: Color(0xFFC9D8E4),
                                fontSize: 12,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SettingsCard(
              icon: Icons.text_fields_rounded,
              title: 'Tamanho do texto',
              subtitle: 'Aumente sem perder informações da tela.',
              child: Semantics(
                label: 'Tamanho do texto',
                child: SegmentedButton<double>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Normal')),
                    ButtonSegment(value: 1.15, label: Text('Grande')),
                    ButtonSegment(value: 1.3, label: Text('Maior')),
                  ],
                  selected: {controller.textScale},
                  onSelectionChanged: (values) =>
                      controller.setTextScale(values.first),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.visibility_outlined,
              title: 'Conforto visual',
              subtitle: 'Ajustes para contraste e sensibilidade a movimento.',
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.contrast_rounded,
                        color: Color(0xFFC6431F)),
                    title: const Text('Alto contraste',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle:
                        const Text('Reforça textos e contornos importantes.'),
                    value: controller.highContrast,
                    onChanged: controller.setHighContrast,
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.motion_photos_off_outlined,
                        color: Color(0xFFC6431F)),
                    title: const Text('Reduzir movimentos',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text(
                        'Evita animações que possam causar desconforto.'),
                    value: controller.reduceMotion,
                    onChanged: controller.setReduceMotion,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _SettingsCard(
              icon: Icons.record_voice_over_outlined,
              title: 'Leitor de tela',
              subtitle:
                  'O BluAlert identifica botões, campos e estados para o leitor de tela do seu aparelho.',
              child: Text(
                  'Ative TalkBack no Android, VoiceOver no iPhone ou o leitor de tela do computador nas configurações do sistema.',
                  style: TextStyle(
                      color: Color(0xFF5C6B74), fontSize: 12, height: 1.45)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessibilityIcon extends StatelessWidget {
  const _AccessibilityIcon();
  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
            color: const Color(0xFFF06432),
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.accessibility_new_rounded,
            color: Colors.white, size: 30),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.child});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD9E1E6)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D0B2748), blurRadius: 16, offset: Offset(0, 6))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: const Color(0xFF173B67)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF162632))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFF5C6B74),
                            fontSize: 11.5,
                            height: 1.35)),
                  ])),
            ]),
            const SizedBox(height: 15),
            child,
          ],
        ),
      );
}
