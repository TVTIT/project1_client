import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/session.dart';
import '../../features/digital_twin/data/digital_twin_dto.dart';
import '../../features/digital_twin/providers/digital_twin_providers.dart';
import '../../features/digital_twin/providers/temporal_history_provider.dart';
import '../../l10n/app_localizations.dart';
import 'states.dart';
import 'temporal_history_controls.dart';
import 'temporal_history_table.dart';

/// Reusable Temporal History Panel for querying and viewing Sensor telemetry.
///
/// Shared between Gateway Detail (under Telemetry History tab) and
/// Sensor Twin Detail (under History tab). Features:
/// - Distinct Draft vs Applied query separation; refresh reruns applied query.
/// - Segmented chart with microsecond precision X-arithmetic.
/// - Complete bucket-key sets (start+end) for stats without average-of-averages.
/// - Exact BigInt sample counts without truncation or .0 floating loss.
/// - Guidance for backend error bounds and Request ID display.
/// - Data inspection table with bounded exact rows.
class TemporalHistoryPanel extends ConsumerStatefulWidget {
  const TemporalHistoryPanel({
    super.key,
    required this.sensorUrn,
    this.unit,
    this.sensorName,
  });

  final String sensorUrn;
  final String? unit;
  final String? sensorName;

  @override
  ConsumerState<TemporalHistoryPanel> createState() =>
      _TemporalHistoryPanelState();
}

class _TemporalHistoryPanelState extends ConsumerState<TemporalHistoryPanel> {
  late DateTime _initialStart;
  late DateTime _initialEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _initialEnd = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    _initialStart = _initialEnd.subtract(const Duration(hours: 24));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _applyDefaultQuery();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TemporalHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensorUrn != widget.sensorUrn) {
      final now = DateTime.now().toUtc();
      _initialEnd = DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      );
      _initialStart = _initialEnd.subtract(const Duration(hours: 24));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _applyDefaultQuery();
        }
      });
    }
  }

  void _applyDefaultQuery() {
    final defaultQuery = TemporalQueryParameters(
      attrs: 'measurement',
      timeAt: _initialStart,
      endTimeAt: _initialEnd,
      mode: TemporalQueryMode.aggregated,
      aggrPeriodDuration: 'PT5M',
      maxPoints: 1000,
    );
    ref
        .read(temporalHistoryProvider(widget.sensorUrn).notifier)
        .fetchTemporal(defaultQuery);
  }

  List<List<TemporalChartPoint>> _buildAggregatedSegments(
    List<TemporalBucketPoint<double>> buckets,
  ) {
    if (buckets.isEmpty) return const [];
    final segments = <List<TemporalChartPoint>>[];
    var currentSegment = <TemporalChartPoint>[];

    for (int i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      if (i > 0) {
        final prev = buckets[i - 1];
        if (b.bucketStart.isAfter(prev.bucketEnd)) {
          if (currentSegment.isNotEmpty) {
            segments.add(currentSegment);
            currentSegment = <TemporalChartPoint>[];
          }
        }
      }
      currentSegment.add(
        TemporalChartPoint(
          timestamp: b.bucketStart,
          bucketEnd: b.bucketEnd,
          value: b.value,
        ),
      );
    }
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }
    return segments;
  }

  List<List<TemporalChartPoint>> _buildCountSegments(
    List<TemporalBucketPoint<BigInt>> buckets,
  ) {
    if (buckets.isEmpty) return const [];
    final segments = <List<TemporalChartPoint>>[];
    var currentSegment = <TemporalChartPoint>[];

    for (int i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      if (i > 0) {
        final prev = buckets[i - 1];
        if (b.bucketStart.isAfter(prev.bucketEnd)) {
          if (currentSegment.isNotEmpty) {
            segments.add(currentSegment);
            currentSegment = <TemporalChartPoint>[];
          }
        }
      }
      currentSegment.add(
        TemporalChartPoint(
          timestamp: b.bucketStart,
          bucketEnd: b.bucketEnd,
          value: b.value.toDouble(),
          exactValue: b.value.toString(),
        ),
      );
    }
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }
    return segments;
  }

  List<List<TemporalChartPoint>> _buildRawSegments(
    List<TemporalRawPoint> rawPoints,
  ) {
    if (rawPoints.isEmpty) return const [];
    final pts = rawPoints
        .map((p) => TemporalChartPoint(timestamp: p.observedAt, value: p.value))
        .toList();
    return [pts];
  }

  String? _getLocalizedGuidance(L l, TemporalGuidanceCode? code) {
    switch (code) {
      case TemporalGuidanceCode.rawLimitExceeded:
        return l.temporalGuidanceRawLimit;
      case TemporalGuidanceCode.rawResolutionRequired:
        return l.temporalRawRange;
      case TemporalGuidanceCode.resolutionTooFine:
        return l.temporalGuidanceResolution;
      case TemporalGuidanceCode.queryRangeExceeded:
        return l.temporalGuidanceRange;
      case TemporalGuidanceCode.invalidDateFormat:
        return l.temporalGuidanceInvalidDate;
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(twinSessionScopeProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(sessionProvider).isAuthenticated) {
          _applyDefaultQuery();
        }
      });
    });
    final state = ref.watch(temporalHistoryProvider(widget.sensorUrn));
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);

    // CRITICAL FIX: effectiveUnit is derived from the APPLIED query, not the draft dropdown!
    final effectiveUnit = state.appliedQuery?.attrs == 'sample_interval_us'
        ? 'µs'
        : (widget.unit != null && widget.unit!.isNotEmpty ? widget.unit! : '');

    final guidanceText = _getLocalizedGuidance(l, state.guidanceCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Query form controls
        TemporalHistoryControls(
          isLoading: state.isLoading,
          initialStart: _initialStart,
          initialEnd: _initialEnd,
          onApply: (query) {
            ref
                .read(temporalHistoryProvider(widget.sensorUrn).notifier)
                .fetchTemporal(query);
          },
          onRefresh: () {
            final notifier = ref.read(
              temporalHistoryProvider(widget.sensorUrn).notifier,
            );
            if (state.appliedQuery != null) {
              notifier.refreshApplied();
            } else {
              _applyDefaultQuery();
            }
          },
        ),
        const SizedBox(height: KiteSpace.md),

        // Applied Query Status Banner (separate from draft controls)
        if (state.appliedQuery != null)
          _buildAppliedQueryBanner(state.appliedQuery!, effectiveUnit, c, t, l),

        // Server Guidance Banner (e.g. raw_limit_exceeded)
        if (guidanceText != null) ...[
          const SizedBox(height: KiteSpace.md),
          Container(
            padding: const EdgeInsets.all(KiteSpace.md),
            decoration: BoxDecoration(
              color: c.muted.withValues(alpha: 0.3),
              borderRadius: KiteRadius.allMd,
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: c.mutedForeground),
                const SizedBox(width: KiteSpace.sm),
                Expanded(
                  child: Text(
                    guidanceText,
                    style: t.small.copyWith(color: c.foreground),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Error Banner when response is retained or stale
        if (state.hasError && state.response != null) ...[
          const SizedBox(height: KiteSpace.md),
          _buildErrorNotice(state, c, t, l),
        ],

        // Stale Data Warning Banner
        if (state.isStale && !state.hasError) ...[
          const SizedBox(height: KiteSpace.md),
          Container(
            padding: const EdgeInsets.all(KiteSpace.md),
            decoration: BoxDecoration(
              color: c.muted.withValues(alpha: 0.2),
              borderRadius: KiteRadius.allMd,
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: c.mutedForeground),
                const SizedBox(width: KiteSpace.sm),
                Expanded(
                  child: Text(
                    l.temporalStaleWarning,
                    style: t.small.copyWith(color: c.mutedForeground),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: KiteSpace.lg),

        // Main Content Area
        _buildContent(context, state, effectiveUnit, c, t, l),
      ],
    );
  }

  Widget _buildAppliedQueryBanner(
    TemporalQueryParameters q,
    String unit,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    final modeLabel = q.isRaw
        ? l.temporalModeRaw
        : '${l.temporalModeAggregated} (${q.aggrPeriodDuration ?? ''})';
    final attrLabel = q.attrs == 'sample_interval_us'
        ? l.temporalAttrSampleInterval
        : '${l.temporalAttrMeasurement}${unit.isNotEmpty ? ' [$unit]' : ''}';
    final tzOffset = formatTimezoneOffset(DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KiteSpace.md,
        vertical: KiteSpace.sm,
      ),
      decoration: BoxDecoration(
        color: c.muted.withValues(alpha: 0.15),
        borderRadius: KiteRadius.allSm,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.query_builder, size: 16, color: c.mutedForeground),
          const SizedBox(width: KiteSpace.sm),
          Expanded(
            child: Text(
              '${l.temporalShowing}: [${formatLocalIsoDate(q.timeAt)} → ${formatLocalIsoDate(q.endTimeAt)} ($tzOffset)] | $modeLabel | $attrLabel (${q.maxPoints})',
              style: t.small.copyWith(fontSize: 11, color: c.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorNotice(
    TemporalHistoryState state,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    final errorMsg = l.temporalFailed;

    final reqId = state.requestId;

    return Container(
      padding: const EdgeInsets.all(KiteSpace.md),
      decoration: BoxDecoration(
        color: c.destructive.withValues(alpha: 0.08),
        borderRadius: KiteRadius.allMd,
        border: Border.all(color: c.destructive.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: c.destructive),
          const SizedBox(width: KiteSpace.sm),
          Expanded(
            child: Text(
              reqId != null ? '$errorMsg (Request ID: $reqId)' : errorMsg,
              style: t.small.copyWith(color: c.destructive),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    TemporalHistoryState state,
    String unit,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    if (state.isLoading && state.response == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: KiteSpace.xxl * 2),
        child: LoadingState(),
      );
    }

    if (state.hasError && state.response == null) {
      final msg =
          '${l.temporalFailed}${state.requestId == null ? '' : ' (Request ID: ${state.requestId})'}';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KiteSpace.xl),
        child: ErrorState(message: msg, onRetry: _applyDefaultQuery),
      );
    }

    final resp = state.response;
    if (resp == null) {
      return const SizedBox.shrink();
    }

    final stats = TemporalStats.calculate(resp);

    // Prepare chart series using semantic theme tokens
    final List<TemporalChartSeries> series;
    TemporalChartSeries? countSeries;

    if (resp.isRaw) {
      series = [
        TemporalChartSeries(
          name: l.temporalModeRaw,
          color: c.primary,
          segments: _buildRawSegments(resp.rawPoints),
        ),
      ];
    } else {
      series = [
        TemporalChartSeries(
          name: l.temporalStatsRawAvg,
          color: c.primary,
          segments: _buildAggregatedSegments(resp.avgBuckets),
        ),
        TemporalChartSeries(
          name: l.temporalStatsMin,
          color: const Color(0xFF0284C7),
          segments: _buildAggregatedSegments(resp.minBuckets),
          strokeWidth: 1.8,
          isDashed: true,
        ),
        TemporalChartSeries(
          name: l.temporalStatsMax,
          color: c.destructive,
          segments: _buildAggregatedSegments(resp.maxBuckets),
          strokeWidth: 1.5,
          isDashed: true,
        ),
      ];

      if (resp.totalCountBuckets.isNotEmpty) {
        countSeries = TemporalChartSeries(
          name: l.temporalStatsCount,
          color: const Color(0xFF8B5CF6),
          segments: _buildCountSegments(resp.totalCountBuckets),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary statistics card
        if (stats != null) ...[
          _buildStatsCard(stats, unit, c, t, l),
          const SizedBox(height: KiteSpace.lg),
        ],

        // Line Chart
        Container(
          padding: const EdgeInsets.all(KiteSpace.lg),
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.border),
            borderRadius: KiteRadius.allLg,
          ),
          child: KiteTemporalChart(
            series: series,
            countSeries: countSeries,
            unit: unit,
            height: 280,
            emptyMessage: l.temporalNoData,
            measurementToggleLabel: l.temporalAttrMeasurement,
            countToggleLabel: l.temporalSamples,
            invalidMessage: l.temporalFailed,
          ),
        ),

        const SizedBox(height: KiteSpace.lg),

        // Data inspection table
        TemporalHistoryTable(response: resp, unit: unit),
      ],
    );
  }

  Widget _buildStatsCard(
    TemporalStats stats,
    String unit,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    final unitSuffix = unit.isNotEmpty ? ' $unit' : '';

    return Container(
      padding: const EdgeInsets.all(KiteSpace.md),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: KiteRadius.allMd,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: KiteSpace.xl,
        runSpacing: KiteSpace.sm,
        children: [
          _buildStatItem(
            label: l.temporalStatsMin,
            value: '${stats.min.toStringAsFixed(2)}$unitSuffix',
            c: c,
            t: t,
          ),
          _buildStatItem(
            label: stats.isRaw ? l.temporalStatsRawAvg : l.temporalStatsAvg,
            value: '${stats.avg.toStringAsFixed(2)}$unitSuffix',
            c: c,
            t: t,
          ),
          _buildStatItem(
            label: l.temporalStatsMax,
            value: '${stats.max.toStringAsFixed(2)}$unitSuffix',
            c: c,
            t: t,
          ),
          _buildStatItem(
            label: l.temporalStatsCount,
            value: stats.count.toString(), // Exact BigInt string
            c: c,
            t: t,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required KiteColors c,
    required KiteText t,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.muted.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: t.p.copyWith(
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
