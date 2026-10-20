import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/core/router/routes.dart';
import 'package:kite/features/users/data/user_dto.dart';
import 'package:kite/features/users/data/user_repository.dart';
import 'package:kite/features/users/presentation/user_list_screen.dart';

import 'permissions_test.dart';
import 'session_test.dart';

class FakeUserRepository implements UserRepository {
  List<UserSummary> users = [];
  Object? listError;
  int listCallCount = 0;

  @override
  Future<List<UserSummary>> listUsers() async {
    listCallCount++;
    if (listError != null) throw listError!;
    return users;
  }

  @override
  Future<CreatedUser> createUser(CreateUserInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<UpdatedUser> updateUser(String userId, UpdateUserInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<AssignGatewayUserResult> assignGatewayUser({
    required String gatewayId,
    required String userId,
    required String role,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> revokeGatewayUser({
    required String gatewayId,
    required String userId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<TransferGatewayOwnerResult> transferGatewayOwner({
    required String gatewayId,
    required String targetUserId,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  late FakeAuthRepository fakeAuthRepo;
  late FakeUserRepository fakeUserRepo;
  late FakePermissionsRepository fakePermsRepo;

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeUserRepo = FakeUserRepository();
    fakePermsRepo = FakePermissionsRepository();
  });

  tearDown(() {
    fakeAuthRepo.dispose();
  });

  Widget createTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const KiteApp(),
    );
  }

  group('UserListScreen Behavioral Tests', () {
    testWidgets(
      'fail-closed barrier: non-admin does not see user list or call listUsers',
      (tester) async {
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: false,
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const user = SessionUser(
          userId: 'regular-user',
          name: 'Regular',
          email: 'reg@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user);
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.adminUsers);
        await tester.pumpAndSettle();

        // Non-admin is redirected away from /admin/users by router guard, zero listUsers calls
        expect(find.byType(UserListScreen), findsNothing);
        expect(fakeUserRepo.listCallCount, 0);
      },
    );

    testWidgets(
      'admin view renders list, shows nullable name fallback, badges, and membership count',
      (tester) async {
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440001',
            email: 'admin1@example.com',
            fullName: null, // Nullable name
            platformRole: 'platform_admin',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
            gatewayRoles: const [
              UserGatewayRole(gatewayId: 'gw-1', role: 'owner'),
              UserGatewayRole(gatewayId: 'gw-2', role: 'viewer'),
            ],
          ),
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440002',
            email: 'user2@example.com',
            fullName: 'Trần Văn Nam',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-02T00:00:00Z'),
            gatewayRoles: const [],
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const admin = SessionUser(
          userId: 'admin-uuid',
          name: 'Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(admin);
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.adminUsers);
        await tester.pumpAndSettle();

        expect(find.text('Quản lý Người dùng'), findsAtLeast(1));
        expect(find.text('admin1@example.com'), findsOneWidget);
        expect(find.text('Trần Văn Nam'), findsOneWidget);
        expect(
          find.text('Chưa cập nhật'),
          findsOneWidget,
        ); // Fallback for null full_name
        expect(find.text('2 trạm'), findsOneWidget);
      },
    );

    testWidgets(
      'capacity error 409 user_list_capacity_exceeded does NOT show partial data as complete',
      (tester) async {
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.listError = const ApiException(
          statusCode: 409,
          code: 'user_list_capacity_exceeded',
          message:
              'Dung lượng danh sách người dùng vượt quá giới hạn hệ thống.',
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const admin = SessionUser(
          userId: 'admin-uuid',
          name: 'Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(admin);
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.adminUsers);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('vượt quá giới hạn hệ thống'),
          findsOneWidget,
        );
      },
    );
  });
}
