import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite/features/gateways/presentation/create_sensor_dialog.dart';
import 'package:kite/features/gateways/providers/gateway_detail_provider.dart';

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

  group('GatewayDetailProvider Validation & Composition', () {
    test('invalid gateway ID syntax immediately marks notFound without calling repository', () async {
      final container = createContainer();

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
      expect(state.isOwner, isFalse);
      expect(state.membershipRole, isNull);
      expect(state.sensors, isEmpty);
      expect(state.gateway, isNull);
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
      final container = createContainer();

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
      final container = createContainer();

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
      final container = createContainer();

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

    test('loaded owner -> reload 404 returns notfound and clears role, isOwner, and sensors', () async {
      final container = createContainer();

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(userId: 'u1', name: 'User', email: 'u@test.com'),
          );

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-owner-001',
          name: 'Owner Station',
          role: GatewayRole.owner,
        ),
      ];
      fakeGatewayRepo.sensorsMap = {
        'gw-owner-001': [
          const SensorItem(sensorId: 's1', name: 'Sensor 1', unit: '°C'),
        ],
      };

      final notifier = container.read(
        gatewayDetailProvider('gw-owner-001').notifier,
      );
      await notifier.load();

      final loadedState = container.read(gatewayDetailProvider('gw-owner-001'));
      expect(loadedState.isLoaded, isTrue);
      expect(loadedState.isOwner, isTrue);
      expect(loadedState.membershipRole, GatewayRole.owner);
      expect(loadedState.sensors.length, 1);
      expect(loadedState.gateway, isNotNull);

      // Now reload returns 404 (e.g. gateway removed from user catalog / 404 from server)
      fakeGatewayRepo.items = []; // Anti-enumeration 404
      await notifier.load();

      final reloadedState = container.read(
        gatewayDetailProvider('gw-owner-001'),
      );
      expect(reloadedState.isNotFound, isTrue);
      expect(reloadedState.isLoaded, isFalse);
      expect(reloadedState.isOwner, isFalse);
      expect(reloadedState.membershipRole, isNull);
      expect(reloadedState.sensors, isEmpty);
      expect(reloadedState.gateway, isNull);
    });

    test('loaded owner -> sensor reload 404 returns notfound and clears role, isOwner, and sensors', () async {
      final container = createContainer();

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(userId: 'u1', name: 'User', email: 'u@test.com'),
          );

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-owner-002',
          name: 'Owner Station 2',
          role: GatewayRole.owner,
        ),
      ];
      fakeGatewayRepo.sensorsMap = {
        'gw-owner-002': [
          const SensorItem(sensorId: 's1', name: 'Sensor 1', unit: '°C'),
        ],
      };

      final notifier = container.read(
        gatewayDetailProvider('gw-owner-002').notifier,
      );
      await notifier.load();

      final loadedState = container.read(gatewayDetailProvider('gw-owner-002'));
      expect(loadedState.isLoaded, isTrue);
      expect(loadedState.isOwner, isTrue);
      expect(loadedState.membershipRole, GatewayRole.owner);

      // Sensors fetch returns 404 on reload
      fakeGatewayRepo.shouldThrowSensors = true;
      fakeGatewayRepo.sensorsErrorToThrow = const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'resource not found',
      );
      await notifier.load();

      final reloadedState = container.read(
        gatewayDetailProvider('gw-owner-002'),
      );
      expect(reloadedState.isNotFound, isTrue);
      expect(reloadedState.isLoaded, isFalse);
      expect(reloadedState.isOwner, isFalse);
      expect(reloadedState.membershipRole, isNull);
      expect(reloadedState.sensors, isEmpty);
      expect(reloadedState.gateway, isNull);
    });

    test('loaded owner -> partial reloadSensorsOnly 404 returns notfound and clears role, isOwner, and sensors, denying capability', () async {
      final container = createContainer();

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(userId: 'u1', name: 'User', email: 'u@test.com'),
          );

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-owner-003',
          name: 'Owner Station 3',
          role: GatewayRole.owner,
        ),
      ];
      fakeGatewayRepo.sensorsMap = {
        'gw-owner-003': [
          const SensorItem(sensorId: 's1', name: 'Sensor 1', unit: '°C'),
        ],
      };

      final notifier = container.read(
        gatewayDetailProvider('gw-owner-003').notifier,
      );
      await notifier.load();

      final loadedState = container.read(gatewayDetailProvider('gw-owner-003'));
      expect(loadedState.isLoaded, isTrue);
      expect(loadedState.isOwner, isTrue);
      expect(loadedState.membershipRole, GatewayRole.owner);
      expect(loadedState.sensors.length, 1);

      // Sensors fetch returns 404 on partial sensor reload
      fakeGatewayRepo.shouldThrowSensors = true;
      fakeGatewayRepo.sensorsErrorToThrow = const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'resource not found',
      );
      await notifier.load(reloadSensorsOnly: true);

      final reloadedState = container.read(
        gatewayDetailProvider('gw-owner-003'),
      );
      expect(reloadedState.isNotFound, isTrue);
      expect(reloadedState.isLoaded, isFalse);
      expect(reloadedState.isOwner, isFalse);
      expect(reloadedState.membershipRole, isNull);
      expect(reloadedState.sensors, isEmpty);
      expect(reloadedState.gateway, isNull);

      // Capability denied in resolveSensorProvisionAuthority
      final permissionsState = container.read(userPermissionsProvider);
      final authority = resolveSensorProvisionAuthority(
        permissionsState: permissionsState,
        detailState: reloadedState,
        gatewayId: 'gw-owner-003',
      );
      expect(authority, isNull);
    });

    test('loaded owner -> partial reloadSensorsOnly 503 retains metadata, role, isOwner, and session', () async {
      final container = createContainer();

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(userId: 'u1', name: 'User', email: 'u@test.com'),
          );

      fakeGatewayRepo.items = [
        const GatewayItem(
          gatewayId: 'gw-owner-004',
          name: 'Owner Station 4',
          role: GatewayRole.owner,
        ),
      ];
      fakeGatewayRepo.sensorsMap = {
        'gw-owner-004': [
          const SensorItem(sensorId: 's1', name: 'Sensor 1', unit: '°C'),
        ],
      };

      final notifier = container.read(
        gatewayDetailProvider('gw-owner-004').notifier,
      );
      await notifier.load();

      final loadedState = container.read(gatewayDetailProvider('gw-owner-004'));
      expect(loadedState.isLoaded, isTrue);

      fakeGatewayRepo.shouldThrowSensors = true;
      fakeGatewayRepo.sensorsErrorToThrow = const ApiException(
        statusCode: 503,
        code: 'service_unavailable',
        message: 'Server busy',
      );
      await notifier.load(reloadSensorsOnly: true);

      final reloadedState = container.read(
        gatewayDetailProvider('gw-owner-004'),
      );
      expect(reloadedState.isLoaded, isTrue);
      expect(reloadedState.isOwner, isTrue);
      expect(reloadedState.membershipRole, GatewayRole.owner);
      expect(reloadedState.gateway, isNotNull);
      expect(reloadedState.hasSensorsError, isTrue);
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
    });
  });

  group('Failure Distinction & Sensor Recovery', () {
    test('metadata failure results in general error state', () async {
      final container = createContainer();

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
      final container = createContainer();

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
      final container = createContainer();

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
      final container = createContainer();

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
      final container = createContainer();

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

  group('Admin Inventory Keyset Cursor Lookup & Denial Scenarios', () {
    test('admin resolves foreign gateway metadata on later page via cursor pagination', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.items = []; // Not in user_gateways

      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        if (after == null) {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-page1-01', name: 'Page 1 First'),
              AdminGatewayItem(gatewayId: 'gw-page1-02', name: 'Page 1 Second'),
            ],
            nextCursor: 'gw-page1-02',
          );
        } else if (after == 'gw-page1-02') {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-page2-found',
                name: 'Found on Page 2',
                description: 'Description 2',
              ),
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
              userId: 'admin-u1',
              name: 'Admin',
              email: 'admin@test.com',
            ),
          );

      final notifier = container.read(
        gatewayDetailProvider('gw-page2-found').notifier,
      );
      await notifier.load();

      final state = container.read(gatewayDetailProvider('gw-page2-found'));
      expect(state.isLoaded, isTrue);
      expect(state.gateway, isNotNull);
      expect(state.gateway!.gatewayId, 'gw-page2-found');
      expect(state.gateway!.name, 'Found on Page 2');
      expect(state.gateway!.role, isNull);
      expect(state.membershipRole, isNull);
      expect(state.isOwner, isFalse);
      expect(state.isSensorReadDenied, isTrue);
      expect(state.sensors, isEmpty);
      expect(fakeGatewayRepo.adminGatewaysCallCount, 2);
    });

    test(
      'admin lookup stops early when lexicographical order passed',
      () async {
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.items = [];

        // We are looking for 'gw-alpha'.
        // Page 1 has 'gw-beta', which is lexicographically > 'gw-alpha'.
        fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
          return const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(gatewayId: 'gw-beta', name: 'Beta Gateway'),
              AdminGatewayItem(gatewayId: 'gw-gamma', name: 'Gamma Gateway'),
            ],
            nextCursor: 'gw-gamma',
          );
        };

        final container = createContainer();
        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-u1',
                name: 'Admin',
                email: 'admin@test.com',
              ),
            );

        final notifier = container.read(
          gatewayDetailProvider('gw-alpha').notifier,
        );
        await notifier.load();

        final state = container.read(gatewayDetailProvider('gw-alpha'));
        // Because order passed on page 1, stops scanning and marks notFound
        expect(state.isNotFound, isTrue);
        expect(fakeGatewayRepo.adminGatewaysCallCount, 1);
      },
    );

    test('admin lookup returns 504 lookup_limit_exceeded when explicit page cap reached', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.items = [];

      // Endless pages of smaller IDs
      fakeGatewayRepo.adminGatewaysHandler = (limit, after) {
        final currentIdx = after == null ? 0 : int.parse(after.split('-').last);
        final nextIdx = currentIdx + 1;
        return AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(
              gatewayId: 'gw-a-${currentIdx.toString().padLeft(4, '0')}',
              name: 'Gateway $currentIdx',
            ),
          ],
          nextCursor: 'gw-a-${nextIdx.toString().padLeft(4, '0')}',
        );
      };

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-u1',
              name: 'Admin',
              email: 'admin@test.com',
            ),
          );

      // Target is 'gw-z-target' which won't be reached within 20 pages
      final notifier = container.read(
        gatewayDetailProvider('gw-z-target').notifier,
      );
      await notifier.load();

      final state = container.read(gatewayDetailProvider('gw-z-target'));
      expect(state.hasGeneralError, isTrue);
      expect(state.metadataError, isA<ApiException>());
      final err = state.metadataError as ApiException;
      expect(err.statusCode, 504);
      expect(err.code, 'lookup_limit_exceeded');
      expect(fakeGatewayRepo.adminGatewaysCallCount, 20);
    });

    test(
      'stale response discarded on session change during cursor lookup',
      () async {
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.items = [];

        final completer = Completer<AdminGatewayInventoryResponse>();
        fakeGatewayRepo.pendingAdminGatewaysCompleter = completer;

        final container = createContainer();
        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-u1',
                name: 'Admin',
                email: 'admin@test.com',
              ),
            );

        final notifier = container.read(
          gatewayDetailProvider('gw-deep-stale').notifier,
        );
        final future = notifier.load();

        // Session logs out while request in-flight
        await container.read(sessionProvider.notifier).signOut();

        completer.complete(
          const AdminGatewayInventoryResponse(
            items: [
              AdminGatewayItem(
                gatewayId: 'gw-deep-stale',
                name: 'Stale Admin Item',
              ),
            ],
            nextCursor: null,
          ),
        );
        await future;

        final state = container.read(gatewayDetailProvider('gw-deep-stale'));
        expect(state.gateway, isNull);
      },
    );

    test('detail lookup in-flight downgrade clears metadata and discards late response', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.items = []; // Not in user_gateways

      final completer = Completer<AdminGatewayInventoryResponse>();
      fakeGatewayRepo.pendingAdminGatewaysCompleter = completer;

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-detail-down',
              name: 'Admin Detail Down',
              email: 'detaildown@example.com',
            ),
          );

      await container.read(userPermissionsProvider.notifier).loadPermissions();

      final notifier = container.read(
        gatewayDetailProvider('gw-foreign-inflight').notifier,
      );
      final loadFuture = notifier.load();

      // Allow user_gateways fetch to complete and admin inventory lookup to begin
      await Future<void>.delayed(Duration.zero);
      expect(fakeGatewayRepo.adminGatewaysCallCount, 1);

      // Downgrade permissions while lookup is in-flight
      container
          .read(userPermissionsProvider.notifier)
          .invalidateAdminPermissions();

      // Detail state must clear immediately and mark notFound
      final clearedState = container.read(
        gatewayDetailProvider('gw-foreign-inflight'),
      );
      expect(clearedState.gateway, isNull);
      expect(clearedState.isNotFound, isTrue);
      expect(clearedState.isSensorReadDenied, isFalse);

      // Now resolve the in-flight admin gateways request
      completer.complete(
        const AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(
              gatewayId: 'gw-foreign-inflight',
              name: 'Late Found Gateway',
            ),
          ],
          nextCursor: null,
        ),
      );
      await loadFuture;

      // Verify late response was discarded and state remains notFound
      final finalState = container.read(
        gatewayDetailProvider('gw-foreign-inflight'),
      );
      expect(finalState.gateway, isNull);
      expect(finalState.isNotFound, isTrue);
    });

    test('downgrade->upgrade late response in detail is fenced by authority generation', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.items = [];

      final gen1Completer = Completer<AdminGatewayInventoryResponse>();
      fakeGatewayRepo.pendingAdminGatewaysCompleter = gen1Completer;

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-detail-late',
              name: 'Admin Detail Late',
              email: 'detaillate@example.com',
            ),
          );

      await container.read(userPermissionsProvider.notifier).loadPermissions();

      final notifier = container.read(
        gatewayDetailProvider('gw-foreign-late').notifier,
      );
      final loadFuture = notifier.load();

      await Future<void>.delayed(Duration.zero);
      expect(fakeGatewayRepo.adminGatewaysCallCount, 1);

      // Downgrade
      container
          .read(userPermissionsProvider.notifier)
          .invalidateAdminPermissions();

      // Upgrade back to admin
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakePermsRepo.pendingCompleter = null;
      await container.read(userPermissionsProvider.notifier).loadPermissions();
      expect(container.read(isPlatformAdminProvider), isTrue);

      // Resolve gen1 late response
      gen1Completer.complete(
        const AdminGatewayInventoryResponse(
          items: [
            AdminGatewayItem(
              gatewayId: 'gw-foreign-late',
              name: 'Stale Gen1 Gateway',
            ),
          ],
          nextCursor: null,
        ),
      );
      await loadFuture;

      final state = container.read(gatewayDetailProvider('gw-foreign-late'));
      expect(state.gateway, isNull);
      expect(state.isNotFound, isTrue);
    });

    test('permission error on foreign gateway shows honest error not masquerade notfound', () async {
      fakeGatewayRepo.items = []; // Foreign gateway

      fakePermsRepo.shouldThrow = true;
      fakePermsRepo.errorToThrow = const ApiException(
        statusCode: 503,
        code: 'service_unavailable',
        message: 'Permission database timeout',
      );

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'user-perm-err',
              name: 'Perm Err User',
              email: 'permerr@example.com',
            ),
          );

      final notifier = container.read(
        gatewayDetailProvider('gw-foreign-err').notifier,
      );
      await notifier.load();

      final state = container.read(gatewayDetailProvider('gw-foreign-err'));
      expect(state.hasGeneralError, isTrue);
      expect(state.isNotFound, isFalse);
      expect(state.metadataError, isA<ApiException>());
      expect((state.metadataError as ApiException).statusCode, 503);
      expect(
        (state.metadataError as ApiException).message,
        'Permission database timeout',
      );
    });

    test('403 on admin inventory lookup fails closed and refreshes permissions without loops', () async {
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.items = [];
      fakeGatewayRepo.shouldThrowAdminGateways = true;
      fakeGatewayRepo.adminGatewaysErrorToThrow = const ApiException(
        statusCode: 403,
        code: 'forbidden',
        message: 'Admin inventory forbidden',
      );

      final container = createContainer();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-403-detail',
              name: 'Admin 403 Detail',
              email: 'admin403@example.com',
            ),
          );

      final notifier = container.read(
        gatewayDetailProvider('gw-foreign-403').notifier,
      );
      await notifier.load();

      final state = container.read(gatewayDetailProvider('gw-foreign-403'));
      expect(state.hasGeneralError, isTrue);
      expect(state.metadataError, isA<ApiException>());
      expect((state.metadataError as ApiException).statusCode, 403);
      expect(state.gateway, isNull);

      // Permissions invalidated
      expect(container.read(isPlatformAdminProvider), isFalse);

      // No endless loops
      expect(fakeGatewayRepo.adminGatewaysCallCount, 1);
    });

    test(
      'detail retains valid user membership data on admin downgrade',
      () async {
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.items = [
          const GatewayItem(
            gatewayId: 'gw-member-owner',
            name: 'Member Owner Gateway',
            role: GatewayRole.owner,
          ),
        ];

        final container = createContainer();
        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'dual-role-user',
                name: 'Dual Role User',
                email: 'dual@example.com',
              ),
            );

        final notifier = container.read(
          gatewayDetailProvider('gw-member-owner').notifier,
        );
        await notifier.load();

        final state = container.read(gatewayDetailProvider('gw-member-owner'));
        expect(state.isLoaded, isTrue);
        expect(state.gateway, isNotNull);
        expect(state.membershipRole, GatewayRole.owner);
        expect(state.isOwner, isTrue);

        // Downgrade platform admin
        container
            .read(userPermissionsProvider.notifier)
            .invalidateAdminPermissions();

        // State must retain user membership data and ordinary user catalog behavior/owner semantics
        final retainedState = container.read(
          gatewayDetailProvider('gw-member-owner'),
        );
        expect(retainedState.gateway, isNotNull);
        expect(retainedState.gateway!.name, 'Member Owner Gateway');
        expect(retainedState.membershipRole, GatewayRole.owner);
        expect(retainedState.isOwner, isTrue);
        expect(retainedState.isNotFound, isFalse);
      },
    );
  });
}
