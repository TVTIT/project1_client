import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite_ui/kite_ui.dart';
import 'package:kite_ui/shadcn.dart';

Widget wrap(Widget child) => ShadApp(
  home: Scaffold(body: SizedBox(width: 600, child: child)),
);

void main() {
  testWidgets('tooltip preserves full UTC boundaries and exact integers', (
    tester,
  ) async {
    final start = DateTime.parse('2026-10-23T23:59:59.123456Z');
    final end = DateTime.parse('2026-10-24T00:00:00.654321Z');
    await tester.pumpWidget(
      wrap(
        KiteTemporalChart(
          series: [
            TemporalChartSeries(
              name: 'Exact',
              color: Colors.blue,
              segments: [
                [
                  TemporalChartPoint(
                    timestamp: start,
                    bucketEnd: end,
                    value: 1,
                    exactValue: '9007199254740993',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    final bar = data.lineBarsData.first;
    final items = data.lineTouchData.touchTooltipData.getTooltipItems([
      LineBarSpot(bar, 0, bar.spots.first),
    ]);
    expect(items.single!.text, 'Exact: 9007199254740993');
    expect(items.single!.text, isNot(contains(start.toIso8601String())));
    expect(items.single!.text, isNot(contains(end.toIso8601String())));
    expect(items.single!.text, isNot(contains('UTC')));
  });

  testWidgets(
    'tooltip in raw mode only shows the value without time or series name',
    (tester) async {
      final t = DateTime.parse('2026-10-23T10:00:00Z');
      await tester.pumpWidget(
        wrap(
          KiteTemporalChart(
            series: [
              TemporalChartSeries(
                name: 'Đo thô (Raw)',
                color: Colors.blue,
                segments: [
                  [TemporalChartPoint(timestamp: t, value: 25.5)],
                ],
              ),
            ],
            unit: '°C',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final bar = data.lineBarsData.first;
      final items = data.lineTouchData.touchTooltipData.getTooltipItems([
        LineBarSpot(bar, 0, bar.spots.first),
      ]);
      expect(items.single!.text, '25.5 °C');
      expect(items.single!.text, isNot(contains('Đo thô')));
      expect(items.single!.text, isNot(contains('UTC')));
    },
  );

  testWidgets(
    'chart bottom titles use local time and display date instead of hour for multi-day range',
    (tester) async {
      final start = DateTime.parse('2026-10-20T10:00:00Z');
      final end = DateTime.parse(
        '2026-10-25T10:00:00Z',
      ); // 5 days range (> 86400s)
      await tester.pumpWidget(
        wrap(
          KiteTemporalChart(
            series: [
              TemporalChartSeries(
                name: 'Multi-day',
                color: Colors.blue,
                segments: [
                  [
                    TemporalChartPoint(timestamp: start, value: 10),
                    TemporalChartPoint(timestamp: end, value: 20),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final bottomTitles = data.titlesData.bottomTitles.sideTitles;
      final startLocal = start.toLocal();
      final expectedDayMonth =
          '${startLocal.day.toString().padLeft(2, '0')}/${startLocal.month.toString().padLeft(2, '0')}';

      final startWidget = bottomTitles.getTitlesWidget(
        0.0,
        TitleMeta(
          min: 0,
          max: 432000,
          appliedInterval: 86400,
          sideTitles: const SideTitles(),
          formattedValue: '',
          axisPosition: 0,
          parentAxisSize: 800,
          axisSide: AxisSide.bottom,
          rotationQuarterTurns: 0,
        ),
      );

      expect(startWidget, isA<Padding>());
      final textWidget = (startWidget as Padding).child as Text;
      expect(textWidget.data, expectedDayMonth);
    },
  );
  testWidgets('nonfinite data never becomes a zero or invalid chart', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        KiteTemporalChart(
          series: [
            TemporalChartSeries(
              name: 'Invalid',
              color: Colors.blue,
              segments: [
                [
                  TemporalChartPoint(
                    timestamp: DateTime.utc(2026),
                    value: double.nan,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Invalid chart data.'), findsOneWidget);
  });
}
