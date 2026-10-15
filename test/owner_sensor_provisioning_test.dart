import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/core/router/routes.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite/features/gateways/presentation/create_sensor_dialog.dart';
import 'package:kite/features/gateways/providers/gateway_detail_provider.dart';
import 'package:kite_ui/kite_ui.dart';

import 'gateway_list_provider_test.dart';
import 'permissions_test.dart';
import 'session_test.dart';

void main() {
  group('HttpGatewayRepository.provisionOwnerSensor (Owner Sensor PUT)', () {
    late FakeAuthRepository authRepo;

    setUp(() {
      authRepo = FakeAuthRepository();
    });

    tearDown(() {
      authRepo.dispose();
    });

    test('exact owner path, PUT verb, headers, no Idempotency-Key, body only name and unit (201 Created)', () async {
      await authRepo.signInWithPassword(
        email: 'owner@example.com',
        password: 'password',
      );

      late http.Request capturedRequest;
      final mockHttp = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'gateway_id': 'gw-001',
            'sensor_id': 'sensor-temp',
            'name': 'Ambient Temp Sensor',
            'unit': '°C',
            'entity_id': 'urn:ngsi-ld:Sensor:gw-001:sensor-temp',
            'created_at': '2026-10-15T10:00:00Z',
          }),
          201,
          headers: {
            'content-type': 'application/json',
            'cache-control': 'no-store',
            'pragma': 'no-cache',
            'x-request-id': 'req-owner-create-201',
          },
        );
      });

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );
      final repo = HttpGatewayRepository(client);

      const input = ProvisionSensorInput(
        gatewayId: 'gw-001',
        sensorId: 'sensor-temp',
        name: 'Ambient Temp Sensor',
        unit: '°C',
      );

      final result = await repo.provisionOwnerSensor(input);

      // Path check: must NOT have admin prefix, must NOT have query parameters
      expect(
        capturedRequest.url.toString(),
        'http://localhost/v1/gateways/gw-001/sensors/sensor-temp',
      );
      expect(capturedRequest.method, 'PUT');
      expect(capturedRequest.headers['Authorization'], 'Bearer mock_jwt_token');
      expect(
        capturedRequest.headers['Content-Type'],
        contains('application/json'),
      );
      expect(capturedRequest.headers['Accept'], 'application/json');

      // MUST NOT have Idempotency-Key header on owner sensor provisioning:
      expect(capturedRequest.headers.containsKey('Idempotency-Key'), isFalse);
      expect(capturedRequest.headers.containsKey('idempotency-key'), isFalse);

      // Body must ONLY contain name and unit (no sensor_type, no gateway_id, no extra fields)
      final bodyJson = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(bodyJson.keys.toSet(), equals({'name', 'unit'}));
      expect(bodyJson['name'], 'Ambient Temp Sensor');
      expect(bodyJson['unit'], '°C');

      // 201 Created outcome
      expect(result.isCreated, isTrue);
      expect(result.gatewayId, 'gw-001');
      expect(result.sensorId, 'sensor-temp');
      expect(result.name, 'Ambient Temp Sensor');
      expect(result.unit, '°C');
      expect(result.entityId, 'urn:ngsi-ld:Sensor:gw-001:sensor-temp');
      expect(result.createdAt, DateTime.parse('2026-10-15T10:00:00Z'));
    });

    test('exact replay returns 200 OK with isCreated == false', () async {
      await authRepo.signInWithPassword(
        email: 'owner@example.com',
        password: 'password',
      );

      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'gateway_id': 'gw-001',
            'sensor_id': 'sensor-temp',
            'name': 'Ambient Temp Sensor',
            'unit': '°C',
            'entity_id': 'urn:ngsi-ld:Sensor:gw-001:sensor-temp',
            'created_at': '2026-09-01T08:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );
      final repo = HttpGatewayRepository(client);

      const input = ProvisionSensorInput(
        gatewayId: 'gw-001',
        sensorId: 'sensor-temp',
        name: 'Ambient Temp Sensor',
        unit: '°C',
      );

      final result = await repo.provisionOwnerSensor(input);
      expect(result.isCreated, isFalse);
      expect(result.createdAt, DateTime.parse('2026-09-01T08:00:00Z'));
    });

    test(
      '409 Conflict throws ApiException with conflict code (NOT update)',
      () async {
        await authRepo.signInWithPassword(
          email: 'owner@example.com',
          password: 'password',
        );

        final mockHttp = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'conflict',
                'message': 'resource conflict',
                'request_id': 'req-conflict-409',
              },
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = ApiClient(
          authRepository: authRepo,
          httpClient: mockHttp,
          baseUrl: 'http://localhost/v1/',
        );
        final repo = HttpGatewayRepository(client);

        const input = ProvisionSensorInput(
          gatewayId: 'gw-001',
          sensorId: 'sensor-temp',
          name: 'Different Name',
          unit: '°C',
        );

        expect(
          () => repo.provisionOwnerSensor(input),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having((e) => e.code, 'code', 'conflict')
                .having((e) => e.requestId, 'requestId', 'req-conflict-409'),
          ),
        );
      },
    );

    test(
      'client-side validations reject reserved gatewayId or invalid IDs',
      () async {
        final client = ApiClient(
          authRepository: authRepo,
          httpClient: MockClient((_) async => http.Response('{}', 200)),
          baseUrl: 'http://localhost/v1/',
        );
        final repo = HttpGatewayRepository(client);

        // Reserved backend_service gatewayId rejected
        expect(
          () => repo.provisionOwnerSensor(
            const ProvisionSensorInput(
              gatewayId: 'backend_service',
              sensorId: 's1',
              name: 'Name',
            ),
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 400),
          ),
        );

        // Invalid gatewayId regex rejected
        expect(
          () => repo.provisionOwnerSensor(
            const ProvisionSensorInput(
              gatewayId: '-invalid-gw',
              sensorId: 's1',
              name: 'Name',
            ),
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 400),
          ),
        );

        // Empty sensorId rejected
        expect(
          () => repo.provisionOwnerSensor(
            const ProvisionSensorInput(
              gatewayId: 'gw-1',
              sensorId: '',
              name: 'Name',
            ),
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 400),
          ),
        );

        // Empty name rejected
        expect(
          () => repo.provisionOwnerSensor(
            const ProvisionSensorInput(
              gatewayId: 'gw-1',
              sensorId: 's1',
              name: '   ',
            ),
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 400),
          ),
        );
      },
    );
  });

  group('Authority Matrix & Precedence Unit Resolution', () {
    test('confirmed platform admin takes precedence over gateway owner', () {
      const perms = UserPermissionsState(
        isLoading: false,
        permissions: UserPermissions(isPlatformAdmin: true),
      );
      const detail = GatewayDetailState(
        gatewayId: 'gw-1',
        status: GatewayDetailStatus.loaded,
        isOwner: true,
        membershipRole: GatewayRole.owner,
      );

      final authority = resolveSensorProvisionAuthority(
        permissionsState: perms,
        detailState: detail,
        gatewayId: 'gw-1',
      );
      expect(authority, SensorProvisionAuthority.admin);
    });

    test('confirmed non-admin + verified gateway owner resolves to owner', () {
      const perms = UserPermissionsState(
        isLoading: false,
        permissions: UserPermissions(isPlatformAdmin: false),
      );
      const detail = GatewayDetailState(
        gatewayId: 'gw-1',
        status: GatewayDetailStatus.loaded,
        isOwner: true,
        membershipRole: GatewayRole.owner,
      );

      final authority = resolveSensorProvisionAuthority(
        permissionsState: perms,
        detailState: detail,
        gatewayId: 'gw-1',
      );
      expect(authority, SensorProvisionAuthority.owner);
    });

    test('operator and viewer cannot submit (resolves to null)', () {
      const perms = UserPermissionsState(
        isLoading: false,
        permissions: UserPermissions(isPlatformAdmin: false),
      );

      const detailOperator = GatewayDetailState(
        gatewayId: 'gw-1',
        status: GatewayDetailStatus.loaded,
        isOwner: false,
        membershipRole: GatewayRole.operator,
      );
      expect(
        resolveSensorProvisionAuthority(
          permissionsState: perms,
          detailState: detailOperator,
          gatewayId: 'gw-1',
        ),
        isNull,
      );

      const detailViewer = GatewayDetailState(
        gatewayId: 'gw-1',
        status: GatewayDetailStatus.loaded,
        isOwner: false,
        membershipRole: GatewayRole.viewer,
      );
      expect(
        resolveSensorProvisionAuthority(
          permissionsState: perms,
          detailState: detailViewer,
          gatewayId: 'gw-1',
        ),
        isNull,
      );
    });

    test('permissions loading or in error fail closed (resolves to null)', () {
      const detailOwner = GatewayDetailState(
        gatewayId: 'gw-1',
        status: GatewayDetailStatus.loaded,
        isOwner: true,
        membershipRole: GatewayRole.owner,
      );

      // Loading permissions
      expect(
        resolveSensorProvisionAuthority(
          permissionsState: const UserPermissionsState(isLoading: true),
          detailState: detailOwner,
          gatewayId: 'gw-1',
        ),
        isNull,
      );

      // Error permissions
      expect(
        resolveSensorProvisionAuthority(
          permissionsState: const UserPermissionsState(
            isLoading: false,
            error: ApiException(
              statusCode: 500,
              code: 'server_error',
              message: 'err',
            ),
          ),
          detailState: detailOwner,
          gatewayId: 'gw-1',
        ),
        isNull,
      );
    });

    test(
      'gateway detail loading or general error prevents owner submission',
      () {
        const perms = UserPermissionsState(
          isLoading: false,
          permissions: UserPermissions(isPlatformAdmin: false),
        );

        // Detail is loading
        expect(
          resolveSensorProvisionAuthority(
            permissionsState: perms,
            detailState: const GatewayDetailState(
              gatewayId: 'gw-1',
              status: GatewayDetailStatus.loading,
              isOwner: true,
              membershipRole: GatewayRole.owner,
            ),
            gatewayId: 'gw-1',
          ),
          isNull,
        );

        // Detail has general error
        expect(
          resolveSensorProvisionAuthority(
            permissionsState: perms,
            detailState: const GatewayDetailState(
              gatewayId: 'gw-1',
              status: GatewayDetailStatus.error,
              isOwner: true,
              membershipRole: GatewayRole.owner,
            ),
            gatewayId: 'gw-1',
          ),
          isNull,
        );
      },
    );

    test('mismatched gateway ID fails closed (resolves to null)', () {
      const perms = UserPermissionsState(
        isLoading: false,
        permissions: UserPermissions(isPlatformAdmin: false),
      );
      const detailOwner = GatewayDetailState(
        gatewayId: 'gw-actual',
        status: GatewayDetailStatus.loaded,
        isOwner: true,
        membershipRole: GatewayRole.owner,
      );

      expect(
        resolveSensorProvisionAuthority(
          permissionsState: perms,
          detailState: detailOwner,
          gatewayId: 'gw-different',
        ),
        isNull,
      );
    });

    test('resolver rejects initial or notFound even if stale owner flags are present', () {
      const perms = UserPermissionsState(
        isLoading: false,
        permissions: UserPermissions(isPlatformAdmin: false),
      );

      // Stale owner flags with status == notFound
      const staleNotFound = GatewayDetailState(
        gatewayId: 'gw-1',
        status: GatewayDetailStatus.notFound,
        isOwner: true,
        membershipRole: GatewayRole.owner,
      );
      expect(
        resolveSensorProvisionAuthority(
          permissionsState: perms,
          detailState: staleNotFound,
          gatewayId: 'gw-1',
        ),
        isNull,
      );

      // Stale owner flags with status == initial
      const staleInitial = GatewayDetailState(
        gatewayId: 'gw-1',
        status: GatewayDetailStatus.initial,
        isOwner: true,
        membershipRole: GatewayRole.owner,
      );
      expect(
        resolveSensorProvisionAuthority(
          permissionsState: perms,
          detailState: staleInitial,
          gatewayId: 'gw-1',
        ),
        isNull,
      );

      // Clean notFound state with flags false
      const cleanNotFound = GatewayDetailState(
        gatewayId: 'gw-1',
        status: GatewayDetailStatus.notFound,
        isOwner: false,
        membershipRole: null,
      );
      expect(
        resolveSensorProvisionAuthority(
          permissionsState: perms,
          detailState: cleanNotFound,
          gatewayId: 'gw-1',
        ),
        isNull,
      );

      // Clean initial state with flags false
      const cleanInitial = GatewayDetailState(
        gatewayId: 'gw-1',
        status: GatewayDetailStatus.initial,
        isOwner: false,
        membershipRole: null,
      );
      expect(
        resolveSensorProvisionAuthority(
          permissionsState: perms,
          detailState: cleanInitial,
          gatewayId: 'gw-1',
        ),
        isNull,
      );
    });

    test(
      'confirmed platform admin resolves to admin on foreign loaded gateway',
      () {
        const perms = UserPermissionsState(
          isLoading: false,
          permissions: UserPermissions(isPlatformAdmin: true),
        );
        const foreignDetail = GatewayDetailState(
          gatewayId: 'gw-foreign-1',
          status: GatewayDetailStatus.loaded,
          isOwner: false,
          membershipRole: null,
          isSensorReadDenied: true,
        );

        final authority = resolveSensorProvisionAuthority(
          permissionsState: perms,
          detailState: foreignDetail,
          gatewayId: 'gw-foreign-1',
        );
        expect(authority, SensorProvisionAuthority.admin);
      },
    );
  });

  group('Widget Submission & Authority Routing', () {
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
      'confirmed non-admin owner uses provisionOwnerSensor (owner PUT)',
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
            gatewayId: 'gw-owner-station',
            name: 'Owner Station',
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

        const user = SessionUser(
          userId: '11111111-1111-1111-1111-111111111111',
          name: 'Owner User',
          email: 'owner@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-owner-station'));
        await tester.pumpAndSettle();

        final addBtn = find.text('Thêm cảm biến mới');
        expect(addBtn, findsOneWidget);

        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        expect(find.byType(CreateSensorDialog), findsOneWidget);

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'sensor-humidity',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Humidity Sensor',
        );
        await tester.enterText(find.byType(TextFormField).at(2), '%');

        await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
        await tester.pumpAndSettle();

        // Must call provisionOwnerSensor, NOT provisionSensor!
        expect(fakeGatewayRepo.provisionOwnerSensorCallCount, 1);
        expect(fakeGatewayRepo.provisionSensorCallCount, 0);
        expect(
          fakeGatewayRepo.lastProvisionOwnerSensorInput?.gatewayId,
          'gw-owner-station',
        );
        expect(
          fakeGatewayRepo.lastProvisionOwnerSensorInput?.sensorId,
          'sensor-humidity',
        );
        expect(
          fakeGatewayRepo.lastProvisionOwnerSensorInput?.name,
          'Humidity Sensor',
        );
        expect(fakeGatewayRepo.lastProvisionOwnerSensorInput?.unit, '%');

        // Dialog popped
        expect(find.byType(CreateSensorDialog), findsNothing);
      },
    );

    testWidgets('confirmed platform admin uses provisionSensor (admin PUT)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-admin-station',
          name: 'Admin Station',
          role: GatewayRole.operator, // Admin is operator in user_gateways
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

      container.read(routerProvider).go(R.gatewayDetail('gw-admin-station'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thêm cảm biến mới'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'sensor-pressure',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Pressure Sensor',
      );

      await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
      await tester.pumpAndSettle();

      // Must call admin provisionSensor, NOT provisionOwnerSensor!
      expect(fakeGatewayRepo.provisionSensorCallCount, 1);
      expect(fakeGatewayRepo.provisionOwnerSensorCallCount, 0);
      expect(
        fakeGatewayRepo.lastProvisionSensorInput?.gatewayId,
        'gw-admin-station',
      );
    });

    testWidgets(
      'dual-role precedence: platform admin who is also gateway owner uses provisionSensor (admin PUT)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // BOTH platform admin AND gateway owner
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-dual-role',
            name: 'Dual Role Station',
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

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin Owner',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-dual-role'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 'sensor-dual');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Dual Role Sensor',
        );

        await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
        await tester.pumpAndSettle();

        // Admin takes precedence!
        expect(fakeGatewayRepo.provisionSensorCallCount, 1);
        expect(fakeGatewayRepo.provisionOwnerSensorCallCount, 0);
      },
    );

    testWidgets(
      'OWNER 403 Forbidden refreshes gateway membership, does NOT globally invalidate admin',
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
            gatewayId: 'gw-forbidden-station',
            name: 'Forbidden Station',
            role: GatewayRole.owner,
          ),
        ];

        fakeGatewayRepo.shouldThrowProvisionOwnerSensor = true;
        fakeGatewayRepo.provisionOwnerSensorErrorToThrow = const ApiException(
          statusCode: 403,
          code: 'forbidden',
          message: 'access denied',
        );

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

        container
            .read(routerProvider)
            .go(R.gatewayDetail('gw-forbidden-station'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 's-forbidden');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Forbidden Sensor',
        );

        final initialPermsLoadCount = fakePermsRepo.callCount;
        final initialGatewaysCallCount = fakeGatewayRepo.callCount;

        await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
        await tester.pumpAndSettle();

        // On OWNER 403: gateway detail is refreshed (getGateways called)
        expect(
          fakeGatewayRepo.callCount,
          greaterThan(initialGatewaysCallCount),
        );

        // BUT admin permissions are NOT invalidated/reloaded!
        expect(fakePermsRepo.callCount, equals(initialPermsLoadCount));
      },
    );

    testWidgets(
      'retry preserves pinned authority; permission change does not silently switch routes',
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
            gatewayId: 'gw-retry-station',
            name: 'Retry Station',
            role: GatewayRole.owner,
          ),
        ];

        fakeGatewayRepo.shouldThrowProvisionOwnerSensor = true;
        fakeGatewayRepo.provisionOwnerSensorErrorToThrow = const ApiException(
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

        const user = SessionUser(
          userId: '11111111-1111-1111-1111-111111111111',
          name: 'Owner User',
          email: 'owner@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-retry-station'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 's-timeout');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Timeout Sensor',
        );

        await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
        await tester.pumpAndSettle();

        expect(fakeGatewayRepo.provisionOwnerSensorCallCount, 1);
        expect(find.text('Quá thời gian chờ phản hồi.'), findsOneWidget);

        // Explicit retry button is shown:
        final retryBtn = find.text('Thử lại (Retry)');
        expect(retryBtn, findsOneWidget);

        // Now clear error and retry while authority is still owner:
        fakeGatewayRepo.shouldThrowProvisionOwnerSensor = false;
        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        // Retried with same authority (owner PUT) and same payload:
        expect(fakeGatewayRepo.provisionOwnerSensorCallCount, 2);
        expect(fakeGatewayRepo.provisionSensorCallCount, 0);
        expect(find.byType(CreateSensorDialog), findsNothing);
      },
    );

    testWidgets(
      'stale in-flight response is discarded after session change or user swap',
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
            gatewayId: 'gw-stale-station',
            name: 'Stale Station',
            role: GatewayRole.owner,
          ),
        ];

        // Hang the owner sensor provisioning call
        fakeGatewayRepo.pendingProvisionOwnerSensorCompleter =
            Completer<ProvisionSensorResult>();

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const user1 = SessionUser(
          userId: '11111111-1111-1111-1111-111111111111',
          name: 'User One',
          email: 'user1@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user1);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-stale-station'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thêm cảm biến mới'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 's-stale');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Stale Sensor',
        );

        await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
        await tester.pump(); // Submit is in flight

        expect(fakeGatewayRepo.provisionOwnerSensorCallCount, 1);

        // Now session epoch changes or user swaps while in flight:
        const user2 = SessionUser(
          userId: '22222222-2222-2222-2222-222222222222',
          name: 'User Two',
          email: 'user2@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user2);
        await tester.pump(const Duration(milliseconds: 100));

        // Complete the pending request
        fakeGatewayRepo.pendingProvisionOwnerSensorCompleter!.complete(
          ProvisionSensorResult(
            isCreated: true,
            gatewayId: 'gw-stale-station',
            sensorId: 's-stale',
            name: 'Stale Sensor',
            entityId: 'urn:ngsi-ld:Sensor:gw-stale-station:s-stale',
            createdAt: DateTime.now().toUtc(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Dialog must be popped fail-closed and late response discarded (no success toast)
        expect(find.byType(CreateSensorDialog), findsNothing);
        expect(
          find.text('Đã khởi tạo cảm biến thành công (HTTP 201 Created)'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'success scoped refresh only reloads relevant sensors; admin foreign denied remains denied',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        // Admin foreign gateway: not in user_gateways, found via cursor lookup
        fakeGatewayRepo.items = []; // Not assigned in user_gateways
        fakeGatewayRepo.adminGatewaysResultToReturn =
            const AdminGatewayInventoryResponse(
              items: [
                AdminGatewayItem(
                  gatewayId: 'gw-foreign-station',
                  name: 'Foreign Station',
                ),
              ],
              nextCursor: null,
            );

        // Sensor read will return 404
        fakeGatewayRepo.shouldThrowSensors = true;
        fakeGatewayRepo.sensorsErrorToThrow = const ApiException(
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

        container
            .read(routerProvider)
            .go(R.gatewayDetail('gw-foreign-station'));
        await tester.pumpAndSettle();

        // Foreign gateway denial notice must be rendered
        expect(
          find.text(
            'Bạn không có quyền truy cập danh sách Sensor của Gateway này.',
          ),
          findsOneWidget,
        );
        final detailState = container.read(
          gatewayDetailProvider('gw-foreign-station'),
        );
        expect(detailState.isSensorReadDenied, isTrue);

        // Admin still allowed to open create sensor dialog on foreign gateway
        final addBtn = find.text('Thêm cảm biến mới');
        expect(addBtn, findsOneWidget);

        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        expect(find.byType(CreateSensorDialog), findsOneWidget);

        await tester.enterText(find.byType(TextFormField).at(0), 's-foreign-1');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Foreign Sensor 1',
        );

        final initialSensorsCallCount = fakeGatewayRepo.sensorsCallCount;

        await tester.tap(find.widgetWithText(KiteButton, 'Khởi tạo Cảm biến'));
        await tester.pumpAndSettle();

        // Provision called
        expect(fakeGatewayRepo.provisionSensorCallCount, 1);

        // Success toast shown and dialog closed
        expect(find.byType(CreateSensorDialog), findsNothing);
        expect(
          find.text('Đã khởi tạo cảm biến thành công (HTTP 201 Created)'),
          findsOneWidget,
        );

        // Scoped refresh: reloadSensorsOnly was called, but because isSensorReadDenied is true,
        // it returned early without making any new getGatewaySensors calls:
        expect(
          fakeGatewayRepo.sensorsCallCount,
          equals(initialSensorsCallCount),
        );

        // State remains denied, NO fabricated/made-up sensor list!
        final updatedState = container.read(
          gatewayDetailProvider('gw-foreign-station'),
        );
        expect(updatedState.isSensorReadDenied, isTrue);
        expect(updatedState.sensors, isEmpty);
      },
    );
  });
}
