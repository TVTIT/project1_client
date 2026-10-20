import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/core/router/routes.dart';
import 'package:kite/features/account/account_screen.dart';

import 'session_test.dart';

void main() {
  late FakeAuthRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeAuthRepository();
  });

  tearDown(() {
    fakeRepo.dispose();
  });

  testWidgets(
    'unauthenticated user attempting to access /account is redirected to /sign-in',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).restoreSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KiteApp()),
      );
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.account);
      await tester.pumpAndSettle();

      // Protected route redirects unauthenticated user to sign in
      expect(find.text('Đăng nhập'), findsWidgets);
      expect(find.text('Thông tin tài khoản'), findsNothing);
    },
  );

  testWidgets(
    'while session is restoring, shell shows loading barrier and never renders AccountScreen',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      container
          .read(sessionProvider.notifier)
          .setStatusForTesting(AuthStatus.restoring);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KiteApp()),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Đang kiểm tra phiên làm việc...'), findsOneWidget);
      expect(find.text('Thông tin định danh'), findsNothing);
    },
  );

  testWidgets(
    'authenticated user can navigate to /account and view read-only session data',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const testUser = SessionUser(
        userId: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Trần Vĩnh Trung',
        email: 'trung@example.com',
      );

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).setSession(testUser);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KiteApp()),
      );
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.account);
      await tester.pumpAndSettle();

      // Verify Account screen renders identity and session information
      expect(find.text('Thông tin tài khoản'), findsWidgets);
      expect(find.text('Thông tin định danh'), findsOneWidget);
      expect(find.text('Trần Vĩnh Trung'), findsWidgets);
      expect(find.text('trung@example.com'), findsWidgets);
      expect(find.text('550e8400-e29b-41d4-a716-446655440000'), findsOneWidget);

      // Verify NO gateway role badge or unassigned gateway false claim is rendered
      expect(find.text('Chưa gán vai trò trạm'), findsNothing);
      expect(find.text('Vai trò trạm (Gateway Role)'), findsNothing);

      // Verify explanatory permissions note is rendered
      expect(find.text('Cơ chế phân quyền trạm & quản trị'), findsOneWidget);

      // Verify session & security details
      expect(find.text('Phiên làm việc & Bảo mật'), findsOneWidget);
      expect(find.text('Đang hoạt động (Active)'), findsOneWidget);

      // Verify no JWT secret or raw token is exposed
      expect(find.textContaining('mock_jwt_token'), findsNothing);
      expect(find.textContaining('eyJ'), findsNothing);
    },
  );

  testWidgets(
    'regression: session user with role owner or null does NOT infer or display gateway permissions',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const testUserWithOwnerRole = SessionUser(
        userId: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
        name: 'Chủ Trạm',
        email: 'owner@example.com',
        role: 'owner',
      );

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .setSession(testUserWithOwnerRole);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KiteApp()),
      );
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.account);
      await tester.pumpAndSettle();

      // Ensure 'owner' is NOT rendered inside AccountScreen as a gateway role
      expect(
        find.descendant(
          of: find.byType(AccountScreen),
          matching: find.text('owner'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AccountScreen),
          matching: find.text('Chưa gán vai trò trạm'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AccountScreen),
          matching: find.text('Vai trò trạm (Gateway Role)'),
        ),
        findsNothing,
      );
      expect(find.text('Cơ chế phân quyền trạm & quản trị'), findsOneWidget);

      // Now switch to role: null
      const testUserWithNullRole = SessionUser(
        userId: '6ba7b810-9dad-11d1-80b4-00c04fd430c9',
        name: 'Người Dùng Khác',
        email: 'nullrole@example.com',
      );
      container.read(sessionProvider.notifier).setSession(testUserWithNullRole);
      await tester.pumpAndSettle();

      // Ensure no false claim of unassigned gateway role is displayed
      expect(
        find.descendant(
          of: find.byType(AccountScreen),
          matching: find.text('Chưa gán vai trò trạm'),
        ),
        findsNothing,
      );
      expect(find.text('Cơ chế phân quyền trạm & quản trị'), findsOneWidget);
    },
  );

  testWidgets(
    'clicking "Thông tin tài khoản" in _AccountMenu opens account page',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const testUser = SessionUser(
        userId: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Nguyễn Văn A',
        email: 'nguyenvana@example.com',
      );

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).setSession(testUser);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KiteApp()),
      );
      await tester.pumpAndSettle();

      // Click account avatar / menu trigger in TopBar
      final menuTrigger = find.byIcon(Icons.keyboard_arrow_down);
      expect(menuTrigger, findsOneWidget);
      await tester.tap(menuTrigger);
      await tester.pumpAndSettle();

      // Find "Thông tin tài khoản" menu item and click it
      final accountMenuItem = find.text('Thông tin tài khoản');
      expect(accountMenuItem, findsOneWidget);
      await tester.tap(accountMenuItem);
      await tester.pumpAndSettle();

      // Should now be on /account
      expect(find.text('Thông tin định danh'), findsOneWidget);
      expect(find.text('123e4567-e89b-12d3-a456-426614174000'), findsOneWidget);
    },
  );

  testWidgets('back to dashboard button on /account navigates to /', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const testUser = SessionUser(
      userId: '123e4567-e89b-12d3-a456-426614174000',
      name: 'Nguyễn Văn A',
      email: 'nguyenvana@example.com',
    );

    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);
    container.read(sessionProvider.notifier).setSession(testUser);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KiteApp()),
    );
    await tester.pumpAndSettle();

    container.read(routerProvider).go(R.account);
    await tester.pumpAndSettle();

    expect(find.text('Thông tin định danh'), findsOneWidget);

    final backButton = find.text('Quay lại Bảng điều khiển');
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // Now back on dashboard
    expect(find.text('Giai đoạn 1 · Khung giao diện'), findsOneWidget);
  });

  testWidgets('copy UUID button copies user id to clipboard', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardText = (methodCall.arguments as Map)['text'] as String?;
          return null;
        }
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    const testUser = SessionUser(
      userId: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
      name: 'Kiểm Thử Viên',
      email: 'tester@example.com',
    );

    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);
    container.read(sessionProvider.notifier).setSession(testUser);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KiteApp()),
    );
    await tester.pumpAndSettle();

    container.read(routerProvider).go(R.account);
    await tester.pumpAndSettle();

    final copyBtn = find.text('Sao chép ID');
    expect(copyBtn, findsOneWidget);
    await tester.tap(copyBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify clipboard content
    expect(clipboardText, equals('7c9e6679-7425-40de-944b-e07fc1f90ae7'));
  });

  for (final size in [
    const Size(390, 844),
    const Size(1024, 768),
    const Size(1366, 768),
    const Size(1920, 1080),
  ]) {
    testWidgets('responsive /account fits ${size.width} px without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const testUser = SessionUser(
        userId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'Người Dùng Responsive',
        email: 'responsive.user@example.com',
      );

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).setSession(testUser);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KiteApp()),
      );
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.account);
      await tester.pumpAndSettle();

      expect(find.text('Thông tin định danh'), findsOneWidget);
      expect(find.text('a1b2c3d4-e5f6-7890-abcd-ef1234567890'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
