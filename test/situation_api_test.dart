import 'dart:convert';

import 'package:blualert/data/blualert_situation_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('dados oficiais usam a rota do BluAlert na Vercel', () async {
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      return http.Response(
        jsonEncode({
          'fetchedAt': '2026-10-16T12:00:00Z',
          'telemetry': {'available': false},
          'municipal': {
            'available': true,
            'publishedAt': '16/10/2026',
            'riverStage': 'Normalidade',
            'regions': {'Centro': 'Normalidade'},
          },
        }),
        200,
      );
    });
    final provider = BluAlertSituationProvider(httpClient: client);

    final result = await provider.loadOfficialAlerts();

    expect(result.hasData, isTrue);
    expect(result.data!.weatherByRegion.single.region, 'Centro');
    expect(requested, hasLength(1));
    expect(requested.single.host, 'blualert.vercel.app');
    expect(requested.single.path, '/api/situation');
  });

  test('resposta inválida não vira dado oficial', () async {
    final provider = BluAlertSituationProvider(
      httpClient:
          MockClient((_) async => http.Response('<html>erro</html>', 200)),
    );

    final result = await provider.loadOfficialAlerts();

    expect(result.hasData, isFalse);
  });
}
