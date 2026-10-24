import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/providers/digital_twin_providers.dart';

import 'session_test.dart';
import 'twin_list_provider_test.dart';

const sensorUrn = 'urn:ngsi-ld:Sensor:gw:s1';
TwinStateResponse stateFixture() => TwinStateResponse(
  id: sensorUrn,
  type: 'Sensor',
  gatewayId: 'gw',
  reportedState: {'exact': BigInt.parse('9223372036854775807'), 'small': 12},
  desiredState: const {},
  reportedVersion: '9223372036854775807',
  desiredVersion: '0',
);

class StateRepository extends ListTwinRepository {
  int stateCalls = 0;
  Future<TwinStateResponse> Function()? stateHandler;
  @override
  Future<TwinStateResponse> getTwinState(String entityId) {
    stateCalls++;
    return stateHandler?.call() ?? Future.value(stateFixture());
  }
}

void main() {
  late ProviderContainer container;
  late FakeAuthRepository auth;
  late StateRepository repo;
  late ProviderSubscription<TwinStateViewState> subscription;
  void signIn([String id = 'u1']) => container
      .read(sessionProvider.notifier)
      .setSession(
        SessionUser(userId: id, name: 'Member', email: '$id@example.com'),
      );
  setUp(() {
    auth = FakeAuthRepository();
    repo = StateRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        digitalTwinRepositoryProvider.overrideWithValue(repo),
      ],
    );
    signIn();
    subscription = container.listen(
      twinStateViewProvider(sensorUrn),
      (_, _) {},
    );
  });
  tearDown(() {
    subscription.close();
    container.dispose();
    auth.dispose();
  });
  for (final status in [403, 404, 503]) {
    test(
      '$status purges denial but retains transient stale state and session',
      () async {
        final notifier = container.read(
          twinStateViewProvider(sensorUrn).notifier,
        );
        await notifier.loadState();
        repo.stateHandler = () => Future.error(
          ApiException(statusCode: status, code: 'test', message: 'test'),
        );
        await notifier.loadState();
        final state = container.read(twinStateViewProvider(sensorUrn));
        expect(state.state == null, status != 503);
        expect(state.error, isA<ApiException>());
        expect(container.read(sessionProvider).isAuthenticated, isTrue);
      },
    );
  }
  test('same identity token refresh does not erase populated state', () async {
    await container.read(twinStateViewProvider(sensorUrn).notifier).loadState();
    signIn();
    expect(container.read(twinStateViewProvider(sensorUrn)).state, isNotNull);
  });
  test(
    'identity switch releases in-flight lock and fences old success',
    () async {
      final pending = Completer<TwinStateResponse>();
      repo.stateHandler = () => pending.future;
      final old = container
          .read(twinStateViewProvider(sensorUrn).notifier)
          .loadState();
      signIn('u2');
      container.read(twinStateViewProvider(sensorUrn));
      repo.stateHandler = () => Future.value(stateFixture());
      final fresh = container
          .read(twinStateViewProvider(sensorUrn).notifier)
          .loadState();
      await Future<void>.delayed(Duration.zero);
      expect(repo.stateCalls, 2);
      pending.complete(stateFixture());
      await Future.wait([old, fresh]);
      expect(container.read(twinStateViewProvider(sensorUrn)).state, isNotNull);
    },
  );
  test('anonymous never requests state', () async {
    container.read(sessionProvider.notifier).setSession(null);
    await container.read(twinStateViewProvider(sensorUrn).notifier).loadState();
    expect(repo.stateCalls, 0);
  });
  test('copyWith can explicitly clear data', () {
    final state = TwinStateViewState(state: stateFixture());
    expect(state.copyWith(state: null).state, isNull);
  });
  test(
    'new identity ignores late 404 while current request is pending',
    () async {
      final oldPending = Completer<TwinStateResponse>();
      final newPending = Completer<TwinStateResponse>();
      repo.stateHandler = () => oldPending.future;
      final old = container
          .read(twinStateViewProvider(sensorUrn).notifier)
          .loadState();
      signIn('u2');
      container.read(twinStateViewProvider(sensorUrn));
      repo.stateHandler = () => newPending.future;
      final fresh = container
          .read(twinStateViewProvider(sensorUrn).notifier)
          .loadState();
      oldPending.completeError(
        const ApiException(statusCode: 404, code: 'not_found', message: 'safe'),
      );
      await old;
      final concurrent = container
          .read(twinStateViewProvider(sensorUrn).notifier)
          .loadState();
      expect(repo.stateCalls, 2);
      expect(container.read(twinStateViewProvider(sensorUrn)).error, isNull);
      newPending.complete(stateFixture());
      await Future.wait([fresh, concurrent]);
      expect(container.read(twinStateViewProvider(sensorUrn)).state, isNotNull);
    },
  );
  test(
    'state response for different entity is rejected rather than displayed',
    () async {
      repo.stateHandler = () async => const TwinStateResponse(
        id: 'urn:ngsi-ld:Sensor:other:s1',
        type: 'Sensor',
        gatewayId: 'other',
        reportedState: {},
        desiredState: {},
        reportedVersion: '1',
        desiredVersion: '0',
      );
      await container
          .read(twinStateViewProvider(sensorUrn).notifier)
          .loadState();
      final state = container.read(twinStateViewProvider(sensorUrn));
      expect(state.state, isNull);
      expect(state.error, isA<FormatException>());
    },
  );
}
