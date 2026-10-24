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

class FakePanelTwinRepository implements DigitalTwinRepository {
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

  int callCount = 0;
  String? lastEntityId;
  String? lastDuration;

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
    lastEntityId = entityId;
    lastDuration = aggrPeriodDuration;
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
          value: 25.5,
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
          value: BigInt.from(120),
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
  const sensorUrn = 'urn:ngsi-ld:Sensor:gw-alpha:sensor-temp';

  late FakePanelTwinRepository fakeRepo;

  setUp(() {
    fakeRepo = FakePanelTwinRepository();
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
            child: SizedBox(width: 1000, child: child),
          ),
        ),
      ),
    );
  }

  group('TemporalHistoryPanel Widget Tests', () {
    testWidgets(
      'mounts, queries initial 24h default and renders stats & chart',
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
                userId: 'user-1',
                name: 'Tester',
                email: 'test@example.com',
              ),
            );

        await tester.pumpWidget(
          wrapWidget(
            const TemporalHistoryPanel(
              sensorUrn: sensorUrn,
              unit: '°C',
              sensorName: 'Temperature Sensor',
            ),
            container,
          ),
        );
        await tester.pumpAndSettle();

        expect(fakeRepo.callCount, 1);
        expect(fakeRepo.lastEntityId, sensorUrn);
        expect(fakeRepo.lastDuration, 'PT5M');

        // Presets visible
        expect(find.text('10s (Thô)'), findsOneWidget);
        expect(find.text('24 giờ'), findsOneWidget);

        // Stats rendered
        expect(find.text('20.00 °C'), findsOneWidget); // min
        expect(find.text('25.50 °C'), findsWidgets); // avg
        expect(find.text('30.00 °C'), findsOneWidget); // max
        expect(
          find.text('120'),
          findsWidgets,
        ); // exact BigInt count in stats & table

        // Chart rendered
        expect(find.byType(KiteTemporalChart), findsOneWidget);
      },
    );

    testWidgets('tapping 10s preset switches to raw mode and fetches', (
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
              userId: 'user-1',
              name: 'Tester',
              email: 'test@example.com',
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

      // Tap 10s preset
      await tester.tap(find.text('10s (Thô)'));
      await tester.pumpAndSettle();

      expect(fakeRepo.callCount, 2);
      // Raw mode has duration == null
      expect(fakeRepo.lastDuration, isNull);
    });
  });
}
