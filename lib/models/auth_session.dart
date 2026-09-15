import 'dart:convert';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.email,
    required this.fullName,
    this.isDemo = false,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String email;
  final String fullName;
  final bool isDemo;

  factory AuthSession.demo() {
    return AuthSession(
      accessToken: 'demo-access-token',
      refreshToken: 'demo-refresh-token',
      expiresAt: DateTime.utc(2100),
      email: 'demo@smartparking.app',
      fullName: 'Demo Sürücü',
      isDemo: true,
    );
  }

  bool get expiresSoon =>
      expiresAt.isBefore(DateTime.now().toUtc().add(const Duration(minutes: 1)));

  Set<String> get roles {
    if (isDemo) return const {'User'};
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return const {};
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) return const {};
      final roleValue = payload['role'] ??
          payload['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'];
      if (roleValue is List) {
        return roleValue.map((role) => role.toString()).toSet();
      }
      if (roleValue == null) return const {};
      return {roleValue.toString()};
    } catch (_) {
      return const {};
    }
  }

  bool get isAdmin => roles.any(
        (role) => role.toLowerCase() == 'admin',
      );

  factory AuthSession.fromApi(
    Map<String, dynamic> json, {
    required String email,
    String fullName = '',
  }) {
    final accessToken = _readString(json, 'accessToken', 'AccessToken');
    final refreshToken = _readString(json, 'refreshToken', 'RefreshToken');
    final expiresAtText = _readString(json, 'expiresAt', 'ExpiresAt');

    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw const FormatException('API geçerli bir oturum bilgisi döndürmedi.');
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.tryParse(expiresAtText)?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(hours: 1)),
      email: email,
      fullName: fullName,
      isDemo: false,
    );
  }

  AuthSession withIdentity({String? email, String? fullName}) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      isDemo: isDemo,
    );
  }

  static String _readString(
    Map<String, dynamic> json,
    String camelCase,
    String pascalCase,
  ) {
    return (json[camelCase] ?? json[pascalCase] ?? '').toString();
  }
}
