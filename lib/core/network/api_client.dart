import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_repository.dart';
import '../auth/session.dart';
import '../config/app_config.dart';
import 'api_exception.dart';

/// Result of an API mutation request, preserving response HTTP status code.
class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.data,
    this.requestId,
  });

  final int statusCode;
  final Map<String, dynamic> data;
  final String? requestId;

  bool get isCreated => statusCode == 201;
  bool get isOk => statusCode == 200;
}

/// HTTP Client providing shared transport for Go REST API (`/v1/*`).
///
/// Complies with Stage 2 Client boundaries:
/// - Injects `Authorization: Bearer <token>` fetched dynamically per call.
/// - Injects `Accept: application/json`.
/// - Injects and echoes valid log-safe `X-Request-ID`.
/// - Strictly forbids `user_id` query parameters (Anti-IDOR).
/// - Enforces relative URI paths within the backend origin (anti-SSRF/token leakage).
/// - Session epoch & user identity fencing prevents cross-session refresh/logout/replay.
/// - Safe single-flight 401 token refresh retry (max 1 retry for safe reads).
/// - Safe error envelope parsing (`httpapi.APIErrorEnvelope`).
/// - Preserves user session on 403, 404, 5xx, or transient network timeouts (never logs out).
class ApiClient {
  ApiClient({
    required this.authRepository,
    http.Client? httpClient,
    String? baseUrl,
    this.sessionEpochReader,
    this.userIdReader,
    this.sessionTerminator,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? AppConfig.current.backendApiBaseUrl {
    // Ensure base URL ends with '/' for Uri.resolve
    if (!_baseUrl.endsWith('/')) {
      _baseUrl = '$_baseUrl/';
    }
  }

  final AuthRepository authRepository;
  final http.Client _httpClient;
  String _baseUrl;

  final int Function()? sessionEpochReader;
  final String? Function()? userIdReader;
  final Future<void> Function()? sessionTerminator;

  int _reqCounter = 0;

  String _generateRequestId() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final seq = ++_reqCounter;
    return 'req-$now-$seq';
  }

  bool _isSessionMismatch(int? expectedEpoch, String? expectedUserId) {
    if (sessionEpochReader == null && userIdReader == null) return false;
    final currentEpoch = sessionEpochReader?.call();
    final currentUserId = userIdReader?.call();
    if (expectedEpoch != null && currentEpoch != expectedEpoch) return true;
    if (expectedUserId != null && currentUserId != expectedUserId) return true;
    return false;
  }

  Uri buildUri(String path, [Map<String, String>? queryParams]) {
    if (queryParams != null && queryParams.containsKey('user_id')) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Sending user_id query parameter is strictly forbidden.',
      );
    }

    final trimmed = path.trim();
    // Path constraints: avoid bearer arbitrary origin internal calls (relative only)
    if (trimmed.startsWith('//') ||
        trimmed.contains('://') ||
        trimmed.contains(r'\') ||
        Uri.tryParse(trimmed)?.hasScheme == true) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Only relative API paths are allowed.',
      );
    }

    final cleanPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    final baseUri = Uri.parse(_baseUrl);
    final resolved = baseUri.resolve(cleanPath);

    if (resolved.scheme != baseUri.scheme ||
        resolved.host != baseUri.host ||
        resolved.port != baseUri.port) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Path cannot navigate outside the backend API origin.',
      );
    }

    if (queryParams != null && queryParams.isNotEmpty) {
      return resolved.replace(queryParameters: queryParams);
    }
    return resolved;
  }

  /// Sends an authenticated GET request to the given relative [path].
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
    String? customRequestId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return _sendWithRetry(
      method: 'GET',
      path: path,
      queryParams: queryParams,
      customRequestId: customRequestId,
      timeout: timeout,
    );
  }

  /// Sends an authenticated PUT mutation to the given relative [path] with [body].
  ///
  /// Safe mutation rules:
  /// - Sets `Content-Type: application/json; charset=utf-8`.
  /// - Serializes [body] as JSON string.
  /// - Preserves response status code (e.g. 201 Created vs 200 OK replay).
  /// - Does NOT auto-retry on 401 or network errors (no auto replay mutation).
  /// - Enforces session epoch and user identity fencing before request, after token, and after response.
  /// - Parses standard error envelope on 4xx/5xx with Request ID.
  Future<ApiResponse> put(
    String path, {
    required Map<String, dynamic> body,
    String? idempotencyKey,
    String? customRequestId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return _sendMutation(
      method: 'PUT',
      path: path,
      body: body,
      idempotencyKey: idempotencyKey,
      customRequestId: customRequestId,
      timeout: timeout,
    );
  }

  /// Sends an authenticated POST mutation to the given relative [path].
  ///
  /// Safe mutation rules:
  /// - If [body] is null, sends empty body (0 bytes) without Content-Type header.
  /// - Transmits `Idempotency-Key` header if provided.
  /// - Does NOT auto-retry on 401 or network errors (no auto replay mutation).
  /// - Preserves response status code (e.g. 201 Created vs 200 OK).
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
    String? customRequestId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return _sendMutation(
      method: 'POST',
      path: path,
      body: body,
      idempotencyKey: idempotencyKey,
      customRequestId: customRequestId,
      timeout: timeout,
    );
  }

  /// Sends an authenticated DELETE mutation to the given relative [path].
  ///
  /// Safe mutation rules:
  /// - If [body] is null, sends empty body (0 bytes).
  /// - Transmits `Idempotency-Key` header if provided.
  /// - Does NOT auto-retry on 401 or network errors (no auto replay mutation).
  /// - Preserves response status code (e.g. 200 OK for revoke).
  Future<ApiResponse> delete(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
    String? customRequestId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return _sendMutation(
      method: 'DELETE',
      path: path,
      body: body,
      idempotencyKey: idempotencyKey,
      customRequestId: customRequestId,
      timeout: timeout,
    );
  }

  Future<ApiResponse> _sendMutation({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? idempotencyKey,
    String? customRequestId,
    required Duration timeout,
  }) async {
    final uri = buildUri(path);
    final reqId = customRequestId ?? _generateRequestId();

    final opEpoch = sessionEpochReader?.call();
    final opUserId = userIdReader?.call();

    // Guard before starting request:
    if (_isSessionMismatch(opEpoch, opUserId)) {
      throw const ApiException(
        statusCode: 401,
        code: 'session_mismatch',
        message: 'Yêu cầu bị hủy do phiên làm việc đã thay đổi.',
      );
    }

    final token = await authRepository.getAccessToken();

    // Guard after acquiring token:
    if (_isSessionMismatch(opEpoch, opUserId)) {
      throw const ApiException(
        statusCode: 401,
        code: 'session_mismatch',
        message: 'Yêu cầu bị hủy do phiên làm việc đã thay đổi.',
      );
    }

    if (token == null || token.isEmpty) {
      throw ApiException(
        statusCode: 401,
        code: 'unauthorized',
        message: 'Yêu cầu xác thực. Vui lòng đăng nhập.',
        requestId: reqId,
      );
    }

    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'X-Request-ID': reqId,
    };

    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }

    Object? encodedBody;
    if (body != null) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
      encodedBody = jsonEncode(body);
    } else {
      // Empty body: transmit empty string (0 bytes) without Content-Type
      encodedBody = '';
    }

    final http.Response response;
    try {
      if (method == 'PUT') {
        response = await _httpClient
            .put(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
      } else if (method == 'POST') {
        response = await _httpClient
            .post(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
      } else if (method == 'DELETE') {
        response = await _httpClient
            .delete(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
      } else {
        throw UnsupportedError('Unsupported mutation method: $method');
      }
    } on http.ClientException catch (e) {
      if (_isSessionMismatch(opEpoch, opUserId)) {
        throw const ApiException(
          statusCode: 401,
          code: 'session_mismatch',
          message: 'Yêu cầu bị hủy do phiên làm việc đã thay đổi.',
        );
      }
      throw NetworkException(
        'Không thể kết nối đến máy chủ hoặc request bị chặn bởi chính sách CORS của trình duyệt.',
        cause: e,
      );
    } on TimeoutException catch (e) {
      if (_isSessionMismatch(opEpoch, opUserId)) {
        throw const ApiException(
          statusCode: 401,
          code: 'session_mismatch',
          message: 'Yêu cầu bị hủy do phiên làm việc đã thay đổi.',
        );
      }
      throw NetworkException(
        'Quá thời gian chờ phản hồi từ máy chủ. Vui lòng thử lại.',
        cause: e,
      );
    } catch (e) {
      if (_isSessionMismatch(opEpoch, opUserId)) {
        throw const ApiException(
          statusCode: 401,
          code: 'session_mismatch',
          message: 'Yêu cầu bị hủy do phiên làm việc đã thay đổi.',
        );
      }
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(
        'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
        cause: e,
      );
    }

    // Guard immediately after HTTP response:
    if (_isSessionMismatch(opEpoch, opUserId)) {
      throw const ApiException(
        statusCode: 401,
        code: 'session_mismatch',
        message: 'Phản hồi bị loại bỏ do phiên làm việc đã thay đổi.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return ApiResponse(
            statusCode: response.statusCode,
            data: decoded,
            requestId: response.headers['x-request-id'] ?? reqId,
          );
        }
        throw FormatException(
          'Expected JSON map but got ${decoded.runtimeType}',
        );
      } on FormatException {
        throw ApiException(
          statusCode: response.statusCode,
          code: 'invalid_response',
          message: 'Dữ liệu phản hồi từ máy chủ không hợp lệ.',
          requestId: response.headers['x-request-id'] ?? reqId,
        );
      }
    }

    // Handle 401 Unauthorized for mutations: NO auto retry mutation!
    if (response.statusCode == 401) {
      if (!_isSessionMismatch(opEpoch, opUserId)) {
        try {
          final activeUser = await authRepository.restoreSession();
          if (activeUser == null && !_isSessionMismatch(opEpoch, opUserId)) {
            await _terminateSession();
          }
        } catch (_) {}
      }
    }

    throw _parseErrorResponse(response, fallbackReqId: reqId);
  }

  Future<Map<String, dynamic>> _sendWithRetry({
    required String method,
    required String path,
    Map<String, String>? queryParams,
    String? customRequestId,
    required Duration timeout,
    bool isRetry = false,
    int? expectedEpoch,
    String? expectedUserId,
  }) async {
    final uri = buildUri(path, queryParams);
    final reqId = customRequestId ?? _generateRequestId();

    final opEpoch = expectedEpoch ?? sessionEpochReader?.call();
    final opUserId = expectedUserId ?? userIdReader?.call();

    // Guard before starting request:
    if (_isSessionMismatch(opEpoch, opUserId)) {
      throw const ApiException(
        statusCode: 401,
        code: 'session_mismatch',
        message: 'Yêu cầu bị hủy do phiên làm việc đã thay đổi.',
      );
    }

    final token = await authRepository.getAccessToken();

    // Guard after acquiring token:
    if (_isSessionMismatch(opEpoch, opUserId)) {
      throw const ApiException(
        statusCode: 401,
        code: 'session_mismatch',
        message: 'Yêu cầu bị hủy do phiên làm việc đã thay đổi.',
      );
    }

    if (token == null || token.isEmpty) {
      throw ApiException(
        statusCode: 401,
        code: 'unauthorized',
        message: 'Yêu cầu xác thực. Vui lòng đăng nhập.',
        requestId: reqId,
      );
    }

    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'X-Request-ID': reqId,
    };

    final http.Response response;
    try {
      if (method == 'GET') {
        response = await _httpClient
            .get(uri, headers: headers)
            .timeout(timeout);
      } else {
        throw UnsupportedError('Only GET is supported in current stage.');
      }
    } on http.ClientException catch (e) {
      if (_isSessionMismatch(opEpoch, opUserId)) {
        throw const ApiException(
          statusCode: 401,
          code: 'session_mismatch',
          message: 'Yêu cầu bị hủy do phiên làm việc đã thay đổi.',
        );
      }
      throw NetworkException(
        'Không thể kết nối đến máy chủ hoặc request bị chặn bởi chính sách CORS của trình duyệt.',
        cause: e,
      );
    } on TimeoutException catch (e) {
      if (_isSessionMismatch(opEpoch, opUserId)) {
        throw const ApiException(
          statusCode: 401,
          code: 'session_mismatch',
          message: 'Yêu cầu bị hủy do phiên làm việc đã thay đổi.',
        );
      }
      throw NetworkException(
        'Quá thời gian chờ phản hồi từ máy chủ. Vui lòng thử lại.',
        cause: e,
      );
    } catch (e) {
      if (_isSessionMismatch(opEpoch, opUserId)) {
        throw const ApiException(
          statusCode: 401,
          code: 'session_mismatch',
          message: 'Yêu cầu bị hủy do phiên làm việc đã thay đổi.',
        );
      }
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(
        'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
        cause: e,
      );
    }

    // Guard immediately after HTTP response:
    if (_isSessionMismatch(opEpoch, opUserId)) {
      throw const ApiException(
        statusCode: 401,
        code: 'session_mismatch',
        message: 'Phản hồi bị loại bỏ do phiên làm việc đã thay đổi.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw FormatException(
          'Expected JSON map but got ${decoded.runtimeType}',
        );
      } on FormatException {
        throw ApiException(
          statusCode: response.statusCode,
          code: 'invalid_response',
          message: 'Dữ liệu phản hồi từ máy chủ không hợp lệ.',
          requestId: response.headers['x-request-id'] ?? reqId,
        );
      }
    }

    // Handle 401 Unauthorized with bounded single-flight refresh retry (max 1 retry)
    if (response.statusCode == 401) {
      if (!isRetry) {
        // Guard before attempting refresh
        if (_isSessionMismatch(opEpoch, opUserId)) {
          throw const ApiException(
            statusCode: 401,
            code: 'session_mismatch',
            message: 'Không thực hiện refresh do phiên làm việc đã thay đổi.',
          );
        }

        String? refreshedToken;
        try {
          refreshedToken = await authRepository.refreshSession();
        } on AuthException catch (e) {
          // Check if session is STILL the same before acting on AuthException
          if (!_isSessionMismatch(opEpoch, opUserId)) {
            // Only confirm invalid if error code indicates invalid grant/refresh token
            final isConfirmedInvalid = {
              'invalid_grant',
              'refresh_token_not_found',
              'refresh_token_already_used',
            }.contains(e.code);

            if (isConfirmedInvalid) {
              await _terminateSession();
            }
          }
          throw _parseErrorResponse(response, fallbackReqId: reqId);
        } catch (_) {
          // Transient failure (network/timeout) -> preserve session, do NOT signOut
          throw _parseErrorResponse(response, fallbackReqId: reqId);
        }

        // Guard after refresh completes
        if (_isSessionMismatch(opEpoch, opUserId)) {
          throw const ApiException(
            statusCode: 401,
            code: 'session_mismatch',
            message: 'Không thực hiện replay do phiên làm việc đã thay đổi.',
          );
        }

        if (refreshedToken != null && refreshedToken.isNotEmpty) {
          return _sendWithRetry(
            method: method,
            path: path,
            queryParams: queryParams,
            customRequestId: customRequestId,
            timeout: timeout,
            isRetry: true,
            expectedEpoch: opEpoch,
            expectedUserId: opUserId,
          );
        } else {
          // Refresh returned null without error. Check if session was confirmed invalid
          if (!_isSessionMismatch(opEpoch, opUserId)) {
            final activeUser = await authRepository.restoreSession();
            if (activeUser == null && !_isSessionMismatch(opEpoch, opUserId)) {
              await _terminateSession();
            }
          }
        }
      } else {
        // Replay still returned 401: end session immediately ONLY if still the same session!
        if (!_isSessionMismatch(opEpoch, opUserId)) {
          await _terminateSession();
        }
      }
    }

    throw _parseErrorResponse(response, fallbackReqId: reqId);
  }

  Future<void> _terminateSession() async {
    if (sessionTerminator != null) {
      await sessionTerminator!();
    } else {
      await authRepository.signOut();
    }
  }

  ApiException _parseErrorResponse(
    http.Response response, {
    required String fallbackReqId,
  }) {
    String code = 'unknown_error';
    String message = 'Đã xảy ra sự cố (${response.statusCode}).';
    String? requestId = response.headers['x-request-id'] ?? fallbackReqId;

    try {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
          final err = decoded['error'] as Map;
          if (err['code'] != null) code = err['code'].toString();
          if (err['message'] != null) message = err['message'].toString();
          if (err['request_id'] != null) {
            requestId = err['request_id'].toString();
          }
        }
      }
    } catch (_) {
      // Body is not JSON
    }

    return ApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
      requestId: requestId,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  // Re-create ApiClient when sessionProvider changes (login/logout/user switch)
  ref.watch(sessionProvider);
  final httpClient = http.Client();
  ref.onDispose(() {
    httpClient.close();
  });

  return ApiClient(
    authRepository: authRepo,
    httpClient: httpClient,
    sessionEpochReader: () => ref.read(sessionProvider.notifier).sessionEpoch,
    userIdReader: () => ref.read(currentUserProvider)?.userId,
    sessionTerminator: () => ref.read(sessionProvider.notifier).signOut(),
  );
});
