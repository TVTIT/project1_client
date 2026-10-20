import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/core/network/link_header.dart';

void main() {
  group('SafeLinkParser & Validator', () {
    final baseUri = Uri.parse('http://localhost/v1/');
    final requestUri = Uri.parse(
      'http://localhost/v1/digital-twins?type=Gateway&limit=50',
    );

    test('extracts URI from standard RFC 8288 next relation with quoted and unquoted rel', () {
      expect(
        SafeLinkParser.extractNextUri(
          '</v1/digital-twins?cursor=v1.abc>; rel="next"',
        ),
        '/v1/digital-twins?cursor=v1.abc',
      );

      expect(
        SafeLinkParser.extractNextUri(
          '</v1/digital-twins?cursor=v1.abc>; rel=next',
        ),
        '/v1/digital-twins?cursor=v1.abc',
      );

      // Multiple links in single header
      const multi =
          '<http://localhost/v1/prev>; rel="prev", </v1/digital-twins?cursor=v1.abc>; rel="next"';
      expect(
        SafeLinkParser.extractNextUri(multi),
        '/v1/digital-twins?cursor=v1.abc',
      );
    });

    test('returns null when header is null or does not contain rel="next"', () {
      expect(SafeLinkParser.extractNextUri(null), isNull);
      expect(SafeLinkParser.extractNextUri(''), isNull);
      expect(
        SafeLinkParser.extractNextUri('<http://localhost/v1/prev>; rel="prev"'),
        isNull,
      );
    });

    test('resolves relative next URI against actual request URI preserving scheme, host, port, /v1', () {
      const header =
          '</v1/digital-twins?type=Gateway&limit=50&cursor=v1.nextCursor>; rel="next"';
      final resolved = SafeLinkParser.resolveAndValidateNextLink(
        rawLinkHeader: header,
        requestUri: requestUri,
        baseUri: baseUri,
        expectedPath: '/v1/digital-twins',
        allowedQueryParams: {'type', 'gateway_id', 'limit', 'format', 'cursor'},
      );

      expect(resolved, isNotNull);
      expect(
        resolved.toString(),
        'http://localhost/v1/digital-twins?type=Gateway&limit=50&cursor=v1.nextCursor',
      );
      expect(resolved!.queryParameters['cursor'], 'v1.nextCursor');
    });

    test('rejects external origin links', () {
      const evilHeader =
          '<http://evil.com/v1/digital-twins?cursor=v1.evil>; rel="next"';
      expect(
        () => SafeLinkParser.resolveAndValidateNextLink(
          rawLinkHeader: evilHeader,
          requestUri: requestUri,
          baseUri: baseUri,
          expectedPath: '/v1/digital-twins',
          allowedQueryParams: {'type', 'cursor'},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_link_header'),
        ),
      );
    });

    test('rejects links escaping /v1 prefix', () {
      const evilHeader = '</auth/v1/users>; rel="next"';
      expect(
        () => SafeLinkParser.resolveAndValidateNextLink(
          rawLinkHeader: evilHeader,
          requestUri: requestUri,
          baseUri: baseUri,
          expectedPath: '/v1/digital-twins',
          allowedQueryParams: {'cursor'},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_link_header'),
        ),
      );
    });

    test('rejects links with user credentials or fragments', () {
      for (final malicious in [
        '<http://user:pass@localhost/v1/digital-twins?cursor=abc>; rel="next"',
        '</v1/digital-twins?cursor=abc#fragment>; rel="next"',
      ]) {
        expect(
          () => SafeLinkParser.resolveAndValidateNextLink(
            rawLinkHeader: malicious,
            requestUri: requestUri,
            baseUri: baseUri,
            expectedPath: '/v1/digital-twins',
            allowedQueryParams: {'cursor'},
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.code, 'code', 'invalid_link_header'),
          ),
        );
      }
    });

    test('rejects links containing user_id (anti-IDOR violation)', () {
      const idorLink =
          '</v1/digital-twins?cursor=abc&user_id=target-uuid>; rel="next"';
      expect(
        () => SafeLinkParser.resolveAndValidateNextLink(
          rawLinkHeader: idorLink,
          requestUri: requestUri,
          baseUri: baseUri,
          expectedPath: '/v1/digital-twins',
          allowedQueryParams: {'cursor', 'user_id'},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_link_header'),
        ),
      );
    });

    test('rejects unexpected paths or query parameters not in allowlist', () {
      const unexpectedQueryLink =
          '</v1/digital-twins?cursor=abc&unknown_param=val>; rel="next"';
      expect(
        () => SafeLinkParser.resolveAndValidateNextLink(
          rawLinkHeader: unexpectedQueryLink,
          requestUri: requestUri,
          baseUri: baseUri,
          expectedPath: '/v1/digital-twins',
          allowedQueryParams: {'cursor'},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_link_header'),
        ),
      );
    });

    test('rejects duplicate query parameter ambiguity', () {
      const dupLink = '</v1/digital-twins?cursor=abc&cursor=def>; rel="next"';
      expect(
        () => SafeLinkParser.resolveAndValidateNextLink(
          rawLinkHeader: dupLink,
          requestUri: requestUri,
          baseUri: baseUri,
          expectedPath: '/v1/digital-twins',
          allowedQueryParams: {'cursor'},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_link_header'),
        ),
      );
    });

    test('rejects conflicting multiple rel="next" links (duplicate next relation ambiguity)', () {
      const conflicting =
          '</v1/digital-twins?cursor=a>; rel="next", </v1/digital-twins?cursor=b>; rel="next"';
      expect(
        () => SafeLinkParser.resolveAndValidateNextLink(
          rawLinkHeader: conflicting,
          requestUri: requestUri,
          baseUri: baseUri,
          expectedPath: '/v1/digital-twins',
          allowedQueryParams: {'cursor'},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_link_header'),
        ),
      );
    });
  });
}
