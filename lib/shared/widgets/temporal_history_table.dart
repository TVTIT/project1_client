import 'package:flutter/material.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../features/digital_twin/data/digital_twin_dto.dart';
import '../../l10n/app_localizations.dart';
import 'temporal_history_controls.dart';

class TemporalHistoryTable extends StatelessWidget {
  const TemporalHistoryTable({
    super.key,
    required this.response,
    required this.unit,
  });

  final TwinTemporalResponse response;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);
    final tzOffset = formatTimezoneOffset(DateTime.now());
    final timestampHeader = '${l.temporalTimestamp} ($tzOffset)';

    final unitSuffix = unit.isNotEmpty ? ' $unit' : '';

    if (response.isRaw) {
      if (response.rawPoints.isEmpty) return const SizedBox.shrink();

      return Container(
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border),
          borderRadius: KiteRadius.allMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(KiteSpace.md),
              child: Text(
                '${l.temporalInspectTable} (${response.rawPoints.length})',
                style: t.p.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: KiteSpace.lg,
                    columns: [
                      DataColumn(label: Text(timestampHeader, style: t.small)),
                      DataColumn(label: Text(l.temporalValue, style: t.small)),
                    ],
                    rows: [
                      for (final pt in response.rawPoints)
                        DataRow(
                          cells: [
                            DataCell(
                              SelectableText(
                                formatLocalIsoDate(
                                  pt.observedAt,
                                  includeMicroseconds: true,
                                ),
                                style: t.small.copyWith(
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${pt.value.toStringAsFixed(2)}$unitSuffix',
                                style: t.small.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      if (response.avgBuckets.isEmpty) return const SizedBox.shrink();

      String bucketKey(DateTime start, DateTime end) =>
          '${start.toIso8601String()}_${end.toIso8601String()}';

      final countMap = {
        for (final cb in response.totalCountBuckets)
          bucketKey(cb.bucketStart, cb.bucketEnd): cb.value,
      };

      return Container(
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border),
          borderRadius: KiteRadius.allMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(KiteSpace.md),
              child: Text(
                '${l.temporalInspectTable} (${response.avgBuckets.length})',
                style: t.p.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: KiteSpace.md,
                    columns: [
                      DataColumn(label: Text(timestampHeader, style: t.small)),
                      DataColumn(
                        label: Text(l.temporalStatsRawAvg, style: t.small),
                      ),
                      DataColumn(
                        label: Text(l.temporalSamples, style: t.small),
                      ),
                    ],
                    rows: [
                      for (final ab in response.avgBuckets)
                        DataRow(
                          cells: [
                            DataCell(
                              SelectableText(
                                '${formatLocalIsoDate(ab.bucketStart)} → ${formatLocalIsoDate(ab.bucketEnd)}',
                                style: t.small.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${ab.value.toStringAsFixed(2)}$unitSuffix',
                                style: t.small.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                countMap[bucketKey(
                                          ab.bucketStart,
                                          ab.bucketEnd,
                                        )]
                                        ?.toString() ??
                                    '—',
                                style: t.small.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
