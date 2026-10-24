import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/data/twin_detail.dart';
import 'package:kite/features/digital_twin/providers/twin_list_provider.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';

import 'gateway_list_provider_test.dart';
import 'session_test.dart';
import 'twin_list_page_test.dart' show twinRow;

class ListTwinRepository implements DigitalTwinRepository {
  final calls = <Map<String, dynamic>>[];
  Future<ApiResponse> Function(Map<String, dynamic>)? handler;
  @override
  Future<ApiResponse> listTwins({
    EntityType? type,
    String? gatewayId,
    int? limit,
    String? cursor,
    bool simplified = true,
  }) {
    final call = {
      'type': type,
      'gateway_id': gatewayId,
      'limit': limit,
      'cursor': cursor,
      'simplified': simplified,
    };
    calls.add(call);
    return handler?.call(call) ?? Future.value(twinResponse([]));
  }

  @override
  Future<TwinDetailPage> getTwinDetail(
    String entityId, {
    int relationshipLimit = 20,
    String? relationshipAfter,
  }) => throw StateError('Unexpected detail request');
  @override
  Future<TwinStateResponse> getTwinState(String entityId) =>
      throw StateError('Unexpected row detail or state request');
  @override
  Future<TwinTemporalResponse> getSensorTemporal(
    String entityId, {
    required String attrs,
    required DateTime timeAt,
    required DateTime endTimeAt,
    String? aggrPeriodDuration,
    String? aggrMethods,
    int? maxPoints,
  }) => throw StateError('Unexpected temporal request');
  @override
  Future<ApiResponse> createTwin(PostTwinEntityInput input) =>
      throw StateError('Unexpected create');
  @override
  Future<PatchTwinResponseDto> patchTwinAttrs(
    String entityId,
    PatchTwinAttrsInput input,
  ) => throw StateError('Unexpected patch');
}

ApiResponse twinResponse(List<Map<String, dynamic>> rows, {String? next}) =>
    ApiResponse(
      statusCode: 200,
      rawBody: rows,
      headers: {
        if (next != null)
          'link': '<?format=simplified&limit=50&cursor=$next>; rel="next"',
      },
    );

void main() {
  late FakeAuthRepository auth;
  late ListTwinRepository repo;
  late FakeGatewayRepository gateways;
  late ProviderContainer container;
  setUp(() {
    auth = FakeAuthRepository();
    repo = ListTwinRepository();
    gateways = FakeGatewayRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        digitalTwinRepositoryProvider.overrideWithValue(repo),
        gatewayRepositoryProvider.overrideWithValue(gateways),
        twinListEndpointProvider.overrideWithValue(
          Uri.parse('https://api.example/v1/digital-twins'),
        ),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    auth.dispose();
  });
  void signIn([String id = 'u1']) => container
      .read(sessionProvider.notifier)
      .setSession(
        SessionUser(userId: id, name: 'Member', email: '$id@example.com'),
      );

  test('anonymous does not fetch list or member catalog', () async {
    await container.read(twinListProvider.notifier).load();
    await container.read(twinMemberGatewaysProvider.future);
    expect(repo.calls, isEmpty);
    expect(gateways.callCount, 0);
  });
  test(
    'authorized empty is valid and catalog never uses admin inventory',
    () async {
      signIn();
      await container.read(twinListProvider.notifier).load();
      await container.read(twinMemberGatewaysProvider.future);
      expect(container.read(twinListProvider).items, isEmpty);
      expect(container.read(twinListProvider).error, isNull);
      expect(gateways.callCount, 1);
      expect(gateways.adminGatewaysCallCount, 0);
      expect(repo.calls.single['simplified'], isTrue);
    },
  );
  test(
    'explicit next appends typed rows with no N+1 and terminal stops',
    () async {
      signIn();
      repo.handler = (call) async => call['cursor'] == null
          ? twinResponse([twinRow('one')], next: 'c1')
          : twinResponse([twinRow('two')]);
      final notifier = container.read(twinListProvider.notifier);
      await notifier.load();
      expect(repo.calls, hasLength(1));
      await notifier.loadMore();
      await notifier.loadMore();
      expect(repo.calls, hasLength(2));
      expect(container.read(twinListProvider).items.map((e) => e.name), [
        'Temperature one',
        'Temperature two',
      ]);
      expect(container.read(twinListProvider).nextCursor, isNull);
    },
  );
  test(
    'filter reset removes old rows cursor and ignores stale response',
    () async {
      signIn();
      final pending = Completer<ApiResponse>();
      repo.handler = (call) => call['type'] == null
          ? pending.future
          : Future.value(twinResponse([twinRow('new')]));
      final notifier = container.read(twinListProvider.notifier);
      final old = notifier.load();
      await notifier.load(type: EntityType.sensor, gatewayId: 'gw');
      expect(repo.calls.last['cursor'], isNull);
      pending.complete(twinResponse([twinRow('old')], next: 'old'));
      await old;
      expect(
        container.read(twinListProvider).items.single.name,
        'Temperature new',
      );
      expect(container.read(twinListProvider).type, EntityType.sensor);
    },
  );
  test('late prior session response is discarded and rows purged', () async {
    signIn();
    final pending = Completer<ApiResponse>();
    repo.handler = (_) => pending.future;
    final old = container.read(twinListProvider.notifier).load();
    signIn('u2');
    expect(container.read(twinListProvider).items, isEmpty);
    pending.complete(twinResponse([twinRow('old')]));
    await old;
    expect(container.read(twinListProvider).items, isEmpty);
    expect(container.read(twinListProvider).isLoading, isFalse);
  });
  test('cursor loop stops visibly while retaining fetched new rows', () async {
    signIn();
    repo.handler = (call) async => twinResponse([
      twinRow(call['cursor'] == null ? 'one' : 'two'),
    ], next: 'loop');
    final notifier = container.read(twinListProvider.notifier);
    await notifier.load();
    await notifier.loadMore();
    await notifier.loadMore();
    expect(repo.calls, hasLength(2));
    expect(container.read(twinListProvider).items, hasLength(2));
    expect(container.read(twinListProvider).error, isA<FormatException>());
    expect(container.read(twinListProvider).nextCursor, isNull);
  });
  test('new cursor with repeated rows is rejected as no advancement', () async {
    signIn();
    repo.handler = (call) async => twinResponse([
      twinRow('same'),
    ], next: call['cursor'] == null ? 'c1' : 'c2');
    final notifier = container.read(twinListProvider.notifier);
    await notifier.load();
    await notifier.loadMore();
    expect(container.read(twinListProvider).items, hasLength(1));
    expect(container.read(twinListProvider).error, isNotNull);
    expect(container.read(twinListProvider).nextCursor, isNull);
  });
  test(
    'memory capacity stops before another request without dropping rows',
    () async {
      signIn();
      repo.handler = (call) async {
        final page = call['cursor'] == null
            ? 0
            : int.parse(call['cursor'] as String);
        return twinResponse(
          List.generate(50, (i) => twinRow('p${page}s$i')),
          next: '${page + 1}',
        );
      };
      final notifier = container.read(twinListProvider.notifier);
      await notifier.load();
      for (var i = 0; i < 25; i++) {
        await notifier.loadMore();
      }
      expect(repo.calls, hasLength(20));
      expect(container.read(twinListProvider).items, hasLength(1000));
      expect(container.read(twinListProvider).atCapacity, isTrue);
    },
  );
  test('read denial purges prior rows but retains session', () async {
    signIn();
    repo.handler = (_) async => twinResponse([twinRow('one')], next: 'c1');
    final notifier = container.read(twinListProvider.notifier);
    await notifier.load();
    repo.handler = (_) async => throw const ApiException(
      statusCode: 404,
      code: 'not_found',
      message: 'resource not found',
    );
    await notifier.loadMore();
    expect(container.read(twinListProvider).items, isEmpty);
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
  });
}
