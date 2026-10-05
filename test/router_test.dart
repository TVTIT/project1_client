import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/core/router/routes.dart';

import 'session_test.dart';

void main() {
  late FakeAuthRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeAuthRepository();
  });

  tearDown(() {
    fakeRepo.dispose();
  });

  testWidgets('unauthenticated user is redirected to /sign-in', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);

    // Initial restore resolves to unauthenticated
    await container.read(sessionProvider.notifier).restoreSession();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KiteApp()),
    );
    await tester.pumpAndSettle();

    // Verify redirected to sign-in screen
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Hệ thống Quản lý IoT & Digital Twin'), findsOneWidget);
    expect(find.text('Quản lý tài khoản tập trung'), findsOneWidget);
    expect(find.text('Giấy phép (License)'), findsOneWidget);
  });

  testWidgets(
    'while session is restoring, shell shows loading barrier and never renders PlaceholderScreen',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      // Explicitly set restoring status
      container
          .read(sessionProvider.notifier)
          .setStatusForTesting(AuthStatus.restoring);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KiteApp()),
      );
      await tester.pump();

      // Verify loading barrier is shown, NOT PlaceholderScreen
      expect(find.text('Đang kiểm tra phiên làm việc...'), findsOneWidget);
      expect(find.text('Giai đoạn 1 · Khung giao diện'), findsNothing);
      expect(find.text('Trạng thái Hệ thống Client'), findsNothing);
    },
  );

  testWidgets('authenticated user can view protected / (PlaceholderScreen)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const testUser = SessionUser(
      userId: 'test-user-id',
      name: 'Nguyễn Văn A',
      email: 'nguyenvana@example.com',
    );

    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);

    // Set authenticated session before launch
    container.read(sessionProvider.notifier).setSession(testUser);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KiteApp()),
    );
    await tester.pumpAndSettle();

    // Verify on PlaceholderScreen
    expect(find.text('Hệ thống Quản lý IoT & Digital Twin'), findsWidgets);
    expect(find.text('Giai đoạn 1 · Khung giao diện'), findsOneWidget);
    expect(
      find.text('Xác thực hoạt động (Stage 2 Auth Active)'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Chào mừng Nguyễn Văn A (nguyenvana@example.com) đã đăng nhập vào hệ thống.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('/license is accessible when unauthenticated', (tester) async {
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

    // Navigate to /license
    container.read(routerProvider).go(R.license);
    await tester.pumpAndSettle();

    expect(
      find.text('Giấy phép bản quyền · Open Source License'),
      findsOneWidget,
    );
    expect(find.text('Quay lại'), findsOneWidget);
  });

  for (final size in [
    const Size(390, 844),
    const Size(1024, 768),
    const Size(1366, 768),
    const Size(1920, 1080),
  ]) {
    testWidgets('authenticated placeholder fits ${size.width} px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'responsive-user',
              name: 'Người dùng kiểm thử',
              email: 'responsive@example.com',
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KiteApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trạng thái Hệ thống Client'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('/license is accessible when authenticated', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const testUser = SessionUser(
      userId: 'test-user-id-2',
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

    // Navigate to /license
    container.read(routerProvider).go(R.license);
    await tester.pumpAndSettle();

    expect(
      find.text('Giấy phép bản quyền · Open Source License'),
      findsOneWidget,
    );
    expect(find.text('Quay lại'), findsOneWidget);
  });

  testWidgets(
    'unknown location renders NotFoundScreen 404 for authenticated user',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const testUser = SessionUser(
        userId: 'test-user-id-3',
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

      container.read(routerProvider).go('/non-existent-page-url');
      await tester.pumpAndSettle();

      expect(find.text('That page does not exist'), findsOneWidget);
      expect(find.text('404'), findsOneWidget);
    },
  );
}
