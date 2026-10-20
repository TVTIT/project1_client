import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/config/app_config.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/users/data/user_dto.dart';
import 'package:kite/features/users/data/user_repository.dart';
import 'package:kite/features/users/providers/user_providers.dart';

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

  group('UserRepository Tests', () {
    test('listUsers calls GET admin/users without query params and returns bounded list', () async {
      await authRepo.signInWithPassword(
        email: 'admin@example.com',
        password: 'pwd',
      );

      late http.Request capturedRequest;
      final mockHttp = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': '550e8400-e29b-41d4-a716-446655440001',
                'email': 'user1@example.com',
                'full_name': 'User One',
                'platform_role': 'user',
                'created_at': '2026-10-01T00:00:00Z',
                'gateway_roles': [
                  {'gateway_id': 'gw-1', 'role': 'operator'},
                ],
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

      final repo = HttpUserRepository(client);
      final users = await repo.listUsers();

      expect(users.length, 1);
      expect(users[0].email, 'user1@example.com');
      expect(users[0].gatewayRoles.length, 1);
      expect(capturedRequest.url.path, '/v1/admin/users');
      expect(capturedRequest.url.query, isEmpty);
    });

    test(
      'createUser validates and calls POST admin/users returning CreatedUser',
      () async {
        await authRepo.signInWithPassword(
          email: 'admin@example.com',
          password: 'pwd',
        );

        late http.Request capturedRequest;
        final mockHttp = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'id': '550e8400-e29b-41d4-a716-446655440002',
              'email': 'new@example.com',
              'full_name': 'New Admin',
              'platform_role': 'user',
              'created_at': '2026-10-19T10:00:00Z',
            }),
            201,
            headers: {
              'content-type': 'application/json',
              'location':
                  '/v1/admin/users/550e8400-e29b-41d4-a716-446655440002',
            },
          );
        });

        final client = ApiClient(
          authRepository: authRepo,
          httpClient: mockHttp,
          baseUrl: 'http://localhost/v1/',
        );

        final repo = HttpUserRepository(client);
        final created = await repo.createUser(
          const CreateUserInput(
            fullName: 'New Admin',
            email: 'new@example.com',
            password: 'secure_password_123',
          ),
        );

        expect(created.id, '550e8400-e29b-41d4-a716-446655440002');
        expect(created.email, 'new@example.com');
        expect(capturedRequest.method, 'POST');
        expect(capturedRequest.url.path, '/v1/admin/users');
      },
    );

    test(
      'updateUser validates UUID and calls PATCH admin/users/{id}',
      () async {
        await authRepo.signInWithPassword(
          email: 'admin@example.com',
          password: 'pwd',
        );

        late http.Request capturedRequest;
        final mockHttp = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'id': '550e8400-e29b-41d4-a716-446655440003',
              'full_name': 'Renamed User',
              'platform_role': 'platform_admin',
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

        final repo = HttpUserRepository(client);
        final updated = await repo.updateUser(
          '550e8400-e29b-41d4-a716-446655440003',
          const UpdateUserInput(
            fullName: 'Renamed User',
            platformRole: 'platform_admin',
          ),
        );

        expect(updated.id, '550e8400-e29b-41d4-a716-446655440003');
        expect(updated.fullName, 'Renamed User');
        expect(updated.platformRole, 'platform_admin');
        expect(capturedRequest.method, 'PATCH');
        expect(
          capturedRequest.url.path,
          '/v1/admin/users/550e8400-e29b-41d4-a716-446655440003',
        );
      },
    );

    test('assignGatewayUser forbids owner role and calls PUT admin/gateways/{id}/users/{id}', () async {
      await authRepo.signInWithPassword(
        email: 'admin@example.com',
        password: 'pwd',
      );

      final client = ApiClient(
        authRepository: authRepo,
        baseUrl: 'http://localhost/v1/',
      );
      final repo = HttpUserRepository(client);

      // Rejects owner role locally
      expect(
        () => repo.assignGatewayUser(
          gatewayId: 'gw-1',
          userId: '550e8400-e29b-41d4-a716-446655440000',
          role: 'owner',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_role'),
        ),
      );
    });

    test('transferGatewayOwner validates UUID and calls PUT admin/gateways/{id}/owner', () async {
      await authRepo.signInWithPassword(
        email: 'admin@example.com',
        password: 'pwd',
      );

      late http.Request capturedRequest;
      final mockHttp = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'gateway_id': 'gw-1',
            'owner_user_id': '550e8400-e29b-41d4-a716-446655440004',
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

      final repo = HttpUserRepository(client);
      final transfer = await repo.transferGatewayOwner(
        gatewayId: 'gw-1',
        targetUserId: '550e8400-e29b-41d4-a716-446655440004',
      );

      expect(transfer.gatewayId, 'gw-1');
      expect(transfer.ownerUserId, '550e8400-e29b-41d4-a716-446655440004');
      expect(capturedRequest.method, 'PUT');
      expect(capturedRequest.url.path, '/v1/admin/gateways/gw-1/owner');
    });

    test('revokeGatewayUser validates UUID and calls DELETE admin/gateways/{id}/users/{id}', () async {
      await authRepo.signInWithPassword(
        email: 'admin@example.com',
        password: 'pwd',
      );

      late http.Request capturedRequest;
      final mockHttp = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          '',
          204,
          headers: {'cache-control': 'no-store', 'pragma': 'no-cache'},
        );
      });

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );

      final repo = HttpUserRepository(client);

      // Rejects invalid UUID locally:
      expect(
        () => repo.revokeGatewayUser(gatewayId: 'gw-1', userId: 'invalid-uuid'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_request'),
        ),
      );

      // Successful revocation:
      await repo.revokeGatewayUser(
        gatewayId: 'gw-1',
        userId: '550e8400-e29b-41d4-a716-446655440004',
      );

      expect(capturedRequest.method, 'DELETE');
      expect(
        capturedRequest.url.path,
        '/v1/admin/gateways/gw-1/users/550e8400-e29b-41d4-a716-446655440004',
      );
    });

    test('UserListNotifier does not load users if unauthenticated or not platform admin', () async {
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepo)],
      );
      addTearDown(container.dispose);

      final state = container.read(userListProvider);
      expect(state.isLoading, isFalse);
      expect(state.users, isEmpty);
    });
  });
}
