import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/config/app_config.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/core/network/api_exception.dart';

import 'session_test.dart';

class FakePermissionsRepository implements PermissionsRepository {
  UserPermissions resultToReturn = UserPermissions.unprivileged;
  Completer<UserPermissions>? pendingCompleter;
  bool shouldThrow = false;
  Object? errorToThrow;
  int callCount = 0;

  @override
  Future<UserPermissions> getMyPermissions() async {
    callCount++;
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    if (shouldThrow) {
      throw errorToThrow ??
          const ApiException(
            statusCode: 503,
            code: 'service_unavailable',
            message: 'Database temporarily unavailable',
          );
    }
    return resultToReturn;
  }
}

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

  group('Permissions DTO & Repository', () {
    test('UserPermissions parses is_platform_admin correctly', () {
      expect(
        UserPermissions.fromJson({'is_platform_admin': true}).isPlatformAdmin,
        isTrue,
      );
      expect(
        UserPermissions.fromJson({'is_platform_admin': false}).isPlatformAdmin,
        isFalse,
      );
      expect(UserPermissions.fromJson({}).isPlatformAdmin, isFalse);
    });

    test(
      'HttpPermissionsRepository calls GET /v1/me/permissions with empty body',
      () async {
        await authRepo.signInWithPassword(
          email: 'admin@example.com',
          password: 'pwd',
        );

        late http.Request capturedRequest;
        final mockHttp = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({'is_platform_admin': true}),
            200,
            headers: {
              'content-type': 'application/json',
              'x-request-id': 'req-perm-1',
            },
          );
        });

        final client = ApiClient(
          authRepository: authRepo,
          httpClient: mockHttp,
          baseUrl: 'http://localhost/v1/',
        );

        final repo = HttpPermissionsRepository(client);
        final perms = await repo.getMyPermissions();

        expect(perms.isPlatformAdmin, isTrue);
        expect(capturedRequest.method, 'GET');
        expect(capturedRequest.url.path, '/v1/me/permissions');
        expect(
          capturedRequest.headers['Authorization'],
          'Bearer mock_jwt_token',
        );
        expect(capturedRequest.body, isEmpty);
      },
    );
  });

  group('UserPermissionsNotifier & Fail-Closed Provider', () {
    test(
      'unauthenticated session defaults to fail-closed isPlatformAdmin = false',
      () {
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(authRepo)],
        );
        addTearDown(container.dispose);

        final state = container.read(userPermissionsProvider);
        expect(state.isLoading, isFalse);
        expect(state.isPlatformAdmin, isFalse);
        expect(container.read(isPlatformAdminProvider), isFalse);
      },
    );

    test('while restoring session, permissions remain fail-closed false', () {
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepo)],
      );
      addTearDown(container.dispose);

      container
          .read(sessionProvider.notifier)
          .setStatusForTesting(AuthStatus.restoring);

      final state = container.read(userPermissionsProvider);
      expect(state.isPlatformAdmin, isFalse);
      expect(container.read(isPlatformAdminProvider), isFalse);
    });

    test(
      'authenticated platform admin loads and confirms isPlatformAdmin = true',
      () async {
        final fakeRepo = FakePermissionsRepository()
          ..resultToReturn = const UserPermissions(isPlatformAdmin: true);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            permissionsRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );
        addTearDown(container.dispose);

        const user = SessionUser(
          userId: '11111111-1111-1111-1111-111111111111',
          name: 'Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user);

        // Trigger permission load
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        final state = container.read(userPermissionsProvider);
        expect(state.isLoading, isFalse);
        expect(state.isPlatformAdmin, isTrue);
        expect(container.read(isPlatformAdminProvider), isTrue);
      },
    );

    test(
      'authenticated standard user confirms isPlatformAdmin = false',
      () async {
        final fakeRepo = FakePermissionsRepository()
          ..resultToReturn = const UserPermissions(isPlatformAdmin: false);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            permissionsRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );
        addTearDown(container.dispose);

        const user = SessionUser(
          userId: '22222222-2222-2222-2222-222222222222',
          name: 'User',
          email: 'user@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user);

        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        final state = container.read(userPermissionsProvider);
        expect(state.isLoading, isFalse);
        expect(state.isPlatformAdmin, isFalse);
        expect(container.read(isPlatformAdminProvider), isFalse);
      },
    );

    test(
      'on error (503, network, 401), permissions fail-closed to false',
      () async {
        final fakeRepo = FakePermissionsRepository()
          ..shouldThrow = true
          ..errorToThrow = const ApiException(
            statusCode: 503,
            code: 'service_unavailable',
            message: 'Database error',
          );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            permissionsRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );
        addTearDown(container.dispose);

        const user = SessionUser(
          userId: '33333333-3333-3333-3333-333333333333',
          name: 'User',
          email: 'user@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user);

        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        final state = container.read(userPermissionsProvider);
        expect(state.isLoading, isFalse);
        expect(state.hasError, isTrue);
        expect(state.isPlatformAdmin, isFalse);
        expect(container.read(isPlatformAdminProvider), isFalse);
      },
    );

    test(
      'session epoch change or sign-out resets permissions to unprivileged',
      () async {
        final fakeRepo = FakePermissionsRepository()
          ..resultToReturn = const UserPermissions(isPlatformAdmin: true);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            permissionsRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );
        addTearDown(container.dispose);

        const user = SessionUser(
          userId: '44444444-4444-4444-4444-444444444444',
          name: 'Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user);
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        expect(container.read(isPlatformAdminProvider), isTrue);

        // Sign out
        await container.read(sessionProvider.notifier).signOut();

        // State is purged
        expect(
          container.read(userPermissionsProvider).isPlatformAdmin,
          isFalse,
        );
        expect(container.read(isPlatformAdminProvider), isFalse);
      },
    );

    test(
      'stale permission response from old session epoch is discarded',
      () async {
        final completer = Completer<UserPermissions>();
        final fakeRepo = FakePermissionsRepository()
          ..pendingCompleter = completer;

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            permissionsRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );
        addTearDown(container.dispose);

        const userA = SessionUser(
          userId: 'aaaa-aaaa-aaaa-aaaa',
          name: 'Admin A',
          email: 'adminA@example.com',
        );
        container.read(sessionProvider.notifier).setSession(userA);

        // Start pending load for user A
        final future = container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        // Switch to user B before completer completes
        const userB = SessionUser(
          userId: 'bbbb-bbbb-bbbb-bbbb',
          name: 'Standard B',
          email: 'userB@example.com',
        );
        container.read(sessionProvider.notifier).setSession(userB);

        // Complete delayed response claiming admin
        completer.complete(const UserPermissions(isPlatformAdmin: true));
        await future;

        // User B should NOT adopt user A's admin permission
        expect(
          container.read(userPermissionsProvider).isPlatformAdmin,
          isFalse,
        );
      },
    );
  });
}
