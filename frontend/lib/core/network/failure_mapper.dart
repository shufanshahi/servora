import 'dart:io';

import 'package:dio/dio.dart';
import 'package:servora/core/error/app_failure.dart';

/// Converts any [DioException] into the single [AppFailure] type the UI understands.
///
/// The API's error envelope is
/// `{ "success": false, "error": { "code", "message", "details"? } }`. Responses
/// that are not in that shape (for example an HTML page from a proxy) are mapped
/// from the HTTP status alone.
AppFailure mapDioException(DioException exception) {
  final existing = exception.error;
  if (existing is AppFailure) return existing;

  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return const UnknownFailure();
    case DioExceptionType.badResponse:
      return _fromResponse(exception.response);
    case DioExceptionType.unknown:
      // dio wraps low-level socket failures as "unknown".
      if (exception.error is SocketException) return const NetworkFailure();
      return const UnknownFailure();
  }
}

AppFailure _fromResponse(Response<dynamic>? response) {
  final status = response?.statusCode ?? 0;
  final error = _errorBody(response?.data);
  final code = error?['code'] as String?;
  final message = error?['message'] as String?;

  if (status >= 500) return ServerFailure(code: code);

  switch (status) {
    case 401:
      // Wrong email or password has its own friendly server message; a missing or
      // expired token should show the standard "session expired" text instead.
      return UnauthenticatedFailure(
        code: code,
        message: code == 'INVALID_CREDENTIALS' ? message : null,
      );
    case 403:
      return ForbiddenFailure(code: code);
    case 404:
      return NotFoundFailure(code: code);
    case 409:
      return ConflictFailure(code: code ?? 'CONFLICT', message: message);
    case 422:
      return ValidationFailure(
        fieldErrors: _fieldErrors(error?['details']),
        message: null,
        code: code,
      );
    case 429:
      return RateLimitedFailure(code: code);
    default:
      return const UnknownFailure();
  }
}

Map<String, dynamic>? _errorBody(Object? data) {
  if (data is Map<String, dynamic>) {
    final error = data['error'];
    if (error is Map<String, dynamic>) return error;
  }
  return null;
}

Map<String, String> _fieldErrors(Object? details) {
  final result = <String, String>{};
  if (details is List) {
    for (final item in details) {
      if (item is Map<String, dynamic>) {
        final field = item['field'];
        final message = item['message'];
        if (field is String && message is String) {
          // Keep the first message per field.
          result.putIfAbsent(field, () => message);
        }
      }
    }
  }
  return result;
}
