import 'api_exception.dart';

/// Robust RFC 8288 Link header parser and validator for API pagination.
///
/// Complies with security requirements:
/// - Extracts next relation (`rel="next"` or `rel=next`) case-insensitively.
/// - Resolves relative URI against the actual API request URI.
/// - Enforces exact same-origin matching against the backend API base URI.
/// - Enforces the API path prefix (e.g. `/v1/...`) and matches the expected endpoint.
/// - Forbids credentials (`userInfo`), fragments (`#...`), and `user_id` query params (anti-IDOR).
/// - Forbids duplicate query parameters to prevent parameter pollution.
/// - Validates query parameters against a strict endpoint allowlist.
abstract final class SafeLinkParser {
  /// Extracts the target URI string for the relation `rel="next"` from a raw Link header.
  ///
  /// Returns `null` if the header is null, empty, or contains no `next` relation.
  static String? extractNextUri(String? rawLinkHeader) {
    if (rawLinkHeader == null || rawLinkHeader.trim().isEmpty) {
      return null;
    }

    // A Link header may contain multiple comma-separated entries:
    // <URI>; rel="prev", <URI>; rel="next"
    final entries = _splitLinkHeader(rawLinkHeader);
    String? foundNextUri;
    for (final entry in entries) {
      final match = _parseSingleLinkEntry(entry);
      if (match != null && match.rel.toLowerCase() == 'next') {
        if (foundNextUri != null && foundNextUri != match.uri) {
          throw const ApiException(
            statusCode: 400,
            code: 'invalid_link_header',
            message: 'Header Link chứa nhiều quan hệ next xung đột.',
          );
        }
        foundNextUri = match.uri;
      }
    }
    return foundNextUri;
  }

  /// Resolves and validates a next link URI against the actual request URI and allowlist.
  ///
  /// Throws [ApiException] with code `invalid_link_header` if the link is invalid,
  /// external, escapes the `/v1/` prefix, contains credentials, fragments, `user_id`,
  /// duplicate query keys, or unapproved query parameters.
  static Uri? resolveAndValidateNextLink({
    required String? rawLinkHeader,
    required Uri requestUri,
    required Uri baseUri,
    required String expectedPath,
    Set<String>? allowedQueryParams,
  }) {
    final nextUriStr = extractNextUri(rawLinkHeader);
    if (nextUriStr == null) {
      return null;
    }

    final parsedTarget = Uri.tryParse(nextUriStr.trim());
    if (parsedTarget == null) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_link_header',
        message: 'Con trỏ phân trang chứa URI không hợp lệ.',
      );
    }

    // Resolve relative against the actual request URI
    final resolved = requestUri.resolveUri(parsedTarget);

    // 1. Enforce same origin (scheme, host, port)
    if (resolved.scheme != baseUri.scheme ||
        resolved.host != baseUri.host ||
        resolved.port != baseUri.port) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_link_header',
        message:
            'Link phân trang không được chuyển hướng ra ngoài origin của API.',
      );
    }

    // 2. Forbid credentials in URI
    if (resolved.userInfo.isNotEmpty) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_link_header',
        message:
            'Link phân trang không được chứa thông tin xác thực người dùng.',
      );
    }

    // 3. Forbid fragments (#...)
    if (resolved.fragment.isNotEmpty) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_link_header',
        message: 'Link phân trang không được chứa fragment.',
      );
    }

    // 4. Enforce /v1/ prefix and expected endpoint path
    final cleanExpectedPath = expectedPath.startsWith('/')
        ? expectedPath
        : '/$expectedPath';
    if (resolved.path != cleanExpectedPath) {
      throw ApiException(
        statusCode: 400,
        code: 'invalid_link_header',
        message:
            'Link phân trang chuyển hướng sai endpoint (kỳ vọng: $cleanExpectedPath, thực tế: ${resolved.path}).',
      );
    }

    // 5. Anti-IDOR: strictly forbid user_id in query parameters
    final queryParamsAll = resolved.queryParametersAll;
    if (queryParamsAll.containsKey('user_id')) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_link_header',
        message:
            'Link phân trang không được chứa tham số user_id (chống IDOR).',
      );
    }

    // 6. Forbid duplicate query parameters to prevent parameter pollution
    for (final entry in queryParamsAll.entries) {
      if (entry.value.length > 1) {
        throw ApiException(
          statusCode: 400,
          code: 'invalid_link_header',
          message:
              'Link phân trang chứa tham số trùng lặp không an toàn: "${entry.key}".',
        );
      }
    }

    // 7. Enforce allowed query parameter allowlist if supplied
    if (allowedQueryParams != null) {
      for (final key in queryParamsAll.keys) {
        if (!allowedQueryParams.contains(key)) {
          throw ApiException(
            statusCode: 400,
            code: 'invalid_link_header',
            message:
                'Link phân trang chứa tham số không nằm trong danh mục cho phép: "$key".',
          );
        }
      }
    }

    return resolved;
  }

  static List<String> _splitLinkHeader(String header) {
    final entries = <String>[];
    var inQuotes = false;
    var start = 0;

    for (var i = 0; i < header.length; i++) {
      final char = header[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        entries.add(header.substring(start, i).trim());
        start = i + 1;
      }
    }
    if (start < header.length) {
      final rem = header.substring(start).trim();
      if (rem.isNotEmpty) {
        entries.add(rem);
      }
    }
    return entries;
  }

  static _LinkEntry? _parseSingleLinkEntry(String entry) {
    final uriStart = entry.indexOf('<');
    final uriEnd = entry.indexOf('>');
    if (uriStart == -1 || uriEnd == -1 || uriEnd <= uriStart) {
      return null;
    }

    final uri = entry.substring(uriStart + 1, uriEnd).trim();
    final remainder = entry.substring(uriEnd + 1);

    // Parse parameters e.g. ; rel="next"
    final params = remainder.split(';');
    String? rel;
    for (final param in params) {
      final trimmed = param.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq != -1) {
        final key = trimmed.substring(0, eq).trim().toLowerCase();
        var val = trimmed.substring(eq + 1).trim();
        if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
          val = val.substring(1, val.length - 1);
        }
        if (key == 'rel') {
          rel = val;
        }
      }
    }

    if (rel != null) {
      return _LinkEntry(uri: uri, rel: rel);
    }
    return null;
  }
}

class _LinkEntry {
  const _LinkEntry({required this.uri, required this.rel});
  final String uri;
  final String rel;
}
