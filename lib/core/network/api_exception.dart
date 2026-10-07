import 'package:flutter/foundation.dart';

/// Exception thrown when Go REST API returns a non-2xx response.
@immutable
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.requestId,
  });

  final int statusCode;
  final String code;
  final String message;
  final String? requestId;

  bool get isBadRequest => statusCode == 400;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isMethodNotAllowed => statusCode == 405;
  bool get isConflict => statusCode == 409;
  bool get isInternalError => statusCode >= 500;
  bool get isNotImplemented => statusCode == 501;
  bool get isServiceUnavailable => statusCode == 503;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, code: $code, message: $message, requestId: $requestId)';
}

/// Exception thrown on low-level network failures (connection refused, browser CORS block, offline).
class NetworkException implements Exception {
  const NetworkException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'NetworkException: $message';
}
