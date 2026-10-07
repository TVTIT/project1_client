import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite_ui/kite_ui.dart';

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

      // Check Sensors rendered
      expect(find.text('Danh sách Cảm biến'), findsOneWidget);
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
      ],
    );
    addTearDown(container.dispose);
    setupAuthenticatedUser(container);

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    container.read(routerProvider).go('/gateways/gw-empty');
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
        ],
      );
      addTearDown(container.dispose);
      setupAuthenticatedUser(container);

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go('/gateways/gw-001');
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
          ],
        );
        addTearDown(container.dispose);
        setupAuthenticatedUser(container);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go('/gateways/gw-resp');
        await tester.pumpAndSettle();

        expect(find.text('Responsive Gateway'), findsOneWidget);
        expect(find.text('Sensor 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
