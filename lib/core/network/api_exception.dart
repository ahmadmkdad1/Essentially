import 'package:dio/dio.dart';

/// A normalised error coming from the API or the network layer.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// Machine readable code sent by the API (e.g. `ACCOUNT_SUSPENDED`).
  final String? code;

  bool get isUnauthorized => statusCode == 401;
  bool get isAccountBlocked => code == 'ACCOUNT_SUSPENDED' || code == 'ACCOUNT_BANNED';

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      final offline =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown;
      return ApiException(
        offline
            ? 'Cannot reach the server. Check your connection and that the API is running.'
            : 'The request timed out. Please try again.',
      );
    }

    final data = response.data;
    String message = 'Something went wrong (${response.statusCode}).';
    String? code;
    if (data is Map) {
      final raw = data['message'];
      if (raw is List && raw.isNotEmpty) {
        message = raw.map((m) => _capitalise(m.toString())).join('\n');
      } else if (raw is String && raw.isNotEmpty) {
        message = _capitalise(raw);
      }
      code = data['code']?.toString();
    }
    return ApiException(message, statusCode: response.statusCode, code: code);
  }

  static String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  String toString() => message;
}

/// Human readable message for any error thrown in the app.
String describeError(Object error) {
  if (error is ApiException) return error.message;
  if (error is DioException) return ApiException.fromDio(error).message;
  return 'Unexpected error: $error';
}
