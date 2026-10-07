import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
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
