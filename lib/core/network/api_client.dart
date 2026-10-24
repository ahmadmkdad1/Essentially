import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Called when the API says the session is no longer usable
/// (expired token, suspended or banned account).
typedef SessionExpiredCallback = void Function(ApiException error);

/// Thin wrapper around Dio that attaches the bearer token and converts
/// every failure into an [ApiException].
class ApiClient {
  ApiClient({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        contentType: Headers.jsonContentType,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _token;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) {
          final apiError = ApiException.fromDio(error);
          final hadToken = error.requestOptions.headers['Authorization'] != null;
          if (hadToken && (apiError.isUnauthorized || apiError.isAccountBlocked)) {
            onSessionExpired?.call(apiError);
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  String? _token;
  SessionExpiredCallback? onSessionExpired;

  set token(String? value) => _token = value;
  bool get hasToken => _token != null;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<T>(path, queryParameters: _clean(query)));

  Future<T> post<T>(String path, {Object? body}) => _send(() => _dio.post<T>(path, data: body ?? const {}));

  Future<T> patch<T>(String path, {Object? body}) => _send(() => _dio.patch<T>(path, data: body ?? const {}));

  Future<T> delete<T>(String path) => _send(() => _dio.delete<T>(path));

  Future<T> _send<T>(Future<Response<T>> Function() call) async {
    try {
      final response = await call();
      return response.data as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return {
      for (final entry in query.entries)
        if (entry.value != null && entry.value.toString().isNotEmpty) entry.key: entry.value,
    };
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
