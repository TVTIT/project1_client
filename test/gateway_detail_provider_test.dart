import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite/features/gateways/providers/gateway_detail_provider.dart';

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

  group('GatewayDetailProvider Validation & Composition', () {
    test('invalid gateway ID syntax immediately marks notFound without calling repository', () async {
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
            const SessionUser(userId: 'u1', name: 'User', email: 'u@test.com'),
          );

      final notifier = container.read(
        gatewayDetailProvider('invalid/id!').notifier,
      );
      await notifier.load();

      final state = container.read(gatewayDetailProvider('invalid/id!'));
      expect(state.isNotFound, isTrue);
      expect(state.invalidId, isTrue);
      expect(fakeGatewayRepo.callCount, 0);
      expect(fakeGatewayRepo.sensorsCallCount, 0);
    });

    test(
      'reserved backend_service identifier immediately marks notFound',
      () async {
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
                name: 'User',
                email: 'u@test.com',
              ),
            );

        final notifier = container.read(
          gatewayDetailProvider('backend_service').notifier,
        );
        await notifier.load();

        final state = container.read(gatewayDetailProvider('backend_service'));
        expect(state.isNotFound, isTrue);
        expect(state.invalidId, isTrue);
        expect(fakeGatewayRepo.callCount, 0);
      },
    );

    test('unauthenticated session stays in initial empty state', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(gatewayDetailProvider('gw-001'));
      expect(state.isLoading, isFalse);
      expect(state.gateway, isNull);
      expect(state.sensors, isEmpty);
    });

    test(
      'composes metadata from getGateways and sensors from getGatewaySensors',
      () async {
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
                name: 'User',
                email: 'u@test.com',
              ),
            );

        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-001',
            name: 'Station 001',
            role: GatewayRole.owner,
            description: 'Greenhouse',
          ),
        ];

        fakeGatewayRepo.sensorsMap = {
          'gw-001': [
            const SensorItem(
              sensorId: 'temp_01',
              name: 'Temperature',
              unit: '°C',
            ),
            const SensorItem(sensorId: 'hum_01', name: 'Humidity', unit: '%'),
          ],
        };

        final notifier = container.read(
          gatewayDetailProvider('gw-001').notifier,
        );
        await notifier.load();

        final state = container.read(gatewayDetailProvider('gw-001'));
        expect(state.isLoaded, isTrue);
        expect(state.gateway, isNotNull);
        expect(state.gateway!.name, 'Station 001');
        expect(state.gateway!.role, GatewayRole.owner);
        expect(state.sensors.length, 2);
        expect(state.sensors[0].sensorId, 'temp_01');
        expect(state.sensors[1].sensorId, 'hum_01');
      },
    );

    test('anti-enumeration: foreign or unknown gateway in getGateways returns notFound', () async {
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
            const SessionUser(userId: 'u1', name: 'User', email: 'u@test.com'),
          );

      // User only has access to gw-authorized
      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-authorized',
          name: 'Authorized GW',
          role: GatewayRole.viewer,
        ),
      ];

      // Accessing foreign gateway
      final notifier = container.read(
        gatewayDetailProvider('gw-foreign').notifier,
      );
      await notifier.load();

      final state = container.read(gatewayDetailProvider('gw-foreign'));
      expect(state.isNotFound, isTrue);
      expect(state.gateway, isNull);
    });

    test('404 on getGatewaySensors marks page as notFound', () async {
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
            const SessionUser(userId: 'u1', name: 'User', email: 'u@test.com'),
          );

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-001',
          name: 'Station 001',
          role: GatewayRole.operator,
        ),
      ];

      fakeGatewayRepo.shouldThrowSensors = true;
      fakeGatewayRepo.sensorsErrorToThrow = const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'resource not found',
      );

      final notifier = container.read(gatewayDetailProvider('gw-001').notifier);
      await notifier.load();

      final state = container.read(gatewayDetailProvider('gw-001'));
      expect(state.isNotFound, isTrue);
    });
  });

  group('Failure Distinction & Sensor Recovery', () {
    test('metadata failure results in general error state', () async {
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
            const SessionUser(userId: 'u1', name: 'User', email: 'u@test.com'),
          );

      fakeGatewayRepo.shouldThrow = true;
      fakeGatewayRepo.errorToThrow = const ApiException(
        statusCode: 500,
        code: 'internal_error',
        message: 'Database unavailable',
      );

      final notifier = container.read(gatewayDetailProvider('gw-001').notifier);
      await notifier.load();

      final state = container.read(gatewayDetailProvider('gw-001'));
      expect(state.hasGeneralError, isTrue);
      expect(state.metadataError, isNotNull);
      expect(state.gateway, isNull);
    });

    test('sensor failure allows metadata display while exposing sensorsError and reloadSensorsOnly', () async {
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
            const SessionUser(userId: 'u1', name: 'User', email: 'u@test.com'),
          );

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
        message: 'Sensors service busy',
      );

      final notifier = container.read(gatewayDetailProvider('gw-001').notifier);
      await notifier.load();

      final state = container.read(gatewayDetailProvider('gw-001'));
      expect(state.isLoaded, isTrue);
      expect(state.gateway, isNotNull);
      expect(state.gateway!.name, 'Station 001');
      expect(state.hasSensorsError, isTrue);
      expect(state.sensors, isEmpty);

      // Now recover sensors
      fakeGatewayRepo.shouldThrowSensors = false;
      fakeGatewayRepo.sensorsMap = {
        'gw-001': [const SensorItem(sensorId: 's1', name: 'Recovered Sensor')],
      };

      await notifier.load(reloadSensorsOnly: true);

      final recovered = container.read(gatewayDetailProvider('gw-001'));
      expect(recovered.hasSensorsError, isFalse);
      expect(recovered.sensors.length, 1);
      expect(recovered.sensors.first.name, 'Recovered Sensor');
    });

    test('valid empty sensors catalog is flagged as isSensorsEmpty', () async {
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
            const SessionUser(userId: 'u1', name: 'User', email: 'u@test.com'),
          );

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-001',
          name: 'Empty Station',
          role: GatewayRole.owner,
        ),
      ];
      fakeGatewayRepo.sensorsMap = {'gw-001': []};

      final notifier = container.read(gatewayDetailProvider('gw-001').notifier);
      await notifier.load();

      final state = container.read(gatewayDetailProvider('gw-001'));
      expect(state.isLoaded, isTrue);
      expect(state.isSensorsEmpty, isTrue);
      expect(state.sensors, isEmpty);
    });

    test('search query correctly filters sensors locally', () async {
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
            const SessionUser(userId: 'u1', name: 'User', email: 'u@test.com'),
          );

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-001',
          name: 'Station',
          role: GatewayRole.operator,
        ),
      ];
      fakeGatewayRepo.sensorsMap = {
        'gw-001': [
          const SensorItem(
            sensorId: 'temp_01',
            name: 'Temperature',
            unit: '°C',
          ),
          const SensorItem(sensorId: 'press_01', name: 'Pressure', unit: 'bar'),
          const SensorItem(sensorId: 'hum_01', name: 'Humidity', unit: '%'),
        ],
      };

      final notifier = container.read(gatewayDetailProvider('gw-001').notifier);
      await notifier.load();

      notifier.setSearchQuery('temp');
      expect(
        container.read(gatewayDetailProvider('gw-001')).filteredSensors.length,
        1,
      );

      notifier.setSearchQuery('bar');
      expect(
        container.read(gatewayDetailProvider('gw-001')).filteredSensors.length,
        1,
      );

      notifier.setSearchQuery('01');
      expect(
        container.read(gatewayDetailProvider('gw-001')).filteredSensors.length,
        3,
      );

      notifier.setSearchQuery('nonexistent');
      expect(
        container.read(gatewayDetailProvider('gw-001')).filteredSensors,
        isEmpty,
      );
    });
  });

  group('Session Epoch Isolation & Out-of-Order Guarding', () {
    test('stale response is discarded when session epoch changes', () async {
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
              email: 'u1@test.com',
            ),
          );

      final completer = Completer<List<GatewayItem>>();
      fakeGatewayRepo.pendingCompleter = completer;

      final notifier = container.read(gatewayDetailProvider('gw-001').notifier);
      final loadFuture = notifier.load();

      // Epoch advances (e.g. user logs out or switches accounts)
      await container.read(sessionProvider.notifier).signOut();

      completer.complete([
        const GatewayItem(
          gatewayId: 'gw-001',
          name: 'Stale Station',
          role: GatewayRole.owner,
        ),
      ]);

      await loadFuture;

      final state = container.read(gatewayDetailProvider('gw-001'));
      // Stale response must be ignored
      expect(state.gateway, isNull);
    });
  });
}
