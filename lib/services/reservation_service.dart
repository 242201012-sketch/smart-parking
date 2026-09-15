import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/parking_reservation.dart';
import 'api_exception.dart';

class ReservationService {
  ReservationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ParkingReservation?> getActive(String accessToken) async {
    try {
      final response = await _client
          .get(
            AppConfig.apiUri('/api/reservations/active'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 204) return null;
      final decoded = _decodeResponse(response);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Aktif rezervasyon yanıtı geçersiz.');
      }
      return ParkingReservation.fromJson(decoded);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Rezervasyon servisine ulaşılamadı.');
    }
  }

  Future<ParkingReservation> create({
    required String accessToken,
    required String parkingLotId,
    required String vehiclePlate,
    required int durationMinutes,
    bool requireElectric = false,
    bool requireAccessible = false,
  }) async {
    try {
      final response = await _client
          .post(
            AppConfig.apiUri('/api/reservations'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'parkingLotId': parkingLotId,
              'vehiclePlate': vehiclePlate,
              'durationMinutes': durationMinutes,
              'requireElectric': requireElectric,
              'requireAccessible': requireAccessible,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = _decodeResponse(response);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Rezervasyon yanıtı geçersiz.');
      }
      return ParkingReservation.fromJson(decoded);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Rezervasyon servisine ulaşılamadı.');
    }
  }

  Future<void> cancel(String accessToken, String reservationId) async {
    try {
      final response = await _client
          .post(
            AppConfig.apiUri('/api/reservations/$reservationId/cancel'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 15));
      _decodeResponse(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Rezervasyon servisine ulaşılamadı.');
    }
  }

  dynamic _decodeResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response.statusCode, body);
    }
    return body.isEmpty ? null : jsonDecode(body);
  }

  void dispose() => _client.close();
}
