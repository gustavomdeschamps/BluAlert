import 'package:blualert/main.dart';
import 'package:blualert/accessibility.dart';
import 'package:blualert/account_flow.dart';
import 'package:blualert/occurrence_flow.dart';
import 'package:blualert/queue/evidence_files_web.dart';
import 'package:blualert/queue/queue_controller.dart';
import 'package:blualert/queue/queue_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('acessibilidade altera escala, contraste e movimento no app',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final accessibility = AccessibilityController.instance;
    await accessibility.setTextScale(1.3);
    await accessibility.setHighContrast(true);
    await accessibility.setReduceMotion(true);
    addTearDown(() async {
      await accessibility.setTextScale(1);
      await accessibility.setHighContrast(false);
      await accessibility.setReduceMotion(false);
    });

    await tester.pumpWidget(const BluAlertApp());
    await tester.pump();
    final context = tester.element(find.byType(AccountGate));
    expect(MediaQuery.textScalerOf(context).scale(10), closeTo(13, .01));
    expect(MediaQuery.highContrastOf(context), isTrue);
    expect(MediaQuery.disableAnimationsOf(context), isTrue);
    expect(Theme.of(context).scaffoldBackgroundColor, Colors.white);
  });

  testWidgets('acessibilidade mantém moldura do app após navegar no desktop',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AppViewport(child: child!),
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const AccessibilityScreen())),
                child: const Text('Abrir acessibilidade'),
              ))),
    ));
    await tester.tap(find.text('Abrir acessibilidade'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Scaffold).last).width, 430);
    expect(tester.takeException(), isNull);
  });
  testWidgets('identidade identifica a Defesa Civil de Blumenau',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CivilDefenseHeader())),
    );

    expect(find.text('BLUALERT'), findsOneWidget);
    expect(find.text('BLUMENAU'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('emergência apresenta somente canais oficiais', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmergencyScreen())),
    );

    expect(find.text('199'), findsOneWidget);
    expect(find.text('193'), findsOneWidget);
    expect(find.text('192'), findsOneWidget);
    expect(find.text('Protocolo'), findsNothing);
  });

  testWidgets('abertura apresenta marca e pode ser antecipada', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SignatureLaunch(onComplete: () => completed = true),
      ),
    );

    expect(find.text('BluAlert'), findsOneWidget);
    expect(find.text('Blumenau mais perto. Você mais seguro.'), findsOneWidget);
    await tester.tap(find.text('Entrar'));
    expect(completed, isTrue);
  });

  testWidgets('cadastro não exige endereço ou GPS para criar conta',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ResidentProfile? registered;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountAccessScreen(
          profile: null,
          vault: const ProfileVault(),
          onRegistered: (profile, _) async => registered = profile,
          onUnlocked: (_) async {},
          onReset: () async {},
        ),
      ),
    );

    // Um dispositivo sem cadastro começa diretamente pelo cadastro.
    expect(find.text('Nome completo'), findsOneWidget);
    expect(find.text('E-mail de acesso'), findsOneWidget);
    expect(find.text('Senha da conta'), findsOneWidget);
    expect(find.text('Telefone para contato'), findsOneWidget);
    expect(find.text('Endereço de referência (opcional)'), findsOneWidget);
    expect(find.text('Rua'), findsNothing);
    expect(find.text('Número'), findsNothing);
    expect(find.text('Usar minha localização atual'), findsNothing);
    expect(find.textContaining('PIN'), findsNothing);
    expect(find.text('Nome do contato'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'Maria Silva');
    await tester.enterText(find.byType(TextFormField).at(1), 'maria@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'senha-segura-123');
    await tester.enterText(find.byType(TextFormField).at(3), '47999999999');
    await tester.tap(find.text('Criar cadastro'));
    await tester.pump();
    expect(registered?.email, 'maria@example.com');
    expect(registered?.referenceAddress, isEmpty);
    expect(registered?.latitude, isNull);
    expect(registered?.longitude, isNull);
    expect(find.text('Confirme seu e-mail'), findsOneWidget);
  });

  testWidgets('perfil já salvo começa pela tela de login', (tester) async {
    const profile = ResidentProfile(
      email: 'morador@exemplo.com',
      fullName: 'Morador de Blumenau',
      phone: '47999999999',
      referenceAddress: 'Blumenau',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AccountAccessScreen(
          profile: profile,
          vault: const ProfileVault(),
          onRegistered: (_, __) async {},
          onUnlocked: (_) async {},
          onReset: () async {},
        ),
      ),
    );

    expect(find.text('Entrar no BluAlert'), findsOneWidget);
    expect(find.text('Nome completo'), findsNothing);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text,
      isEmpty,
    );
  });

  testWidgets('login não revela o e-mail do cadastro salvo',
      (tester) async {
    const profile = ResidentProfile(
      email: 'gustavodeschamps33@gmail.com',
      fullName: 'Gustavo Moreira Deschamps',
      phone: '47999999999',
      referenceAddress: 'Blumenau',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AccountAccessScreen(
          profile: profile,
          vault: const ProfileVault(),
          onRegistered: (_, __) async {},
          onUnlocked: (_) async {},
          onReset: () async {},
        ),
      ),
    );

    expect(find.textContaining('gustavodeschamps33@gmail.com'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('ocorrência exige evidência, descrição e localização',
      (tester) async {
    const profile = ResidentProfile(
      email: 'gustavo@example.com',
      fullName: 'Gustavo Deschamps',
      phone: '47999999999',
      referenceAddress: 'Blumenau',
    );
    final queue = QueueController.forTesting(
      store: MemoryQueueStore(),
      files: MemoryEvidenceFileStore(),
    );
    addTearDown(queue.dispose);

    await tester.pumpWidget(
      MaterialApp(home: OccurrenceScreen(profile: profile, queue: queue)),
    );

    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Gravar vídeo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Capturar e confirmar no mapa'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    // O ponto do GPS precisa passar por confirmação no mapa antes do envio:
    // um alfinete errado manda a equipe para a rua errada.
    expect(find.text('Capturar e confirmar no mapa'), findsOneWidget);
    expect(find.text('Usar endereço de teste'), findsNothing);
    expect(
      find.textContaining('confere o ponto no mapa'),
      findsOneWidget,
    );
  });

  testWidgets('o envio exige revisão antes de sair do aparelho',
      (tester) async {
    const profile = ResidentProfile(
      email: 'gustavo@example.com',
      fullName: 'Gustavo Deschamps',
      phone: '47999999999',
      referenceAddress: 'Blumenau',
    );
    final queue = QueueController.forTesting(
      store: MemoryQueueStore(),
      files: MemoryEvidenceFileStore(),
    );
    addTearDown(queue.dispose);

    await tester.pumpWidget(
      MaterialApp(home: OccurrenceScreen(profile: profile, queue: queue)),
    );
    await tester.scrollUntilVisible(
      find.text('Revisar envio'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    // O botão é de revisão, não de envio direto: o passo de conferência é
    // obrigatório antes de a ocorrência sair do aparelho.
    expect(find.text('Revisar envio'), findsOneWidget);
    expect(find.text('Enviar'), findsNothing);

    // Sem foto, descrição e GPS, a revisão nem abre.
    await tester.tap(find.text('Revisar envio'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar e enviar'), findsNothing);
    expect(find.textContaining('Inclua pelo menos uma foto'), findsOneWidget);
  });

  testWidgets('a lista de registros começa vazia e é honesta sobre isso',
      (tester) async {
    final queue = QueueController.forTesting(
      store: MemoryQueueStore(),
      files: MemoryEvidenceFileStore(),
    );
    addTearDown(queue.dispose);

    await tester.pumpWidget(MaterialApp(home: QueueScreen(queue: queue)));
    await tester.pump();

    expect(find.text('Nenhum registro ainda'), findsOneWidget);
    // Estado vazio não pode inventar contagem, alerta nem ocorrência de exemplo.
    expect(find.textContaining('exemplo'), findsNothing);
  });
}
