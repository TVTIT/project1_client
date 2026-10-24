import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite_ui/kite_ui.dart';
import 'package:kite_ui/shadcn.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return ShadApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 800, height: 400, child: child)),
      ),
    );
  }

  group('KiteTemporalChart Widget Tests', () {
    testWidgets('renders empty message when no series points are available', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const KiteTemporalChart(
            series: [],
            emptyMessage: 'Không có dữ liệu đo đạc trong khoảng thời gian này.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Không có dữ liệu đo đạc trong khoảng thời gian này.'),
        findsOneWidget,
      );
    });

    testWidgets('renders temporal chart and series legends', (tester) async {
      final t0 = DateTime.parse('2026-10-23T10:00:00Z');
      final t1 = DateTime.parse('2026-10-23T10:05:00Z');

      final series = [
        TemporalChartSeries(
          name: 'Trung bình (Avg)',
          color: Colors.blue,
          segments: [
            [
              TemporalChartPoint(timestamp: t0, value: 20.0),
              TemporalChartPoint(timestamp: t1, value: 25.0),
            ],
          ],
        ),
        TemporalChartSeries(
          name: 'Tối thiểu (Min)',
          color: Colors.green,
          segments: [
            [
              TemporalChartPoint(timestamp: t0, value: 15.0),
              TemporalChartPoint(timestamp: t1, value: 18.0),
            ],
          ],
        ),
      ];

      await tester.pumpWidget(
        wrapWidget(KiteTemporalChart(series: series, unit: '°C')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KiteTemporalChart), findsOneWidget);
      expect(find.text('Trung bình (Avg)'), findsOneWidget);
      expect(find.text('Tối thiểu (Min)'), findsOneWidget);
    });

    testWidgets('renders count toggle button and switches between views', (
      tester,
    ) async {
      final t0 = DateTime.parse('2026-10-23T10:00:00Z');
      final t1 = DateTime.parse('2026-10-23T10:05:00Z');

      final series = [
        TemporalChartSeries(
          name: 'Avg',
          color: Colors.blue,
          segments: [
            [
              TemporalChartPoint(timestamp: t0, value: 20.0),
              TemporalChartPoint(timestamp: t1, value: 25.0),
            ],
          ],
        ),
      ];

      final countSeries = TemporalChartSeries(
        name: 'Total Count',
        color: Colors.purple,
        segments: [
          [
            TemporalChartPoint(
              timestamp: t0,
              value: 100.0,
              exactValue: '9007199254740993',
              bucketEnd: t1,
            ),
          ],
        ],
      );

      await tester.pumpWidget(
        wrapWidget(
          KiteTemporalChart(
            series: series,
            countSeries: countSeries,
            unit: '°C',
            measurementToggleLabel: 'Đo đạc',
            countToggleLabel: 'Số mẫu',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Avg'), findsOneWidget);
      expect(find.text('Đo đạc (°C)'), findsOneWidget);
      expect(find.text('Số mẫu'), findsOneWidget);

      // Tap count toggle button
      await tester.tap(find.text('Số mẫu'));
      await tester.pumpAndSettle();

      // Now active series is count series!
      expect(find.text('Total Count'), findsOneWidget);
    });

    testWidgets(
      'handles constant values, negative values, and single points safely',
      (tester) async {
        final t0 = DateTime.parse('2026-10-23T10:00:00Z');
        final t1 = DateTime.parse('2026-10-23T10:05:00Z');

        final constantSeries = [
          TemporalChartSeries(
            name: 'Constant',
            color: Colors.blue,
            segments: [
              [
                TemporalChartPoint(timestamp: t0, value: -10.0),
                TemporalChartPoint(timestamp: t1, value: -10.0),
              ],
            ],
          ),
        ];

        await tester.pumpWidget(
          wrapWidget(KiteTemporalChart(series: constantSeries, unit: '°C')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(KiteTemporalChart), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
