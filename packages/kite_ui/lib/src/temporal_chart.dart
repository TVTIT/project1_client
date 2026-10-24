import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// A single data point in a temporal chart series.
@immutable
class TemporalChartPoint {
  const TemporalChartPoint({
    required this.timestamp,
    required this.value,
    this.exactValue,
    this.bucketEnd,
    this.label,
  });

  final DateTime timestamp;
  final double value;
  final String? exactValue;
  final DateTime? bucketEnd;
  final String? label;
}

/// A series composed of one or more continuous segments.
/// Missing bucket gaps are represented by dividing points into separate segments.
@immutable
class TemporalChartSeries {
  const TemporalChartSeries({
    required this.name,
    required this.color,
    required this.segments,
    this.strokeWidth = 2.0,
    this.isDashed = false,
  });

  final String name;
  final Color color;
  final List<List<TemporalChartPoint>> segments;
  final double strokeWidth;
  final bool isDashed;

  bool get isEmpty => segments.every((s) => s.isEmpty);
  bool get isNotEmpty => !isEmpty;

  Iterable<TemporalChartPoint> get allPoints sync* {
    for (final seg in segments) {
      for (final pt in seg) {
        yield pt;
      }
    }
  }
}

/// Kite Temporal Chart displaying observation time-series with straight line
/// segments, gap handling for missing buckets, microsecond precision arithmetic,
/// responsive tooltip, and separate count view.
class KiteTemporalChart extends StatefulWidget {
  const KiteTemporalChart({
    super.key,
    required this.series,
    this.countSeries,
    this.unit,
    this.height = 260.0,
    this.emptyMessage,
    this.measurementToggleLabel,
    this.countToggleLabel,
    this.invalidMessage,
  });

  final List<TemporalChartSeries> series;
  final TemporalChartSeries? countSeries;
  final String? unit;
  final double height;
  final String? emptyMessage;
  final String? measurementToggleLabel;
  final String? countToggleLabel;
  final String? invalidMessage;

  @override
  State<KiteTemporalChart> createState() => _KiteTemporalChartState();
}

class _KiteTemporalChartState extends State<KiteTemporalChart> {
  bool _viewCount = false;

  String _formatDateTime(DateTime dt, double rangeSeconds) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');

    if (rangeSeconds <= 60) {
      final us = local.millisecond * 1000 + local.microsecond;
      if (us > 0) {
        final usStr = us
            .toString()
            .padLeft(6, '0')
            .replaceAll(RegExp(r'0+$'), '');
        return '$hh:$mm:$ss.$usStr';
      }
      return '$hh:$mm:$ss';
    } else if (rangeSeconds <= 86400) {
      return '$hh:$mm';
    } else {
      return '$d/$m';
    }
  }

  String _formatTooltipPoint(
    TemporalChartPoint pt,
    String seriesName,
    String unit,
  ) {
    final valStr = pt.exactValue ?? pt.value.toStringAsFixed(1);
    final unitSuffix = unit.isNotEmpty ? ' $unit' : '';

    if (pt.bucketEnd != null) {
      // Aggregated mode: only series name and value, no time
      return '$seriesName: $valStr$unitSuffix';
    } else {
      // Raw mode: only value at this point, no verbose series name or time
      return '$valStr$unitSuffix';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);

    final activeSeries = _viewCount && widget.countSeries != null
        ? [widget.countSeries!]
        : widget.series;

    final allActivePoints = activeSeries.expand((s) => s.allPoints).toList();
    Widget invalidData() => SizedBox(
      height: widget.height,
      child: Center(
        child: Text(
          widget.invalidMessage ?? 'Invalid chart data.',
          style: t.muted,
        ),
      ),
    );
    if (allActivePoints.any((p) => !p.value.isFinite)) return invalidData();

    if (allActivePoints.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(KiteSpace.xl),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border),
          borderRadius: KiteRadius.allMd,
        ),
        child: Text(
          widget.emptyMessage ??
              'Không có dữ liệu đo đạc trong khoảng thời gian này.',
          style: t.muted,
          textAlign: TextAlign.center,
        ),
      );
    }

    // Compute baseTime and bounds
    DateTime minDt = allActivePoints.first.timestamp;
    DateTime maxDt = allActivePoints.first.timestamp;
    double minY = allActivePoints.first.value;
    double maxY = allActivePoints.first.value;

    for (final pt in allActivePoints) {
      if (pt.timestamp.isBefore(minDt)) minDt = pt.timestamp;
      if (pt.timestamp.isAfter(maxDt)) maxDt = pt.timestamp;
      if (pt.value < minY) minY = pt.value;
      if (pt.value > maxY) maxY = pt.value;
    }

    final baseTime = minDt;
    // Microsecond relative arithmetic: avoid microsecond loss by dividing inMicroseconds by 1e6
    final totalRangeSeconds = max(
      0.000001,
      maxDt.difference(minDt).inMicroseconds.toDouble() / 1000000.0,
    );

    // Guard against identical minY and maxY (e.g. constant values)
    if (minY == maxY) {
      minY -= 1.0;
      maxY += 1.0;
    } else {
      final pad = (maxY - minY) * 0.10;
      minY -= pad;
      maxY += pad;
    }
    if (!minY.isFinite || !maxY.isFinite || minY >= maxY) return invalidData();

    // Map spot to point for accurate individual tooltip lookup
    final spotPointMap = <(int, int), (TemporalChartPoint, String)>{};
    final lineBars = <LineChartBarData>[];

    int barIndex = 0;
    for (final s in activeSeries) {
      for (final seg in s.segments) {
        if (seg.isEmpty) continue;
        final spots = <FlSpot>[];
        for (int spotIdx = 0; spotIdx < seg.length; spotIdx++) {
          final pt = seg[spotIdx];
          final x =
              (pt.timestamp.difference(baseTime).inMicroseconds).toDouble() /
              1000000.0;
          spots.add(FlSpot(x, pt.value));
          spotPointMap[(barIndex, spotIdx)] = (pt, s.name);
        }
        lineBars.add(
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: s.strokeWidth,
            color: s.color,
            dashArray: s.isDashed ? [5, 5] : null,
            dotData: FlDotData(show: spots.length == 1),
            belowBarData: BarAreaData(show: false),
          ),
        );
        barIndex++;
      }
    }

    final activeUnit = _viewCount ? '' : (widget.unit ?? '');
    final measurementLabel = widget.measurementToggleLabel ?? 'Đo đạc';
    final countLabel = widget.countToggleLabel ?? 'Số mẫu';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row: Legend and Keyboard Accessible Count Toggle
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: KiteSpace.md,
          runSpacing: KiteSpace.sm,
          children: [
            // Series legend
            Wrap(
              spacing: KiteSpace.md,
              runSpacing: KiteSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final s in activeSeries)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 3,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      const SizedBox(width: KiteSpace.xs),
                      Text(s.name, style: t.small),
                    ],
                  ),
              ],
            ),
            // Accessible Toggle between measurement and totalCount using focusable buttons
            if (widget.countSeries != null && widget.countSeries!.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: c.muted.withValues(alpha: 0.3),
                  borderRadius: KiteRadius.allSm,
                  border: Border.all(color: c.border),
                ),
                padding: const EdgeInsets.all(2),
                child: Wrap(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: !_viewCount ? c.card : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: KiteRadius.allSm,
                        ),
                      ),
                      onPressed: () => setState(() => _viewCount = false),
                      child: Text(
                        activeUnit.isNotEmpty
                            ? '$measurementLabel ($activeUnit)'
                            : measurementLabel,
                        style: t.small.copyWith(
                          fontWeight: !_viewCount
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: !_viewCount ? c.foreground : c.mutedForeground,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: _viewCount ? c.card : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: KiteRadius.allSm,
                        ),
                      ),
                      onPressed: () => setState(() => _viewCount = true),
                      child: Text(
                        countLabel,
                        style: t.small.copyWith(
                          fontWeight: _viewCount
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _viewCount ? c.foreground : c.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: KiteSpace.md),

        // Line Chart
        SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              minX: 0.0,
              maxX: totalRangeSeconds,
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: c.border, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (val, meta) {
                      if (val == meta.min || val == meta.max) {
                        return const SizedBox.shrink();
                      }
                      final label = val.toStringAsFixed(
                        val.truncateToDouble() == val ? 0 : 1,
                      );
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.mutedForeground,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: max(totalRangeSeconds / 5.0, 1.0),
                    getTitlesWidget: (val, meta) {
                      if (val < 0 || val > totalRangeSeconds) {
                        return const SizedBox.shrink();
                      }
                      final dt = baseTime.add(
                        Duration(microseconds: (val * 1000000).round()),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _formatDateTime(dt, totalRangeSeconds),
                          style: TextStyle(
                            fontSize: 10,
                            color: c.mutedForeground,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => c.foreground,
                  tooltipBorderRadius: BorderRadius.circular(6),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  getTooltipItems: (touchedSpots) {
                    if (touchedSpots.isEmpty) return [];
                    return [
                      for (final spot in touchedSpots) ...[
                        () {
                          final pointInfo =
                              spotPointMap[(spot.barIndex, spot.spotIndex)];
                          if (pointInfo != null) {
                            return LineTooltipItem(
                              _formatTooltipPoint(
                                pointInfo.$1,
                                pointInfo.$2,
                                activeUnit,
                              ),
                              TextStyle(
                                color: c.background,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)}${activeUnit.isNotEmpty ? ' $activeUnit' : ''}',
                            TextStyle(
                              color: c.background,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }(),
                      ],
                    ];
                  },
                ),
              ),
              lineBarsData: lineBars,
            ),
          ),
        ),
      ],
    );
  }
}
