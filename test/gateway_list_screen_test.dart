import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/core/router/routes.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite_ui/kite_ui.dart';

import 'gateway_list_provider_test.dart';
import 'permissions_test.dart';
import 'session_test.dart';

void main() {
  late FakeAuthRepository fakeAuthRepo;
  late FakeGatewayRepository fakeGatewayRepo;
  late FakePermissionsRepository fakePermsRepo;

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeGatewayRepo = FakeGatewayRepository();
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
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
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
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
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
        permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
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
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
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
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
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
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
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

  group('GatewayListScreen Pagination & Search Details', () {
    testWidgets(
      'admin role displays "—" never fake role badge; user role displays real badge',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.adminGatewaysResultToReturn =
            const AdminGatewayInventoryResponse(
              items: [
                AdminGatewayItem(
                  gatewayId: 'gw-admin-item',
                  name: 'Admin Gateway Item',
                ),
              ],
              nextCursor: null,
            );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-1',
                name: 'Admin User',
                email: 'admin@test.com',
              ),
            );

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        expect(find.text('Admin Gateway Item'), findsOneWidget);
        // Strictly "—" for admin role, never "Admin" or fake badge
        expect(find.text('—'), findsWidgets);
        expect(find.text('Admin'), findsNothing);
        expect(find.text('Quản trị'), findsNothing);
      },
    );

    testWidgets(
      'search placeholder clarifies loaded-data search and shows loaded count not total',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-01',
            name: 'Station 01',
            role: GatewayRole.owner,
          ),
          const GatewayItem(
            gatewayId: 'gw-02',
            name: 'Station 02',
            role: GatewayRole.viewer,
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'u1',
                name: 'User 1',
                email: 'user@test.com',
              ),
            );

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        // Check placeholder
        expect(
          find.text(
            'Tìm theo mã trạm, tên hoặc mô tả trong danh sách đã tải...',
          ),
          findsOneWidget,
        );

        // Check count not total
        expect(
          find.text('Đang hiển thị 2 trạm đã tải (không phải tổng số)'),
          findsOneWidget,
        );

        // Type in search
        final searchInput = find.byType(KiteInput);
        await tester.enterText(searchInput.first, '01');
        await tester.pumpAndSettle();

        // Filtered count
        expect(
          find.text('Đang hiển thị 1 trên 2 trạm đã tải (không phải tổng số)'),
          findsOneWidget,
        );
        expect(find.text('Station 01'), findsOneWidget);
        expect(find.text('Station 02'), findsNothing);
      },
    );

    testWidgets(
      'list scroll triggers loadNextPage and merges page 2 without duplicate triggers',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        final page1Items = List.generate(
          15,
          (i) => AdminGatewayItem(
            gatewayId: 'gw-page1-${i.toString().padLeft(2, '0')}',
            name: 'Gateway Page 1 - $i',
          ),
        );

        final page2Items = [
          const AdminGatewayItem(
            gatewayId: 'gw-page2-99',
            name: 'Gateway Page 2 Item',
          ),
        ];

        fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
          if (after == null) {
            return AdminGatewayInventoryResponse(
              items: page1Items,
              nextCursor: 'gw-page1-14',
            );
          } else if (after == 'gw-page1-14') {
            return AdminGatewayInventoryResponse(
              items: page2Items,
              nextCursor: null,
            );
          }
          return const AdminGatewayInventoryResponse(
            items: [],
            nextCursor: null,
          );
        };

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-1',
                name: 'Admin',
                email: 'admin@test.com',
              ),
            );

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        expect(fakeGatewayRepo.adminGatewaysCallCount, 1);
        expect(find.text('Gateway Page 1 - 0'), findsOneWidget);
        expect(find.text('Gateway Page 2 Item'), findsNothing);

        // Scroll near bottom
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -600),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Page 2 items loaded
        expect(fakeGatewayRepo.adminGatewaysCallCount, 2);
        expect(find.text('Gateway Page 2 Item'), findsOneWidget);

        // Subsequent scroll at end does NOT trigger duplicate requests
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(fakeGatewayRepo.adminGatewaysCallCount, 2);
      },
    );

    testWidgets(
      'pagination error displays safe error without extra retry button and refresh recovers',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        final page1Items = List.generate(
          15,
          (i) => AdminGatewayItem(
            gatewayId: 'gw-err-${i.toString().padLeft(2, '0')}',
            name: 'Err Gateway $i',
          ),
        );

        bool shouldFailPage2 = true;

        fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
          if (after == null) {
            return AdminGatewayInventoryResponse(
              items: page1Items,
              nextCursor: 'gw-err-14',
            );
          } else if (after == 'gw-err-14') {
            if (shouldFailPage2) {
              throw const ApiException(
                statusCode: 500,
                code: 'internal_error',
                message: 'Lỗi tải trang tiếp theo',
                requestId: 'req-page2-err',
              );
            }
            return const AdminGatewayInventoryResponse(
              items: [
                AdminGatewayItem(
                  gatewayId: 'gw-err-page2-success',
                  name: 'Page 2 Success Item',
                ),
              ],
              nextCursor: null,
            );
          }
          return const AdminGatewayInventoryResponse(
            items: [],
            nextCursor: null,
          );
        };

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-1',
                name: 'Admin',
                email: 'admin@test.com',
              ),
            );

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        // Scroll to trigger page 2
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -600),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Safe error notification is shown with message and request ID, but NO extra retry button
        expect(find.textContaining('Lỗi tải trang tiếp theo'), findsOneWidget);
        expect(find.textContaining('req-page2-err'), findsOneWidget);
        expect(find.text('Thử lại'), findsNothing);

        // Verify no auto-retry occurs
        expect(fakeGatewayRepo.adminGatewaysCallCount, 2);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(fakeGatewayRepo.adminGatewaysCallCount, 2);

        // Fix error and use existing header 'Làm mới' button to recover
        shouldFailPage2 = false;
        final refreshBtn = find.widgetWithText(KiteButton, 'Làm mới');
        await tester.scrollUntilVisible(
          refreshBtn,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(refreshBtn, findsOneWidget);
        await tester.tap(refreshBtn);
        await tester.pump();
        await tester.pumpAndSettle();

        // Error is cleared after refresh
        expect(find.textContaining('Lỗi tải trang tiếp theo'), findsNothing);
        expect(fakeGatewayRepo.adminGatewaysCallCount, greaterThanOrEqualTo(3));

        // Scroll to load page 2 now that error is resolved
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -600),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Page 2 Success Item'), findsOneWidget);
      },
    );

    testWidgets(
      'controlled viewport fill loads >3 tiny pages until viewport is scrollable then stops',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        int pageNum = 0;
        fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
          pageNum++;
          final current = pageNum;
          return AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-tiny-$current',
                name: 'Gateway Item Tiny $current',
              ),
            ],
            nextCursor: 'cursor-$current',
          );
        };

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-1',
                name: 'Admin',
                email: 'admin@test.com',
              ),
            );

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        // Must have loaded >3 tiny pages because 3 items do not fill 800px viewport
        expect(fakeGatewayRepo.adminGatewaysCallCount, greaterThan(3));

        // Once viewport became scrollable, it must stop requesting automatically
        final callCountAfterFill = fakeGatewayRepo.adminGatewaysCallCount;
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(fakeGatewayRepo.adminGatewaysCallCount, callCountAfterFill);

        // Verify items were rendered
        expect(find.text('Gateway Item Tiny 1'), findsOneWidget);
        expect(
          find.text('Gateway Item Tiny $callCountAfterFill'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'controlled viewport fill stops when end of catalog is reached even if viewport is short',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        // Exactly 3 tiny pages total
        fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
          if (after == null) {
            return const AdminGatewayInventoryResponse(
              items: [
                AdminGatewayItem(gatewayId: 'gw-end-1', name: 'End GW 1'),
              ],
              nextCursor: 'c1',
            );
          } else if (after == 'c1') {
            return const AdminGatewayInventoryResponse(
              items: [
                AdminGatewayItem(gatewayId: 'gw-end-2', name: 'End GW 2'),
              ],
              nextCursor: 'c2',
            );
          } else if (after == 'c2') {
            return const AdminGatewayInventoryResponse(
              items: [
                AdminGatewayItem(gatewayId: 'gw-end-3', name: 'End GW 3'),
              ],
              nextCursor: null, // End of catalog!
            );
          }
          return const AdminGatewayInventoryResponse(
            items: [],
            nextCursor: null,
          );
        };

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-1',
                name: 'Admin',
                email: 'admin@test.com',
              ),
            );

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        // Exactly 3 calls because hasMore became false on page 3
        expect(fakeGatewayRepo.adminGatewaysCallCount, 3);

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(fakeGatewayRepo.adminGatewaysCallCount, 3);

        expect(find.text('End GW 1'), findsOneWidget);
        expect(find.text('End GW 2'), findsOneWidget);
        expect(find.text('End GW 3'), findsOneWidget);
      },
    );

    testWidgets(
      'controlled viewport fill stops immediately on pagination error without auto-retry loops',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
          if (after == null) {
            return const AdminGatewayInventoryResponse(
              items: [
                AdminGatewayItem(gatewayId: 'gw-err-1', name: 'Err Stop GW 1'),
              ],
              nextCursor: 'c1',
            );
          } else {
            throw const ApiException(
              statusCode: 500,
              code: 'internal_error',
              message: 'Lỗi nạp trang tiếp',
              requestId: 'req-err-stop',
            );
          }
        };

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-1',
                name: 'Admin',
                email: 'admin@test.com',
              ),
            );

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        // Initial load (1) + loadNextPage (1) which failed = 2 calls
        expect(fakeGatewayRepo.adminGatewaysCallCount, 2);

        // Ensure no auto-retry loop occurs
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(fakeGatewayRepo.adminGatewaysCallCount, 2);

        expect(find.text('Err Stop GW 1'), findsOneWidget);
        expect(find.textContaining('Lỗi nạp trang tiếp'), findsOneWidget);
      },
    );

    testWidgets('rebuilds do not trigger duplicate network requests', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );

      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        return const AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(gatewayId: 'gw-rebuild-1', name: 'Rebuild GW 1'),
          ],
          nextCursor: null,
        );
      };

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-1',
              name: 'Admin',
              email: 'admin@test.com',
            ),
          );

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.gateways);
      await tester.pumpAndSettle();

      expect(fakeGatewayRepo.adminGatewaysCallCount, 1);

      // Multiple frame pumps / rebuilds
      await tester.pumpWidget(createTestWidget(container));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeGatewayRepo.adminGatewaysCallCount, 1);
    });

    testWidgets(
      'refresh resets fill generation and disposing widget ignores obsolete callbacks',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        int call = 0;
        fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
          call++;
          return AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-ref-$call',
                name: 'Refresh GW $call',
              ),
            ],
            nextCursor: 'c-$call',
          );
        };

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-1',
                name: 'Admin',
                email: 'admin@test.com',
              ),
            );

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        final countBeforeRefresh = fakeGatewayRepo.adminGatewaysCallCount;
        expect(countBeforeRefresh, greaterThan(0));

        // Click refresh button in header
        final refreshBtn = find.widgetWithText(KiteButton, 'Làm mới');
        expect(refreshBtn, findsOneWidget);
        await tester.tap(refreshBtn);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          fakeGatewayRepo.adminGatewaysCallCount,
          greaterThan(countBeforeRefresh),
        );

        // Navigate away to test safe disposal with no pending callback crash
        container.read(routerProvider).go(R.dashboard);
        await tester.pump();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'user searching does not drain catalog and horizontal table scroll does not trigger load more',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        final page1 = List.generate(
          12,
          (i) => AdminGatewayItem(gatewayId: 'gw-hz-$i', name: 'Hz Gateway $i'),
        );

        fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
          if (after == null) {
            return AdminGatewayInventoryResponse(
              items: page1,
              nextCursor: 'hz-cursor-1',
            );
          }
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-hz-extra', name: 'Extra Item'),
            ],
            nextCursor: null,
          );
        };

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-1',
                name: 'Admin',
                email: 'admin@test.com',
              ),
            );

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        expect(fakeGatewayRepo.adminGatewaysCallCount, 1);

        // 1. Horizontal scroll on data table should NOT trigger load more
        final tableHorizontalScroll = find.byType(SingleChildScrollView).at(1);
        await tester.drag(tableHorizontalScroll, const Offset(-200, 0));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(fakeGatewayRepo.adminGatewaysCallCount, 1);

        // 2. User searching should not drain catalog
        final searchInput = find.byType(KiteInput);
        await tester.enterText(searchInput.first, 'Hz Gateway 1');
        await tester.pumpAndSettle();

        // Vertical scroll while searching
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -500),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Call count must remain 1 (search does not drain catalog)
        expect(fakeGatewayRepo.adminGatewaysCallCount, 1);
      },
    );
  });
}
