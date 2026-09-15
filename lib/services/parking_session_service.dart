import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/parking_session.dart';
import 'api_exception.dart';

class ParkingSessionService {
  ParkingSessionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ParkingSession?> getActive(String accessToken) async {
    final response = await _send('GET', '/api/sessions/active', accessToken);
    if (response == null) return null;
    if (response is! Map<String, dynamic>) {
      throw const ApiException('Aktif park oturumu geçersiz biçimde döndü.');
    }
    return ParkingSession.fromJson(response);
  }

  Future<List<ParkingSession>> getHistory(String accessToken) async {
    final response = await _send('GET', '/api/sessions', accessToken);
    if (response is! List) throw const ApiException('Park geçmişi geçersiz biçimde döndü.');
    return response
        .whereType<Map<String, dynamic>>()
        .map(ParkingSession.fromJson)
        .toList();
  }

  Future<ParkingSession> start(
    String accessToken, {
    required String parkingLotId,
    required String vehiclePlate,
  }) async {
    final response = await _send(
      'POST',
      '/api/sessions/start',
      accessToken,
      body: {
        'parkingLotId': parkingLotId,
        'vehiclePlate': vehiclePlate,
      },
    );
    if (response is! Map<String, dynamic>) {
      throw const ApiException('Park oturumu başlatılamadı.');
    }
    return ParkingSession.fromJson(response);
  }

  Future<ParkingSession> stop(String accessToken, String sessionId) async {
    final response = await _send('POST', '/api/sessions/$sessionId/stop', accessToken);
    if (response is! Map<String, dynamic>) {
      throw const ApiException('Park oturumu sonlandırılamadı.');
    }
    return ParkingSession.fromJson(response);
  }

  Future<dynamic> _send(
    String method,
    String path,
    String accessToken, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };
      final uri = AppConfig.apiUri(path);
      final response = method == 'POST'
          ? await _client
              .post(uri, headers: headers, body: body == null ? null : jsonEncode(body))
              .timeout(const Duration(seconds: 15))
          : await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 204) return null;
      final responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(response.statusCode, responseBody);
      }
      return responseBody.isEmpty ? null : jsonDecode(responseBody);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Park oturumu servisine ulaşılamadı.');
    }
  }

  void dispose() => _client.close();
}
