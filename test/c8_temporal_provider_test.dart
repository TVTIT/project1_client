import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/data/twin_detail.dart';
import 'package:kite/features/digital_twin/providers/temporal_history_provider.dart';

class FakeTemporalTwinRepository implements DigitalTwinRepository {
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

  int temporalCallCount = 0;

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
          value: 22.5,
          bucketStart: timeAt,
          bucketEnd: endTimeAt,
        ),
      ],
      minBuckets: [
        TemporalBucketPoint(
          value: 20.0,
          bucketStart: timeAt,
          bucketEnd: endTimeAt,
        ),
      ],
      maxBuckets: [
        TemporalBucketPoint(
          value: 25.0,
          bucketStart: timeAt,
          bucketEnd: endTimeAt,
        ),
      ],
      totalCountBuckets: [
        TemporalBucketPoint(
          value: BigInt.from(50),
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
  const sensorUrn = 'urn:ngsi-ld:Sensor:gw-alpha:sensor-1';

  late FakeTemporalTwinRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeTemporalTwinRepository();
    container = ProviderContainer(
      overrides: [digitalTwinRepositoryProvider.overrideWithValue(fakeRepo)],
    );

    // Authenticate user
    container
        .read(sessionProvider.notifier)
        .setSession(
          const SessionUser(
            userId: 'user-1',
            name: 'User One',
            email: 'user1@example.com',
          ),
        );
  });

  tearDown(() {
    container.dispose();
  });

  final defaultQuery = TemporalQueryParameters(
    timeAt: DateTime.parse('2026-10-23T00:00:00Z'),
    endTimeAt: DateTime.parse('2026-10-23T01:00:00Z'),
    aggrPeriodDuration: 'PT5M',
  );

  group('TemporalHistoryNotifier Unit Tests', () {
    test('fetches temporal data and stores successful response', () async {
      final sub = container.listen(
        temporalHistoryProvider(sensorUrn),
        (_, _) {},
      );
      addTearDown(sub.close);

      await container
          .read(temporalHistoryProvider(sensorUrn).notifier)
          .fetchTemporal(defaultQuery);

      final state = container.read(temporalHistoryProvider(sensorUrn));
      expect(state.isLoading, isFalse);
      expect(state.hasError, isFalse);
      expect(state.response, isNotNull);
      expect(state.response!.id, sensorUrn);
      expect(state.appliedQuery, defaultQuery);
      expect(state.isStale, isFalse);
      expect(fakeRepo.temporalCallCount, 1);
    });

    test('fencing: discards stale out-of-order response', () async {
      final sub = container.listen(
        temporalHistoryProvider(sensorUrn),
        (_, _) {},
      );
      addTearDown(sub.close);

      final completer1 = Completer<TwinTemporalResponse>();
      final completer2 = Completer<TwinTemporalResponse>();

      int callNum = 0;
      fakeRepo.temporalHandler =
          (
            entityId, {
            required attrs,
            required timeAt,
            required endTimeAt,
            aggrPeriodDuration,
            aggrMethods,
            maxPoints,
          }) {
            callNum++;
            if (callNum == 1) return completer1.future;
            return completer2.future;
          };

      final q1 = TemporalQueryParameters(
        mode: TemporalQueryMode.raw,
        timeAt: DateTime.parse('2026-10-23T00:00:00Z'),
        endTimeAt: DateTime.parse('2026-10-23T00:00:10Z'),
      );
      final q2 = TemporalQueryParameters(
        mode: TemporalQueryMode.raw,
        timeAt: DateTime.parse('2026-10-23T01:00:00Z'),
        endTimeAt: DateTime.parse('2026-10-23T01:00:10Z'),
      );

      // Start call 1
      final future1 = container
          .read(temporalHistoryProvider(sensorUrn).notifier)
          .fetchTemporal(q1);
      // Start call 2 before call 1 finishes
      final future2 = container
          .read(temporalHistoryProvider(sensorUrn).notifier)
          .fetchTemporal(q2);

      // Complete call 2 first
      completer2.complete(
        TwinTemporalResponse(
          id: sensorUrn,
          type: 'Sensor',
          attrName: 'measurement',
          rawPoints: [TemporalRawPoint(value: 99.0, observedAt: q2.timeAt)],
        ),
      );
      await future2;

      // Complete call 1 later (stale)
      completer1.complete(
        TwinTemporalResponse(
          id: sensorUrn,
          type: 'Sensor',
          attrName: 'measurement',
          rawPoints: [TemporalRawPoint(value: 11.0, observedAt: q1.timeAt)],
        ),
      );
      await future1;

      final state = container.read(temporalHistoryProvider(sensorUrn));
      // State must reflect call 2 (99.0), not call 1 (11.0)!
      expect(state.response!.rawPoints.first.value, 99.0);
      expect(state.appliedQuery, q2);
    });

    test('403 or 404 denial purges previous data', () async {
      final sub = container.listen(
        temporalHistoryProvider(sensorUrn),
        (_, _) {},
      );
      addTearDown(sub.close);

      // Initial successful fetch
      await container
          .read(temporalHistoryProvider(sensorUrn).notifier)
          .fetchTemporal(defaultQuery);
      expect(
        container.read(temporalHistoryProvider(sensorUrn)).response,
        isNotNull,
      );

      // Subsequent 404 forbidden/not found
      fakeRepo.temporalHandler =
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
              statusCode: 404,
              code: 'not_found',
              message: 'Resource not found',
            );
          };

      await container
          .read(temporalHistoryProvider(sensorUrn).notifier)
          .fetchTemporal(defaultQuery);

      final state = container.read(temporalHistoryProvider(sensorUrn));
      expect(state.hasError, isTrue);
      // Denied => data purged!
      expect(state.response, isNull);
      expect(state.isStale, isFalse);
    });

    test('503 transient failure retains previous data as stale', () async {
      final sub = container.listen(
        temporalHistoryProvider(sensorUrn),
        (_, _) {},
      );
      addTearDown(sub.close);

      // Initial successful fetch
      await container
          .read(temporalHistoryProvider(sensorUrn).notifier)
          .fetchTemporal(defaultQuery);
      expect(
        container.read(temporalHistoryProvider(sensorUrn)).response,
        isNotNull,
      );

      // Subsequent 503 Service Unavailable
      fakeRepo.temporalHandler =
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
              statusCode: 503,
              code: 'service_unavailable',
              message: 'Database temporarily unavailable',
            );
          };

      await container
          .read(temporalHistoryProvider(sensorUrn).notifier)
          .fetchTemporal(defaultQuery);

      final state = container.read(temporalHistoryProvider(sensorUrn));
      expect(state.hasError, isTrue);
      // Transient => previous data retained, marked stale!
      expect(state.response, isNotNull);
      expect(state.isStale, isTrue);
    });

    test('maps raw_limit_exceeded to localized guidance', () async {
      final sub = container.listen(
        temporalHistoryProvider(sensorUrn),
        (_, _) {},
      );
      addTearDown(sub.close);

      fakeRepo.temporalHandler =
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
              statusCode: 400,
              code: 'raw_limit_exceeded',
              message: 'Too many raw data points',
            );
          };

      await container
          .read(temporalHistoryProvider(sensorUrn).notifier)
          .fetchTemporal(defaultQuery);

      final state = container.read(temporalHistoryProvider(sensorUrn));
      expect(state.hasError, isTrue);
      expect(state.guidanceCode, TemporalGuidanceCode.rawLimitExceeded);
    });
  });
}
