import 'dart:convert';

import 'package:http/http.dart' as http;

class AddressSuggestion {
  const AddressSuggestion({
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  final String street;
  final String neighborhood;
  final String city;
  final double latitude;
  final double longitude;

  String get subtitle =>
      [neighborhood, city].where((part) => part.trim().isNotEmpty).join(' · ');
}

class AddressSearchService {
  AddressSearchService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<AddressSuggestion>> searchStreets(String query) async {
    final term = query.trim();
    if (term.length < 3) return const [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'addressdetails': '1',
      'countrycodes': 'br',
      'city': 'Blumenau',
      'street': term,
      'limit': '6',
      'accept-language': 'pt-BR',
    });
    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'BluAlert/1.0 (projeto academico; Blumenau-SC)',
    }).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw const AddressSearchException();
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
    final unique = <String, AddressSuggestion>{};
    for (final item in decoded.cast<Map<String, dynamic>>()) {
      final address = item['address'] as Map<String, dynamic>? ?? const {};
      final street = (address['road'] ??
              address['pedestrian'] ??
              address['residential'] ??
              address['path'])
          ?.toString()
          .trim();
      if (street == null || street.isEmpty) continue;
      final neighborhood = (address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              '')
          .toString();
      final suggestion = AddressSuggestion(
        street: street,
        neighborhood: neighborhood,
        city: (address['city'] ?? address['town'] ?? 'Blumenau').toString(),
        latitude: double.tryParse(item['lat']?.toString() ?? '') ?? 0,
        longitude: double.tryParse(item['lon']?.toString() ?? '') ?? 0,
      );
      unique['${street.toLowerCase()}|${neighborhood.toLowerCase()}'] =
          suggestion;
    }
    return unique.values.toList(growable: false);
  }
}

class AddressSearchException implements Exception {
  const AddressSearchException();
}
