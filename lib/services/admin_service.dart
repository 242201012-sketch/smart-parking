import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/admin_models.dart';
import 'api_exception.dart';

class AdminService {
  AdminService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AdminDashboard> getDashboard(String accessToken) async {
    final decoded = await _request('GET', '/api/admin/dashboard', accessToken);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Yönetim özeti geçersiz biçimde döndü.');
    }
    return AdminDashboard.fromJson(decoded);
  }

  Future<List<AdminSensor>> getSensors(String accessToken) async {
    final decoded = await _request('GET', '/api/admin/sensors', accessToken);
    if (decoded is! List) {
      throw const ApiException('Sensör listesi geçersiz biçimde döndü.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AdminSensor.fromJson)
        .toList();
  }

  Future<void> setSensorStatus(
    String accessToken,
    String sensorId,
    bool isActive,
  ) async {
    await _request(
      'PUT',
      '/api/admin/sensors/$sensorId/status',
      accessToken,
      body: {'isActive': isActive},
    );
  }

  Future<void> createSensor(
    String accessToken, {
    required String parkingLotId,
    required String deviceId,
    required String name,
  }) async {
    await _request(
      'POST',
      '/api/admin/sensors',
      accessToken,
      body: {
        'parkingLotId': parkingLotId,
        'deviceId': deviceId,
        'name': name,
      },
    );
  }

  Future<void> createParkingLot(
    String accessToken, {
    required Map<String, dynamic> values,
  }) async {
    await _request(
      'POST',
      '/api/admin/parking-lots',
      accessToken,
      body: values,
    );
  }

  Future<dynamic> _request(
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
      final encodedBody = body == null ? null : jsonEncode(body);
      final response = switch (method) {
        'POST' => await _client
            .post(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 15)),
        'PUT' => await _client
            .put(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 15)),
        _ => await _client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15)),
      };
      final responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(response.statusCode, responseBody);
      }
      return responseBody.isEmpty ? null : jsonDecode(responseBody);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Yönetim servisine ulaşılamadı.');
    }
  }

  void dispose() => _client.close();
}
