import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/auth/auth_repository.dart';
import 'package:kite/core/auth/session.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

http.Response sessionResponse(String id, {int lifetime = 3600}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + lifetime,
          }),
        ),
      )
      .replaceAll('=', '');
  return http.Response(
    jsonEncode({
      'access_token': 'e30.$payload.sig',
      'token_type': 'bearer',
      'expires_in': lifetime,
      'refresh_token': 'synthetic-refresh',
      'user': {
        'id': id,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': '$id@example.com',
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  late supa.SupabaseClient sdk;
  late SupabaseAuthRepository repo;
  final events = <SessionUser?>[];
  void setup(Future<http.Response> Function(http.Request) handler) {
    events.clear();
    sdk = supa.SupabaseClient(
      'http://localhost',
      'sb_publishable_synthetic',
      httpClient: MockClient(handler),
      authOptions: const supa.AuthClientOptions(autoRefreshToken: false),
    );
    repo = SupabaseAuthRepository(client: sdk);
    final sub = repo.authStateChanges.listen(events.add);
    addTearDown(() async {
      await sub.cancel();
      repo.dispose();
      await sdk.dispose();
    });
  }

  test('SDK late login never publishes canceled user, including before response future returns', () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    setup((req) async {
      if (req.url.path.endsWith('/token')) {
        started.complete();
        return response.future;
      }
      return http.Response('', 204);
    });
    final login = repo.signInWithPassword(
      email: 'A@example.com',
      password: 'synthetic',
    );
    final rejected = expectLater(login, throwsA(isA<AuthException>()));
    await started.future;
    final logout = repo.signOut();
    expect(await repo.getAccessToken(), isNull);
    response.complete(sessionResponse('A'));
    await rejected;
    await logout;
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<SessionUser>(), isEmpty);
    expect(sdk.auth.currentSession, isNull);
  });

  test('A logout B serializes cleanup before B and never nukes B', () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    var calls = 0;
    setup((req) async {
      if (req.url.path.endsWith('/token')) {
        if (++calls == 1) {
          started.complete();
          return response.future;
        }
        return sessionResponse('B');
      }
      return http.Response('', 204);
    });
    final a = repo.signInWithPassword(
      email: 'A@example.com',
      password: 'synthetic',
    );
    final rejected = expectLater(a, throwsA(isA<AuthException>()));
    await started.future;
    final logout = repo.signOut();
    final b = repo.signInWithPassword(
      email: 'B@example.com',
      password: 'synthetic',
    );
    response.complete(sessionResponse('A'));
    await rejected;
    await logout;
    expect((await b).userId, 'B');
    await Future<void>.delayed(Duration.zero);
    expect(sdk.auth.currentUser?.id, 'B');
    expect(events.whereType<SessionUser>().map((e) => e.userId), ['B']);
    expect(await repo.getAccessToken(), isNotNull);
  });

  test(
    'dispose while login pending suppresses stream and clears late SDK session',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      setup((req) async {
        if (req.url.path.endsWith('/token')) {
          started.complete();
          return response.future;
        }
        return http.Response('', 204);
      });
      final login = repo.signInWithPassword(
        email: 'A@example.com',
        password: 'synthetic',
      );
      final rejected = expectLater(login, throwsA(isA<AuthException>()));
      await started.future;
      repo.dispose();
      response.complete(sessionResponse('A'));
      await rejected;
      expect(sdk.auth.currentSession, isNull);
      expect(await repo.getAccessToken(), isNull);
      expect(events, isEmpty);
    },
  );

  test('expiring real SDK session refreshes once for concurrent calls; invalid grant clears', () async {
    var refreshes = 0;
    setup((req) async {
      if (req.url.queryParameters['grant_type'] == 'password') {
        return sessionResponse('A', lifetime: 5);
      }
      if (req.url.queryParameters['grant_type'] == 'refresh_token') {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response(
          jsonEncode({
            'error_code': 'invalid_grant',
            'msg': 'Invalid refresh token',
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('', 204);
    });
    await repo.signInWithPassword(
      email: 'A@example.com',
      password: 'synthetic',
    );
    await Future<void>.delayed(Duration.zero);
    expect(sdk.auth.currentSession, isNotNull);
    expect(await Future.wait([repo.getAccessToken(), repo.getAccessToken()]), [
      null,
      null,
    ]);
    expect(refreshes, 1);
    expect(sdk.auth.currentSession, isNull);
  });

  for (final action in ['logout', 'dispose', 'identity']) {
    test(
      'refresh late response after $action returns no stale token',
      () async {
        final started = Completer<void>();
        final response = Completer<http.Response>();
        setup((req) async {
          if (req.url.queryParameters['grant_type'] == 'password') {
            return sessionResponse('A', lifetime: 5);
          }
          if (req.url.queryParameters['grant_type'] == 'refresh_token') {
            started.complete();
            return response.future;
          }
          return http.Response('', 204);
        });
        await repo.signInWithPassword(
          email: 'A@example.com',
          password: 'synthetic',
        );
        await Future<void>.delayed(Duration.zero);
        final token = repo.getAccessToken();
        await started.future;
        Future<void>? logout;
        if (action == 'logout') logout = repo.signOut();
        if (action == 'dispose') repo.dispose();
        response.complete(sessionResponse(action == 'identity' ? 'B' : 'A'));
        expect(await token, isNull);
        if (logout != null) await logout;
        expect(sdk.auth.currentSession, isNull);
      },
    );
  }

  test('successful single flight uses current SDK token; transient refresh retains session', () async {
    var refreshes = 0;
    var fail = false;
    setup((req) async {
      if (req.url.queryParameters['grant_type'] == 'password') {
        return sessionResponse('A', lifetime: 5);
      }
      if (req.url.queryParameters['grant_type'] == 'refresh_token') {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (fail) throw http.ClientException('synthetic offline');
        return sessionResponse('A', lifetime: 5);
      }
      return http.Response('', 204);
    });
    await repo.signInWithPassword(
      email: 'A@example.com',
      password: 'synthetic',
    );
    await Future<void>.delayed(Duration.zero);
    final tokens = await Future.wait([
      repo.getAccessToken(),
      repo.getAccessToken(),
    ]);
    expect(refreshes, 1);
    expect(tokens, [
      sdk.auth.currentSession!.accessToken,
      sdk.auth.currentSession!.accessToken,
    ]);
    fail = true;
    expect(await repo.getAccessToken(), isNull);
    expect(sdk.auth.currentUser?.id, 'A');
  });
}
