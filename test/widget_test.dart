import 'package:blualert/main.dart';
import 'package:blualert/account_flow.dart';
import 'package:blualert/occurrence_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('cadastro reúne identificação, telefone e localização',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountAccessScreen(
          profile: null,
          vault: const ProfileVault(),
          onRegistered: (_, __) async {},
          onUnlocked: (_) async {},
          onReset: () async {},
        ),
      ),
    );

    expect(find.text('Entrar no BluAlert'), findsWidgets);
    await tester.tap(find.text('Ainda não tenho cadastro'));
    await tester.pumpAndSettle();
    expect(find.text('Nome completo'), findsOneWidget);
    expect(find.text('E-mail de acesso'), findsOneWidget);
    expect(find.text('Senha da conta'), findsOneWidget);
    expect(find.text('Telefone para contato'), findsOneWidget);
    expect(find.text('Rua'), findsOneWidget);
    expect(find.text('Número'), findsOneWidget);
    expect(find.text('Usar minha localização atual'), findsNothing);
    expect(find.textContaining('PIN'), findsNothing);
    expect(find.text('Nome do contato'), findsNothing);
  });

  testWidgets('cadastro pendente abre a tela de confirmação', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountAccessScreen(
          profile: null,
          pendingConfirmationEmail: 'morador@exemplo.com',
          vault: const ProfileVault(),
          onRegistered: (_, __) async {},
          onUnlocked: (_) async {},
          onReset: () async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Confirme seu e-mail'), findsOneWidget);
    expect(find.text('morador@exemplo.com'), findsOneWidget);
    expect(find.text('Já confirmei meu e-mail'), findsOneWidget);
    expect(find.textContaining('Reenviar em'), findsOneWidget);
  });

  testWidgets('ocorrência exige evidência, descrição e localização',
      (tester) async {
    const profile = ResidentProfile(
      email: 'gustavo@example.com',
      fullName: 'Gustavo Deschamps',
      phone: '47999999999',
      referenceAddress: 'Blumenau',
    );
    await tester.pumpWidget(
      const MaterialApp(home: OccurrenceScreen(profile: profile)),
    );

    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Gravar vídeo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Capturar GPS agora'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Capturar GPS agora'), findsOneWidget);
  });
}
