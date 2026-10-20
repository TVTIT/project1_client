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
import 'package:kite/features/users/presentation/edit_user_dialog.dart';
import 'package:kite_ui/kite_ui.dart';

import 'permissions_test.dart';
import 'session_test.dart';

class FakeEditUserRepository implements UserRepository {
  UpdateUserInput? lastUpdateInput;
  String? lastUpdateUserId;
  Object? updateError;
  int updateCallCount = 0;
  List<UserSummary> users = [];

  @override
  Future<List<UserSummary>> listUsers() async => users;

  @override
  Future<CreatedUser> createUser(CreateUserInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<UpdatedUser> updateUser(String userId, UpdateUserInput input) async {
    updateCallCount++;
    lastUpdateUserId = userId;
    lastUpdateInput = input;
    if (updateError != null) throw updateError!;
    return UpdatedUser(
      id: userId,
      fullName: input.fullName,
      platformRole: input.platformRole ?? 'user',
    );
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
  late FakeEditUserRepository fakeUserRepo;
  late FakePermissionsRepository fakePermsRepo;

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeUserRepo = FakeEditUserRepository();
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

  group('EditUserDialog Behavioral Tests', () {
    testWidgets(
      'displays user details, handles nullable legacy name, disables save when no fields changed',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440001',
            email: 'target@example.com',
            fullName: null, // Legacy null name
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
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

        // Open edit dialog for target user
        await tester.ensureVisible(find.byIcon(Icons.edit_outlined).first);
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();

        expect(find.byType(EditUserDialog), findsOneWidget);
        expect(find.text('Chỉnh sửa Người dùng'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(EditUserDialog),
            matching: find.text('target@example.com'),
          ),
          findsOneWidget,
        );

        // Save button should be disabled when no fields changed
        final saveBtn = tester.widget<KiteButton>(
          find.widgetWithText(KiteButton, 'Lưu thay đổi'),
        );
        expect(saveBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'self-demotion guard: actor editing self can rename but cannot demote to user',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.users = [
          UserSummary(
            id: 'admin-uuid', // Actor is editing themselves!
            email: 'admin@example.com',
            fullName: 'Self Admin',
            platformRole: 'platform_admin',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
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
          name: 'Self Admin',
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

        await tester.ensureVisible(find.byIcon(Icons.edit_outlined).first);
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();

        // Should show self-demotion prevention indicator / disabled option
        expect(
          find.textContaining('Bạn không thể tự hạ quyền'),
          findsOneWidget,
        );

        // Actor can rename self
        await tester.enterText(
          find.byType(TextFormField),
          'Self Admin Renamed',
        );
        await tester.pumpAndSettle();

        final saveBtn = tester.widget<KiteButton>(
          find.widgetWithText(KiteButton, 'Lưu thay đổi'),
        );
        expect(saveBtn.onPressed, isNotNull);

        await tester.tap(find.text('Lưu thay đổi'));
        await tester.pumpAndSettle();

        expect(fakeUserRepo.updateCallCount, 1);
        expect(fakeUserRepo.lastUpdateInput!.fullName, 'Self Admin Renamed');
        expect(
          fakeUserRepo.lastUpdateInput!.platformRole,
          isNull,
        ); // Role unchanged, not sent!
      },
    );

    testWidgets(
      'requires explicit confirmation before changing platform role',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440005',
            email: 'target5@example.com',
            fullName: 'Regular User',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
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

        await tester.ensureVisible(find.byIcon(Icons.edit_outlined).first);
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();

        // Change role to platform_admin
        await tester.tap(find.text('Platform Admin').last);
        await tester.pumpAndSettle();

        // Confirmation checkbox appears
        expect(find.byType(CheckboxListTile), findsOneWidget);
        expect(
          find.textContaining('Tôi xác nhận cấp quyền Quản trị viên'),
          findsOneWidget,
        );

        // Save button remains disabled until confirmed!
        var saveBtn = tester.widget<KiteButton>(
          find.widgetWithText(KiteButton, 'Lưu thay đổi'),
        );
        expect(saveBtn.onPressed, isNull);

        // Check confirmation box
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();

        saveBtn = tester.widget<KiteButton>(
          find.widgetWithText(KiteButton, 'Lưu thay đổi'),
        );
        expect(saveBtn.onPressed, isNotNull);

        await tester.tap(find.text('Lưu thay đổi'));
        await tester.pumpAndSettle();

        expect(fakeUserRepo.updateCallCount, 1);
        expect(fakeUserRepo.lastUpdateInput!.platformRole, 'platform_admin');
        expect(
          fakeUserRepo.lastUpdateInput!.fullName,
          isNull,
        ); // Name unchanged, not sent!
      },
    );

    testWidgets(
      'handles backend 409 self_admin_demotion_forbidden atomically',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.updateError = const ApiException(
          statusCode: 409,
          code: 'self_admin_demotion_forbidden',
          message: 'self admin demotion forbidden',
        );
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440006',
            email: 'target6@example.com',
            fullName: 'Target 6',
            platformRole: 'platform_admin',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
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

        await tester.ensureVisible(find.byIcon(Icons.edit_outlined).first);
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();

        // Change role to user
        await tester.tap(find.text('User').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Lưu thay đổi'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Bạn không thể tự hạ quyền Quản trị viên'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'admin 403 on PATCH invalidates admin capabilities while retaining auth session',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.updateError = const ApiException(
          statusCode: 403,
          code: 'forbidden',
          message: 'access denied',
        );
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440007',
            email: 'target7@example.com',
            fullName: 'Target 7',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
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

        await tester.ensureVisible(find.byIcon(Icons.edit_outlined).first);
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Target 7 Renamed');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Lưu thay đổi'));
        await tester.pumpAndSettle();

        // 403 received -> admin permissions invalidated!
        expect(
          container.read(userPermissionsProvider).isPlatformAdmin,
          isFalse,
        );
        // But auth session is RETAINED!
        expect(container.read(sessionProvider).isAuthenticated, isTrue);
      },
    );
  });
}
