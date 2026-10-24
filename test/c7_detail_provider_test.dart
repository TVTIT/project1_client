import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/data/twin_detail.dart';
import 'package:kite/features/digital_twin/data/twin_json_display.dart';
import 'package:kite/features/digital_twin/providers/twin_detail_provider.dart';

import 'c7_detail_http_test.dart' show detailFixture, gatewayUrn;
import 'c7_detail_screen_test.dart' show DetailRepository;
import 'session_test.dart';

TwinDetailPage page({String sensor = 's1', String? next}) {
  final json = detailFixture();
  (json['hasSensor'] as Map)['object'] = ['urn:ngsi-ld:Sensor:gw:$sensor'];
  return TwinDetailPage(TwinDetail.fromJson(json), next);
}

void main() {
  late ProviderContainer container;
  late FakeAuthRepository auth;
  late DetailRepository repo;
  ProviderSubscription<TwinDetailState>? subscription;
  void signIn([String id = 'u1']) => container
      .read(sessionProvider.notifier)
      .setSession(
        SessionUser(userId: id, name: 'Member', email: '$id@example.com'),
      );
  Future<void> settle() {
    subscription ??= container.listen(
      twinDetailProvider(gatewayUrn),
      (_, _) {},
    );
    return Future<void>.delayed(Duration.zero);
  }

  TwinDetailState read() => container.read(twinDetailProvider(gatewayUrn));
  TwinDetailNotifier notifier() =>
      container.read(twinDetailProvider(gatewayUrn).notifier);
  setUp(() {
    auth = FakeAuthRepository();
    repo = DetailRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        digitalTwinRepositoryProvider.overrideWithValue(repo),
      ],
    );
    signIn();
    subscription = null;
  });
  tearDown(() {
    subscription?.close();
    container.dispose();
    auth.dispose();
  });
  test('retry of first-page transient failure replaces snapshot rather than duplicate append', () async {
    await settle();
    repo.detailHandler = (_, _) => Future.error(
      const ApiException(statusCode: 503, code: 'busy', message: 'busy'),
    );
    await notifier().retry();
    repo.detailHandler = (_, _) async => page(next: 'c1');
    await notifier().retry();
    expect(read().error, isNull);
    expect(read().sensors, hasLength(1));
    expect(read().nextCursor, 'c1');
  });
  test('load-more explicit, terminal stops, no N+1', () async {
    repo.detailHandler = (_, cursor) async =>
        cursor == null ? page(next: 'c1') : page(sensor: 's2');
    await settle();
    expect(repo.details, hasLength(1));
    expect(read().sensors, hasLength(1));
    await notifier().loadMore();
    await notifier().loadMore();
    expect(read().sensors, hasLength(2));
    expect(read().nextCursor, isNull);
    expect(repo.details, [(gatewayUrn, null), (gatewayUrn, 'c1')]);
    expect(repo.stateCalls, 0);
  });
  for (final loop in ['cursor', 'duplicate', 'empty']) {
    test('$loop stops non-advancing pagination', () async {
      repo.detailHandler = (_, cursor) async {
        if (cursor == null) return page(next: 'c1');
        if (loop == 'empty') {
          return TwinDetailPage(
            TwinDetail.fromJson({'id': gatewayUrn, 'type': 'Gateway'}),
            'c2',
          );
        }
        return page(
          sensor: loop == 'duplicate' ? 's1' : 's2',
          next: loop == 'cursor' ? 'c1' : 'c2',
        );
      };
      await settle();
      await notifier().loadMore();
      expect(read().error, isA<FormatException>());
      expect(read().nextCursor, isNull);
      final calls = repo.details.length;
      await notifier().loadMore();
      expect(repo.details.length, calls);
    });
  }
  test('bounded accumulation stops at 20 relationship pages', () async {
    var n = 0;
    repo.detailHandler = (_, _) async {
      n++;
      return page(sensor: 's$n', next: 'c$n');
    };
    await settle();
    for (var i = 0; i < 25; i++) {
      await notifier().loadMore();
    }
    expect(repo.details, hasLength(20));
    expect(read().sensors, hasLength(20));
    expect(read().atCapacity, isTrue);
    expect(read().nextCursor, isNull);
  });
  for (final status in [403, 404, 503]) {
    test(
      'detail $status denial purge versus transient stale and session retention',
      () async {
        await settle();
        expect(read().detail, isNotNull);
        repo.detailHandler = (_, _) => Future.error(
          ApiException(statusCode: status, code: 'test', message: 'test'),
        );
        await notifier().retry();
        expect(read().detail == null, status != 503);
        expect(read().sensors.isEmpty, status != 503);
        expect(read().error, isA<ApiException>());
        expect(container.read(sessionProvider).isAuthenticated, isTrue);
      },
    );
  }
  test('same identity refresh preserves data, session switch purges and loads anew', () async {
    await settle();
    signIn();
    expect(read().detail, isNotNull);
    expect(repo.details, hasLength(1));
    signIn('u2');
    expect(read().detail, isNull);
    await settle();
    expect(repo.details, hasLength(2));
    expect(read().detail, isNotNull);
  });
  for (final failure in [false, true]) {
    test(
      'identity switch fences late ${failure ? 'error' : 'success'}',
      () async {
        final pending = Completer<TwinDetailPage>();
        repo.detailHandler = (_, _) => pending.future;
        await settle();
        signIn('u2');
        read();
        repo.detailHandler = (_, _) async => page(sensor: 'new');
        await settle();
        if (failure) {
          pending.completeError(
            const ApiException(
              statusCode: 404,
              code: 'not_found',
              message: 'test',
            ),
          );
        } else {
          pending.complete(page(sensor: 'old'));
        }
        await settle();
        expect(read().sensors.single.sensorId, 'new');
        expect(read().error, isNull);
      },
    );
  }
  test('sign-out purges and never fetches or bypasses membership', () async {
    await settle();
    container.read(sessionProvider.notifier).setSession(null);
    expect(read().detail, isNull);
    await notifier().load();
    await settle();
    expect(repo.details, hasLength(1));
  });
  test('known units, unknown raw measurementUnit and optional properties', () {
    for (final entry in {'CEL': '°C', 'C81': 'rad', 'P1': '%'}.entries) {
      final json = detailFixture(sensor: true);
      json['measurement'] = {
        'type': 'Property',
        'value': 1,
        'unitCode': entry.key,
      };
      expect(TwinDetail.fromJson(json).displayUnit, entry.value);
    }
    final json = detailFixture(sensor: true);
    json['measurementUnit'] = {'type': 'Property', 'value': 'custom-unit'};
    expect(TwinDetail.fromJson(json).displayUnit, 'custom-unit');
    expect(TwinDetail.fromJson(json).measurement, isNull);
  });
  test('nested JSONB exact BigInt tokens preserve ordinary numbers and escape strings', () {
    expect(
      formatTwinJson({
        'list': [
          BigInt.parse('9223372036854775807'),
          12,
          '12',
          null,
          true,
          '<script>',
        ],
      }),
      '{\n  "list": [\n    9223372036854775807,\n    12,\n    "12",\n    null,\n    true,\n    "<script>"\n  ]\n}',
    );
  });
}
