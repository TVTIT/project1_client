import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/core/router/app_router.dart';
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

  void setupAuthenticatedUser(ProviderContainer container) {
    container
        .read(sessionProvider.notifier)
        .setSession(
          const SessionUser(
            userId: 'user-uuid-1',
            name: 'Nguyen Van A',
            email: 'user@example.com',
          ),
        );
  }

  testWidgets(
    'unauthenticated user attempting to access /gateways/:gatewayId is redirected to /sign-in',
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

      container.read(routerProvider).go('/gateways/gw-001');
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập'), findsWidgets);
      expect(find.text('Chi tiết Gateway: gw-001'), findsNothing);
    },
  );

  testWidgets(
    'authenticated user deep linking to /gateways/:gatewayId sees composed metadata & sensors',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-001',
          name: 'AM5728 Station Alpha',
          role: GatewayRole.owner,
          description: 'Trạm quan trắc nhà kính số 1',
        ),
      ];
      fakeGatewayRepo.sensorsMap = {
        'gw-001': [
          const SensorItem(
            sensorId: 'sensor_temp',
            name: 'Ambient Temperature',
            unit: '°C',
          ),
          const SensorItem(
            sensorId: 'sensor_humidity',
            name: 'Air Humidity',
            unit: '%',
          ),
        ],
      };

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
        ],
      );
      addTearDown(container.dispose);
      setupAuthenticatedUser(container);

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go('/gateways/gw-001');
      await tester.pumpAndSettle();

      // Check Gateway details rendered
      expect(find.text('Chi tiết Gateway: gw-001'), findsOneWidget);
      expect(find.text('AM5728 Station Alpha'), findsOneWidget);
      expect(find.text('Trạm quan trắc nhà kính số 1'), findsOneWidget);
      expect(find.text('Chủ sở hữu'), findsWidgets);

      // Switch to Sensor Catalog tab
      await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
      await tester.pumpAndSettle();

      // Check Sensors rendered
      expect(find.text('sensor_temp'), findsOneWidget);
      expect(find.text('Ambient Temperature'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);
      expect(find.text('sensor_humidity'), findsOneWidget);
      expect(find.text('Air Humidity'), findsOneWidget);

      // Check Stage 2 read-only banner
      expect(
        find.text(
          'Chế độ chỉ đọc (Giai đoạn 2). Tính năng điều khiển từ xa, lệnh downlink và đo từ xa thời gian thực chưa được kích hoạt.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'foreign or non-existent gateway deep link retains URL, shows 404, and allows returning to list',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // User only has access to gw-authorized
      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-authorized',
          name: 'Authorized GW',
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
      setupAuthenticatedUser(container);

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      // Navigate to foreign gateway
      container.read(routerProvider).go('/gateways/gw-foreign-999');
      await tester.pumpAndSettle();

      // Anti-enumeration 404
      expect(find.text('Không tìm thấy Gateway'), findsOneWidget);
      expect(
        find.text(
          'Trạm kết nối không tồn tại hoặc tài khoản của bạn chưa được cấp quyền truy cập.',
        ),
        findsOneWidget,
      );

      // Back to list button works
      expect(find.text('Quay lại danh sách Gateway'), findsWidgets);
      await tester.tap(find.text('Quay lại danh sách Gateway').first);
      await tester.pumpAndSettle();

      // Returned to list
      expect(find.text('Authorized GW'), findsOneWidget);
    },
  );

  testWidgets(
    'invalid gateway ID syntax shows invalid format message and allows back to list',
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
      setupAuthenticatedUser(container);

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go('/gateways/backend_service');
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy Gateway'), findsOneWidget);
      expect(
        find.text(
          'Mã trạm Gateway không đúng định dạng hoặc chứa định danh hệ thống dành riêng.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Quay lại danh sách Gateway').first);
      await tester.pumpAndSettle();

      expect(find.text('Quản lý Gateway'), findsWidgets);
    },
  );

  testWidgets('empty sensor catalog shows empty state without error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    fakeGatewayRepo.items = [
      const GatewayItem(
        gatewayId: 'gw-empty',
        name: 'Empty Station',
        role: GatewayRole.operator,
      ),
    ];
    fakeGatewayRepo.sensorsMap = {'gw-empty': []};

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuthRepo),
        gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
        permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
      ],
    );
    addTearDown(container.dispose);
    setupAuthenticatedUser(container);

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    container.read(routerProvider).go('/gateways/gw-empty');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
    await tester.pumpAndSettle();

    expect(find.text('Empty Station'), findsOneWidget);
    expect(find.text('Chưa có cảm biến nào'), findsOneWidget);
    expect(
      find.text('Trạm Gateway này hiện chưa được cấu hình cảm biến nào.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'sensors failure exposes sensor error banner while displaying gateway details, and retry recovers',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-001',
          name: 'Station 001',
          role: GatewayRole.viewer,
        ),
      ];
      fakeGatewayRepo.shouldThrowSensors = true;
      fakeGatewayRepo.sensorsErrorToThrow = const ApiException(
        statusCode: 503,
        code: 'service_unavailable',
        message: 'Sensors DB busy',
      );

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
        ],
      );
      addTearDown(container.dispose);
      setupAuthenticatedUser(container);

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go('/gateways/gw-001');
      await tester.pumpAndSettle();

      // Metadata is displayed
      expect(find.text('Station 001'), findsOneWidget);

      // Sensor error banner is displayed
      expect(find.text('Không thể tải danh sách cảm biến'), findsOneWidget);
      expect(find.text('Thử tải lại cảm biến'), findsOneWidget);

      // Now recover sensors
      fakeGatewayRepo.shouldThrowSensors = false;
      fakeGatewayRepo.sensorsMap = {
        'gw-001': [
          const SensorItem(
            sensorId: 'sensor_rec',
            name: 'Recovered Sensor',
            unit: 'V',
          ),
        ],
      };

      // Tap retry on sensors banner
      await tester.tap(find.text('Thử tải lại cảm biến'));
      await tester.pumpAndSettle();

      // Sensors are recovered
      expect(find.text('Không thể tải danh sách cảm biến'), findsNothing);
      await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
      await tester.pumpAndSettle();
      expect(find.text('Recovered Sensor'), findsOneWidget);
      expect(find.text('sensor_rec'), findsOneWidget);
    },
  );

  testWidgets(
    'search filtering in sensor list filters by sensor ID, name, or unit',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-001',
          name: 'Station 001',
          role: GatewayRole.owner,
        ),
      ];
      fakeGatewayRepo.sensorsMap = {
        'gw-001': [
          const SensorItem(
            sensorId: 'sensor_temp',
            name: 'Temperature',
            unit: '°C',
          ),
          const SensorItem(
            sensorId: 'sensor_press',
            name: 'Pressure',
            unit: 'bar',
          ),
        ],
      };

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
        ],
      );
      addTearDown(container.dispose);
      setupAuthenticatedUser(container);

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go('/gateways/gw-001');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
      await tester.pumpAndSettle();

      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Pressure'), findsOneWidget);

      // Enter search query 'temp'
      final searchInput = find.byType(KiteInput);
      await tester.enterText(searchInput.first, 'temp');
      await tester.pumpAndSettle();

      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Pressure'), findsNothing);

      // Clear search
      await tester.enterText(searchInput.first, '');
      await tester.pumpAndSettle();

      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Pressure'), findsOneWidget);
    },
  );

  group('Responsive Layout Verification for Detail Screen', () {
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
            gatewayId: 'gw-resp',
            name: 'Responsive Gateway',
            role: GatewayRole.operator,
            description:
                'Long description to test overflow across screen widths',
          ),
        ];
        fakeGatewayRepo.sensorsMap = {
          'gw-resp': [
            const SensorItem(sensorId: 's1', name: 'Sensor 1', unit: 'mA'),
          ],
        };

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);
        setupAuthenticatedUser(container);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go('/gateways/gw-resp');
        await tester.pumpAndSettle();

        final tab = find.byKey(const Key('tab-sensor-catalog'));
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();

        expect(find.text('Responsive Gateway'), findsOneWidget);
        expect(find.text('Sensor 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Task 3: Admin Foreign Gateway & Sensor Access Denial Scenarios', () {
    testWidgets(
      'admin foreign deep link on later page resolves metadata, renders denial message, and allows create sensor',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Admin user
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        // User catalog has NO gateways for this admin
        fakeGatewayRepo.items = [];

        // Admin inventory has 2 pages; target gateway 'gw-page2-target' is on page 2
        fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
          if (after == null) {
            return const AdminGatewayInventoryResponse(
              items: [
                AdminGatewayItem(
                  gatewayId: 'gw-page1-01',
                  name: 'Page 1 First',
                ),
                AdminGatewayItem(
                  gatewayId: 'gw-page1-02',
                  name: 'Page 1 Second',
                ),
              ],
              nextCursor: 'gw-page1-02',
            );
          } else if (after == 'gw-page1-02') {
            return const AdminGatewayInventoryResponse(
              items: [
                AdminGatewayItem(
                  gatewayId: 'gw-page2-target',
                  name: 'Target Station on Page 2',
                  description: 'Station found via cursor lookup',
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

        container.read(routerProvider).go('/gateways/gw-page2-target');
        await tester.pumpAndSettle();

        // Real metadata resolved and displayed!
        expect(find.text('Target Station on Page 2'), findsOneWidget);
        expect(find.text('gw-page2-target'), findsWidgets);
        expect(find.text('Station found via cursor lookup'), findsOneWidget);
        // Role is "—" (null role, never fake admin/owner badge)
        expect(find.text('—'), findsWidgets);
        expect(find.text('Chủ sở hữu'), findsNothing);

        // Sensor area shows exact Vietnamese text
        expect(
          find.text(
            'Bạn không có quyền truy cập danh sách Sensor của Gateway này.',
          ),
          findsOneWidget,
        );

        // Does NOT show empty sensor state
        expect(find.text('Chưa có cảm biến nào'), findsNothing);

        // Admin still allowed to see "Thêm cảm biến mới" button
        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();
        expect(find.text('Thêm cảm biến mới'), findsOneWidget);
      },
    );

    testWidgets(
      'admin assigned gateway renders normal user sensor reads with role badge',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        // Admin is assigned in user_gateways as owner
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-admin-assigned',
            name: 'Admin Assigned Gateway',
            role: GatewayRole.owner,
          ),
        ];
        fakeGatewayRepo.sensorsMap = {
          'gw-admin-assigned': [
            const SensorItem(
              sensorId: 'sensor-temp',
              name: 'Temperature Sensor',
              unit: '°C',
            ),
            const SensorItem(
              sensorId: 'sensor-hum',
              name: 'Humidity Sensor',
              unit: '%',
            ),
          ],
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

        container.read(routerProvider).go('/gateways/gw-admin-assigned');
        await tester.pumpAndSettle();

        // Metadata card has real role badge
        expect(find.text('Admin Assigned Gateway'), findsOneWidget);
        expect(find.text('Chủ sở hữu'), findsWidgets);

        // Sensors are loaded normally
        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();
        expect(find.text('Temperature Sensor'), findsOneWidget);
        expect(find.text('Humidity Sensor'), findsOneWidget);
        expect(
          find.text(
            'Bạn không có quyền truy cập danh sách Sensor của Gateway này.',
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'transient membership error displays honest error and retry action, not denial',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.shouldThrow = true;
        fakeGatewayRepo.errorToThrow = const ApiException(
          statusCode: 500,
          code: 'internal_error',
          message: 'Lỗi máy chủ khi truy vấn danh mục trạm',
          requestId: 'req-member-err-500',
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
                name: 'Admin',
                email: 'admin@test.com',
              ),
            );

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go('/gateways/gw-any');
        await tester.pumpAndSettle();

        // Honest error state is displayed, NOT denied and NOT 404
        expect(
          find.textContaining('Lỗi máy chủ khi truy vấn danh mục trạm'),
          findsOneWidget,
        );
        expect(find.textContaining('req-member-err-500'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(
          find.text(
            'Bạn không có quyền truy cập danh sách Sensor của Gateway này.',
          ),
          findsNothing,
        );
        expect(find.text('Không tìm thấy Gateway'), findsNothing);
      },
    );

    testWidgets(
      'loaded gateway with retained metadata shows error and retry on refresh failure, clears stale sensors, and recovers on retry',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: false,
        );
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-refresh-test',
            name: 'Active Station Alpha',
            role: GatewayRole.owner,
            description: 'Station for testing refresh failures',
          ),
        ];
        fakeGatewayRepo.sensorsMap = {
          'gw-refresh-test': [
            const SensorItem(
              sensorId: 'sensor-temp-1',
              name: 'Temperature Sensor',
              unit: '°C',
            ),
          ],
        };

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        setupAuthenticatedUser(container);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go('/gateways/gw-refresh-test');
        await tester.pumpAndSettle();

        // Initially loaded successfully with metadata and sensors
        expect(find.text('Active Station Alpha'), findsOneWidget);
        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();
        expect(find.text('Temperature Sensor'), findsOneWidget);
        expect(find.text('Try again'), findsNothing);

        // Simulate refresh failure (server returns 500)
        fakeGatewayRepo.shouldThrow = true;
        fakeGatewayRepo.errorToThrow = const ApiException(
          statusCode: 500,
          code: 'internal_error',
          message: 'Lỗi máy chủ khi làm mới thông tin trạm',
          requestId: 'req-refresh-fail-500',
        );

        // Tap refresh button in header
        await tester.tap(find.text('Làm mới'));
        await tester.pumpAndSettle();

        // Verify state: error is shown, stale metadata and stale sensors are NOT displayed
        expect(
          find.textContaining('Lỗi máy chủ khi làm mới thông tin trạm'),
          findsOneWidget,
        );
        expect(find.textContaining('req-refresh-fail-500'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('Active Station Alpha'), findsNothing);
        expect(find.text('Temperature Sensor'), findsNothing);

        // Recover on retry
        fakeGatewayRepo.shouldThrow = false;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        // Metadata and sensors are restored
        expect(find.text('Active Station Alpha'), findsOneWidget);
        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();
        expect(find.text('Temperature Sensor'), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
        expect(
          find.textContaining('Lỗi máy chủ khi làm mới thông tin trạm'),
          findsNothing,
        );
      },
    );
  });
}
