import 'package:equatable/equatable.dart';

import 'json.dart';

/// `Error` schema of openapi.yaml. Also used for network failures
/// (`code: network_error`, not sent by the backend).
class ApiError extends Equatable implements Exception {
  const ApiError({required this.code, required this.message, this.details = const {}, this.status});

  factory ApiError.fromJson(Json j, {int? status}) => ApiError(
        code: j['code'] as String? ?? 'internal_error',
        message: j['message'] as String? ?? '',
        details: (j['details'] as Json?) ?? const {},
        status: status,
      );

  static const network = ApiError(code: 'network_error', message: 'Network error');

  final String code;
  final String message;
  final Json details;
  final int? status;

  @override
  List<Object?> get props => [code, message, details, status];

  @override
  String toString() => 'ApiError($status $code: $message)';
}
