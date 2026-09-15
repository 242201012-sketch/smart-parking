import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';

class TokenStorage {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _expiresAtKey = 'expires_at';
  static const _emailKey = 'email';
  static const _fullNameKey = 'full_name';
  static const _isDemoKey = 'is_demo';

  Future<void> save(AuthSession session) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: session.accessToken),
      _storage.write(key: _refreshTokenKey, value: session.refreshToken),
      _storage.write(key: _expiresAtKey, value: session.expiresAt.toIso8601String()),
      _storage.write(key: _emailKey, value: session.email),
      _storage.write(key: _fullNameKey, value: session.fullName),
      _storage.write(key: _isDemoKey, value: session.isDemo.toString()),
    ]);
  }

  Future<AuthSession?> read() async {
    final values = await Future.wait([
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _refreshTokenKey),
      _storage.read(key: _expiresAtKey),
      _storage.read(key: _emailKey),
      _storage.read(key: _fullNameKey),
      _storage.read(key: _isDemoKey),
    ]);

    final accessToken = values[0];
    final refreshToken = values[1];
    if (accessToken == null || refreshToken == null) return null;

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.tryParse(values[2] ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      email: values[3] ?? '',
      fullName: values[4] ?? '',
      isDemo: values[5] == 'true',
    );
  }

  Future<void> clear() => _storage.deleteAll();
}
