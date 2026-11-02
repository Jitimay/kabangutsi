import 'package:dio/dio.dart';

import '../../core/env/env.dart';
import '../models/models.dart';

/// Thin dio wrapper for the REST API. Widgets never use it directly:
/// only repositories do. Every failure becomes an [ApiError].
class ApiClient {
  ApiClient(this.env, {Dio? dio})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: env.apiUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 120),
              contentType: Headers.jsonContentType,
            ));

  final Env env;
  final Dio dio;

  /// Absolute URL for a backend path such as `/v1/files/{id}`.
  String resolve(String url) => url.startsWith('http') ? url : '${env.apiUrl}$url';

  Future<Json> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get<Object?>(path, queryParameters: _clean(query)));

  Future<Json> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send(() => dio.post<Object?>(path, data: body, queryParameters: _clean(query)));

  Future<Json> patch(String path, {Object? body}) => _send(() => dio.patch<Object?>(path, data: body));

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) =>
      q == null ? null : (Map.of(q)..removeWhere((_, v) => v == null));

  Future<Json> _send(Future<Response<Object?>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      return data is Json ? data : <String, dynamic>{};
    } on DioException catch (e) {
      throw toApiError(e);
    }
  }

  static ApiError toApiError(DioException e) {
    final data = e.response?.data;
    final status = e.response?.statusCode;
    if (data is Json && data['code'] is String) return ApiError.fromJson(data, status: status);
    if (e.response == null) return ApiError.network;
    return ApiError(code: 'internal_error', message: e.message ?? 'HTTP $status', status: status);
  }
}
