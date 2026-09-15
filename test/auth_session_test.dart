import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_parking_mobile/models/auth_session.dart';

void main() {
  test('AuthSession ASP.NET Core yanıtını okur', () {
    final session = AuthSession.fromApi(
      {
        'success': true,
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'expiresAt': '2030-01-01T10:00:00Z',
      },
      email: 'efe@example.com',
    );

    expect(session.accessToken, 'access');
    expect(session.refreshToken, 'refresh');
    expect(session.email, 'efe@example.com');
    expect(session.expiresAt.isUtc, isTrue);
    expect(session.isDemo, isFalse);
  });

  test('Demo oturumu çevrimdışı keşif için oluşturulur', () {
    final session = AuthSession.demo();

    expect(session.isDemo, isTrue);
    expect(session.fullName, 'Demo Sürücü');
    expect(session.expiresSoon, isFalse);
  });

  test('JWT içindeki Admin rolünü mobil yönetim yetkisine dönüştürür', () {
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'none'})));
    final payload = base64Url.encode(
      utf8.encode(jsonEncode({'role': ['User', 'Admin']})),
    );
    final session = AuthSession(
      accessToken: '$header.$payload.signature',
      refreshToken: 'refresh',
      expiresAt: DateTime.utc(2030),
      email: 'admin@example.com',
      fullName: 'Yönetici',
    );

    expect(session.isAdmin, isTrue);
    expect(session.roles, containsAll(['User', 'Admin']));
  });
}
