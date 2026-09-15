import 'dart:convert';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromResponse(int statusCode, String responseBody) {
    var message = 'Sunucu isteği tamamlanamadı.';

    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final candidate = decoded['message'] ?? decoded['Message'] ?? decoded['title'];
        if (candidate != null && candidate.toString().trim().isNotEmpty) {
          message = candidate.toString();
        } else if (decoded['errors'] is Map) {
          final validationMessages = (decoded['errors'] as Map).values
              .expand((value) => value is List ? value : [value])
              .map((value) => value.toString());
          if (validationMessages.isNotEmpty) {
            message = validationMessages.join('\n');
          }
        }
      } else if (decoded is String && decoded.trim().isNotEmpty) {
        message = decoded;
      }
    } catch (_) {
      if (responseBody.trim().isNotEmpty) message = responseBody.trim();
    }

    return ApiException(message, statusCode: statusCode);
  }

  @override
  String toString() => message;
}
