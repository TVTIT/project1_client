import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/data/twin_detail.dart';
import 'package:kite/l10n/app_localizations.dart';
import 'package:kite/shared/widgets/temporal_history_panel.dart';
import 'package:kite_ui/kite_ui.dart';
import 'package:kite_ui/shadcn.dart';

class FakeRegressionTwinRepo implements DigitalTwinRepository {
  TemporalQueryParameters? lastQueryParams;
  int callCount = 0;

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
    callCount++;
    lastQueryParams = TemporalQueryParameters(
      attrs: attrs,
      timeAt: timeAt,
      endTimeAt: endTimeAt,
      mode: aggrPeriodDuration == null
          ? TemporalQueryMode.raw
          : TemporalQueryMode.aggregated,
      aggrPeriodDuration: aggrPeriodDuration,
      aggrMethods: aggrMethods,
      maxPoints: maxPoints ?? 1000,
    );

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
          value: 25.0,
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
          value: 30.0,
          bucketStart: timeAt,
          bucketEnd: endTimeAt,
        ),
      ],
      totalCountBuckets: [
        TemporalBucketPoint(
          value: BigInt.parse('9007199254740993'),
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
  const sensorUrn = 'urn:ngsi-ld:Sensor:gw-1:s1';
  late FakeRegressionTwinRepo fakeRepo;

  setUp(() {
    fakeRepo = FakeRegressionTwinRepo();
  });

  Widget wrapWidget(Widget child, ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: ShadApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: const Locale('vi'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 1200, child: child),
          ),
        ),
      ),
    );
  }

  group('C8 Regression 1: Draft vs Applied Query & Unit Isolation', () {
    testWidgets(
      'changing draft attribute dropdown does NOT relabel old applied measurement unit',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            digitalTwinRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'u1',
                name: 'User',
                email: 'user@example.com',
              ),
            );

        await tester.pumpWidget(
          wrapWidget(
            const TemporalHistoryPanel(sensorUrn: sensorUrn, unit: '°C'),
            container,
          ),
        );
        await tester.pumpAndSettle();

        // Initial applied query was measurement, so stats card and table should show °C
        expect(find.text('25.00 °C'), findsWidgets);

        // Now change the draft dropdown to sample_interval_us WITHOUT clicking Apply
        final attrDropdown = find.byType(DropdownButtonFormField<String>).last;
        await tester.tap(attrDropdown);
        await tester.pumpAndSettle();

        // Select sample_interval_us
        await tester.tap(find.text('Chu kỳ lấy mẫu (µs)').last);
        await tester.pumpAndSettle();

        // REGRESSION ASSERTION:
        // The displayed stats/chart must STILL show °C because the draft was NOT applied!
        // In defective code, effectiveUnit used draft _attrs and immediately relabeled old data as µs.
        expect(find.text('25.00 °C'), findsWidgets);
        expect(find.text('25.00 µs'), findsNothing);
      },
    );

    testWidgets('refresh button reruns applied query, NOT modified draft', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [digitalTwinRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u1',
              name: 'User',
              email: 'user@example.com',
            ),
          );

      await tester.pumpWidget(
        wrapWidget(
          const TemporalHistoryPanel(sensorUrn: sensorUrn, unit: '°C'),
          container,
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeRepo.callCount, 1);
      expect(fakeRepo.lastQueryParams?.attrs, 'measurement');

      // Change draft dropdown to sample_interval_us WITHOUT clicking Apply
      final attrDropdown = find.byType(DropdownButtonFormField<String>).last;
      await tester.tap(attrDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chu kỳ lấy mẫu (µs)').last);
      await tester.pumpAndSettle();

      // Click Refresh button (Làm mới)
      final refreshBtn = find.widgetWithText(KiteButton, 'Làm mới');
      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      // REGRESSION ASSERTION:
      // Refresh must rerun the APPLIED query ('measurement'), NOT the modified draft ('sample_interval_us')!
      expect(fakeRepo.callCount, 2);
      expect(fakeRepo.lastQueryParams?.attrs, 'measurement');
    });
  });

  group('C8 Regression 2: Stats Strict Complete Bucket Keys (start + end)', () {
    test('withholds stats when avg/min/max/count buckets have unmatched start or end keys', () {
      final t0 = DateTime.parse('2026-10-23T10:00:00Z');
      final t1 = DateTime.parse('2026-10-23T10:05:00Z');
      final t2 = DateTime.parse('2026-10-23T10:10:00Z');

      // avg has [t0, t1], but totalCount has same start t0 but different end t2!
      final response = TwinTemporalResponse(
        id: sensorUrn,
        type: 'Sensor',
        attrName: 'measurement',
        isAggregated: true,
        avgBuckets: [
          TemporalBucketPoint(value: 25.0, bucketStart: t0, bucketEnd: t1),
        ],
        minBuckets: [
          TemporalBucketPoint(value: 20.0, bucketStart: t0, bucketEnd: t1),
        ],
        maxBuckets: [
          TemporalBucketPoint(value: 30.0, bucketStart: t0, bucketEnd: t1),
        ],
        totalCountBuckets: [
          TemporalBucketPoint(
            value: BigInt.from(10),
            bucketStart: t0,
            bucketEnd: t2,
          ),
        ],
      );

      // REGRESSION ASSERTION:
      // Must return null because bucket end key differs!
      final stats = TemporalStats.calculate(response);
      expect(stats, isNull);
    });

    test('exact BigInt count without double loss in stats', () {
      final t0 = DateTime.parse('2026-10-23T10:00:00Z');
      final t1 = DateTime.parse('2026-10-23T10:05:00Z');

      final hugeCount = BigInt.parse('9007199254740993'); // 2^53 + 1
      final response = TwinTemporalResponse(
        id: sensorUrn,
        type: 'Sensor',
        attrName: 'measurement',
        isAggregated: true,
        avgBuckets: [
          TemporalBucketPoint(value: 25.0, bucketStart: t0, bucketEnd: t1),
        ],
        minBuckets: [
          TemporalBucketPoint(value: 20.0, bucketStart: t0, bucketEnd: t1),
        ],
        maxBuckets: [
          TemporalBucketPoint(value: 30.0, bucketStart: t0, bucketEnd: t1),
        ],
        totalCountBuckets: [
          TemporalBucketPoint(value: hugeCount, bucketStart: t0, bucketEnd: t1),
        ],
      );

      final stats = TemporalStats.calculate(response);
      expect(stats, isNotNull);
      expect(stats!.count.toString(), '9007199254740993');
    });
  });

  group('C8 Regression 3: Strict Types & Reject String Numeric in DTO', () {
    test('rejects string measurement in raw tuple (must be strictly num)', () {
      final json = {
        'id': sensorUrn,
        'type': 'Sensor',
        'measurement': {
          'type': 'Property',
          'values': [
            ['24.5', '2026-10-23T10:00:00.000000Z'], // String instead of num!
          ],
        },
      };

      // REGRESSION ASSERTION: Must throw FormatException, not accept string as numeric
      expect(
        () => TwinTemporalResponse.fromJson(json, attrName: 'measurement'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects mixed raw and aggregated payload as malformed', () {
      final json = {
        'id': sensorUrn,
        'type': 'Sensor',
        'measurement': {
          'type': 'Property',
          'values': [
            [24.5, '2026-10-23T10:00:00.000000Z'],
          ],
          'avg': [
            [
              24.5,
              '2026-10-23T10:00:00.000000Z',
              '2026-10-23T10:05:00.000000Z',
            ],
          ],
        },
      };

      // REGRESSION ASSERTION: Both 'values' and 'avg' present -> malformed mixed payload
      expect(
        () => TwinTemporalResponse.fromJson(json, attrName: 'measurement'),
        throwsA(isA<FormatException>()),
      );
    });

    test('raw mode rejects aggrMethods and aggrPeriodDuration', () {
      final q = TemporalQueryParameters(
        timeAt: DateTime.parse('2026-10-23T10:00:00Z'),
        endTimeAt: DateTime.parse('2026-10-23T10:00:05Z'),
        mode: TemporalQueryMode.raw,
        aggrPeriodDuration: 'PT1M',
      );

      // REGRESSION ASSERTION: raw mode must reject aggrPeriodDuration
      expect(() => q.validate(), throwsA(isA<FormatException>()));
    });
  });
}
