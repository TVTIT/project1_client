import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/data/twin_detail.dart';
import 'package:kite/l10n/app_localizations.dart';
import 'package:kite/shared/widgets/temporal_history_controls.dart';
import 'package:kite/shared/widgets/temporal_history_panel.dart';
import 'package:kite/shared/widgets/temporal_history_table.dart';
import 'package:kite_ui/kite_ui.dart';
import 'package:kite_ui/shadcn.dart';

class FakeDateTimeRepo implements DigitalTwinRepository {
  TemporalQueryParameters? lastQueryParams;
  int callCount = 0;
  TwinTemporalResponse? responseToReturn;

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
    return responseToReturn ??
        TwinTemporalResponse(
          id: entityId,
          type: 'Sensor',
          attrName: attrs,
          isAggregated: aggrPeriodDuration != null,
          avgBuckets: const [],
          minBuckets: const [],
          maxBuckets: const [],
          totalCountBuckets: const [],
          rawPoints: const [],
        );
  }

  @override
  Future<ApiResponse> createTwin(PostTwinEntityInput input) =>
      throw UnimplementedError();
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
  Future<ApiResponse> listTwins({
    EntityType? type,
    String? gatewayId,
    int? limit,
    String? cursor,
    bool simplified = true,
  }) => throw UnimplementedError();
  @override
  Future<PatchTwinResponseDto> patchTwinAttrs(
    String entityId,
    PatchTwinAttrsInput input,
  ) => throw UnimplementedError();
}

Widget wrapWithShad(Widget child, [ProviderContainer? container]) {
  final content = ShadApp(
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    locale: const Locale('vi'),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 1000, child: child)),
    ),
  );
  if (container != null) {
    return UncontrolledProviderScope(container: container, child: content);
  }
  return content;
}

void main() {
  group('Adaptive DateTime Parsing and Formatting Unit Tests', () {
    test('formatLocalIsoDate formats DateTime to local representation', () {
      final now = DateTime.now();
      final localExpected =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      expect(formatLocalIsoDate(now), localExpected);

      expect(
        formatLocalIsoDate(now, includeMicroseconds: true),
        startsWith(localExpected),
      );
    });

    test('formatTimezoneOffset formats offset string correctly', () {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final hours = offset.inHours.abs().toString().padLeft(2, '0');
      final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final expectedTz = 'UTC$sign$hours:$minutes';

      expect(formatTimezoneOffset(now), expectedTz);
    });

    test('parseStrictLocalDate parses valid local dates and handles optional seconds', () {
      final parsedWithSec = parseStrictLocalDate('2026-10-24 15:30:45');
      expect(parsedWithSec, isNotNull);
      expect(parsedWithSec!.year, 2026);
      expect(parsedWithSec.month, 10);
      expect(parsedWithSec.day, 24);
      expect(parsedWithSec.hour, 15);
      expect(parsedWithSec.minute, 30);
      expect(parsedWithSec.second, 45);
      expect(parsedWithSec.isUtc, isFalse); // Must be local DateTime

      final parsedNoSec = parseStrictLocalDate('2026-10-24 09:15');
      expect(parsedNoSec, isNotNull);
      expect(parsedNoSec!.year, 2026);
      expect(parsedNoSec.month, 10);
      expect(parsedNoSec.day, 24);
      expect(parsedNoSec.hour, 9);
      expect(parsedNoSec.minute, 15);
      expect(parsedNoSec.second, 0);
      expect(parsedNoSec.isUtc, isFalse);
    });

    test('parseStrictLocalDate rejects invalid calendar dates and out-of-range times', () {
      expect(parseStrictLocalDate('2026-02-30 12:00:00'), isNull);
      expect(parseStrictLocalDate('2026-04-31 10:00:00'), isNull);
      expect(parseStrictLocalDate('2026-13-01 00:00:00'), isNull);
      expect(parseStrictLocalDate('2026-10-24 25:00:00'), isNull);
      expect(parseStrictLocalDate('2026-10-24 12:60:00'), isNull);
      expect(parseStrictLocalDate('invalid-date'), isNull);
    });

    test(
      'local DateTime converted via .toUtc() reflects user timezone offset',
      () {
        final local = parseStrictLocalDate('2026-10-24 12:00:00');
        expect(local, isNotNull);
        final utc = local!.toUtc();
        expect(utc.isUtc, isTrue);

        final clockLocalAsUtc = DateTime.utc(
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
          local.second,
        );
        expect(clockLocalAsUtc.difference(utc), local.timeZoneOffset);
      },
    );
  });

  group('TemporalHistoryControls Local Timezone & Picker Widget Tests', () {
    testWidgets(
      'shows timezone label and calendar picker buttons on both start and end fields',
      (tester) async {
        await tester.pumpWidget(
          wrapWithShad(
            TemporalHistoryControls(
              isLoading: false,
              initialStart: DateTime.utc(2026, 10, 23, 10, 0),
              initialEnd: DateTime.utc(2026, 10, 24, 10, 0),
              onApply: (_) {},
              onRefresh: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final now = DateTime.now();
        final offsetStr = formatTimezoneOffset(now);

        // Label must display timezone offset e.g. Bắt đầu (UTC+07:00)
        expect(find.textContaining(offsetStr), findsWidgets);

        // Both start and end fields have calendar picker icon buttons
        expect(
          find.byKey(const ValueKey('temporal-start-time-picker-btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('temporal-end-time-picker-btn')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.calendar_today_outlined), findsNWidgets(2));
      },
    );

    testWidgets(
      'typing local time in fields converts to UTC ISO8601 when calling onApply',
      (tester) async {
        TemporalQueryParameters? capturedQuery;

        await tester.pumpWidget(
          wrapWithShad(
            TemporalHistoryControls(
              isLoading: false,
              initialStart: DateTime.now().subtract(const Duration(hours: 1)),
              initialEnd: DateTime.now(),
              onApply: (q) {
                capturedQuery = q;
              },
              onRefresh: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter local times: 2026-10-24 10:00:00 and 2026-10-24 11:00:00
        final startField = find.byKey(
          const ValueKey('temporal-start-time-field'),
        );
        final endField = find.byKey(const ValueKey('temporal-end-time-field'));

        await tester.enterText(startField, '2026-10-24 10:00:00');
        await tester.enterText(endField, '2026-10-24 11:00:00');
        await tester.pump();

        // Click Apply
        await tester.tap(find.text('Áp dụng'));
        await tester.pumpAndSettle();

        expect(capturedQuery, isNotNull);
        // Verify query is strictly in UTC:
        expect(capturedQuery!.timeAt.isUtc, isTrue);
        expect(capturedQuery!.endTimeAt.isUtc, isTrue);

        // The UTC time must equal local time converted to UTC:
        final expectedStartLocal = DateTime(2026, 10, 24, 10, 0, 0);
        final expectedEndLocal = DateTime(2026, 10, 24, 11, 0, 0);
        expect(capturedQuery!.timeAt, expectedStartLocal.toUtc());
        expect(capturedQuery!.endTimeAt, expectedEndLocal.toUtc());
      },
    );
    testWidgets(
      'tapping start picker button opens date and time picker and updates field',
      (tester) async {
        await tester.pumpWidget(
          wrapWithShad(
            TemporalHistoryControls(
              isLoading: false,
              initialStart: DateTime(2026, 10, 24, 9, 30),
              initialEnd: DateTime(2026, 10, 24, 18, 30),
              onApply: (_) {},
              onRefresh: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pickerBtn = find.byKey(
          const ValueKey('temporal-start-time-picker-btn'),
        );
        await tester.tap(pickerBtn);
        await tester.pumpAndSettle();

        // DatePicker dialog is shown
        expect(find.byType(DatePickerDialog), findsOneWidget);

        // Tap OK button on DatePicker
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // TimePicker dialog is shown
        expect(find.byType(TimePickerDialog), findsOneWidget);

        // Tap OK button on TimePicker
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Field text is updated with the picked local date/time
        final startField = tester.widget<TextField>(
          find.byKey(const ValueKey('temporal-start-time-field')),
        );
        expect(startField.controller?.text, isNotNull);
        expect(startField.controller?.text.startsWith('2026-10-24'), isTrue);
      },
    );
  });

  group('TemporalHistoryPanel Local Time Integration Tests', () {
    testWidgets('applying local time queries API with UTC ISO8601 timestamps', (
      tester,
    ) async {
      final fakeRepo = FakeDateTimeRepo();
      final container = ProviderContainer(
        overrides: [digitalTwinRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'user-tz',
              name: 'TZ Tester',
              email: 'tz@example.com',
            ),
          );

      await tester.pumpWidget(
        wrapWithShad(
          const TemporalHistoryPanel(
            sensorUrn: 'urn:ngsi-ld:Sensor:gw1:sensor1',
            unit: '°C',
          ),
          container,
        ),
      );
      await tester.pumpAndSettle();

      // Initial call happened
      expect(fakeRepo.callCount, 1);

      // Enter specific local time:
      final startField = find.byKey(
        const ValueKey('temporal-start-time-field'),
      );
      final endField = find.byKey(const ValueKey('temporal-end-time-field'));

      await tester.enterText(startField, '2026-10-24 08:00:00');
      await tester.enterText(endField, '2026-10-24 12:00:00');
      await tester.pump();

      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      expect(fakeRepo.callCount, 2);
      final lastQuery = fakeRepo.lastQueryParams!;
      expect(lastQuery.timeAt.isUtc, isTrue);
      expect(lastQuery.endTimeAt.isUtc, isTrue);

      final expectedStart = DateTime(2026, 10, 24, 8, 0, 0).toUtc();
      final expectedEnd = DateTime(2026, 10, 24, 12, 0, 0).toUtc();
      expect(lastQuery.timeAt, expectedStart);
      expect(lastQuery.endTimeAt, expectedEnd);
    });

    testWidgets(
      'temporal history table displays local time and timezone offset in header',
      (tester) async {
        final fakeRepo = FakeDateTimeRepo();
        final now = DateTime.now().toUtc();
        final t0 = now.subtract(const Duration(hours: 2));
        final t1 = now.subtract(const Duration(hours: 1));
        fakeRepo.responseToReturn = TwinTemporalResponse(
          id: 'urn:ngsi-ld:Sensor:gw1:sensor1',
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
              value: BigInt.from(12),
              bucketStart: t0,
              bucketEnd: t1,
            ),
          ],
        );

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
                userId: 'user-tz-table',
                name: 'Table Tester',
                email: 'table@example.com',
              ),
            );

        await tester.pumpWidget(
          wrapWithShad(
            const TemporalHistoryPanel(
              sensorUrn: 'urn:ngsi-ld:Sensor:gw1:sensor1',
              unit: '°C',
            ),
            container,
          ),
        );
        await tester.pumpAndSettle();

        final offsetStr = formatTimezoneOffset(DateTime.now());

        // Table header must show offset e.g. "Thời gian (UTC+07:00)"
        expect(find.byType(TemporalHistoryTable), findsOneWidget);
        expect(find.text('Thời gian ($offsetStr)'), findsWidgets);
      },
    );

    testWidgets(
      'minimum line in aggregated series has high-visibility color instead of c.secondary',
      (tester) async {
        final fakeRepo = FakeDateTimeRepo();
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
                userId: 'user-color',
                name: 'Color Tester',
                email: 'color@example.com',
              ),
            );

        await tester.pumpWidget(
          wrapWithShad(
            const TemporalHistoryPanel(
              sensorUrn: 'urn:ngsi-ld:Sensor:gw1:sensor1',
              unit: '°C',
            ),
            container,
          ),
        );
        await tester.pumpAndSettle();

        final chart = tester.widget<KiteTemporalChart>(
          find.byType(KiteTemporalChart),
        );
        final minSeries = chart.series.firstWhere(
          (s) => s.name.contains('Tối thiểu'),
        );
        // Must not be c.secondary (which is faint grey), but a visible distinct color
        expect(minSeries.color, const Color(0xFF0284C7));
      },
    );
  });
}
