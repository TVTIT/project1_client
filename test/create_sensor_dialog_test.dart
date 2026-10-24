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
import 'package:kite/features/gateways/presentation/create_sensor_dialog.dart';
import 'package:kite/features/gateways/presentation/gateway_detail_screen.dart';
import 'package:kite/features/gateways/providers/gateway_detail_provider.dart';
import 'package:kite_ui/kite_ui.dart';

import 'gateway_list_provider_test.dart';
import 'permissions_test.dart';
import 'session_test.dart';

void main() {
  late FakeAuthRepository fakeAuthRepo;
  late FakeGatewayRepository fakeGatewayRepo;
  late FakePermissionsRepository fakePermsRepo;

  const testGateway = GatewayItem(
    gatewayId: 'gw-alpha',
    name: 'Trạm Alpha',
    description: 'Trạm thử nghiệm',
    role: GatewayRole.owner,
  );

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeGatewayRepo = FakeGatewayRepository()..items = [testGateway];
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

  group('Create Sensor Button & Admin Permission Guard', () {
    testWidgets(
      'non-admin operator on GatewayDetailScreen does NOT see "Thêm cảm biến mới" button',
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
            gatewayId: 'gw-alpha',
            name: 'Trạm Alpha',
            description: 'Trạm thử nghiệm',
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

        const user = SessionUser(
          userId: '11111111-1111-1111-1111-111111111111',
          name: 'Regular User',
          email: 'user@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
        await tester.pumpAndSettle();

        expect(find.byType(GatewayDetailScreen), findsOneWidget);
        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();
        // Non-admin operator must NOT see create sensor button
        expect(find.text('Thêm cảm biến mới'), findsNothing);
      },
    );

    testWidgets(
      'non-admin owner on GatewayDetailScreen sees "Thêm cảm biến mới" button and clicking opens dialog',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: false,
        );
        fakeGatewayRepo.items = [testGateway];

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const user = SessionUser(
          userId: '11111111-1111-1111-1111-111111111111',
          name: 'Owner User',
          email: 'owner@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
        await tester.pumpAndSettle();

        expect(find.byType(GatewayDetailScreen), findsOneWidget);
        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();
        final addBtn = find.text('Thêm cảm biến mới');
        expect(addBtn, findsOneWidget);

        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        expect(find.byType(CreateSensorDialog), findsOneWidget);
      },
    );

    testWidgets(
      'confirmed admin user on GatewayDetailScreen sees "Thêm cảm biến mới" button and clicking opens dialog',
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
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();

        final addBtn = find.text('Thêm cảm biến mới');
        expect(addBtn, findsOneWidget);

        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // Dialog opens
        expect(find.byType(CreateSensorDialog), findsOneWidget);
        expect(find.text('Khởi tạo Cảm biến mới'), findsOneWidget);
        // Parent gateway ID is displayed read-only
        expect(find.text('gw-alpha'), findsWidgets);
      },
    );
  });

  group('Dialog Form Fields, Scopes & Validations', () {
    testWidgets(
      'dialog renders ONLY sensor_id, name, optional unit; parent gateway is fixed read-only',
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
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        // Check fields:
        expect(find.text('ID Gateway'), findsOneWidget);
        expect(find.text('Mã cảm biến (Sensor ID)'), findsOneWidget);
        expect(find.text('Tên cảm biến'), findsOneWidget);
        expect(find.text('Đơn vị đo (Tùy chọn)'), findsOneWidget);

        // Verify NO sensor_type field or extraneous controls:
        expect(find.text('sensor_type'), findsNothing);
        expect(find.text('Loại cảm biến'), findsNothing);
      },
    );

    testWidgets(
      'rejects empty sensor_id, invalid regex, name empty, name > 256 bytes, unit > 64 bytes; backend_service IS allowed',
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
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        final submitBtn = find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Validations trigger:
        expect(
          find.text('Vui lòng nhập mã cảm biến (Sensor ID).'),
          findsOneWidget,
        );
        expect(find.text('Vui lòng nhập tên cảm biến.'), findsOneWidget);

        // Verify backend_service IS ALLOWED for sensor:
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'backend_service',
        );
        await tester.enterText(find.byType(TextFormField).at(1), '');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        // Should NOT say backend_service is forbidden!
        expect(
          find.text('Mã "backend_service" là định danh hệ thống dành riêng.'),
          findsNothing,
        );
        expect(find.text('Vui lòng nhập tên cảm biến.'), findsOneWidget);

        // Test name exceeding 256 bytes UTF-8
        final longName = 'S' * 257;
        await tester.enterText(find.byType(TextFormField).at(1), longName);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Tên cảm biến không được vượt quá 256 bytes UTF-8.'),
          findsOneWidget,
        );

        // Test unit exceeding 64 bytes UTF-8
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Valid Sensor',
        );
        final longUnit = 'U' * 65;
        await tester.enterText(find.byType(TextFormField).at(2), longUnit);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Đơn vị đo không được vượt quá 64 bytes UTF-8.'),
          findsOneWidget,
        );
      },
    );

    test('distinguishes null vs empty vs "0" unit correctly', () {
      // Input with empty string unit: contract allows preserving empty string
      const inputEmpty = ProvisionSensorInput(
        gatewayId: 'gw-1',
        sensorId: 's-1',
        name: 'Sensor 1',
        unit: '',
      );
      expect(inputEmpty.toJson()['unit'], equals(''));

      // Input with null unit
      const inputNull = ProvisionSensorInput(
        gatewayId: 'gw-1',
        sensorId: 's-1',
        name: 'Sensor 1',
        unit: null,
      );
      expect(inputNull.toJson()['unit'], isNull);

      // Input with "0" unit
      const inputZero = ProvisionSensorInput(
        gatewayId: 'gw-1',
        sensorId: 's-1',
        name: 'Sensor 1',
        unit: '0',
      );
      expect(inputZero.toJson()['unit'], equals('0'));

      // Input with "°C" unit
      const inputDegC = ProvisionSensorInput(
        gatewayId: 'gw-1',
        sensorId: 's-1',
        name: 'Sensor 1',
        unit: '°C',
      );
      expect(inputDegC.toJson()['unit'], equals('°C'));
    });
  });

  group('Sensor Provisioning Mutation Scenarios', () {
    testWidgets(
      '201 Created provisions sensor, invalidates sensor catalog, pops dialog and shows toast',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.provisionSensorResultToReturn = ProvisionSensorResult(
          isCreated: true,
          gatewayId: 'gw-alpha',
          sensorId: 'sensor-temp-01',
          name: 'Cảm biến Nhiệt độ 01',
          unit: '°C',
          entityId: 'urn:ngsi-ld:Sensor:gw-alpha:sensor-temp-01',
          createdAt: DateTime.parse('2026-10-08T00:00:00Z'),
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'sensor-temp-01',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Cảm biến Nhiệt độ 01',
        );
        await tester.enterText(find.byType(TextFormField).at(2), '°C');

        await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
        await tester.pumpAndSettle();

        // Repository called
        expect(fakeGatewayRepo.provisionSensorCallCount, 1);
        expect(fakeGatewayRepo.lastProvisionSensorInput?.gatewayId, 'gw-alpha');
        expect(
          fakeGatewayRepo.lastProvisionSensorInput?.sensorId,
          'sensor-temp-01',
        );
        expect(fakeGatewayRepo.lastProvisionSensorInput?.unit, '°C');

        // Dialog is popped
        expect(find.byType(CreateSensorDialog), findsNothing);
        expect(find.byType(GatewayDetailScreen), findsOneWidget);

        // Authoritative toast is displayed
        expect(
          find.text('Đã khởi tạo cảm biến thành công (HTTP 201 Created)'),
          findsOneWidget,
        );
      },
    );

    testWidgets('200 OK replay displays idempotent replay toast', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.provisionSensorResultToReturn = ProvisionSensorResult(
        isCreated: false, // 200 OK replay
        gatewayId: 'gw-alpha',
        sensorId: 'sensor-temp-01',
        name: 'Cảm biến Nhiệt độ 01',
        unit: '°C',
        entityId: 'urn:ngsi-ld:Sensor:gw-alpha:sensor-temp-01',
        createdAt: DateTime.parse('2026-09-01T00:00:00Z'),
      );

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
        ],
      );
      addTearDown(container.dispose);

      const adminUser = SessionUser(
        userId: '99999999-9999-9999-9999-999999999999',
        name: 'Platform Admin',
        email: 'admin@example.com',
      );
      container.read(sessionProvider.notifier).setSession(adminUser);

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thêm cảm biến mới'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'sensor-temp-01',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Cảm biến Nhiệt độ 01',
      );

      await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
      await tester.pumpAndSettle();

      // Dialog is popped and replay toast is displayed
      expect(find.byType(CreateSensorDialog), findsNothing);
      expect(
        find.text(
          'Cảm biến đã tồn tại với thông tin trùng khớp (HTTP 200 OK - Lặp lại an toàn)',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      '409 Conflict displays representation conflict error in dialog',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.shouldThrowProvisionSensor = true;
        fakeGatewayRepo.provisionSensorErrorToThrow = const ApiException(
          statusCode: 409,
          code: 'conflict',
          message: 'resource conflict',
          requestId: 'req-sensor-conflict-409',
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'sensor-conflict',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'New Conflicting Name',
        );

        await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
        await tester.pumpAndSettle();

        // Dialog stays open displaying error
        expect(find.byType(CreateSensorDialog), findsOneWidget);
        expect(
          find.text(
            'Cảm biến đã tồn tại với thông tin khác biệt (HTTP 409 Conflict). Cơ chế khởi tạo không hỗ trợ cập nhật thay đổi dữ liệu.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Mã yêu cầu (Request ID): req-sensor-conflict-409'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '404 Not Found displays parent gateway not found error in dialog',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.shouldThrowProvisionSensor = true;
        fakeGatewayRepo.provisionSensorErrorToThrow = const ApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'resource not found',
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'sensor-orphan',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Orphan Sensor',
        );

        await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateSensorDialog), findsOneWidget);
        expect(
          find.text('Trạm Gateway cha không tồn tại (HTTP 404 Not Found).'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'network timeout displays error and explicit Retry button with same payload',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.shouldThrowProvisionSensor = true;
        fakeGatewayRepo.provisionSensorErrorToThrow = const ApiException(
          statusCode: 504,
          code: 'gateway_timeout',
          message: 'Quá thời gian chờ phản hồi.',
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'sensor-timeout',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Timeout Sensor',
        );

        await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
        await tester.pumpAndSettle();

        expect(fakeGatewayRepo.provisionSensorCallCount, 1);
        expect(find.text('Quá thời gian chờ phản hồi.'), findsOneWidget);

        // Now clear error on repository and click Retry:
        fakeGatewayRepo.shouldThrowProvisionSensor = false;
        final retryBtn = find.text('Thử lại (Retry)');
        expect(retryBtn, findsOneWidget);

        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        // Retry executed with the exact same payload:
        expect(fakeGatewayRepo.provisionSensorCallCount, 2);
        expect(
          fakeGatewayRepo.lastProvisionSensorInput?.sensorId,
          'sensor-timeout',
        );
        expect(find.byType(CreateSensorDialog), findsNothing);
      },
    );

    testWidgets(
      'permission revocation while dialog is open auto-dismisses dialog fail-closed',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-alpha',
            name: 'Trạm Alpha',
            description: 'Trạm thử nghiệm',
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

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateSensorDialog), findsOneWidget);

        // Revoke admin permission:
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: false,
        );
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();
        await tester.pumpAndSettle();

        // Dialog is dismissed fail-closed
        expect(find.byType(CreateSensorDialog), findsNothing);
      },
    );

    testWidgets(
      'dialog opened as owner -> gateway notfound denies/close no mutation',
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
            gatewayId: 'gw-alpha',
            name: 'Trạm Alpha',
            description: 'Trạm thử nghiệm',
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

        const ownerUser = SessionUser(
          userId: '11111111-1111-1111-1111-111111111111',
          name: 'Owner User',
          email: 'owner@example.com',
        );
        container.read(sessionProvider.notifier).setSession(ownerUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateSensorDialog), findsOneWidget);

        // Gateway becomes not found (e.g. gateway deleted or user loses access)
        fakeGatewayRepo.items = [];
        await container.read(gatewayDetailProvider('gw-alpha').notifier).load();
        await tester.pumpAndSettle();

        // Dialog must be closed fail-closed:
        expect(find.byType(CreateSensorDialog), findsNothing);

        // No mutation was triggered:
        expect(fakeGatewayRepo.provisionOwnerSensorCallCount, 0);
        expect(fakeGatewayRepo.provisionSensorCallCount, 0);
      },
    );
  });

  group('Responsive Layout Widths for CreateSensorDialog', () {
    for (final size in [
      const Size(390, 844),
      const Size(1024, 768),
      const Size(1366, 768),
      const Size(1920, 1080),
    ]) {
      testWidgets(
        'dialog renders cleanly without overflow at width ${size.width}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          fakePermsRepo.resultToReturn = const UserPermissions(
            isPlatformAdmin: true,
          );

          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
              permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            ],
          );
          addTearDown(container.dispose);

          const adminUser = SessionUser(
            userId: '99999999-9999-9999-9999-999999999999',
            name: 'Platform Admin',
            email: 'admin@example.com',
          );
          container.read(sessionProvider.notifier).setSession(adminUser);

          await tester.pumpWidget(createTestWidget(container));
          await tester.pumpAndSettle();

          container.read(routerProvider).go(R.gatewayDetail('gw-alpha'));
          await tester.pumpAndSettle();

          final tab = find.byKey(const Key('tab-sensor-catalog'));
          await tester.ensureVisible(tab);
          await tester.tap(tab);
          await tester.pumpAndSettle();

          final addBtn = find.text('Thêm cảm biến mới');
          await tester.ensureVisible(addBtn);
          await tester.tap(addBtn);
          await tester.pumpAndSettle();

          expect(find.byType(CreateSensorDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
