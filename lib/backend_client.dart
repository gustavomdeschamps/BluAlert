import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Converte um telefone brasileiro para o formato E.164 esperado pelo banco
/// (`^\+[1-9][0-9]{9,14}$`).
///
/// A decisão é pelo comprimento, não pelo prefixo. Testar `startsWith('55')`
/// corrompe números legítimos: o fixo `55 3333-4444` de São Paulo tem 10
/// dígitos e começa com 55, e viraria `+5533334444` — um número diferente, que
/// mesmo assim passa na validação do banco e chega errado à equipe.
///
/// - 10 ou 11 dígitos: número nacional (DDD + assinante) → recebe `+55`.
/// - 12 ou 13 dígitos começando com 55: já traz o código do país.
/// - Qualquer outro comprimento é devolvido com `+` para que a validação
///   do servidor recuse de forma visível, em vez de aceitar algo inventado.
String normalizeBrazilianPhone(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  // Prefixo internacional discado (00) ou já em E.164.
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 10 || digits.length == 11) return '+55$digits';
  if ((digits.length == 12 || digits.length == 13) && digits.startsWith('55')) {
    return '+$digits';
  }
  return '+$digits';
}

class BackendUnavailable implements Exception {
  const BackendUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackendSession {
  const BackendSession(
      {required this.accessToken,
      required this.refreshToken,
      required this.expiresAt});
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  Map<String, Object?> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory BackendSession.fromJson(Map<String, dynamic> json) => BackendSession(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

class BackendClient {
  BackendClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _sessionKey = 'blualert_backend_session_v1';
  static const _secureStorage = FlutterSecureStorage();
  final http.Client _http;

  bool get isConfigured => supabaseUrl.isNotEmpty && anonKey.isNotEmpty;

  /// Tenta reaproveitar a sessão guardada no aparelho.
  ///
  /// Devolve `null` quando não há sessão utilizável — sessão ausente, expirada
  /// sem refresh válido, ou backend indisponível. Nunca lança: a abertura do
  /// aplicativo não pode quebrar por causa de rede, e cair na tela de login é
  /// sempre um destino seguro.
  Future<bool> hasRestorableSession() async {
    if (!isConfigured) return false;
    try {
      await session();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Encerra a sessão local. O token de acesso continua válido no servidor até
  /// expirar, por isso também pedimos a revogação — sem falhar se ela não vier.
  Future<void> signOut() async {
    final current = await _readSession();
    await _clearSession();
    if (current == null || !isConfigured) return;
    try {
      await _http.post(
        Uri.parse('$supabaseUrl/auth/v1/logout'),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer ${current.accessToken}',
        },
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      // A sessão local já foi apagada; a revogação remota é o melhor esforço.
    }
  }

  Future<BackendSession> session() async {
    if (!isConfigured) {
      throw const BackendUnavailable(
        'O canal piloto ainda não foi configurado neste aplicativo. Em emergência, ligue 199.',
      );
    }
    final current = await _readSession();
    if (current != null &&
        current.expiresAt
            .isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return current;
    }
    if (current != null) {
      try {
        return await _refresh(current.refreshToken);
      } catch (_) {
        await _clearSession();
      }
    }
    throw const BackendUnavailable(
      'Sua sessão segura expirou. Entre novamente com e-mail e senha.',
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String referenceAddress,
    double? latitude,
    double? longitude,
  }) async {
    _requireConfiguration();
    final response = await _http
        .post(
          Uri.parse('$supabaseUrl/auth/v1/signup'),
          headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim().toLowerCase(),
            'password': password,
            'data': {
              'full_name': fullName.trim(),
              'phone': _internationalPhone(phone),
              'reference_address': referenceAddress.trim(),
              'reference_latitude': latitude,
              'reference_longitude': longitude,
            },
          }),
        )
        .timeout(const Duration(seconds: 20));
    final decoded = _decode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['user'] == null) {
      throw BackendUnavailable(_authError(decoded));
    }
    if (decoded['access_token'] != null) await _saveAuthResponse(decoded);
  }

  Future<void> signIn({required String email, required String password}) async {
    _requireConfiguration();
    final response = await _http
        .post(
          Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
          headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim().toLowerCase(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendUnavailable(_authError(decoded));
    }
    await _saveAuthResponse(decoded);
  }

  Future<Map<String, dynamic>> fetchMyProfile() async {
    final active = await session();
    final response = await _http.get(
      Uri.parse(
          '$supabaseUrl/rest/v1/profiles?select=full_name,phone,reference_address,reference_latitude,reference_longitude&limit=1'),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer ${active.accessToken}',
      },
    ).timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendUnavailable(_authError(
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{}));
    }
    if (decoded is! List || decoded.isEmpty) {
      throw const BackendUnavailable(
          'Seu acesso foi confirmado, mas o perfil não foi encontrado.');
    }
    return Map<String, dynamic>.from(decoded.first as Map);
  }

  Future<void> resendConfirmation(String email) async {
    _requireConfiguration();
    final response = await _http
        .post(
          Uri.parse('$supabaseUrl/auth/v1/resend'),
          headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'type': 'signup',
            'email': email.trim().toLowerCase(),
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendUnavailable(_authError(_decode(response.body)));
    }
  }

  Future<Map<String, dynamic>> invoke(
      String function, Map<String, Object?> body) async {
    final active = await session();
    final response = await _http
        .post(
          Uri.parse('$supabaseUrl/functions/v1/$function'),
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer ${active.accessToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendUnavailable(_friendlyError(decoded['error']?.toString()));
    }
    return decoded;
  }

  Future<void> upload(Uri signedUrl, Uint8List bytes, String mimeType) async {
    final response = await _http
        .put(signedUrl, headers: {'Content-Type': mimeType}, body: bytes)
        .timeout(const Duration(seconds: 90));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const BackendUnavailable(
          'A evidência não terminou de enviar. Ela poderá ser reenviada sem duplicar a ocorrência.');
    }
  }

  String sha256Of(Uint8List bytes) => sha256.convert(bytes).toString();

  String uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<BackendSession> _refresh(String refreshToken) async {
    final response = await _http
        .post(
          Uri.parse('$supabaseUrl/auth/v1/token?grant_type=refresh_token'),
          headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const BackendUnavailable('Sessão expirada.');
    }
    return _saveAuthResponse(_decode(response.body));
  }

  Future<BackendSession> _saveAuthResponse(Map<String, dynamic> body) async {
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
    final value = BackendSession(
      accessToken: body['access_token'] as String,
      refreshToken: body['refresh_token'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
    final encoded = jsonEncode(value.toJson());
    if (kIsWeb) {
      await (await SharedPreferences.getInstance())
          .setString(_sessionKey, encoded);
    } else {
      await _secureStorage.write(key: _sessionKey, value: encoded);
    }
    return value;
  }

  Future<BackendSession?> _readSession() async {
    final encoded = kIsWeb
        ? (await SharedPreferences.getInstance()).getString(_sessionKey)
        : await _secureStorage.read(key: _sessionKey);
    if (encoded == null) return null;
    try {
      return BackendSession.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearSession() async {
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).remove(_sessionKey);
    } else {
      await _secureStorage.delete(key: _sessionKey);
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': 'INVALID_RESPONSE'};
    }
  }

  String _friendlyError(String? code) => switch (code) {
        'RATE_LIMITED' =>
          'Limite de envios atingido. Se houver risco imediato, ligue 199 ou 193.',
        'RECEIVING_DISABLED' =>
          'O canal digital está temporariamente indisponível. Ligue 199.',
        'UPLOAD_INCOMPLETE' =>
          'Uma evidência ainda não chegou por completo. Tente novamente.',
        'PHOTO_REQUIRED' => 'Inclua pelo menos uma foto da ocorrência.',
        'INVALID_MEDIA' =>
          'Uma evidência não atende aos limites de tamanho ou formato.',
        'INVALID_PROFILE' =>
          'Seu perfil está incompleto no servidor. Saia e entre novamente antes de reenviar.',
        'INVALID_LOCATION' =>
          'A localização da ocorrência não foi aceita pelo servidor.',
        'INVALID_OCCURRENCE' =>
          'Revise o tipo e a descrição da ocorrência antes de reenviar.',
        _ =>
          'A central não confirmou o recebimento. O envio não será marcado como recebido.',
      };

  void _requireConfiguration() {
    if (!isConfigured) {
      throw const BackendUnavailable(
        'O canal piloto ainda não foi configurado neste aplicativo.',
      );
    }
  }

  String _internationalPhone(String value) => normalizeBrazilianPhone(value);

  String _authError(Map<String, dynamic> body) {
    final code = body['error_code']?.toString();
    final message =
        (body['msg'] ?? body['message'] ?? body['error_description'])
            ?.toString()
            .toLowerCase();
    if (code == 'user_already_exists' || code == 'email_exists') {
      return 'Este e-mail já possui cadastro.';
    }
    if (code == 'invalid_credentials') return 'E-mail ou senha incorretos.';
    if (code == 'email_not_confirmed') {
      return 'Confirme o link enviado ao seu e-mail antes de entrar.';
    }
    if (code == 'weak_password') {
      return 'Use uma senha mais forte, com pelo menos 8 caracteres.';
    }
    if (code == 'email_address_not_authorized' ||
        message?.contains('email address not authorized') == true) {
      return 'Este e-mail foi recusado porque o envio de confirmações do projeto ainda não está configurado.';
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'email_rate_limit_exceeded' ||
        message?.contains('rate limit') == true) {
      return 'O limite temporário de e-mails foi atingido. Aguarde uma hora e tente novamente.';
    }
    if (code == 'signup_disabled') {
      return 'Novos cadastros estão desativados no servidor.';
    }
    if (message?.contains('database error') == true) {
      return 'A conta chegou ao servidor, mas o perfil não pôde ser salvo no banco.';
    }
    if (message?.contains('error sending confirmation email') == true ||
        message?.contains('confirmation email') == true) {
      return 'O Supabase não conseguiu enviar o e-mail de confirmação. O projeto precisa de um servidor de e-mail configurado.';
    }
    if (code == 'email_address_invalid') {
      return 'O endereço de e-mail informado não foi aceito.';
    }
    final safeCode = code == null || code.isEmpty ? null : ' Código: $code.';
    return 'O Supabase recusou o cadastro.${safeCode ?? ''}';
  }
}
