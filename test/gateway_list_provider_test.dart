import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite/features/gateways/data/mqtt_credential_dto.dart';
import 'package:kite/features/gateways/providers/gateway_list_provider.dart';

import 'permissions_test.dart';
import 'session_test.dart';

class FakeGatewayRepository implements GatewayRepository {
  List<GatewayItem> items = [];
  Completer<List<GatewayItem>>? pendingCompleter;
  bool shouldThrow = false;
  ApiException? errorToThrow;
  int callCount = 0;

  Map<String, List<SensorItem>> sensorsMap = {};
  Completer<SensorListResponse>? pendingSensorsCompleter;
  bool shouldThrowSensors = false;
  ApiException? sensorsErrorToThrow;
  int sensorsCallCount = 0;

  @override
  Future<List<GatewayItem>> getGateways() async {
    callCount++;
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    if (shouldThrow) {
      throw errorToThrow ??
          const ApiException(
            statusCode: 500,
            code: 'internal_error',
            message: 'Server error',
          );
    }
    return items;
  }

  Completer<AdminGatewayInventoryResponse>? pendingAdminGatewaysCompleter;
  bool shouldThrowAdminGateways = false;
  ApiException? adminGatewaysErrorToThrow;
  int adminGatewaysCallCount = 0;
  int? lastAdminGatewaysLimit;
  String? lastAdminGatewaysAfter;
  AdminGatewayInventoryResponse? adminGatewaysResultToReturn;
  AdminGatewayInventoryResponse Function(int? limit, String? after)?
  adminGatewaysHandler;

  @override
  Future<AdminGatewayInventoryResponse> getAdminGateways({
    int? limit,
    String? after,
  }) async {
    adminGatewaysCallCount++;
    lastAdminGatewaysLimit = limit;
    lastAdminGatewaysAfter = after;
    if (pendingAdminGatewaysCompleter != null) {
      return pendingAdminGatewaysCompleter!.future;
    }
    if (shouldThrowAdminGateways) {
      throw adminGatewaysErrorToThrow ??
          const ApiException(
            statusCode: 500,
            code: 'internal_error',
            message: 'Admin gateways server error',
          );
    }
    if (adminGatewaysHandler != null) {
      return adminGatewaysHandler!(limit, after);
    }
    return adminGatewaysResultToReturn ??
        const AdminGatewayInventoryResponse(items: [], nextCursor: null);
  }

  @override
  Future<SensorListResponse> getGatewaySensors(String gatewayId) async {
    sensorsCallCount++;
    if (pendingSensorsCompleter != null) {
      return pendingSensorsCompleter!.future;
    }
    if (shouldThrowSensors) {
      throw sensorsErrorToThrow ??
          const ApiException(
            statusCode: 500,
            code: 'internal_error',
            message: 'Sensors server error',
          );
    }
    final list = sensorsMap[gatewayId] ?? [];
    return SensorListResponse(gatewayId: gatewayId, items: list);
  }

  Completer<ProvisionGatewayResult>? pendingProvisionCompleter;
  bool shouldThrowProvision = false;
  ApiException? provisionErrorToThrow;
  int provisionCallCount = 0;
  ProvisionGatewayInput? lastProvisionInput;
  ProvisionGatewayResult? provisionResultToReturn;

  @override
  Future<ProvisionGatewayResult> provisionGateway(
    ProvisionGatewayInput input,
  ) async {
    provisionCallCount++;
    lastProvisionInput = input;
    if (pendingProvisionCompleter != null) {
      return pendingProvisionCompleter!.future;
    }
    if (shouldThrowProvision) {
      throw provisionErrorToThrow ??
          const ApiException(
            statusCode: 500,
            code: 'internal_error',
            message: 'Provision server error',
          );
    }
    return provisionResultToReturn ??
        ProvisionGatewayResult(
          isCreated: true,
          gatewayId: input.gatewayId,
          name: input.name,
          description: input.description,
          ownerUserId: input.ownerUserId,
          entityId: 'urn:ngsi-ld:Gateway:${input.gatewayId}',
          createdAt: DateTime.now().toUtc(),
        );
  }

  Completer<ProvisionSensorResult>? pendingProvisionSensorCompleter;
  bool shouldThrowProvisionSensor = false;
  ApiException? provisionSensorErrorToThrow;
  int provisionSensorCallCount = 0;
  ProvisionSensorInput? lastProvisionSensorInput;
  ProvisionSensorResult? provisionSensorResultToReturn;

  @override
  Future<ProvisionSensorResult> provisionSensor(
    ProvisionSensorInput input,
  ) async {
    provisionSensorCallCount++;
    lastProvisionSensorInput = input;
    if (pendingProvisionSensorCompleter != null) {
      return pendingProvisionSensorCompleter!.future;
    }
    if (shouldThrowProvisionSensor) {
      throw provisionSensorErrorToThrow ??
          const ApiException(
            statusCode: 500,
            code: 'internal_error',
            message: 'Sensor provision server error',
          );
    }
    return provisionSensorResultToReturn ??
        ProvisionSensorResult(
          isCreated: true,
          gatewayId: input.gatewayId,
          sensorId: input.sensorId,
          name: input.name,
          unit: input.unit,
          entityId: 'urn:ngsi-ld:Sensor:${input.gatewayId}:${input.sensorId}',
          createdAt: DateTime.now().toUtc(),
        );
  }

  Completer<ProvisionSensorResult>? pendingProvisionOwnerSensorCompleter;
  bool shouldThrowProvisionOwnerSensor = false;
  ApiException? provisionOwnerSensorErrorToThrow;
  int provisionOwnerSensorCallCount = 0;
  ProvisionSensorInput? lastProvisionOwnerSensorInput;
  ProvisionSensorResult? provisionOwnerSensorResultToReturn;

  @override
  Future<ProvisionSensorResult> provisionOwnerSensor(
    ProvisionSensorInput input,
  ) async {
    provisionOwnerSensorCallCount++;
    lastProvisionOwnerSensorInput = input;
    if (pendingProvisionOwnerSensorCompleter != null) {
      return pendingProvisionOwnerSensorCompleter!.future;
    }
    if (shouldThrowProvisionOwnerSensor) {
      throw provisionOwnerSensorErrorToThrow ??
          const ApiException(
            statusCode: 500,
            code: 'internal_error',
            message: 'Sensor owner provision server error',
          );
    }
    return provisionOwnerSensorResultToReturn ??
        ProvisionSensorResult(
          isCreated: true,
          gatewayId: input.gatewayId,
          sensorId: input.sensorId,
          name: input.name,
          unit: input.unit,
          entityId: 'urn:ngsi-ld:Sensor:${input.gatewayId}:${input.sensorId}',
          createdAt: DateTime.now().toUtc(),
        );
  }

  Completer<MqttCredentialMetadata>? pendingMetadataCompleter;
  bool shouldThrowMetadata = false;
  ApiException? metadataErrorToThrow;
  int metadataCallCount = 0;
  MqttCredentialMetadata? metadataResultToReturn;

  @override
  Future<MqttCredentialMetadata> getMqttCredential(String gatewayId) async {
    metadataCallCount++;
    if (pendingMetadataCompleter != null) {
      return pendingMetadataCompleter!.future;
    }
    if (shouldThrowMetadata) {
      throw metadataErrorToThrow ??
          const ApiException(
            statusCode: 500,
            code: 'internal_error',
            message: 'Metadata server error',
          );
    }
    return metadataResultToReturn ??
        MqttCredentialMetadata(
          gatewayId: gatewayId,
          username: gatewayId,
          credentialVersion: 1,
          status: MqttCredentialStatus.active,
          lastOperationId: '00000000-0000-0000-0000-000000000001',
          operationStatus: MqttOperationStatus.succeeded,
          activatedAt: DateTime.now().toUtc(),
        );
  }

  Completer<Object>? pendingProvisionMqttCompleter;
  bool shouldThrowProvisionMqtt = false;
  ApiException? provisionMqttErrorToThrow;
  int provisionMqttCallCount = 0;
  String? lastProvisionMqttIdempotencyKey;
  Object? provisionMqttResultToReturn;

  @override
  Future<Object> provisionMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  }) async {
    provisionMqttCallCount++;
    lastProvisionMqttIdempotencyKey = idempotencyKey;
    if (pendingProvisionMqttCompleter != null) {
      return pendingProvisionMqttCompleter!.future;
    }
    if (shouldThrowProvisionMqtt) {
      throw provisionMqttErrorToThrow ??
          const ApiException(
            statusCode: 500,
            code: 'internal_error',
            message: 'Provision MQTT server error',
          );
    }
    return provisionMqttResultToReturn ??
        MqttCredentialSecretResult(
          metadata: MqttCredentialMetadata(
            gatewayId: gatewayId,
            username: gatewayId,
            credentialVersion: 1,
            status: MqttCredentialStatus.active,
            lastOperationId: '00000000-0000-0000-0000-000000000002',
            operationStatus: MqttOperationStatus.succeeded,
            activatedAt: DateTime.now().toUtc(),
          ),
          operationId: '00000000-0000-0000-0000-000000000002',
          password: 'mock_plaintext_secret_123',
          secretReturned: true,
        );
  }

  Completer<Object>? pendingRotateMqttCompleter;
  bool shouldThrowRotateMqtt = false;
  ApiException? rotateMqttErrorToThrow;
  int rotateMqttCallCount = 0;
  String? lastRotateMqttIdempotencyKey;
  Object? rotateMqttResultToReturn;

  @override
  Future<Object> rotateMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  }) async {
    rotateMqttCallCount++;
    lastRotateMqttIdempotencyKey = idempotencyKey;
    if (pendingRotateMqttCompleter != null) {
      return pendingRotateMqttCompleter!.future;
    }
    if (shouldThrowRotateMqtt) {
      throw rotateMqttErrorToThrow ??
          const ApiException(
            statusCode: 500,
            code: 'internal_error',
            message: 'Rotate MQTT server error',
          );
    }
    return rotateMqttResultToReturn ??
        MqttCredentialSecretResult(
          metadata: MqttCredentialMetadata(
            gatewayId: gatewayId,
            username: gatewayId,
            credentialVersion: 2,
            status: MqttCredentialStatus.active,
            lastOperationId: '00000000-0000-0000-0000-000000000003',
            operationStatus: MqttOperationStatus.succeeded,
            activatedAt: DateTime.now().toUtc(),
          ),
          operationId: '00000000-0000-0000-0000-000000000003',
          password: 'mock_rotated_secret_456',
          secretReturned: true,
        );
  }

  Completer<MqttCredentialMutationResult>? pendingRevokeMqttCompleter;
  bool shouldThrowRevokeMqtt = false;
  ApiException? revokeMqttErrorToThrow;
  int revokeMqttCallCount = 0;
  String? lastRevokeMqttIdempotencyKey;
  MqttCredentialMutationResult? revokeMqttResultToReturn;

  @override
  Future<MqttCredentialMutationResult> revokeMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  }) async {
    revokeMqttCallCount++;
    lastRevokeMqttIdempotencyKey = idempotencyKey;
    if (pendingRevokeMqttCompleter != null) {
      return pendingRevokeMqttCompleter!.future;
    }
    if (shouldThrowRevokeMqtt) {
      throw revokeMqttErrorToThrow ??
          const ApiException(
            statusCode: 500,
            code: 'internal_error',
            message: 'Revoke MQTT server error',
          );
    }
    return revokeMqttResultToReturn ??
        MqttCredentialMutationResult(
          metadata: MqttCredentialMetadata(
            gatewayId: gatewayId,
            username: gatewayId,
            credentialVersion: 1,
            status: MqttCredentialStatus.revoked,
            lastOperationId: '00000000-0000-0000-0000-000000000004',
            operationStatus: MqttOperationStatus.succeeded,
            revokedAt: DateTime.now().toUtc(),
          ),
          operationId: '00000000-0000-0000-0000-000000000004',
          secretReturned: false,
        );
  }
}

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

  ProviderContainer createContainer({List<dynamic> overrides = const []}) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuthRepo),
        gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
        permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
        ...overrides.cast(),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('GatewayListProvider & Session / Epoch Isolation', () {
    test('unauthenticated session leaves provider with empty state and does not fetch', () async {
      final container = createContainer();

      final state = container.read(gatewayListProvider);
      expect(state.isLoading, isFalse);
      expect(state.gateways, isEmpty);
      expect(fakeGatewayRepo.callCount, 0);
    });

    test('authenticated session auto-loads gateways into state', () async {
      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-001',
          name: 'Gateway 1',
          description: 'Greenhouse 1',
          role: GatewayRole.owner,
        ),
      ];

      final container = createContainer();

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u1',
              name: 'User 1',
              email: 'u1@example.com',
            ),
          );

      // Wait for auto-load microtask
      await container.read(gatewayListProvider.notifier).loadGateways();

      final state = container.read(gatewayListProvider);
      expect(state.isLoading, isFalse);
      expect(state.gateways.length, 1);
      expect(state.gateways.first.gatewayId, 'gw-001');
      expect(state.gateways.first.role, GatewayRole.owner);
    });

    test('stale response is discarded if session epoch changes while request is in-flight', () async {
      final completer = Completer<List<GatewayItem>>();
      fakeGatewayRepo.pendingCompleter = completer;

      final container = createContainer();

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u1',
              name: 'User 1',
              email: 'u1@example.com',
            ),
          );

      // Trigger load which gets held by pendingCompleter
      final future = container
          .read(gatewayListProvider.notifier)
          .loadGateways();

      // Now session changes/signs out before future resolves
      await container.read(sessionProvider.notifier).signOut();

      // Now resolve the old request
      completer.complete([
        const GatewayItem(
          gatewayId: 'stale-gw',
          name: 'Stale Gateway',
          role: GatewayRole.owner,
        ),
      ]);
      await future;

      // State must be empty because session was logged out / epoch advanced!
      final state = container.read(gatewayListProvider);
      expect(state.gateways, isEmpty);
    });

    test('signing out immediately purges in-memory gateways catalog', () async {
      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-private',
          name: 'Confidential Gateway',
          role: GatewayRole.owner,
        ),
      ];

      final container = createContainer();

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u1',
              name: 'User 1',
              email: 'u1@example.com',
            ),
          );
      await container.read(gatewayListProvider.notifier).loadGateways();

      expect(container.read(gatewayListProvider).gateways, isNotEmpty);

      // User signs out
      await container.read(sessionProvider.notifier).signOut();

      // Catalog in memory must be purged
      expect(container.read(gatewayListProvider).gateways, isEmpty);
    });

    test(
      'local search query filters items by gateway ID, name, or description',
      () async {
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-am5728-01',
            name: 'Greenhouse Alpha',
            description: 'Station 1 sensor hub',
            role: GatewayRole.owner,
          ),
          const GatewayItem(
            gatewayId: 'gw-esp32-02',
            name: 'Hydroponic Beta',
            description: 'Water pump controller',
            role: GatewayRole.operator,
          ),
          const GatewayItem(
            gatewayId: 'gw-rpi-03',
            name: 'Weather Gamma',
            description: 'Wind and rain gauge',
            role: GatewayRole.viewer,
          ),
        ];

        final container = createContainer();

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'u1',
                name: 'User 1',
                email: 'u1@example.com',
              ),
            );
        await container.read(gatewayListProvider.notifier).loadGateways();

        final notifier = container.read(gatewayListProvider.notifier);

        // Search by ID substring
        notifier.setSearchQuery('am5728');
        expect(container.read(gatewayListProvider).filteredGateways.length, 1);
        expect(
          container.read(gatewayListProvider).filteredGateways.first.gatewayId,
          'gw-am5728-01',
        );

        // Search by Name substring
        notifier.setSearchQuery('beta');
        expect(container.read(gatewayListProvider).filteredGateways.length, 1);
        expect(
          container.read(gatewayListProvider).filteredGateways.first.name,
          'Hydroponic Beta',
        );

        // Search by Description substring
        notifier.setSearchQuery('pump');
        expect(container.read(gatewayListProvider).filteredGateways.length, 1);

        // Clear search
        notifier.setSearchQuery('');
        expect(container.read(gatewayListProvider).filteredGateways.length, 3);
      },
    );
  });

  group('GatewayListProvider Admin Inventory & Keyset Pagination', () {
    test(
      'admin chooses inventory endpoint GET /v1/admin/gateways with no role',
      () async {
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.adminGatewaysResultToReturn =
            const AdminGatewayInventoryResponse(
              items: [
                AdminGatewayItem(
                  gatewayId: 'gw-admin-01',
                  name: 'System Admin Gateway',
                  description: 'All nodes',
                ),
              ],
              nextCursor: null,
            );

        final container = createContainer();
        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-u1',
                name: 'Admin User',
                email: 'admin@example.com',
              ),
            );

        await container.read(gatewayListProvider.notifier).loadGateways();

        expect(fakeGatewayRepo.adminGatewaysCallCount, 1);
        expect(fakeGatewayRepo.callCount, 0);

        final state = container.read(gatewayListProvider);
        expect(state.isLoading, isFalse);
        expect(state.isAdminMode, isTrue);
        expect(state.gateways.length, 1);
        expect(state.gateways.first.gatewayId, 'gw-admin-01');
        expect(state.gateways.first.name, 'System Admin Gateway');
        expect(state.gateways.first.role, isNull);
        expect(state.hasMore, isFalse);
        expect(state.nextCursor, isNull);
      },
    );

    test('ordinary non-admin user chooses user API GET /v1/gateways', () async {
      fakePermsRepo.resultToReturn = UserPermissions.unprivileged;
      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-user-01',
          name: 'User Gateway',
          role: GatewayRole.operator,
        ),
      ];

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'user-u1',
              name: 'Regular User',
              email: 'user@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();

      expect(fakeGatewayRepo.callCount, 1);
      expect(fakeGatewayRepo.adminGatewaysCallCount, 0);

      final state = container.read(gatewayListProvider);
      expect(state.isLoading, isFalse);
      expect(state.isAdminMode, isFalse);
      expect(state.gateways.length, 1);
      expect(state.gateways.first.gatewayId, 'gw-user-01');
      expect(state.gateways.first.role, GatewayRole.operator);
      expect(state.hasMore, isFalse);
      expect(state.nextCursor, isNull);
    });

    test('loading permissions waits for confirmation and does not pick user API prematurely', () async {
      final permsCompleter = Completer<UserPermissions>();
      fakePermsRepo.pendingCompleter = permsCompleter;

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-u2',
              name: 'Pending Admin',
              email: 'admin2@example.com',
            ),
          );

      fakeGatewayRepo.adminGatewaysResultToReturn =
          const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-waited-01',
                name: 'Waited Admin Gateway',
              ),
            ],
            nextCursor: null,
          );

      final loadFuture = container
          .read(gatewayListProvider.notifier)
          .loadGateways();

      // While permissions are loading, neither gateway repo should be queried
      expect(fakeGatewayRepo.callCount, 0);
      expect(fakeGatewayRepo.adminGatewaysCallCount, 0);

      // Resolve permissions as platform admin
      permsCompleter.complete(const UserPermissions(isPlatformAdmin: true));
      await loadFuture;

      // Must have chosen admin API, never fallen back to user API prematurely
      expect(fakeGatewayRepo.adminGatewaysCallCount, 1);
      expect(fakeGatewayRepo.callCount, 0);

      final state = container.read(gatewayListProvider);
      expect(state.isAdminMode, isTrue);
      expect(state.gateways.first.gatewayId, 'gw-waited-01');
    });

    test(
      'permissions error fails closed: no API called, state has error',
      () async {
        fakePermsRepo.shouldThrow = true;
        fakePermsRepo.errorToThrow = const ApiException(
          statusCode: 503,
          code: 'service_unavailable',
          message: 'Permission check database timeout',
        );

        final container = createContainer();
        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'u-err',
                name: 'Error User',
                email: 'err@example.com',
              ),
            );

        await container.read(gatewayListProvider.notifier).loadGateways();

        // Failed closed: neither API called
        expect(fakeGatewayRepo.callCount, 0);
        expect(fakeGatewayRepo.adminGatewaysCallCount, 0);

        final state = container.read(gatewayListProvider);
        expect(state.hasError, isTrue);
        expect(state.gateways, isEmpty);
        expect(state.error, isA<ApiException>());
        expect((state.error as ApiException).code, 'service_unavailable');
      },
    );

    test('pagination merge: loadNextPage merges next page items and advances cursor', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );

      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        if (after == null) {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-01', name: 'Gateway Page 1'),
            ],
            nextCursor: 'gw-01',
          );
        } else if (after == 'gw-01') {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-02', name: 'Gateway Page 2'),
            ],
            nextCursor: 'gw-02',
          );
        } else if (after == 'gw-02') {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-03', name: 'Gateway Page 3'),
            ],
            nextCursor: null,
          );
        }
        return const AdminGatewayInventoryResponse(items: [], nextCursor: null);
      };

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-p',
              name: 'Admin Paginator',
              email: 'p@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();

      var state = container.read(gatewayListProvider);
      expect(state.gateways.length, 1);
      expect(state.gateways.first.gatewayId, 'gw-01');
      expect(state.hasMore, isTrue);
      expect(state.nextCursor, 'gw-01');

      // Load page 2
      await container.read(gatewayListProvider.notifier).loadNextPage();
      expect(fakeGatewayRepo.lastAdminGatewaysAfter, 'gw-01');

      state = container.read(gatewayListProvider);
      expect(state.gateways.length, 2);
      expect(state.gateways[0].gatewayId, 'gw-01');
      expect(state.gateways[1].gatewayId, 'gw-02');
      expect(state.hasMore, isTrue);
      expect(state.nextCursor, 'gw-02');

      // Load page 3 (last page)
      await container.read(gatewayListProvider.notifier).loadNextPage();
      expect(fakeGatewayRepo.lastAdminGatewaysAfter, 'gw-02');

      state = container.read(gatewayListProvider);
      expect(state.gateways.length, 3);
      expect(state.gateways[2].gatewayId, 'gw-03');
      expect(state.hasMore, isFalse);
      expect(state.nextCursor, isNull);

      // Calling loadNextPage when hasMore is false does nothing
      final callsBefore = fakeGatewayRepo.adminGatewaysCallCount;
      await container.read(gatewayListProvider.notifier).loadNextPage();
      expect(fakeGatewayRepo.adminGatewaysCallCount, callsBefore);
    });

    test(
      'cursor malformed / non-advancing cursor guards against endless loops',
      () async {
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        // Page 1 returns nextCursor: 'gw-01'
        // Page 2 returns same nextCursor: 'gw-01' (non-advancing loop)
        fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
          if (after == null) {
            return const AdminGatewayInventoryResponse(
              items: [AdminGatewayItem(gatewayId: 'gw-01', name: 'Gateway 1')],
              nextCursor: 'gw-01',
            );
          } else {
            return const AdminGatewayInventoryResponse(
              items: [AdminGatewayItem(gatewayId: 'gw-02', name: 'Gateway 2')],
              nextCursor: 'gw-01', // Stagnant cursor!
            );
          }
        };

        final container = createContainer();
        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-loop',
                name: 'Admin Loop',
                email: 'loop@example.com',
              ),
            );

        await container.read(gatewayListProvider.notifier).loadGateways();
        expect(container.read(gatewayListProvider).hasMore, isTrue);

        await container.read(gatewayListProvider.notifier).loadNextPage();

        final state = container.read(gatewayListProvider);
        expect(state.gateways.length, 2);
        // Guard terminated the loop because cursor did not advance:
        expect(state.hasMore, isFalse);
        expect(state.nextCursor, isNull);
      },
    );

    test('deduplicates exact IDs on page merge', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );

      // Page 1 returns gw-01, gw-02
      // Page 2 returns gw-02 (duplicate), gw-03
      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        if (after == null) {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-01', name: 'Gateway 1'),
              AdminGatewayItem(gatewayId: 'gw-02', name: 'Gateway 2'),
            ],
            nextCursor: 'gw-02',
          );
        } else {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-02', name: 'Gateway 2 Duplicate'),
              AdminGatewayItem(gatewayId: 'gw-03', name: 'Gateway 3'),
            ],
            nextCursor: null,
          );
        }
      };

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-dedup',
              name: 'Admin Dedup',
              email: 'dedup@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();
      await container.read(gatewayListProvider.notifier).loadNextPage();

      final state = container.read(gatewayListProvider);
      expect(state.gateways.length, 3);
      expect(state.gateways.map((g) => g.gatewayId).toList(), [
        'gw-01',
        'gw-02',
        'gw-03',
      ]);
    });

    test('singleflight guard: at most one loadNextPage in flight', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );

      final nextCompleter = Completer<AdminGatewayInventoryResponse>();
      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        if (after == null) {
          return const AdminGatewayInventoryResponse(
            items: [AdminGatewayItem(gatewayId: 'gw-01', name: 'Gateway 1')],
            nextCursor: 'gw-01',
          );
        }
        return const AdminGatewayInventoryResponse(items: [], nextCursor: null);
      };

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-sf',
              name: 'Admin SingleFlight',
              email: 'sf@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();
      expect(fakeGatewayRepo.adminGatewaysCallCount, 1);

      // Now set pending completer for next page
      fakeGatewayRepo.pendingAdminGatewaysCompleter = nextCompleter;
      fakeGatewayRepo.adminGatewaysHandler = null;

      final f1 = container.read(gatewayListProvider.notifier).loadNextPage();
      final f2 = container.read(gatewayListProvider.notifier).loadNextPage();

      // Only one next page request should have been sent to repo
      expect(fakeGatewayRepo.adminGatewaysCallCount, 2);

      nextCompleter.complete(
        const AdminGatewayInventoryResponse(
          items: [AdminGatewayItem(gatewayId: 'gw-02', name: 'Gateway 2')],
          nextCursor: null,
        ),
      );

      await Future.wait([f1, f2]);
      expect(container.read(gatewayListProvider).gateways.length, 2);
    });

    test('refresh during loadNextPage discards pagination response and resets to first page', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );

      final page2Completer = Completer<AdminGatewayInventoryResponse>();
      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        if (after == null) {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-01', name: 'Initial Gateway 1'),
            ],
            nextCursor: 'gw-01',
          );
        }
        return const AdminGatewayInventoryResponse(items: [], nextCursor: null);
      };

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-ref',
              name: 'Admin Refresh',
              email: 'ref@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();
      expect(container.read(gatewayListProvider).gateways.length, 1);

      // Start page 2 which hangs on completer
      fakeGatewayRepo.adminGatewaysHandler = null;
      fakeGatewayRepo.pendingAdminGatewaysCompleter = page2Completer;
      final page2Future = container
          .read(gatewayListProvider.notifier)
          .loadNextPage();

      // While page 2 is in-flight, trigger refresh
      fakeGatewayRepo.pendingAdminGatewaysCompleter = null;
      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        return const AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(
              gatewayId: 'gw-refreshed',
              name: 'Refreshed Gateway',
            ),
          ],
          nextCursor: null,
        );
      };

      final refreshFuture = container
          .read(gatewayListProvider.notifier)
          .loadGateways();
      await refreshFuture;

      // Now resolve old page 2 request
      page2Completer.complete(
        const AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(gatewayId: 'gw-stale-p2', name: 'Stale Page 2'),
          ],
          nextCursor: null,
        ),
      );
      await page2Future;

      final state = container.read(gatewayListProvider);
      expect(state.gateways.length, 1);
      expect(state.gateways.first.gatewayId, 'gw-refreshed');
      expect(state.isLoadingMore, isFalse);
    });

    test('regression: refresh while page2 pending; firstpage completes state.isLoadingMore false then new nextpage succeeds (old page2 arrives after new results)', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );

      final page2Completer = Completer<AdminGatewayInventoryResponse>();
      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        if (after == null) {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-01', name: 'Initial Gateway 1'),
            ],
            nextCursor: 'gw-01',
          );
        }
        return const AdminGatewayInventoryResponse(items: [], nextCursor: null);
      };

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-ref-1',
              name: 'Admin Refresh 1',
              email: 'ref1@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();
      expect(container.read(gatewayListProvider).gateways.length, 1);
      expect(container.read(gatewayListProvider).hasMore, isTrue);

      // Start page 2 which hangs on completer
      fakeGatewayRepo.adminGatewaysHandler = null;
      fakeGatewayRepo.pendingAdminGatewaysCompleter = page2Completer;
      final page2Future = container
          .read(gatewayListProvider.notifier)
          .loadNextPage();
      expect(container.read(gatewayListProvider).isLoadingMore, isTrue);

      // Refresh triggered while page 2 is in-flight
      fakeGatewayRepo.pendingAdminGatewaysCompleter = null;
      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        if (after == null) {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-refreshed-01',
                name: 'Refreshed Gateway 1',
              ),
            ],
            nextCursor: 'gw-refreshed-01',
          );
        } else if (after == 'gw-refreshed-01') {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-refreshed-02',
                name: 'Refreshed Gateway 2',
              ),
            ],
            nextCursor: null,
          );
        }
        return const AdminGatewayInventoryResponse(items: [], nextCursor: null);
      };

      final refreshFuture = container
          .read(gatewayListProvider.notifier)
          .loadGateways();
      await refreshFuture;

      // Firstpage refreshed: isLoadingMore must be reset to false!
      var state = container.read(gatewayListProvider);
      expect(state.isLoadingMore, isFalse);
      expect(state.gateways.length, 1);
      expect(state.gateways.first.gatewayId, 'gw-refreshed-01');
      expect(state.hasMore, isTrue);
      expect(state.nextCursor, 'gw-refreshed-01');

      // Subsequent loadNextPage with refreshed cursor succeeds!
      await container.read(gatewayListProvider.notifier).loadNextPage();
      state = container.read(gatewayListProvider);
      expect(state.isLoadingMore, isFalse);
      expect(state.gateways.length, 2);
      expect(state.gateways[0].gatewayId, 'gw-refreshed-01');
      expect(state.gateways[1].gatewayId, 'gw-refreshed-02');
      expect(state.hasMore, isFalse);

      // Old page 2 arrives afterwards: must be ignored, no corruption!
      page2Completer.complete(
        const AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(gatewayId: 'gw-stale-p2', name: 'Stale Page 2'),
          ],
          nextCursor: null,
        ),
      );
      await page2Future;

      state = container.read(gatewayListProvider);
      expect(state.gateways.length, 2);
      expect(state.gateways[0].gatewayId, 'gw-refreshed-01');
      expect(state.gateways[1].gatewayId, 'gw-refreshed-02');
      expect(state.isLoadingMore, isFalse);
    });

    test('regression: old page2 result arrives BEFORE refreshed firstpage results, no corruption and subsequent nextpage works', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );

      final page2Completer = Completer<AdminGatewayInventoryResponse>();
      final firstPageCompleter = Completer<AdminGatewayInventoryResponse>();

      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        if (after == null) {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-01', name: 'Initial Gateway 1'),
            ],
            nextCursor: 'gw-01',
          );
        }
        return const AdminGatewayInventoryResponse(items: [], nextCursor: null);
      };

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-ref-2',
              name: 'Admin Refresh 2',
              email: 'ref2@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();
      expect(container.read(gatewayListProvider).gateways.length, 1);

      // Start page 2 which hangs on completer
      fakeGatewayRepo.adminGatewaysHandler = null;
      fakeGatewayRepo.pendingAdminGatewaysCompleter = page2Completer;
      final page2Future = container
          .read(gatewayListProvider.notifier)
          .loadNextPage();
      expect(container.read(gatewayListProvider).isLoadingMore, isTrue);

      // Trigger refresh which hangs on firstPageCompleter
      fakeGatewayRepo.pendingAdminGatewaysCompleter = firstPageCompleter;
      final refreshFuture = container
          .read(gatewayListProvider.notifier)
          .loadGateways();

      // Old page 2 arrives BEFORE refreshed first page finishes
      page2Completer.complete(
        const AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(gatewayId: 'gw-stale-p2', name: 'Stale Page 2'),
          ],
          nextCursor: null,
        ),
      );
      await page2Future;

      // Old page 2 response was discarded because seq advanced; state not corrupted
      var state = container.read(gatewayListProvider);
      expect(state.isLoading, isTrue);
      expect(state.isLoadingMore, isFalse);

      // Now refreshed first page completes
      firstPageCompleter.complete(
        const AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(
              gatewayId: 'gw-refreshed-01',
              name: 'Refreshed Gateway 1',
            ),
          ],
          nextCursor: 'gw-refreshed-01',
        ),
      );
      await refreshFuture;

      state = container.read(gatewayListProvider);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.gateways.length, 1);
      expect(state.gateways.first.gatewayId, 'gw-refreshed-01');
      expect(state.hasMore, isTrue);
      expect(state.nextCursor, 'gw-refreshed-01');

      // Subsequent loadNextPage with refreshed cursor succeeds
      fakeGatewayRepo.pendingAdminGatewaysCompleter = null;
      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        return const AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(
              gatewayId: 'gw-refreshed-02',
              name: 'Refreshed Gateway 2',
            ),
          ],
          nextCursor: null,
        );
      };

      await container.read(gatewayListProvider.notifier).loadNextPage();
      state = container.read(gatewayListProvider);
      expect(state.gateways.length, 2);
      expect(state.gateways[1].gatewayId, 'gw-refreshed-02');
      expect(state.isLoadingMore, isFalse);
    });

    test('regression: old page2 fails with error before or after refresh, no corruption and nextpage succeeds', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );

      final page2Completer = Completer<AdminGatewayInventoryResponse>();
      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        if (after == null) {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-01', name: 'Initial Gateway 1'),
            ],
            nextCursor: 'gw-01',
          );
        }
        return const AdminGatewayInventoryResponse(items: [], nextCursor: null);
      };

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-ref-3',
              name: 'Admin Refresh 3',
              email: 'ref3@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();

      // Start page 2
      fakeGatewayRepo.adminGatewaysHandler = null;
      fakeGatewayRepo.pendingAdminGatewaysCompleter = page2Completer;
      final page2Future = container
          .read(gatewayListProvider.notifier)
          .loadNextPage();

      // Refresh starts
      fakeGatewayRepo.pendingAdminGatewaysCompleter = null;
      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        if (after == null) {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-refreshed-01',
                name: 'Refreshed Gateway 1',
              ),
            ],
            nextCursor: 'gw-refreshed-01',
          );
        } else if (after == 'gw-refreshed-01') {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-refreshed-02',
                name: 'Refreshed Gateway 2',
              ),
            ],
            nextCursor: null,
          );
        }
        return const AdminGatewayInventoryResponse(items: [], nextCursor: null);
      };

      final refreshFuture = container
          .read(gatewayListProvider.notifier)
          .loadGateways();

      // Old page 2 throws error
      page2Completer.completeError(
        const ApiException(
          statusCode: 500,
          code: 'internal_error',
          message: 'Stale page 2 network timeout',
        ),
      );
      await page2Future;

      await refreshFuture;

      var state = container.read(gatewayListProvider);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasLoadMoreError, isFalse);
      expect(state.gateways.length, 1);
      expect(state.gateways.first.gatewayId, 'gw-refreshed-01');

      // Next page succeeds normally
      await container.read(gatewayListProvider.notifier).loadNextPage();
      state = container.read(gatewayListProvider);
      expect(state.gateways.length, 2);
      expect(state.gateways[1].gatewayId, 'gw-refreshed-02');
      expect(state.isLoadingMore, isFalse);
    });

    test('regression: failed refreshed firstpage clears loadingMore and pagination tracking', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );

      final page2Completer = Completer<AdminGatewayInventoryResponse>();
      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        if (after == null) {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-01', name: 'Initial Gateway 1'),
            ],
            nextCursor: 'gw-01',
          );
        }
        return const AdminGatewayInventoryResponse(items: [], nextCursor: null);
      };

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-ref-4',
              name: 'Admin Refresh 4',
              email: 'ref4@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();

      // Start page 2
      fakeGatewayRepo.adminGatewaysHandler = null;
      fakeGatewayRepo.pendingAdminGatewaysCompleter = page2Completer;
      final page2Future = container
          .read(gatewayListProvider.notifier)
          .loadNextPage();
      expect(container.read(gatewayListProvider).isLoadingMore, isTrue);

      // Trigger refresh which fails with ApiException 500
      fakeGatewayRepo.pendingAdminGatewaysCompleter = null;
      fakeGatewayRepo.shouldThrowAdminGateways = true;
      fakeGatewayRepo.adminGatewaysErrorToThrow = const ApiException(
        statusCode: 500,
        code: 'internal_error',
        message: 'Database query failed',
      );

      final refreshFuture = container
          .read(gatewayListProvider.notifier)
          .loadGateways();

      await refreshFuture;

      var state = container.read(gatewayListProvider);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasError, isTrue);
      expect(state.loadMoreError, isNull);
      expect(state.hasMore, isFalse);
      expect(state.nextCursor, isNull);

      // Old page 2 resolves afterwards: cannot resurrect loadingMore or mutate state
      page2Completer.complete(
        const AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(gatewayId: 'gw-stale-p2', name: 'Stale Page 2'),
          ],
          nextCursor: null,
        ),
      );
      await page2Future;

      state = container.read(gatewayListProvider);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasError, isTrue);
    });

    test('authority switch from Admin to User clears cached admin items immediately', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.adminGatewaysResultToReturn =
          const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-admin-secret',
                name: 'Secret Admin Nodes',
              ),
            ],
            nextCursor: null,
          );

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-downgrade',
              name: 'Admin User',
              email: 'downgrade@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();
      expect(container.read(gatewayListProvider).gateways.isNotEmpty, isTrue);
      expect(container.read(gatewayListProvider).isAdminMode, isTrue);

      // Invalidate / downgrade platform admin permission
      container
          .read(userPermissionsProvider.notifier)
          .invalidateAdminPermissions();

      // Memory must be purged immediately so no stale admin inventory is shown
      final state = container.read(gatewayListProvider);
      expect(state.gateways, isEmpty);
      expect(state.isAdminMode, isFalse);
    });

    test('403 admin inventory clears data, invalidates permissions, returns honest error without loops', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.shouldThrowAdminGateways = true;
      fakeGatewayRepo.adminGatewaysErrorToThrow = const ApiException(
        statusCode: 403,
        code: 'forbidden',
        message: 'insufficient permissions',
      );

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-403',
              name: 'Forbidden User',
              email: '403@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();

      final state = container.read(gatewayListProvider);
      expect(state.gateways, isEmpty);
      expect(state.hasError, isTrue);
      expect(state.error, isA<ApiException>());
      expect((state.error as ApiException).statusCode, 403);
      expect((state.error as ApiException).message, 'insufficient permissions');

      // Permissions state must be invalidated
      expect(container.read(isPlatformAdminProvider), isFalse);

      // Honest error: no silent fallback to getGateways()
      expect(fakeGatewayRepo.callCount, 0);
      // No endless 403 refresh loops
      expect(fakeGatewayRepo.adminGatewaysCallCount, 1);
    });

    test('in-flight first inventory + loading with old bool true clears state and discards response without sticking spinner', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );

      final adminCompleter = Completer<AdminGatewayInventoryResponse>();
      fakeGatewayRepo.pendingAdminGatewaysCompleter = adminCompleter;

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-first-flight',
              name: 'Admin InFlight',
              email: 'inflight@example.com',
            ),
          );

      // Await initial permissions load so user is confirmed admin
      await container.read(userPermissionsProvider.notifier).loadPermissions();

      final loadFuture = container
          .read(gatewayListProvider.notifier)
          .loadGateways();

      // First admin inventory request is now in flight
      expect(fakeGatewayRepo.adminGatewaysCallCount, 1);
      expect(container.read(gatewayListProvider).isLoading, isTrue);
      expect(container.read(gatewayListProvider).isAdminMode, isFalse);

      // Now permissions become uncertain: loading with old bool true
      final permsCompleter = Completer<UserPermissions>();
      fakePermsRepo.pendingCompleter = permsCompleter;
      unawaited(
        container.read(userPermissionsProvider.notifier).loadPermissions(),
      );

      // Yield to allow microtask/notifier update
      await Future<void>.delayed(Duration.zero);

      // State must immediately clear and spinner must not be left stuck
      final clearedState = container.read(gatewayListProvider);
      expect(clearedState.isLoading, isFalse);
      expect(clearedState.gateways, isEmpty);
      expect(clearedState.isAdminMode, isFalse);

      // Complete the in-flight admin gateways request
      adminCompleter.complete(
        const AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(
              gatewayId: 'gw-stale-first',
              name: 'Stale First Admin Item',
            ),
          ],
          nextCursor: null,
        ),
      );
      await loadFuture;

      // Verify response was discarded and did not overwrite empty state
      final finalState = container.read(gatewayListProvider);
      expect(finalState.gateways, isEmpty);
      expect(finalState.isAdminMode, isFalse);
    });

    test('admin loaded downgrade clears inventory immediately', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.adminGatewaysResultToReturn =
          const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-admin-loaded',
                name: 'Loaded Admin Nodes',
              ),
            ],
            nextCursor: null,
          );

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-downgrade-user',
              name: 'Admin Downgrade User',
              email: 'downgrade_user@example.com',
            ),
          );

      await container.read(gatewayListProvider.notifier).loadGateways();
      expect(container.read(gatewayListProvider).gateways.isNotEmpty, isTrue);
      expect(container.read(gatewayListProvider).isAdminMode, isTrue);

      // Invalidate / downgrade platform admin permission
      container
          .read(userPermissionsProvider.notifier)
          .invalidateAdminPermissions();

      // Memory must be purged immediately so no stale admin inventory is shown
      final state = container.read(gatewayListProvider);
      expect(state.gateways, isEmpty);
      expect(state.isAdminMode, isFalse);
      expect(state.hasMore, isFalse);
      expect(state.nextCursor, isNull);
    });

    test(
      'downgrade->upgrade late response is fenced by authority generation',
      () async {
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        final gen1Completer = Completer<AdminGatewayInventoryResponse>();
        fakeGatewayRepo.pendingAdminGatewaysCompleter = gen1Completer;

        final container = createContainer();
        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-late-user',
                name: 'Late Admin User',
                email: 'late@example.com',
              ),
            );

        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        final gen1Future = container
            .read(gatewayListProvider.notifier)
            .loadGateways();
        expect(fakeGatewayRepo.adminGatewaysCallCount, 1);

        // Downgrade (authority generation advances)
        container
            .read(userPermissionsProvider.notifier)
            .invalidateAdminPermissions();

        // Upgrade back to admin (authority generation advances again)
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakePermsRepo.pendingCompleter = null;
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();
        expect(container.read(isPlatformAdminProvider), isTrue);

        // Now complete the generation 1 late response
        gen1Completer.complete(
          const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-gen1-stale',
                name: 'Stale Gen1 Gateway',
              ),
            ],
            nextCursor: null,
          ),
        );
        await gen1Future;

        // Pre-change response must NOT be accepted even though isPlatformAdmin is true again
        final state = container.read(gatewayListProvider);
        expect(state.gateways, isEmpty);
        expect(state.isAdminMode, isFalse);
      },
    );
  });
}
