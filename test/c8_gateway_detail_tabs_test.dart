import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/data/twin_detail.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite/features/gateways/presentation/gateway_detail_screen.dart';
import 'package:kite/l10n/app_localizations.dart';
import 'package:kite/shared/widgets/temporal_history_panel.dart';
import 'package:kite_ui/shadcn.dart';

import 'gateway_list_provider_test.dart';
import 'permissions_test.dart';
import 'session_test.dart';

class FakeGatewayDetailTabsTwinRepo implements DigitalTwinRepository {
  int temporalCallCount = 0;
  String? lastRequestedEntityId;
  Future<TwinTemporalResponse> Function(
    String entityId, {
    required String attrs,
    required DateTime timeAt,
    required DateTime endTimeAt,
    String? aggrPeriodDuration,
    String? aggrMethods,
    int? maxPoints,
  })?
  temporalHandler;

  @override
  Future<TwinTemporalResponse> getSensorTemporal(
    String entityId, {
    required String attrs,
    required DateTime timeAt,
    required DateTime endTimeAt,
    String? aggrPeriodDuration,
    String? aggrMethods,
    int? maxPoints,
  }) async {
    temporalCallCount++;
    lastRequestedEntityId = entityId;
    if (temporalHandler != null) {
      return temporalHandler!(
        entityId,
        attrs: attrs,
        timeAt: timeAt,
        endTimeAt: endTimeAt,
        aggrPeriodDuration: aggrPeriodDuration,
        aggrMethods: aggrMethods,
        maxPoints: maxPoints,
      );
    }
    return TwinTemporalResponse(
      id: entityId,
      type: 'Sensor',
      attrName: attrs,
      isAggregated: true,
      avgBuckets: [
        TemporalBucketPoint(
          value: 23.5,
          bucketStart: timeAt,
          bucketEnd: endTimeAt,
        ),
      ],
      minBuckets: [
        TemporalBucketPoint(
          value: 19.0,
          bucketStart: timeAt,
          bucketEnd: endTimeAt,
        ),
      ],
      maxBuckets: [
        TemporalBucketPoint(
          value: 28.0,
          bucketStart: timeAt,
          bucketEnd: endTimeAt,
        ),
      ],
      totalCountBuckets: [
        TemporalBucketPoint(
          value: BigInt.from(80),
          bucketStart: timeAt,
          bucketEnd: endTimeAt,
        ),
      ],
    );
  }

  @override
  Future<ApiResponse> listTwins({
    EntityType? type,
    String? gatewayId,
    int? limit,
    String? cursor,
    bool simplified = true,
  }) => throw UnimplementedError();

  @override
  Future<TwinDetailPage> getTwinDetail(
    String entityId, {
    int relationshipLimit = 20,
    String? relationshipAfter,
  }) => throw UnimplementedError();

  @override
  Future<TwinStateResponse> getTwinState(String entityId) =>
      throw UnimplementedError();

  @override
  Future<ApiResponse> createTwin(PostTwinEntityInput input) =>
      throw UnimplementedError();

  @override
  Future<PatchTwinResponseDto> patchTwinAttrs(
    String entityId,
    PatchTwinAttrsInput input,
  ) => throw UnimplementedError();
}

void main() {
  late FakeAuthRepository fakeAuthRepo;
  late FakeGatewayRepository fakeGatewayRepo;
  late FakePermissionsRepository fakePermsRepo;
  late FakeGatewayDetailTabsTwinRepo fakeTwinRepo;

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeGatewayRepo = FakeGatewayRepository();
    fakePermsRepo = FakePermissionsRepository();
    fakeTwinRepo = FakeGatewayDetailTabsTwinRepo();
  });

  tearDown(() {
    fakeAuthRepo.dispose();
  });

  Widget createTestWidget(
    ProviderContainer container, {
    Locale locale = const Locale('vi'),
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: ShadApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: locale,
        home: const Scaffold(body: GatewayDetailScreen(gatewayId: 'gw-001')),
      ),
    );
  }

  void setupAuthenticatedUser(
    ProviderContainer container, {
    bool isPlatformAdmin = false,
  }) {
    container
        .read(sessionProvider.notifier)
        .setSession(
          const SessionUser(
            userId: 'user-001',
            name: 'Nguyen Van A',
            email: 'user@example.com',
          ),
        );
    fakePermsRepo.resultToReturn = UserPermissions(
      isPlatformAdmin: isPlatformAdmin,
    );
  }

  const sampleGateway = GatewayItem(
    gatewayId: 'gw-001',
    name: 'AM5728 Gateway Alpha',
    role: GatewayRole.owner,
    description: 'Trạm quan trắc nhà kính',
  );

  final sampleSensors = [
    const SensorItem(sensorId: 'sensor_temp', name: 'Nhiệt độ', unit: '°C'),
    const SensorItem(sensorId: 'sensor_hum', name: 'Độ ẩm', unit: '%'),
  ];

  group('GatewayDetailScreen Tabs & Temporal History Tests', () {
    testWidgets(
      'renders metadata card and two tabs; defaults to Telemetry history with DropdownMenu',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakeGatewayRepo.items = [sampleGateway];
        fakeGatewayRepo.sensorsMap = {'gw-001': sampleSensors};

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
          ],
        );
        addTearDown(container.dispose);
        setupAuthenticatedUser(container);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        // Gateway Metadata Card is rendered intact
        expect(find.text('Chi tiết Gateway: gw-001'), findsOneWidget);
        expect(find.text('AM5728 Gateway Alpha'), findsOneWidget);
        expect(find.text('Trạm quan trắc nhà kính'), findsOneWidget);
        expect(find.text('Chủ sở hữu'), findsWidgets);

        // Two tabs are visible under metadata
        expect(find.byKey(const Key('tab-telemetry-history')), findsOneWidget);
        expect(find.byKey(const Key('tab-sensor-catalog')), findsOneWidget);

        // Default tab is Telemetry History:
        // DropdownMenu choosing one authorized sensor
        expect(find.byType(DropdownMenu<String>), findsOneWidget);

        // Selected sensor history panel is rendered
        expect(find.byType(TemporalHistoryPanel), findsOneWidget);
        expect(fakeTwinRepo.temporalCallCount, 1);
        expect(
          fakeTwinRepo.lastRequestedEntityId,
          'urn:ngsi-ld:Sensor:gw-001:sensor_temp',
        );

        // Sensor catalog table/cards are NOT mounted on Tab 0
        expect(find.text('Tìm kiếm theo ID, tên hoặc đơn vị...'), findsNothing);
      },
    );

    testWidgets(
      'switching to Sensor catalog tab mounts catalog and unmounts history',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakeGatewayRepo.items = [sampleGateway];
        fakeGatewayRepo.sensorsMap = {'gw-001': sampleSensors};

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
          ],
        );
        addTearDown(container.dispose);
        setupAuthenticatedUser(container);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        expect(find.byType(TemporalHistoryPanel), findsOneWidget);

        // Tap Tab 1: Sensor Catalog
        await tester.tap(find.byKey(const Key('tab-sensor-catalog')));
        await tester.pumpAndSettle();

        // Now Sensor catalog is mounted: search field, add button, table
        expect(find.byType(TemporalHistoryPanel), findsNothing);
        expect(
          find.text('Tìm cảm biến theo mã, tên hoặc đơn vị...'),
          findsOneWidget,
        );
        expect(find.text('Nhiệt độ'), findsOneWidget);
        expect(find.text('Độ ẩm'), findsOneWidget);

        // Tap Tab 0: Telemetry History
        await tester.tap(find.byKey(const Key('tab-telemetry-history')));
        await tester.pumpAndSettle();

        // Sensor catalog unmounted, history remounted
        expect(find.byType(TemporalHistoryPanel), findsOneWidget);
        expect(
          find.text('Tìm cảm biến theo mã, tên hoặc đơn vị...'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'admin without gateway membership keeps exact sensor-read denial and makes NO temporal call',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakeGatewayRepo.items = [];
        fakeGatewayRepo.adminGatewaysResultToReturn =
            AdminGatewayInventoryResponse(
              items: [
                AdminGatewayItem(
                  gatewayId: 'gw-001',
                  name: 'AM5728 Gateway Alpha',
                  createdAt: DateTime.parse('2026-10-23T00:00:00Z'),
                ),
              ],
            );
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
            digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
          ],
        );
        addTearDown(container.dispose);
        // Platform admin = true
        setupAuthenticatedUser(container, isPlatformAdmin: true);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        // Metadata card is visible
        expect(find.text('Chi tiết Gateway: gw-001'), findsOneWidget);

        // History tab shows exact sensor-read denial message
        expect(
          find.text(
            'Bạn không có quyền truy cập danh sách Sensor của Gateway này.',
          ),
          findsOneWidget,
        );

        // Crucial security barrier: NO temporal call was made!
        expect(fakeTwinRepo.temporalCallCount, 0);
        expect(find.byType(TemporalHistoryPanel), findsNothing);
      },
    );

    testWidgets(
      'independent history error keeps gateway metadata card visible',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakeGatewayRepo.items = [sampleGateway];
        fakeGatewayRepo.sensorsMap = {'gw-001': sampleSensors};
        // Temporal call throws 500 internal error
        fakeTwinRepo.temporalHandler =
            (
              entityId, {
              required attrs,
              required timeAt,
              required endTimeAt,
              aggrPeriodDuration,
              aggrMethods,
              maxPoints,
            }) {
              throw const ApiException(
                statusCode: 500,
                code: 'internal_error',
                message: 'Lỗi máy chủ đo đạc',
              );
            };

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
          ],
        );
        addTearDown(container.dispose);
        setupAuthenticatedUser(container);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        // Metadata card is fully intact and visible!
        expect(find.text('Chi tiết Gateway: gw-001'), findsOneWidget);
        expect(find.text('AM5728 Gateway Alpha'), findsOneWidget);
        expect(find.text('Chủ sở hữu'), findsWidgets);

        // Independent history error shown in history area
        expect(find.textContaining('Không thể tải lịch sử'), findsOneWidget);
        expect(find.text('Lỗi máy chủ đo đạc'), findsNothing);
      },
    );

    testWidgets('responsive layout at 390 mobile without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeGatewayRepo.items = [sampleGateway];
      fakeGatewayRepo.sensorsMap = {'gw-001': sampleSensors};

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
        ],
      );
      addTearDown(container.dispose);
      setupAuthenticatedUser(container);

      await tester.pumpWidget(
        createTestWidget(
          container,
          locale: const Locale('en'),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gateway Details: gw-001'), findsOneWidget);
      expect(find.byKey(const Key('tab-telemetry-history')), findsOneWidget);
      expect(find.byType(TemporalHistoryPanel), findsOneWidget);
    });

    testWidgets('responsive layout at 1920 wide screen without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeGatewayRepo.items = [sampleGateway];
      fakeGatewayRepo.sensorsMap = {'gw-001': sampleSensors};

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
        ],
      );
      addTearDown(container.dispose);
      setupAuthenticatedUser(container);

      await tester.pumpWidget(
        createTestWidget(
          container,
          locale: const Locale('vi'),
          themeMode: ThemeMode.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết Gateway: gw-001'), findsOneWidget);
      expect(find.byKey(const Key('tab-telemetry-history')), findsOneWidget);
      expect(find.byType(TemporalHistoryPanel), findsOneWidget);
    });
  });
}
