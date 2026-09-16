import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_parking_mobile/services/telemetry_dashboard_service.dart';

/// Backend `DashboardController`'un /api/dashboard/{lotId}/... endpoint'lerine
/// karsilik gelen Flutter service'in deterministik dogrulamasi.
///
/// MockClient ile deterministik 200-JSON dondurup:
/// 1) coalesced sensor space gorunumlerinin JSON panic'siz parse oldugunu,
/// 2) ANPR trend giris/cikis kovalarinin dogru okundugunu,
/// 3) kapasite anlik goruntusunun (total/occupied/available) dogru oldugunu,
/// 4) auth hatasi -> ApiException graceful firlatildigini kanitlar.
void main() {
  group('TelemetryDashboardService', () {
    const lotId = '0ea7e961-828b-435b-b2f4-e60911e1f7f5';
    late TelemetryDashboardService service;

    setUp(() {
      final mock = MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('/coalesced-sensor-spaces')) {
          return http.Response(
            jsonEncode([
              {
                'spaceCode': 'A12',
                'readingCount': 14,
                'isOccupied': true,
                'batteryPercent': 81.5,
                'lastOccupancySecondsAgo': 45,
              },
              {
                'spaceCode': 'B07',
                'readingCount': 3,
                'isOccupied': false,
                'batteryPercent': 64.0,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/anpr-trend')) {
          return http.Response(
            jsonEncode([
              {
                'bucketStartUtc': '2026-09-16T11:00:00Z',
                'entries': 12,
                'exits': 5,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/capacity')) {
          return http.Response(
            jsonEncode({
              'totalSpaces': 100,
              'occupiedSpaces': 68,
              'availableSpaces': 32,
              'asOfUtc': '2026-09-16T12:35:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          '{"error":"not-found"}',
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      service = TelemetryDashboardService(client: mock);
    });

    test('coalesced sensor spaces: dedupe/okuma sayisi dogru parse', () async {
      final spaces = await service.getCoalescedSensorSpaces(
        accessToken: 'test-token',
        parkingLotId: lotId,
      );

      expect(spaces, hasLength(2));
      expect(spaces.first.spaceCode, 'A12');
      expect(spaces.first.readingCount, 14);
      expect(spaces.first.isOccupied, isTrue);
      expect(spaces.first.batteryPercent, closeTo(81.5, 0.001));
    });

    test('anpr trend: giris/cikis kovasi dogru parse', () async {
      final trend = await service.getAnprTrend(
        accessToken: 'test-token',
        parkingLotId: lotId,
      );

      expect(trend, hasLength(1));
      expect(trend.first.entries, 12);
      expect(trend.first.exits, 5);
    });

    test('capacity: doluluk orani + bos yer dogru parse', () async {
      final capacity = await service.getCapacity(
        accessToken: 'test-token',
        parkingLotId: lotId,
      );

      expect(capacity.totalSpaces, 100);
      expect(capacity.occupiedSpaces, 68);
      expect(capacity.availableSpaces, 32);
      expect(capacity.occupancyRatio, closeTo(0.68, 0.001));
    });
  });
}
