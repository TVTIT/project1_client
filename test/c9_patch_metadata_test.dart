import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kite/app.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/core/router/routes.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/data/twin_detail.dart';
import 'package:kite/features/digital_twin/presentation/edit_metadata_dialog.dart';
import 'package:kite/features/digital_twin/providers/metadata_edit_provider.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite/features/gateways/providers/gateway_list_provider.dart';
import 'package:kite_ui/kite_ui.dart';

import 'gateway_list_provider_test.dart';
import 'permissions_test.dart';
import 'session_test.dart';

class FakeC9TwinRepo implements DigitalTwinRepository {
  PatchTwinResponseDto? patchResponse;
  Object? patchError;
  PatchTwinAttrsInput? capturedInput;
  String? capturedEntityId;

  TwinDetailPage? detailPageResponse;
  Object? detailError;

  @override
  Future<TwinDetailPage> getTwinDetail(
    String entityId, {
    int relationshipLimit = 20,
    String? relationshipAfter,
  }) async {
    if (detailError != null) throw detailError!;
    final parsed = EntityUrn.parse(entityId);
    return detailPageResponse ??
        TwinDetailPage(
          TwinDetail(
            entity: parsed,
            name: TwinProperty(
              parsed.type == EntityType.sensor ? 'Temp Sensor' : 'Main Gateway',
            ),
            description: const TwinProperty('Gateway Description'),
            measurement: parsed.type == EntityType.sensor
                ? const TwinProperty(25.0, unitCode: 'CEL')
                : null,
          ),
          null,
        );
  }

  @override
  Future<PatchTwinResponseDto> patchTwinAttrs(
    String entityId,
    PatchTwinAttrsInput input,
  ) async {
    capturedEntityId = entityId;
    capturedInput = input;
    if (patchError != null) throw patchError!;
    return patchResponse ??
        PatchTwinResponseDto(
          id: entityId,
          type: EntityUrn.parse(entityId).type,
          gatewayId: EntityUrn.parse(entityId).gatewayId,
          sensorId: EntityUrn.parse(entityId).sensorId,
          name: input.name ?? 'Retained Name',
          description: input.clearDescription
              ? null
              : (input.description ?? 'Retained Desc'),
          updatedAt: '2026-10-23T12:00:00.000000Z',
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
  Future<TwinStateResponse> getTwinState(String entityId) =>
      throw UnimplementedError();

  @override
  Future<TwinTemporalResponse> getSensorTemporal(
    String entityId, {
    required String attrs,
    required DateTime timeAt,
    required DateTime endTimeAt,
    String? aggrPeriodDuration,
    String? aggrMethods,
    int? maxPoints,
  }) => throw UnimplementedError();

  @override
  Future<ApiResponse> createTwin(PostTwinEntityInput input) =>
      throw UnimplementedError();
}

Widget createTestApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const KiteApp(),
  );
}

void main() {
  late FakeAuthRepository fakeAuthRepo;
  late FakeGatewayRepository fakeGatewayRepo;
  late FakePermissionsRepository fakePermsRepo;
  late FakeC9TwinRepo fakeTwinRepo;

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeGatewayRepo = FakeGatewayRepository();
    fakePermsRepo = FakePermissionsRepository();
    fakeTwinRepo = FakeC9TwinRepo();
  });

  tearDown(() {
    fakeAuthRepo.dispose();
  });

  Future<void> setupAuth(
    ProviderContainer container, {
    bool isPlatformAdmin = false,
    String userId = 'user-001',
  }) async {
    fakePermsRepo.resultToReturn = UserPermissions(
      isPlatformAdmin: isPlatformAdmin,
    );
    container
        .read(sessionProvider.notifier)
        .setSession(
          SessionUser(
            userId: userId,
            name: 'Nguyen Van A',
            email: 'user@example.com',
          ),
        );
    await container.read(userPermissionsProvider.notifier).loadPermissions();
  }

  group('C9: PatchTwinAttrsInput and DTO tests', () {
    test('PatchTwinAttrsInput preserves exact whitespace without trimming', () {
      const input = PatchTwinAttrsInput(
        name: '  Exact Gateway Name  ',
        description: '  Exact Description  ',
      );
      final json = input.toJson();
      expect(
        (json['name'] as Map<String, dynamic>)['value'],
        '  Exact Gateway Name  ',
      );
      expect(
        (json['description'] as Map<String, dynamic>)['value'],
        '  Exact Description  ',
      );
    });

    test('PatchTwinAttrsInput supports description-only and clear-description sentinel', () {
      const descOnly = PatchTwinAttrsInput(description: 'New Desc');
      final descJson = descOnly.toJson();
      expect(descJson.containsKey('name'), false);
      expect(
        (descJson['description'] as Map<String, dynamic>)['value'],
        'New Desc',
      );

      const clearDesc = PatchTwinAttrsInput(clearDescription: true);
      final clearJson = clearDesc.toJson();
      expect(clearJson.containsKey('name'), false);
      expect(
        (clearJson['description'] as Map<String, dynamic>)['value'],
        'urn:ngsi-ld:null',
      );
    });

    test('PatchTwinAttrsInput validates field bounds and invariants', () {
      // 1. Throws when no fields provided
      const emptyInput = PatchTwinAttrsInput();
      expect(() => emptyInput.toJson(), throwsA(isA<FormatException>()));

      // 2. Throws when both description and clearDescription provided
      const conflictInput = PatchTwinAttrsInput(
        description: 'desc',
        clearDescription: true,
      );
      expect(() => conflictInput.toJson(), throwsA(isA<FormatException>()));

      // 3. Name blank
      const blankName = PatchTwinAttrsInput(name: '   ');
      expect(() => blankName.toJson(), throwsA(isA<FormatException>()));

      // 4. Name > 256 bytes
      final longName = PatchTwinAttrsInput(name: 'a' * 257);
      expect(() => longName.toJson(), throwsA(isA<FormatException>()));

      // 5. Name with NUL byte
      const nulName = PatchTwinAttrsInput(name: 'name\u0000bad');
      expect(() => nulName.toJson(), throwsA(isA<FormatException>()));

      // 6. Description > 512 bytes (recorded HTTP parser limit)
      final longDesc = PatchTwinAttrsInput(description: 'd' * 513);
      expect(() => longDesc.toJson(), throwsA(isA<FormatException>()));

      // 7. Description <= 512 bytes valid
      final validDesc = PatchTwinAttrsInput(description: 'd' * 512);
      expect(() => validDesc.toJson(), returnsNormally);

      // 8. Description with NUL byte
      const nulDesc = PatchTwinAttrsInput(description: 'desc\u0000bad');
      expect(() => nulDesc.toJson(), throwsA(isA<FormatException>()));
    });

    test(
      'PatchTwinResponseDto parses canonical Gateway and Sensor JSON correctly',
      () {
        final gwJson = {
          'id': 'urn:ngsi-ld:Gateway:gw-01',
          'type': 'Gateway',
          'gateway_id': 'gw-01',
          'name': 'Updated GW',
          'description': 'Updated Desc',
          'updated_at': '2026-10-23T12:00:00.123456Z',
        };
        final gwDto = PatchTwinResponseDto.fromJson(gwJson);
        expect(gwDto.id, 'urn:ngsi-ld:Gateway:gw-01');
        expect(gwDto.type, EntityType.gateway);
        expect(gwDto.gatewayId, 'gw-01');
        expect(gwDto.name, 'Updated GW');
        expect(gwDto.description, 'Updated Desc');
        expect(gwDto.updatedAt, '2026-10-23T12:00:00.123456Z');

        final sensorJson = {
          'id': 'urn:ngsi-ld:Sensor:gw-01:temp',
          'type': 'Sensor',
          'gateway_id': 'gw-01',
          'sensor_id': 'temp',
          'name': 'Updated Temp',
          'unit': '°C',
          'updated_at': '2026-10-23T12:00:00.654321Z',
        };
        final sensorDto = PatchTwinResponseDto.fromJson(sensorJson);
        expect(sensorDto.id, 'urn:ngsi-ld:Sensor:gw-01:temp');
        expect(sensorDto.type, EntityType.sensor);
        expect(sensorDto.gatewayId, 'gw-01');
        expect(sensorDto.sensorId, 'temp');
        expect(sensorDto.name, 'Updated Temp');
        expect(sensorDto.unit, '°C');
        expect(sensorDto.updatedAt, '2026-10-23T12:00:00.654321Z');
      },
    );
  });

  group('C9: Authority Resolution Tests', () {
    test('Gateway authority: Platform Admin only; non-admin/owner denied; loading/error denies', () {
      const adminPerms = UserPermissionsState(
        permissions: UserPermissions(isPlatformAdmin: true),
      );
      const userPerms = UserPermissionsState(
        permissions: UserPermissions(isPlatformAdmin: false),
      );
      const loadingPerms = UserPermissionsState(isLoading: true);
      const errorPerms = UserPermissionsState(error: 'err');

      expect(
        resolveMetadataEditAuthority(
          permissionsState: adminPerms,
          entityType: EntityType.gateway,
          membershipRole: GatewayRole.owner,
        ),
        MetadataEditAuthority.admin,
      );

      expect(
        resolveMetadataEditAuthority(
          permissionsState: userPerms,
          entityType: EntityType.gateway,
          membershipRole: GatewayRole.owner,
        ),
        null,
      );

      expect(
        resolveMetadataEditAuthority(
          permissionsState: userPerms,
          entityType: EntityType.gateway,
          membershipRole: GatewayRole.operator,
        ),
        null,
      );

      expect(
        resolveMetadataEditAuthority(
          permissionsState: loadingPerms,
          entityType: EntityType.gateway,
          membershipRole: GatewayRole.owner,
        ),
        null,
      );
      expect(
        resolveMetadataEditAuthority(
          permissionsState: errorPerms,
          entityType: EntityType.gateway,
          membershipRole: GatewayRole.owner,
        ),
        null,
      );
    });

    test('Sensor authority: Platform Admin or Gateway Owner; operator/viewer denied', () {
      const adminPerms = UserPermissionsState(
        permissions: UserPermissions(isPlatformAdmin: true),
      );
      const userPerms = UserPermissionsState(
        permissions: UserPermissions(isPlatformAdmin: false),
      );

      expect(
        resolveMetadataEditAuthority(
          permissionsState: adminPerms,
          entityType: EntityType.sensor,
          membershipRole: GatewayRole.viewer,
        ),
        MetadataEditAuthority.admin,
      );

      expect(
        resolveMetadataEditAuthority(
          permissionsState: userPerms,
          entityType: EntityType.sensor,
          membershipRole: GatewayRole.owner,
        ),
        MetadataEditAuthority.owner,
      );

      expect(
        resolveMetadataEditAuthority(
          permissionsState: userPerms,
          entityType: EntityType.sensor,
          membershipRole: GatewayRole.operator,
        ),
        null,
      );

      expect(
        resolveMetadataEditAuthority(
          permissionsState: userPerms,
          entityType: EntityType.sensor,
          membershipRole: GatewayRole.viewer,
        ),
        null,
      );
    });
  });

  group('C9: MetadataEditNotifier Behavioral & Reconcile Tests', () {
    test('Duplicate submit suppression and validation guard', () async {
      final container = ProviderContainer(
        overrides: [
          digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
        ],
      );
      addTearDown(container.dispose);
      await setupAuth(container, isPlatformAdmin: true);

      final notifier = container.read(
        metadataEditProvider('urn:ngsi-ld:Gateway:gw-01').notifier,
      );

      final emptyResult = await notifier.submit(
        entityUrn: EntityUrn.parse('urn:ngsi-ld:Gateway:gw-01'),
        authority: MetadataEditAuthority.admin,
      );
      expect(emptyResult, false);
      expect(fakeTwinRepo.capturedInput, null);

      final okResult = await notifier.submit(
        entityUrn: EntityUrn.parse('urn:ngsi-ld:Gateway:gw-01'),
        name: 'New Name',
        authority: MetadataEditAuthority.admin,
      );
      expect(okResult, true);
      expect(fakeTwinRepo.capturedInput?.name, 'New Name');
      expect(
        container
            .read(metadataEditProvider('urn:ngsi-ld:Gateway:gw-01'))
            .isSuccess,
        true,
      );
    });

    test('503/Timeout/Network error results in unknown outcome, blocking blind resubmit', () async {
      fakeTwinRepo.patchError = const ApiException(
        statusCode: 503,
        code: 'service_unavailable',
        message: 'Server busy',
        requestId: 'req-503',
      );

      final container = ProviderContainer(
        overrides: [
          digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
        ],
      );
      addTearDown(container.dispose);
      await setupAuth(container, isPlatformAdmin: true);

      final notifier = container.read(
        metadataEditProvider('urn:ngsi-ld:Gateway:gw-01').notifier,
      );
      final res = await notifier.submit(
        entityUrn: EntityUrn.parse('urn:ngsi-ld:Gateway:gw-01'),
        name: 'Target Name',
        authority: MetadataEditAuthority.admin,
      );

      expect(res, false);
      final state = container.read(
        metadataEditProvider('urn:ngsi-ld:Gateway:gw-01'),
      );
      expect(state.isUnknownOutcome, true);
      expect(state.requestId, 'req-503');
      expect(state.requestedInput?.name, 'Target Name');
      expect(state.isSubmitting, false);
    });

    test('Reconciliation readback: matches confirms; mismatch reports discrepancy; 404 says cannot verify', () async {
      fakeTwinRepo.patchError = TimeoutException('Timeout');

      final container = ProviderContainer(
        overrides: [
          digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
        ],
      );
      addTearDown(container.dispose);
      await setupAuth(container, isPlatformAdmin: true);

      final notifier = container.read(
        metadataEditProvider('urn:ngsi-ld:Gateway:gw-01').notifier,
      );
      await notifier.submit(
        entityUrn: EntityUrn.parse('urn:ngsi-ld:Gateway:gw-01'),
        name: 'Desired Name',
        authority: MetadataEditAuthority.admin,
      );

      // 1. Readback matches requested name => Confirmed
      fakeTwinRepo.detailPageResponse = TwinDetailPage(
        TwinDetail(
          entity: EntityUrn.parse('urn:ngsi-ld:Gateway:gw-01'),
          name: const TwinProperty('Desired Name'),
          description: const TwinProperty('Desc'),
        ),
        null,
      );
      await notifier.reconcile(EntityUrn.parse('urn:ngsi-ld:Gateway:gw-01'));
      expect(
        container
            .read(metadataEditProvider('urn:ngsi-ld:Gateway:gw-01'))
            .reconcileStatus,
        MetadataReconcileStatus.confirmed,
      );
      expect(
        container
            .read(metadataEditProvider('urn:ngsi-ld:Gateway:gw-01'))
            .isSuccess,
        true,
      );

      // 2. Readback mismatches => Mismatch reported honestly
      fakeTwinRepo.detailPageResponse = TwinDetailPage(
        TwinDetail(
          entity: EntityUrn.parse('urn:ngsi-ld:Gateway:gw-01'),
          name: const TwinProperty('Old Other Name'),
          description: const TwinProperty('Desc'),
        ),
        null,
      );
      await notifier.reconcile(EntityUrn.parse('urn:ngsi-ld:Gateway:gw-01'));
      expect(
        container
            .read(metadataEditProvider('urn:ngsi-ld:Gateway:gw-01'))
            .reconcileStatus,
        MetadataReconcileStatus
            .confirmed, // confirmed success cannot be demoted by another read
      );

      // 3. Readback 404 (Admin without membership) => cannotVerify
      fakeTwinRepo.detailPageResponse = null;
      fakeTwinRepo.detailError = const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Resource not found',
      );
      await notifier.reconcile(EntityUrn.parse('urn:ngsi-ld:Gateway:gw-01'));
      expect(
        container
            .read(metadataEditProvider('urn:ngsi-ld:Gateway:gw-01'))
            .reconcileStatus,
        MetadataReconcileStatus.confirmed,
      );
    });
  });

  group('C9: UI Widget Tests', () {
    testWidgets(
      'TwinDetailScreen Gateway info pane shows edit button for Admin',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final adminContainer = ProviderContainer(
          overrides: [
            digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          ],
        );
        addTearDown(adminContainer.dispose);
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-01',
            name: 'AM5728',
            role: GatewayRole.viewer,
          ),
        ];
        await setupAuth(
          adminContainer,
          isPlatformAdmin: true,
          userId: 'admin-1',
        );

        adminContainer
            .read(routerProvider)
            .go(R.twinDetail('urn:ngsi-ld:Gateway:gw-01'));
        await tester.pumpWidget(createTestApp(adminContainer));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('edit-twin-metadata-btn')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TwinDetailScreen Gateway info pane hides edit button for non-admin Gateway Owner',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final userContainer = ProviderContainer(
          overrides: [
            digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          ],
        );
        addTearDown(userContainer.dispose);
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-01',
            name: 'AM5728',
            role: GatewayRole.owner,
          ),
        ];
        await setupAuth(
          userContainer,
          isPlatformAdmin: false,
          userId: 'user-1',
        );

        userContainer
            .read(routerProvider)
            .go(R.twinDetail('urn:ngsi-ld:Gateway:gw-01'));
        await tester.pumpWidget(createTestApp(userContainer));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('edit-twin-metadata-btn')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'TwinDetailScreen Sensor info pane shows edit button for Gateway Owner',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ownerContainer = ProviderContainer(
          overrides: [
            digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          ],
        );
        addTearDown(ownerContainer.dispose);
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-01',
            name: 'AM5728',
            role: GatewayRole.owner,
          ),
        ];
        await setupAuth(
          ownerContainer,
          isPlatformAdmin: false,
          userId: 'user-1',
        );
        await ownerContainer.read(gatewayListProvider.notifier).loadGateways();

        ownerContainer
            .read(routerProvider)
            .go(R.twinDetail('urn:ngsi-ld:Sensor:gw-01:temp'));
        await tester.pumpWidget(createTestApp(ownerContainer));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('edit-twin-metadata-btn')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TwinDetailScreen Sensor info pane hides edit button for Operator',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final opContainer = ProviderContainer(
          overrides: [
            digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          ],
        );
        addTearDown(opContainer.dispose);
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-01',
            name: 'AM5728',
            role: GatewayRole.operator,
          ),
        ];
        await setupAuth(opContainer, isPlatformAdmin: false, userId: 'user-2');
        await opContainer.read(gatewayListProvider.notifier).loadGateways();

        opContainer
            .read(routerProvider)
            .go(R.twinDetail('urn:ngsi-ld:Sensor:gw-01:temp'));
        await tester.pumpWidget(createTestApp(opContainer));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('edit-twin-metadata-btn')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'GatewayDetailScreen header displays edit metadata button for Admin, hides for non-admin',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final adminContainer = ProviderContainer(
          overrides: [
            digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          ],
        );
        addTearDown(adminContainer.dispose);
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-01',
            name: 'AM5728 Gateway Alpha',
            role: GatewayRole.viewer,
            description: 'Trạm quan trắc',
          ),
        ];
        fakeGatewayRepo.sensorsMap = {'gw-01': []};
        await setupAuth(
          adminContainer,
          isPlatformAdmin: true,
          userId: 'admin-1',
        );

        adminContainer.read(routerProvider).go(R.gatewayDetail('gw-01'));
        await tester.pumpWidget(createTestApp(adminContainer));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('gateway-edit-metadata-btn')),
          findsOneWidget,
        );

        final userContainer = ProviderContainer(
          overrides: [
            digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          ],
        );
        addTearDown(userContainer.dispose);
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-01',
            name: 'AM5728 Gateway Alpha',
            role: GatewayRole.owner,
            description: 'Trạm quan trắc',
          ),
        ];
        fakeGatewayRepo.sensorsMap = {'gw-01': []};
        await setupAuth(
          userContainer,
          isPlatformAdmin: false,
          userId: 'owner-1',
        );

        userContainer.read(routerProvider).go(R.gatewayDetail('gw-01'));
        await tester.pumpWidget(createTestApp(userContainer));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('gateway-edit-metadata-btn')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'EditMetadataDialog form behavior: validation, no changes disabled, description clear, notice',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          ],
        );
        addTearDown(container.dispose);
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-01',
            name: 'AM5728',
            role: GatewayRole.owner,
          ),
        ];
        await setupAuth(container, isPlatformAdmin: true, userId: 'admin-1');

        container
            .read(routerProvider)
            .go(R.twinDetail('urn:ngsi-ld:Gateway:gw-01'));
        await tester.pumpWidget(createTestApp(container));
        await tester.pumpAndSettle();

        // Tap edit button to open dialog:
        final editBtn = find.byKey(const ValueKey('edit-twin-metadata-btn'));
        expect(editBtn, findsOneWidget);
        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        expect(find.byType(EditMetadataDialog), findsOneWidget);
        expect(
          find.text(
            'Metadata được cập nhật trong cơ sở dữ liệu máy chủ (thao tác này không thực thi lệnh trên phần cứng).',
          ),
          findsOneWidget,
        );

        final saveBtnFinder = find.byKey(
          const ValueKey('metadata-edit-submit-btn'),
        );
        expect(tester.widget<KiteButton>(saveBtnFinder).onPressed, isNull);

        await tester.enterText(
          find.byKey(const ValueKey('metadata-edit-name-field')),
          'Updated Gateway Name',
        );
        await tester.pumpAndSettle();
        expect(tester.widget<KiteButton>(saveBtnFinder).onPressed, isNotNull);

        await tester.tap(
          find.byKey(const ValueKey('metadata-edit-clear-desc-check')),
        );
        await tester.pumpAndSettle();

        await tester.tap(saveBtnFinder);
        await tester.pumpAndSettle();

        expect(fakeTwinRepo.capturedInput?.name, 'Updated Gateway Name');
        expect(fakeTwinRepo.capturedInput?.clearDescription, true);
      },
    );

    testWidgets(
      'EditMetadataDialog responsive layout across 390, 1024, 1366, 1920 without overflow',
      (tester) async {
        for (final width in [390.0, 1024.0, 1366.0, 1920.0]) {
          tester.view.physicalSize = Size(width, 768);
          tester.view.devicePixelRatio = 1.0;

          final container = ProviderContainer(
            overrides: [
              digitalTwinRepositoryProvider.overrideWithValue(fakeTwinRepo),
              permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
              gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            ],
          );
          fakeGatewayRepo.items = [
            const GatewayItem(
              gatewayId: 'gw-01',
              name: 'AM5728',
              role: GatewayRole.owner,
            ),
          ];
          await setupAuth(container, isPlatformAdmin: true, userId: 'admin-1');

          container
              .read(routerProvider)
              .go(R.twinDetail('urn:ngsi-ld:Gateway:gw-01'));
          await tester.pumpWidget(createTestApp(container));
          await tester.pumpAndSettle();

          final editBtn = find.byKey(const ValueKey('edit-twin-metadata-btn'));
          expect(editBtn, findsOneWidget);
          await tester.tap(editBtn);
          await tester.pumpAndSettle();

          expect(find.byType(EditMetadataDialog), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'Must not overflow at $width',
          );

          container.dispose();
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });
}
