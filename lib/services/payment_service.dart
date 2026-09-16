import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/payment_models.dart';
import 'api_exception.dart';

class PaymentService {
  PaymentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PaymentConfig> getConfig() async {
    final decoded = await _request('GET', '/api/payments/config');
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Ödeme yapılandırması geçersiz.');
    }
    return PaymentConfig.fromJson(decoded);
  }

  Future<List<PayableSession>> getPayableSessions(String accessToken) async {
    final decoded = await _request(
      'GET',
      '/api/payments/payable-sessions',
      accessToken: accessToken,
    );
    if (decoded is! List) {
      throw const ApiException('Ödenecek oturum listesi geçersiz.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PayableSession.fromJson)
        .toList();
  }

  Future<List<PaymentItem>> getPayments(String accessToken) async {
    final decoded = await _request(
      'GET',
      '/api/payments',
      accessToken: accessToken,
    );
    if (decoded is! List) throw const ApiException('Ödeme geçmişi geçersiz.');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PaymentItem.fromJson)
        .toList();
  }

  Future<PaymentItem> getPaymentStatus(
    String accessToken,
    String paymentId,
  ) async {
    final decoded = await _request(
      'GET',
      '/api/payments/$paymentId/status',
      accessToken: accessToken,
    );
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Ödeme durumu alınamadı.');
    }
    return PaymentItem.fromJson(decoded);
  }

  Future<CheckoutSession> createCheckout(
    String accessToken, {
    required String parkingSessionId,
    required String gsmNumber,
    required String identityNumber,
    required String registrationAddress,
    required String city,
    required String zipCode,
  }) async {
    final decoded = await _request(
      'POST',
      '/api/payments/checkout',
      accessToken: accessToken,
      body: {
        'parkingSessionId': parkingSessionId,
        'gsmNumber': gsmNumber,
        'identityNumber': identityNumber,
        'registrationAddress': registrationAddress,
        'city': city,
        'country': 'Türkiye',
        'zipCode': zipCode,
      },
    );
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Ödeme oturumu oluşturulamadı.');
    }
    return CheckoutSession.fromJson(decoded);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    String? accessToken,
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (accessToken != null) headers['Authorization'] = 'Bearer $accessToken';
      final uri = AppConfig.apiUri(path);
      final response = method == 'POST'
          ? await _client
                .post(uri, headers: headers, body: jsonEncode(body))
                .timeout(const Duration(seconds: 20))
          : await _client
                .get(uri, headers: headers)
                .timeout(const Duration(seconds: 15));
      final responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(response.statusCode, responseBody);
      }
      return responseBody.isEmpty ? null : jsonDecode(responseBody);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Ödeme servisine güvenli bağlantı kurulamadı.');
    }
  }

  void dispose() => _client.close();
}
