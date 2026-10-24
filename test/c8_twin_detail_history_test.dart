import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/data/twin_detail.dart';
import 'package:kite/features/digital_twin/presentation/twin_detail_screen.dart';
import 'package:kite/l10n/app_localizations.dart';
import 'package:kite/shared/widgets/temporal_history_panel.dart';
import 'package:kite_ui/shadcn.dart';

class FakeTwinHistoryRepo implements DigitalTwinRepository {
  int temporalCallCount = 0;

  @override
  Future<TwinDetailPage> getTwinDetail(
    String entityId, {
    int relationshipLimit = 20,
    String? relationshipAfter,
  }) async {
    final parsed = EntityUrn.parse(entityId);
    return TwinDetailPage(
      TwinDetail(
        entity: parsed,
        name: TwinProperty(
          parsed.type == EntityType.sensor ? 'Temp Sensor' : 'Main Gateway',
        ),
        measurement: parsed.type == EntityType.sensor
            ? const TwinProperty(24.5, unitCode: 'CEL')
            : null,
      ),
      null,
    );
  }

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
    return TwinTemporalResponse(
      id: entityId,
      type: 'Sensor',
      attrName: attrs,
      isAggregated: true,
      avgBuckets: [
        TemporalBucketPoint(
          value: 26.0,
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
          value: BigInt.from(100),
          bucketStart: timeAt,
          bucketEnd: endTimeAt,
        ),
      ],
    );
  }

  @override
  Future<TwinStateResponse> getTwinState(String entityId) async {
    return TwinStateResponse(
      id: entityId,
      type: 'Sensor',
      gatewayId: 'gw-1',
      reportedState: const {},
      desiredState: const {},
      reportedVersion: '1',
      desiredVersion: '1',
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
  Future<ApiResponse> createTwin(PostTwinEntityInput input) =>
      throw UnimplementedError();

  @override
  Future<PatchTwinResponseDto> patchTwinAttrs(
    String entityId,
    PatchTwinAttrsInput input,
  ) => throw UnimplementedError();
}

void main() {
  const sensorUrn = 'urn:ngsi-ld:Sensor:gw-1:sensor-1';
  const gatewayUrn = 'urn:ngsi-ld:Gateway:gw-1';

  late FakeTwinHistoryRepo fakeRepo;

  setUp(() {
    fakeRepo = FakeTwinHistoryRepo();
  });

  Widget wrapWidget(Widget child, ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: ShadApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: const Locale('vi'),
        home: Scaffold(body: child),
      ),
    );
  }

  group('TwinDetailScreen Sensor History Tab Tests', () {
    testWidgets('Sensor Twin detail shows History tab and mounts lazily', (
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
        wrapWidget(const TwinDetailScreen(entityId: sensorUrn), container),
      );
      await tester.pumpAndSettle();

      // Check tabs
      expect(find.text('Thông tin'), findsOneWidget);
      expect(find.text('Trạng thái'), findsOneWidget);
      expect(find.text('Lịch sử'), findsOneWidget);

      // Initially on tab 0 (Information); TemporalHistoryPanel must NOT be mounted yet
      expect(find.byType(TemporalHistoryPanel), findsNothing);
      expect(fakeRepo.temporalCallCount, 0);

      // Tap History tab
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();

      // Now TemporalHistoryPanel is mounted and queried
      expect(find.byType(TemporalHistoryPanel), findsOneWidget);
      expect(fakeRepo.temporalCallCount, 1);
    });

    testWidgets(
      'Gateway Twin detail shows ONLY 2 tabs (never shows History tab)',
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
          wrapWidget(const TwinDetailScreen(entityId: gatewayUrn), container),
        );
        await tester.pumpAndSettle();

        // Check tabs for Gateway: ONLY Information and State
        expect(find.text('Thông tin'), findsOneWidget);
        expect(find.text('Trạng thái'), findsOneWidget);
        expect(find.text('Lịch sử'), findsNothing);
        expect(find.byType(TemporalHistoryPanel), findsNothing);
      },
    );
  });
}
