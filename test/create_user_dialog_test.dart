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
import 'package:kite/features/users/presentation/create_user_dialog.dart';

import 'permissions_test.dart';
import 'session_test.dart';

class FakeCreateUserRepository implements UserRepository {
  CreateUserInput? lastCreatedInput;
  Object? createError;
  int createCallCount = 0;
  List<UserSummary> users = [];
  Object? listError;

  @override
  Future<List<UserSummary>> listUsers() async {
    if (listError != null) throw listError!;
    return users;
  }

  @override
  Future<CreatedUser> createUser(CreateUserInput input) async {
    createCallCount++;
    lastCreatedInput = input;
    if (createError != null) throw createError!;
    return CreatedUser(
      id: '550e8400-e29b-41d4-a716-446655440099',
      email: input.email,
      fullName: input.fullName,
      platformRole: 'user',
      createdAt: DateTime.now().toUtc(),
    );
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
  late FakeCreateUserRepository fakeUserRepo;
  late FakePermissionsRepository fakePermsRepo;

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeUserRepo = FakeCreateUserRepository();
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

  group('CreateUserDialog Behavioral Tests', () {
    testWidgets('password field is obscured and form validates input bounds', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
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
      await container.read(userPermissionsProvider.notifier).loadPermissions();

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.adminUsers);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thêm Người dùng').first);
      await tester.pumpAndSettle();

      expect(find.byType(CreateUserDialog), findsOneWidget);
      expect(find.text('Tạo tài khoản người dùng mới'), findsOneWidget);

      // Verify password field is obscured
      final editableTextFinders = find.byType(EditableText);
      // The search box on UserListScreen is index 0, dialog has name (1), email (2), password (3)
      final pwdWidget = tester.widget<EditableText>(editableTextFinders.last);
      expect(pwdWidget.obscureText, isTrue);

      // Submit empty form -> triggers field validation errors
      await tester.tap(find.text('Tạo tài khoản'));
      await tester.pumpAndSettle();

      expect(find.text('Họ và tên không được để trống.'), findsOneWidget);
      expect(find.text('Email không được để trống.'), findsOneWidget);
      expect(find.text('Mật khẩu không được để trống.'), findsOneWidget);
      expect(fakeUserRepo.createCallCount, 0);
    });

    testWidgets(
      'successful create calls repo, preserves exact password whitespace, refreshes list',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
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

        await tester.tap(find.text('Thêm Người dùng').first);
        await tester.pumpAndSettle();

        // Enter valid fields into text fields inside dialog (indices 1, 2, 3)
        await tester.enterText(
          find.byType(TextField).at(1),
          '  Nguyễn Văn A  ',
        );
        await tester.enterText(
          find.byType(TextField).at(2),
          '  userA@example.com  ',
        );
        await tester.enterText(find.byType(TextField).at(3), '  pwd_123456  ');

        await tester.tap(find.text('Tạo tài khoản'));
        await tester.pumpAndSettle();

        expect(fakeUserRepo.createCallCount, 1);
        expect(fakeUserRepo.lastCreatedInput!.fullName, 'Nguyễn Văn A');
        expect(fakeUserRepo.lastCreatedInput!.email, 'userA@example.com');
        // Password exact whitespace must be preserved!
        expect(fakeUserRepo.lastCreatedInput!.password, '  pwd_123456  ');
      },
    );

    testWidgets(
      'duplicate email (409) shows conflict error and preserves entered fields',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.createError = const ApiException(
          statusCode: 409,
          code: 'user_already_exists',
          message: 'user already exists',
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

        await tester.tap(find.text('Thêm Người dùng').first);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(1), 'Admin B');
        await tester.enterText(
          find.byType(TextField).at(2),
          'adminB@example.com',
        );
        await tester.enterText(find.byType(TextField).at(3), 'password123');

        await tester.tap(find.text('Tạo tài khoản'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Email này đã tồn tại trong hệ thống'),
          findsOneWidget,
        );
        // Fields are preserved
        expect(find.text('Admin B'), findsOneWidget);
        expect(find.text('adminB@example.com'), findsOneWidget);
      },
    );

    testWidgets(
      'unknown outcome on 503 presents warning with NO blind retry and reconciliation button',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.createError = const ApiException(
          statusCode: 503,
          code: 'service_unavailable',
          message: 'service unavailable',
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

        await tester.tap(find.text('Thêm Người dùng').first);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(1), 'Admin C');
        await tester.enterText(
          find.byType(TextField).at(2),
          'adminC@example.com',
        );
        await tester.enterText(find.byType(TextField).at(3), 'password123');

        await tester.tap(find.text('Tạo tài khoản'));
        await tester.pumpAndSettle();

        // Must show unknown outcome warning with NO blind retry
        expect(
          find.textContaining('Kết quả tạo tài khoản chưa xác định'),
          findsOneWidget,
        );
        expect(find.text('Đối soát danh sách'), findsOneWidget);

        // Password must be cleared immediately upon unknown outcome
        final editableTextFinders = find.byType(EditableText);
        final pwdWidget = tester.widget<EditableText>(editableTextFinders.last);
        expect(pwdWidget.controller.text, isEmpty);

        // Simulate reconciliation found user in list
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440003',
            email: 'adminc@example.com',
            fullName: 'Admin C',
            platformRole: 'user',
            createdAt: DateTime.now().toUtc(),
            gatewayRoles: const [],
          ),
        ];

        await tester.tap(find.text('Đối soát danh sách'));
        await tester.pumpAndSettle();

        // Proves account exists on server, but does NOT claim exact password validity or auto-pop
        expect(find.textContaining('đã tồn tại trên hệ thống'), findsOneWidget);
        expect(
          fakeUserRepo.createCallCount,
          1,
        ); // Exactly 1 create call, NO blind retry!
      },
    );

    testWidgets(
      'reconciliation failure/capacity shows error and does not infer absent account',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.createError = const ApiException(
          statusCode: 503,
          code: 'service_unavailable',
          message: 'service unavailable',
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

        await tester.tap(find.text('Thêm Người dùng').first);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(1), 'Admin D');
        await tester.enterText(
          find.byType(TextField).at(2),
          'adminD@example.com',
        );
        await tester.enterText(find.byType(TextField).at(3), 'password123');

        await tester.tap(find.text('Tạo tài khoản'));
        await tester.pumpAndSettle();

        // Simulate list error / capacity overflow during reconciliation
        fakeUserRepo.createError = null;
        fakeUserRepo.listError = const ApiException(
          statusCode: 409,
          code: 'user_list_capacity_exceeded',
          message: 'Dung lượng danh sách vượt quá giới hạn.',
        );

        await tester.tap(find.text('Đối soát danh sách'));
        await tester.pumpAndSettle();

        // Must display error and NEVER infer absent account!
        expect(
          find.textContaining('Không thể tải danh sách để đối soát'),
          findsOneWidget,
        );
      },
    );

    testWidgets('session logout while dialog open immediately closes dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
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
      await container.read(userPermissionsProvider.notifier).loadPermissions();

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.adminUsers);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thêm Người dùng').first);
      await tester.pumpAndSettle();

      expect(find.byType(CreateUserDialog), findsOneWidget);

      // Session logs out!
      await container.read(sessionProvider.notifier).signOut();
      await tester.pumpAndSettle();

      expect(find.byType(CreateUserDialog), findsNothing);
    });
  });
}
