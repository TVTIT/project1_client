import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite/features/gateways/data/mqtt_credential_dto.dart';
import 'package:kite/features/gateways/providers/gateway_list_provider.dart';

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

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeGatewayRepo = FakeGatewayRepository();
  });

  tearDown(() {
    fakeAuthRepo.dispose();
  });

  group('GatewayListProvider & Session / Epoch Isolation', () {
    test('unauthenticated session leaves provider with empty state and does not fetch', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
        ],
      );
      addTearDown(container.dispose);

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
}
