import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

/// Backend `DashboardController` tarafından sunulan canlı telemetri
/// endpoint'lerinin Flutter görünümleri (okuma — salt), aynı
/// [ParkingService] deseninde (`_get` + Bearer + ApiException).
///
/// Gerçek kullanım şekli:
/// ```dart
/// final svc = TelemetryDashboardService();
/// final spaces = await svc.getCoalescedSensorSpaces(
///   accessToken: token, parkingLotId: lotId);
/// final trend = await svc.getAnprTrend(accessToken: token, parkingLotId: lotId);
/// final cap = await svc.getCapacity(accessToken: token, parkingLotId: lotId);
/// ```
class CoalescedSensorSpaceView {
  const CoalescedSensorSpaceView({
    required this.spaceCode,
    required this.readingCount,
    required this.isOccupied,
    this.batteryPercent,
    this.lastOccupancySecondsAgo,
    this.lastReadingUtc,
  });

  factory CoalescedSensorSpaceView.fromJson(Map<String, dynamic> json) =>
      CoalescedSensorSpaceView(
        spaceCode: json['spaceCode'] as String? ?? '',
        readingCount: (json['readingCount'] as num?)?.toInt() ?? 0,
        isOccupied: json['isOccupied'] as bool? ?? false,
        batteryPercent: (json['batteryPercent'] as num?)?.toDouble(),
        lastOccupancySecondsAgo:
            (json['lastOccupancySecondsAgo'] as num?)?.toInt(),
        lastReadingUtc: json['lastReadingUtc'] != null
            ? DateTime.tryParse(json['lastReadingUtc'] as String)
            : null,
      );

  final String spaceCode;
  final int readingCount;
  final bool isOccupied;
  final double? batteryPercent;
  final int? lastOccupancySecondsAgo;
  final DateTime? lastReadingUtc;

  int get lastOccupancySeconds => lastOccupancySecondsAgo ?? -1;
}

class AnprTrendPoint {
  const AnprTrendPoint({
    required this.bucketStartUtc,
    required this.entries,
    required this.exits,
  });

  factory AnprTrendPoint.fromJson(Map<String, dynamic> json) => AnprTrendPoint(
        bucketStartUtc:
            DateTime.tryParse(json['bucketStartUtc'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
        entries: (json['entries'] as num?)?.toInt() ?? 0,
        exits: (json['exits'] as num?)?.toInt() ?? 0,
      );

  final DateTime bucketStartUtc;
  final int entries;
  final int exits;

  int get netFlow => entries - exits;
}

class ParkingLotCapacitySnapshot {
  const ParkingLotCapacitySnapshot({
    required this.totalSpaces,
    required this.occupiedSpaces,
    required this.availableSpaces,
    required this.asOfUtc,
  });

  factory ParkingLotCapacitySnapshot.fromJson(Map<String, dynamic> json) =>
      ParkingLotCapacitySnapshot(
        totalSpaces: (json['totalSpaces'] as num?)?.toInt() ?? 0,
        occupiedSpaces: (json['occupiedSpaces'] as num?)?.toInt() ?? 0,
        availableSpaces: (json['availableSpaces'] as num?)?.toInt() ?? 0,
        asOfUtc:
            DateTime.tryParse(json['asOfUtc'] as String? ?? '') ??
                DateTime.now().toUtc(),
      );

  final int totalSpaces;
  final int occupiedSpaces;
  final int availableSpaces;
  final DateTime asOfUtc;

  double get occupancyRatio =>
      totalSpaces <= 0 ? 0 : (occupiedSpaces / totalSpaces).clamp(0.0, 1.0);
}

class TelemetryDashboardService {
  TelemetryDashboardService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// GET api/dashboard/{lotId}/coalesced-sensor-spaces
  /// Aynı uzay kodu altında biriken sensör okumalarının birleşik görünümü.
  Future<List<CoalescedSensorSpaceView>> getCoalescedSensorSpaces({
    required String accessToken,
    required String parkingLotId,
  }) async {
    final decoded = await _get(
      '/api/dashboard/$parkingLotId/coalesced-sensor-spaces',
      accessToken,
    );
    if (decoded is! List) {
      throw const ApiException('Sensör verisi geçersiz biçimde döndü.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(CoalescedSensorSpaceView.fromJson)
        .toList();
  }

  /// GET api/dashboard/{lotId}/anpr-trend?fromUtc&toUtc
  Future<List<AnprTrendPoint>> getAnprTrend({
    required String accessToken,
    required String parkingLotId,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) async {
    final to = (toUtc ?? DateTime.now().toUtc()).toUtc();
    final from = (fromUtc ?? to.subtract(const Duration(hours: 24))).toUtc();
    final decoded = await _get(
      '/api/dashboard/$parkingLotId/anpr-trend',
      accessToken,
      queryParameters: {
        'fromUtc': from.toIso8601String(),
        'toUtc': to.toIso8601String(),
      },
    );
    if (decoded is! List) {
      throw const ApiException('ANPR trendi geçersiz biçimde döndü.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AnprTrendPoint.fromJson)
        .toList();
  }

  /// GET api/dashboard/{lotId}/capacity
  Future<ParkingLotCapacitySnapshot> getCapacity({
    required String accessToken,
    required String parkingLotId,
  }) async {
    final decoded =
        await _get('/api/dashboard/$parkingLotId/capacity', accessToken);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Kapasite verisi geçersiz biçimde döndü.');
    }
    return ParkingLotCapacitySnapshot.fromJson(decoded);
  }

  /// GET api/dashboard/{lotId}/export?format=csv — telemetriyi CSV metni olarak indirir.
  Future<String> exportCsv({
    required String accessToken,
    required String parkingLotId,
  }) async {
    try {
      final response = await _client
          .get(
            AppConfig.apiUri(
              '/api/dashboard/$parkingLotId/export',
              queryParameters: {'format': 'csv'},
            ),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 20));
      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(response.statusCode, responseBody);
      }
      return responseBody;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Telemetri dışa aktarılamadı. İnternet ve API bağlantısını kontrol edin.',
      );
    }
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
        'Telemetri servisine ulaşılamadı. İnternet ve API bağlantısını kontrol edin.',
      );
    }
  }

  void dispose() => _client.close();
}
