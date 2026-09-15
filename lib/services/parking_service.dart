import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/parking_location.dart';
import 'api_exception.dart';

class ParkingService {
  ParkingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<ParkingLocation>> getAll(String accessToken) async {
    final decoded = await _get('/api/parking', accessToken);
    if (decoded is! List) {
      throw const ApiException('Otopark listesi geçersiz biçimde döndü.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ParkingLocation.fromJson)
        .toList();
  }

  Future<ParkingLocation> getNearest({
    required String accessToken,
    required double latitude,
    required double longitude,
  }) async {
    final decoded = await _get(
      '/api/parking/nearest',
      accessToken,
      queryParameters: {
        'lat': latitude.toStringAsFixed(7),
        'lng': longitude.toStringAsFixed(7),
      },
    );
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('En yakın otopark bilgisi geçersiz biçimde döndü.');
    }
    return ParkingLocation.fromJson(decoded);
  }

  Future<dynamic> _get(
    String path,
    String accessToken, {
    Map<String, String>? queryParameters,
  }) async {
    try {
      final response = await _client
          .get(
            AppConfig.apiUri(path, queryParameters: queryParameters),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 15));
      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(response.statusCode, responseBody);
      }
      return jsonDecode(responseBody);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Otopark servisine ulaşılamadı. İnternet ve API bağlantısını kontrol edin.',
      );
    }
  }

  void dispose() => _client.close();
}
