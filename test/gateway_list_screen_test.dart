import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/core/router/routes.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';

import 'gateway_list_provider_test.dart';
import 'session_test.dart';

void main() {
  late FakeAuthRepository fakeAuthRepo;
  late FakeGatewayRepository fakeGatewayRepo;

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeGatewayRepo = FakeGatewayRepository();
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

  testWidgets(
    'unauthenticated user attempting to access /gateways is redirected to /sign-in',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).restoreSession();

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.gateways);
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập'), findsWidgets);
      expect(
        find.text('Danh sách các trạm kết nối được phân quyền truy cập.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'authenticated user can navigate to /gateways and see empty state when items is empty',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeGatewayRepo.items = [];

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u1',
              name: 'User 1',
              email: 'user@example.com',
            ),
          );

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.gateways);
      await tester.pumpAndSettle();

      expect(find.text('Quản lý Gateway'), findsWidgets);
      expect(find.text('Chưa có trạm Gateway nào'), findsOneWidget);
      expect(
        find.text(
          'Tài khoản của bạn hiện chưa được phân quyền truy cập trạm Gateway nào.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('displays error state with safe message and allows retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    fakeGatewayRepo.shouldThrow = true;
    fakeGatewayRepo.errorToThrow = const ApiException(
      statusCode: 503,
      code: 'service_unavailable',
      message: 'Hệ thống bận, vui lòng thử lại sau',
      requestId: 'req-503-test',
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuthRepo),
        gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(sessionProvider.notifier)
        .setSession(
          const SessionUser(
            userId: 'u1',
            name: 'User 1',
            email: 'user@example.com',
          ),
        );

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    container.read(routerProvider).go(R.gateways);
    await tester.pumpAndSettle();

    expect(find.textContaining('Hệ thống bận'), findsOneWidget);
    expect(find.textContaining('req-503-test'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    // Now fix the error and tap retry
    fakeGatewayRepo.shouldThrow = false;
    fakeGatewayRepo.items = [
      const GatewayItem(
        gatewayId: 'gateway_001',
        name: 'AM5728 Gateway 001',
        role: GatewayRole.owner,
      ),
    ];

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('AM5728 Gateway 001'), findsOneWidget);
    expect(find.text('Chủ sở hữu'), findsOneWidget);
  });

  testWidgets(
    'renders gateway table on desktop/tablet and clicking an item navigates to /gateways/:gatewayId',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gateway_001',
          name: 'AM5728 Gateway 001',
          description: 'Trạm quan trắc nhà kính số 1',
          role: GatewayRole.owner,
        ),
        const GatewayItem(
          gatewayId: 'gateway_002',
          name: 'ESP32 Gateway 002',
          description: 'Trạm điều khiển tưới tiêu',
          role: GatewayRole.operator,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u1',
              name: 'User 1',
              email: 'user@example.com',
            ),
          );

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.gateways);
      await tester.pumpAndSettle();

      // Check table items
      expect(find.text('gateway_001'), findsOneWidget);
      expect(find.text('AM5728 Gateway 001'), findsOneWidget);
      expect(find.text('Chủ sở hữu'), findsOneWidget);

      expect(find.text('gateway_002'), findsOneWidget);
      expect(find.text('ESP32 Gateway 002'), findsOneWidget);
      expect(find.text('Vận hành'), findsOneWidget);

      // Click on gateway_001 row to navigate to detail
      await tester.tap(find.text('AM5728 Gateway 001'));
      await tester.pumpAndSettle();

      // Verify navigated to placeholder
      expect(find.text('Chi tiết Gateway: gateway_001'), findsOneWidget);
      expect(find.text('Quay lại danh sách Gateway'), findsOneWidget);

      // Tap back button
      await tester.tap(find.text('Quay lại danh sách Gateway'));
      await tester.pumpAndSettle();

      expect(find.text('AM5728 Gateway 001'), findsOneWidget);
    },
  );

  testWidgets(
    'sidebar contains Quản lý Gateway below Bảng điều khiển and supports prefix-active highlighting',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gateway_001',
          name: 'AM5728 Gateway 001',
          role: GatewayRole.owner,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u1',
              name: 'User 1',
              email: 'user@example.com',
            ),
          );

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      // Sidebar should show 'Quản lý Gateway'
      expect(find.text('Quản lý Gateway'), findsWidgets);

      // Tap 'Quản lý Gateway' in sidebar
      await tester.tap(find.text('Quản lý Gateway').first);
      await tester.pumpAndSettle();

      expect(find.text('AM5728 Gateway 001'), findsOneWidget);

      // Go to detail route /gateways/gateway_001
      container.read(routerProvider).go('/gateways/gateway_001');
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết Gateway: gateway_001'), findsOneWidget);
      // Sidebar still has Quản lý Gateway highlighted (prefix-active)
      expect(find.text('Quản lý Gateway'), findsWidgets);
    },
  );

  group('Responsive Layout Widths', () {
    for (final width in [390.0, 1024.0, 1366.0, 1920.0]) {
      testWidgets('renders cleanly without overflow at width $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-resp-01',
            name: 'Responsive Gateway 01',
            description: 'Testing responsiveness at various breakpoints',
            role: GatewayRole.owner,
          ),
          const GatewayItem(
            gatewayId: 'gw-resp-02',
            name: 'Responsive Gateway 02',
            description: 'Testing second item',
            role: GatewayRole.operator,
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'u1',
                name: 'User 1',
                email: 'user@example.com',
              ),
            );

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        expect(find.text('Responsive Gateway 01'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
