import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_session.dart';
import 'api_exception.dart';

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _post(
      '/api/auth/login',
      {'email': email.trim(), 'password': password},
    );
    return AuthSession.fromApi(json, email: email.trim());
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final json = await _post(
      '/api/auth/register',
      {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
    return AuthSession.fromApi(
      json,
      email: email.trim(),
      fullName: fullName.trim(),
    );
  }

  Future<AuthSession> firebaseLogin({
    required String idToken,
    required String email,
    required String fullName,
  }) async {
    final json = await _post(
      '/api/auth/firebase',
      {'idToken': idToken},
    );
    return AuthSession.fromApi(
      json,
      email: email.trim(),
      fullName: fullName.trim(),
    );
  }

  Future<AuthSession> refresh(AuthSession current) async {
    final json = await _post(
      '/api/auth/refresh-token',
      {'refreshToken': current.refreshToken},
    );
    return AuthSession.fromApi(
      json,
      email: current.email,
      fullName: current.fullName,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            AppConfig.apiUri(path),
            headers: const {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(response.statusCode, responseBody);
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('API yanıt biçimi geçersiz.');
      }

      final success = decoded['success'] ?? decoded['Success'];
      if (success == false) {
        throw ApiException(
          (decoded['message'] ?? decoded['Message'] ?? 'İşlem başarısız.').toString(),
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'API sunucusuna ulaşılamadı. Sunucunun çalıştığını ve adresi kontrol edin.',
      );
    }
  }

  void dispose() => _client.close();
}
