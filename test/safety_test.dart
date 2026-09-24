// Testes das garantias de segurança operacional do piloto.
//
// Cada teste aqui corresponde a uma falha real encontrada na auditoria. Se um
// deles quebrar, alguma proteção de vida foi removida — não ajuste o teste sem
// entender qual.
import 'package:blualert/backend_client.dart';
import 'package:blualert/emergency.dart';
import 'package:blualert/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    // Cada teste parte do estado assumido, sem resposta do servidor.
    PilotConfigService.current.value = PilotConfig.safeFallback;
  });

  group('normalização de telefone brasileiro', () {
    test('celular com DDD recebe o código do país', () {
      expect(normalizeBrazilianPhone('47999998888'), '+5547999998888');
      expect(normalizeBrazilianPhone('(47) 99999-8888'), '+5547999998888');
    });

    test('fixo de 10 dígitos recebe o código do país', () {
      expect(normalizeBrazilianPhone('4733334444'), '+554733334444');
    });

    test('número que já começa com 55 não é confundido com o código do país',
        () {
      // Regressão: a heurística antiga testava `startsWith('55')` e convertia
      // este fixo de São Paulo em +55 3333-4444 — um número diferente, que
      // ainda assim passava na validação do banco e chegava errado à equipe.
      expect(normalizeBrazilianPhone('5533334444'), '+555533334444');
      expect(normalizeBrazilianPhone('55987654321'), '+5555987654321');
    });

    test('número já em E.164 é preservado', () {
      expect(normalizeBrazilianPhone('+5547999998888'), '+5547999998888');
      expect(normalizeBrazilianPhone('005547999998888'), '+5547999998888');
    });
  });

  group('configuração do piloto', () {
    test('o estado assumido nunca afirma que existe central humana', () {
      const fallback = PilotConfig.safeFallback;
      expect(fallback.pilotMode, isTrue);
      expect(fallback.humanReceiverConfirmed, isFalse);
      expect(fallback.emergencyPhone, '199');
      expect(fallback.showsPilotNotice, isTrue);
    });

    test('resposta incompleta do servidor cai para o lado seguro', () {
      final config = PilotConfig.fromJson(const <String, dynamic>{});
      expect(config.pilotMode, isTrue);
      expect(config.humanReceiverConfirmed, isFalse);
      expect(config.emergencyPhone, '199');
    });

    test('o aviso só some com piloto encerrado E central confirmada', () {
      const semCentral = PilotConfig(
        pilotMode: false,
        humanReceiverConfirmed: false,
        emergencyPhone: '199',
        uploadsEnabled: true,
        videoEnabled: true,
        origin: PilotConfigOrigin.server,
      );
      expect(semCentral.showsPilotNotice, isTrue,
          reason: 'sem central humana o aviso precisa continuar visível');

      const operacional = PilotConfig(
        pilotMode: false,
        humanReceiverConfirmed: true,
        emergencyPhone: '199',
        uploadsEnabled: true,
        videoEnabled: true,
        origin: PilotConfigOrigin.server,
      );
      expect(operacional.showsPilotNotice, isFalse);
    });
  });

  group('aviso sobre o canal na interface', () {
    testWidgets('mostra o limite do canal e o telefone de emergência',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: PilotNotice())),
        ),
      );

      expect(find.text('SOBRE ESTE CANAL'), findsOneWidget);
      expect(find.textContaining('não substitui uma ligação de emergência'),
          findsOneWidget);
      expect(find.textContaining('199'), findsWidgets);
    });

    testWidgets('nega explicitamente o acionamento automático de equipe',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: PilotNotice())),
        ),
      );

      expect(
        find.textContaining('não aciona automaticamente uma equipe'),
        findsOneWidget,
      );
    });

    testWidgets('some quando o servidor confirma central humana',
        (tester) async {
      PilotConfigService.current.value = const PilotConfig(
        pilotMode: false,
        humanReceiverConfirmed: true,
        emergencyPhone: '199',
        uploadsEnabled: true,
        videoEnabled: true,
        origin: PilotConfigOrigin.server,
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PilotNotice())),
      );

      expect(find.text('SOBRE ESTE CANAL'), findsNothing);
    });

    testWidgets('usa o telefone publicado pelo servidor', (tester) async {
      PilotConfigService.current.value = const PilotConfig(
        pilotMode: true,
        humanReceiverConfirmed: false,
        emergencyPhone: '193',
        uploadsEnabled: true,
        videoEnabled: true,
        origin: PilotConfigOrigin.server,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: PilotNotice())),
        ),
      );

      expect(find.textContaining('193'), findsWidgets);
    });
  });

  group('canal de emergência', () {
    testWidgets('a faixa de risco oferece ligação imediata', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmergencyCallout())),
      );

      expect(find.textContaining('Perigo imediato'), findsOneWidget);
      expect(find.text('199'), findsOneWidget);
    });

    testWidgets('a tela de emergência lista os três serviços oficiais',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmergencyScreen())),
      );
      await tester.pump();

      expect(find.text('199'), findsWidgets);
      expect(find.text('193'), findsOneWidget);
      expect(find.text('192'), findsOneWidget);
    });

    testWidgets('a tela de emergência não promete despacho de equipe',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmergencyScreen())),
      );
      await tester.pump();

      // Regressão: a cópia antiga afirmava que o BluAlert "não simula o envio"
      // e mandava usar outro aplicativo, contradizendo o fluxo real.
      expect(find.textContaining('não simula o envio'), findsNothing);
      expect(find.text('SOBRE ESTE CANAL'), findsOneWidget);
    });
  });
}
