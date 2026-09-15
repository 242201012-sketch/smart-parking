import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

class PushDeviceService {
  PushDeviceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> register({
    required String accessToken,
    required String token,
  }) async {
    final response = await _client
        .post(
          AppConfig.apiUri('/api/devices/push'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode({
            'token': token,
            'platform': defaultTargetPlatform.name,
            'deviceName': 'SmartParking Flutter',
          }),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(response);
  }

  Future<void> unregister({
    required String accessToken,
    required String token,
  }) async {
    final response = await _client
        .delete(
          AppConfig.apiUri('/api/devices/push'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode({'token': token}),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(response);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException.fromResponse(
      response.statusCode,
      utf8.decode(response.bodyBytes),
    );
  }

  void dispose() => _client.close();
}
