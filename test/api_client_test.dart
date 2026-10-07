import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/config/app_config.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/core/network/api_exception.dart';

import 'session_test.dart';

void main() {
  late FakeAuthRepository authRepo;

  setUp(() {
    authRepo = FakeAuthRepository();
    AppConfig.currentForTesting = const AppConfig(
      backendApiBaseUrl: 'http://localhost/v1/',
      supabaseUrl: 'http://localhost',
      supabaseAnonKey: 'anon-key',
      environment: Environment.development,
    );
  });

  tearDown(() {
    authRepo.dispose();
    AppConfig.currentForTesting = null;
  });

  group('ApiClient URI & Anti-IDOR', () {
    test(
      'normalizes baseUrl ending with slash and builds relative URIs correctly',
      () {
        final client = ApiClient(
          authRepository: authRepo,
          baseUrl: 'http://localhost/v1',
        );

        final uri1 = client.buildUri('gateways');
        expect(uri1.toString(), 'http://localhost/v1/gateways');

        final uri2 = client.buildUri('/gateways/gw-1/sensors');
        expect(uri2.toString(), 'http://localhost/v1/gateways/gw-1/sensors');
      },
    );

    test(
      'strictly forbids user_id query parameter and throws 400 invalid_request',
      () {
        final client = ApiClient(
          authRepository: authRepo,
          baseUrl: 'http://localhost/v1/',
        );

        expect(
          () => client.buildUri('gateways', {'user_id': '123'}),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.code, 'code', 'invalid_request'),
          ),
        );
      },
    );

    test('strictly forbids absolute URIs or external origins to prevent token leakage', () {
      final client = ApiClient(
        authRepository: authRepo,
        baseUrl: 'http://localhost/v1/',
      );

      for (final maliciousPath in [
        'https://evil.com/gateways',
        'http://evil.com/gateways',
        '//evil.com/gateways',
        r'\evil.com\gateways',
        'ftp://evil.com/file',
      ]) {
        expect(
          () => client.buildUri(maliciousPath),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.code, 'code', 'invalid_request'),
          ),
        );
      }
    });
  });

  group('ApiClient GET Requests & Headers', () {
    test('injects Authorization, Accept, and X-Request-ID headers', () async {
      await authRepo.signInWithPassword(
        email: 'test@example.com',
        password: 'pwd',
      );

      late http.Request capturedRequest;
      final mockHttp = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'items': <dynamic>[]}),
          200,
          headers: {
            'content-type': 'application/json',
            'x-request-id': 'resp-id-1',
          },
        );
      });

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );

      final res = await client.get('gateways');
      expect(res, {'items': <dynamic>[]});

      expect(capturedRequest.headers['Authorization'], 'Bearer mock_jwt_token');
      expect(capturedRequest.headers['Accept'], 'application/json');
      expect(capturedRequest.headers['X-Request-ID'], isNotNull);
      expect(capturedRequest.headers['X-Request-ID'], startsWith('req-'));
    });

    test('throws 401 ApiException if token is null or empty', () async {
      // User is not signed in
      final mockHttp = MockClient((request) async => http.Response('{}', 200));
      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );

      expect(
        () => client.get('gateways'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.code, 'code', 'unauthorized'),
        ),
      );
    });

    test('parses standard error envelope on 4xx/5xx', () async {
      await authRepo.signInWithPassword(
        email: 'test@example.com',
        password: 'pwd',
      );

      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'not_found',
              'message': 'resource not found',
              'request_id': 'err-trace-123',
            },
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );

      expect(
        () => client.get('gateways/gw-unknown/sensors'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', 'not_found')
              .having((e) => e.message, 'message', 'resource not found')
              .having((e) => e.requestId, 'requestId', 'err-trace-123'),
        ),
      );
    });

    test(
      'preserves session on 403, 404, 500, 503 without signing out',
      () async {
        await authRepo.signInWithPassword(
          email: 'test@example.com',
          password: 'pwd',
        );

        for (final code in [403, 404, 500, 503]) {
          final mockHttp = MockClient((request) async {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'error_$code',
                  'message': 'Error $code occurred',
                  'request_id': 'req-$code',
                },
              }),
              code,
              headers: {'content-type': 'application/json'},
            );
          });

          final client = ApiClient(
            authRepository: authRepo,
            httpClient: mockHttp,
            baseUrl: 'http://localhost/v1/',
          );

          await expectLater(
            () => client.get('gateways'),
            throwsA(
              isA<ApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                code,
              ),
            ),
          );

          // Session must be preserved
          expect(await authRepo.restoreSession(), isNotNull);
        }
      },
    );

    test('wraps low-level transport errors in NetworkException', () async {
      await authRepo.signInWithPassword(
        email: 'test@example.com',
        password: 'pwd',
      );

      final mockHttp = MockClient((request) async {
        throw http.ClientException('XMLHttpRequest error');
      });

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );

      expect(
        () => client.get('gateways'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('CORS'),
          ),
        ),
      );
    });
  });

  group('ApiClient 401 Single-Flight Refresh Retry', () {
    test('retries GET once on 401 when token refresh succeeds', () async {
      await authRepo.signInWithPassword(
        email: 'test@example.com',
        password: 'pwd',
      );

      int attempts = 0;
      final mockHttp = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          // First attempt returns 401
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'unauthorized',
                'message': 'authentication required',
                'request_id': 'req-401',
              },
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        // Second attempt after refresh succeeds with 200
        return http.Response(
          jsonEncode({
            'items': [
              {
                'gateway_id': 'gw-01',
                'name': 'Gateway 01',
                'description': null,
                'role': 'owner',
                'created_at': null,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );

      final res = await client.get('gateways');
      expect(attempts, 2);
      expect((res['items'] as List).length, 1);
    });

    test('bounded retry: if retry still returns 401, throws ApiException without infinite loop', () async {
      await authRepo.signInWithPassword(
        email: 'test@example.com',
        password: 'pwd',
      );

      int attempts = 0;
      final mockHttp = MockClient((request) async {
        attempts++;
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'unauthorized',
              'message': 'token invalid',
              'request_id': 'req-401-loop',
            },
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );

      await expectLater(
        () => client.get('gateways'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.code, 'code', 'unauthorized'),
        ),
      );

      // Exactly 2 attempts (1 initial + 1 bounded retry)
      expect(attempts, 2);
      // Replay 401 must end session
      expect(await authRepo.restoreSession(), isNull);
    });

    test(
      'confirmed invalid on 401 refresh calls signOut and ends session',
      () async {
        await authRepo.signInWithPassword(
          email: 'test@example.com',
          password: 'pwd',
        );
        authRepo.throwInvalidOnRefresh = true;

        final mockHttp = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'unauthorized',
                'message': 'token expired',
                'request_id': 'req-401-inv',
              },
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = ApiClient(
          authRepository: authRepo,
          httpClient: mockHttp,
          baseUrl: 'http://localhost/v1/',
        );

        await expectLater(
          () => client.get('gateways'),
          throwsA(isA<ApiException>()),
        );

        expect(authRepo.refreshCallCount, 1);
        expect(await authRepo.restoreSession(), isNull);
      },
    );

    test(
      'transient error on 401 refresh preserves session without signOut',
      () async {
        await authRepo.signInWithPassword(
          email: 'test@example.com',
          password: 'pwd',
        );
        authRepo.throwTransientOnRefresh = true;

        final mockHttp = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'unauthorized',
                'message': 'temporary auth error',
                'request_id': 'req-401-trans',
              },
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = ApiClient(
          authRepository: authRepo,
          httpClient: mockHttp,
          baseUrl: 'http://localhost/v1/',
        );

        await expectLater(
          () => client.get('gateways'),
          throwsA(isA<ApiException>()),
        );

        expect(authRepo.refreshCallCount, 1);
        // Session must be preserved on transient refresh failure
        expect(await authRepo.restoreSession(), isNotNull);
      },
    );
  });

  group('ApiClient Session Epoch & Identity Fencing', () {
    test('delayed 401 after logout must NOT refresh token and must NOT call sessionTerminator', () async {
      int currentEpoch = 1;
      String? currentUserId = 'user-A';
      bool terminatorCalled = false;

      final completer = Completer<http.Response>();
      final mockHttp = MockClient((request) async => completer.future);

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
        sessionEpochReader: () => currentEpoch,
        userIdReader: () => currentUserId,
        sessionTerminator: () async {
          terminatorCalled = true;
        },
      );

      // Sign in user-A
      await authRepo.signInWithPassword(
        email: 'userA@example.com',
        password: 'pwd',
      );

      // User A starts GET /gateways
      final requestFuture = client.get('gateways');
      final expectation = expectLater(
        requestFuture,
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'session_mismatch'),
        ),
      );

      // While request is in-flight, User A logs out!
      currentEpoch = 2;
      currentUserId = null;
      await authRepo.signOut();

      // Now delayed 401 response arrives for User A
      completer.complete(
        http.Response(
          jsonEncode({
            'error': {
              'code': 'unauthorized',
              'message': 'token expired',
              'request_id': 'req-stale-401',
            },
          }),
          401,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectation;

      // Must NOT attempt refresh
      expect(authRepo.refreshCallCount, 0);
      // Must NOT call terminator
      expect(terminatorCalled, isFalse);
    });

    test('delayed 401 from user A after user B signs in must NOT refresh or logout user B', () async {
      int currentEpoch = 1;
      String? currentUserId = 'user-A';
      bool terminatorCalled = false;

      final completer = Completer<http.Response>();
      final mockHttp = MockClient((request) async => completer.future);

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
        sessionEpochReader: () => currentEpoch,
        userIdReader: () => currentUserId,
        sessionTerminator: () async {
          terminatorCalled = true;
        },
      );

      // Sign in user-A
      await authRepo.signInWithPassword(
        email: 'userA@example.com',
        password: 'pwd',
      );

      // User A starts request
      final requestFuture = client.get('gateways');
      final expectation = expectLater(
        requestFuture,
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'session_mismatch'),
        ),
      );

      // While in-flight, user A signs out and user B signs in!
      await authRepo.signOut();
      await authRepo.signInWithPassword(
        email: 'userB@example.com',
        password: 'pwd',
      );
      currentEpoch = 3;
      currentUserId = 'user-B';

      // Delayed 401 for user A arrives
      completer.complete(
        http.Response(
          jsonEncode({
            'error': {
              'code': 'unauthorized',
              'message': 'user A token invalid',
              'request_id': 'req-user-A-401',
            },
          }),
          401,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectation;

      // User B must NOT be refreshed
      expect(authRepo.refreshCallCount, 0);
      // User B must NOT be logged out
      expect(terminatorCalled, isFalse);
      expect(await authRepo.restoreSession(), isNotNull);
      expect((await authRepo.restoreSession())?.email, 'userB@example.com');
    });

    test('delayed 200 response from user A after user B signs in is safely discarded', () async {
      int currentEpoch = 1;
      String? currentUserId = 'user-A';

      final completer = Completer<http.Response>();
      final mockHttp = MockClient((request) async => completer.future);

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
        sessionEpochReader: () => currentEpoch,
        userIdReader: () => currentUserId,
      );

      await authRepo.signInWithPassword(
        email: 'userA@example.com',
        password: 'pwd',
      );

      final requestFuture = client.get('gateways');
      final expectation = expectLater(
        requestFuture,
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'session_mismatch'),
        ),
      );

      // Session switches to user B
      currentEpoch = 2;
      currentUserId = 'user-B';

      // Delayed 200 arrives with User A's data
      completer.complete(
        http.Response(
          jsonEncode({
            'items': [
              {
                'gateway_id': 'gw-user-A',
                'name': 'User A Gateway',
                'description': null,
                'role': 'owner',
                'created_at': null,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectation;
    });

    test('apiClientProvider creates fresh client and closes http.Client on session change', () async {
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepo)],
      );
      addTearDown(container.dispose);

      // Read client for unauthenticated state
      final client1 = container.read(apiClientProvider);
      expect(client1, isNotNull);

      // Sign in user-A -> session changes
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'uA',
              name: 'User A',
              email: 'a@example.com',
            ),
          );

      // A fresh ApiClient is created for the new session
      final client2 = container.read(apiClientProvider);
      expect(identical(client1, client2), isFalse);
    });
  });
}
