import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../features/digital_twin/data/digital_twin_dto.dart';
import '../../l10n/app_localizations.dart';

DateTime? parseStrictUtcDate(String input) {
  final trimmed = input.trim();
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?Z?$',
  ).firstMatch(trimmed);
  if (match == null) return null;

  final y = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  final d = int.parse(match.group(3)!);
  final h = int.parse(match.group(4)!);
  final min = int.parse(match.group(5)!);
  final s = int.parse(match.group(6)!);
  final microStr = match.group(7);
  final totalFracUs = microStr == null
      ? 0
      : int.parse(microStr.padRight(6, '0').substring(0, 6));
  final ms = totalFracUs ~/ 1000;
  final us = totalFracUs % 1000;

  if (m < 1 || m > 12) return null;
  if (d < 1 || d > 31) return null;
  if (h < 0 || h > 23) return null;
  if (min < 0 || min > 59) return null;
  if (s < 0 || s > 59) return null;

  final dt = DateTime.utc(y, m, d, h, min, s, ms, us);
  // Check calendar date normalization (e.g. Feb 30 normalized to March 2)
  if (dt.year != y || dt.month != m || dt.day != d) {
    return null;
  }
  return dt;
}

/// Parses user-inputted local date-time string strictly without calendar normalization.
/// Accepts YYYY-MM-DD HH:mm, YYYY-MM-DD HH:mm:ss, or YYYY-MM-DD HH:mm:ss.ffffff.
DateTime? parseStrictLocalDate(String input) {
  final trimmed = input.trim();
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?(?:\.(\d{1,6}))?Z?$',
  ).firstMatch(trimmed);
  if (match == null) return null;

  final y = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  final d = int.parse(match.group(3)!);
  final h = int.parse(match.group(4)!);
  final min = int.parse(match.group(5)!);
  final s = match.group(6) != null ? int.parse(match.group(6)!) : 0;
  final microStr = match.group(7);
  final totalFracUs = microStr == null
      ? 0
      : int.parse(microStr.padRight(6, '0').substring(0, 6));
  final ms = totalFracUs ~/ 1000;
  final us = totalFracUs % 1000;

  if (m < 1 || m > 12) return null;
  if (d < 1 || d > 31) return null;
  if (h < 0 || h > 23) return null;
  if (min < 0 || min > 59) return null;
  if (s < 0 || s > 59) return null;

  final dt = DateTime(y, m, d, h, min, s, ms, us);
  // Check calendar date normalization (e.g. Feb 30 normalized to March 2)
  if (dt.year != y || dt.month != m || dt.day != d) {
    return null;
  }
  return dt;
}

/// Formats DateTime into user's local timezone representation (YYYY-MM-DD HH:mm:ss).
String formatLocalIsoDate(DateTime dt, {bool includeMicroseconds = false}) {
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final ss = local.second.toString().padLeft(2, '0');
  if (includeMicroseconds) {
    final fracUs = local.millisecond * 1000 + local.microsecond;
    if (fracUs > 0) {
      return '$y-$m-$d $hh:$mm:$ss.${fracUs.toString().padLeft(6, '0')}';
    }
  }
  return '$y-$m-$d $hh:$mm:$ss';
}

/// Formats the timezone offset of the given DateTime (e.g. UTC+07:00).
String formatTimezoneOffset(DateTime dt) {
  final offset = dt.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hours:$minutes';
}

/// Picks a local date and time adaptively based on platform.
/// On desktop/web: calendar mode for date and text input mode for time.
/// On mobile: standard calendar and dial mode.
Future<DateTime?> pickAdaptiveDateTime(
  BuildContext context, {
  DateTime? initialDateTime,
}) async {
  final isDesktopWeb =
      kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  final initial = (initialDateTime ?? DateTime.now()).toLocal();
  final firstDate = DateTime(2000);
  final lastDate = DateTime(2100);
  final clampedInitial = initial.isBefore(firstDate)
      ? firstDate
      : (initial.isAfter(lastDate) ? lastDate : initial);

  // 1. Chọn ngày (Dùng Calendar mode chuẩn)
  final DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: clampedInitial,
    firstDate: firstDate,
    lastDate: lastDate,
    initialEntryMode: DatePickerEntryMode.calendar,
  );

  if (pickedDate == null || !context.mounted) return null;

  // 2. Chọn giờ: Trên Desktop/Web mở thẳng ô gõ số
  final TimeOfDay? pickedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: clampedInitial.hour,
      minute: clampedInitial.minute,
    ),
    initialEntryMode: isDesktopWeb
        ? TimePickerEntryMode
              .input // Hiển thị ô TextField gõ số trực tiếp
        : TimePickerEntryMode.dial, // Trên mobile dùng mặt đồng hồ
  );

  if (pickedTime == null) return null;

  return DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
  );
}

String formatUtcIsoDate(DateTime dt) {
  final utc = dt.toUtc();
  final y = utc.year.toString().padLeft(4, '0');
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  final hh = utc.hour.toString().padLeft(2, '0');
  final mm = utc.minute.toString().padLeft(2, '0');
  final ss = utc.second.toString().padLeft(2, '0');
  final fracUs = utc.millisecond * 1000 + utc.microsecond;
  if (fracUs > 0) {
    return '$y-$m-$d $hh:$mm:$ss.${fracUs.toString().padLeft(6, '0')}';
  }
  return '$y-$m-$d $hh:$mm:$ss';
}

class TemporalHistoryControls extends StatefulWidget {
  const TemporalHistoryControls({
    super.key,
    required this.isLoading,
    required this.onApply,
    required this.onRefresh,
    required this.initialStart,
    required this.initialEnd,
    this.initialMode = TemporalQueryMode.aggregated,
    this.initialDuration = 'PT5M',
    this.initialAttrs = 'measurement',
    this.initialMaxPoints = 1000,
  });

  final bool isLoading;
  final ValueChanged<TemporalQueryParameters> onApply;
  final VoidCallback onRefresh;
  final DateTime initialStart;
  final DateTime initialEnd;
  final TemporalQueryMode initialMode;
  final String initialDuration;
  final String initialAttrs;
  final int initialMaxPoints;

  @override
  State<TemporalHistoryControls> createState() =>
      _TemporalHistoryControlsState();
}

class _TemporalHistoryControlsState extends State<TemporalHistoryControls> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  late TemporalQueryMode _mode;
  late String _duration;
  late String _attrs;
  late int _maxPoints;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _duration = widget.initialDuration;
    _attrs = widget.initialAttrs;
    _maxPoints = widget.initialMaxPoints;

    _startController = TextEditingController(
      text: formatLocalIsoDate(widget.initialStart),
    );
    _endController = TextEditingController(
      text: formatLocalIsoDate(widget.initialEnd),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _applyPreset({
    required Duration range,
    required TemporalQueryMode mode,
    String? duration,
  }) {
    final now = DateTime.now();
    final end = now;
    final start = end.subtract(range);

    setState(() {
      _startController.text = formatLocalIsoDate(start);
      _endController.text = formatLocalIsoDate(end);
      _mode = mode;
      if (duration != null) _duration = duration;
      _validationError = null;
    });

    _handleApply();
  }

  void _handleApply() {
    final startLocal = parseStrictLocalDate(_startController.text);
    final endLocal = parseStrictLocalDate(_endController.text);

    if (startLocal == null || endLocal == null) {
      setState(() {
        _validationError = L.of(context).temporalGuidanceInvalidDate;
      });
      return;
    }

    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();

    final query = TemporalQueryParameters(
      attrs: _attrs,
      timeAt: startUtc,
      endTimeAt: endUtc,
      mode: _mode,
      aggrPeriodDuration: _mode == TemporalQueryMode.raw ? null : _duration,
      aggrMethods: _mode == TemporalQueryMode.raw
          ? null
          : 'avg,min,max,totalCount',
      maxPoints: _maxPoints,
    );

    try {
      query.validate();
    } on FormatException {
      final l = L.of(context);
      setState(
        () => _validationError = query.range > const Duration(hours: 744)
            ? l.temporalGuidanceRange
            : query.isRaw && query.range > const Duration(seconds: 10)
            ? l.temporalRawRange
            : l.temporalGuidanceInvalidDate,
      );
      return;
    }

    setState(() => _validationError = null);
    widget.onApply(query);
  }

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);
    final tzOffset = formatTimezoneOffset(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(KiteSpace.lg),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: KiteRadius.allLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Presets row with accessible TextButton widgets
          Wrap(
            spacing: KiteSpace.sm,
            runSpacing: KiteSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l.temporalPresets,
                style: t.small.copyWith(fontWeight: FontWeight.w600),
              ),
              _buildPresetButton(
                label: l.temporalPreset10s,
                onPressed: () => _applyPreset(
                  range: const Duration(seconds: 10),
                  mode: TemporalQueryMode.raw,
                ),
                c: c,
                t: t,
              ),
              _buildPresetButton(
                label: l.temporalPreset15m,
                onPressed: () => _applyPreset(
                  range: const Duration(minutes: 15),
                  mode: TemporalQueryMode.aggregated,
                  duration: 'PT1M',
                ),
                c: c,
                t: t,
              ),
              _buildPresetButton(
                label: l.temporalPreset1h,
                onPressed: () => _applyPreset(
                  range: const Duration(hours: 1),
                  mode: TemporalQueryMode.aggregated,
                  duration: 'PT1M',
                ),
                c: c,
                t: t,
              ),
              _buildPresetButton(
                label: l.temporalPreset24h,
                onPressed: () => _applyPreset(
                  range: const Duration(hours: 24),
                  mode: TemporalQueryMode.aggregated,
                  duration: 'PT5M',
                ),
                c: c,
                t: t,
              ),
              _buildPresetButton(
                label: l.temporalPreset7d,
                onPressed: () => _applyPreset(
                  range: const Duration(days: 7),
                  mode: TemporalQueryMode.aggregated,
                  duration: 'PT1H',
                ),
                c: c,
                t: t,
              ),
              _buildPresetButton(
                label: l.temporalPreset30d,
                onPressed: () => _applyPreset(
                  range: const Duration(days: 30),
                  mode: TemporalQueryMode.aggregated,
                  duration: 'P1D',
                ),
                c: c,
                t: t,
              ),
            ],
          ),
          const SizedBox(height: KiteSpace.md),
          const Divider(height: 1),
          const SizedBox(height: KiteSpace.md),

          // Inputs row
          Wrap(
            spacing: KiteSpace.md,
            runSpacing: KiteSpace.md,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              // Start time
              SizedBox(
                width: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l.temporalStartTime} ($tzOffset)', style: t.small),
                    const SizedBox(height: 4),
                    TextField(
                      key: const ValueKey('temporal-start-time-field'),
                      controller: _startController,
                      style: t.small.copyWith(fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: KiteSpace.sm,
                          vertical: 8,
                        ),
                        suffixIcon: IconButton(
                          key: const ValueKey('temporal-start-time-picker-btn'),
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                          ),
                          tooltip: l.temporalPickDateTime,
                          splashRadius: 16,
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.isLoading
                              ? null
                              : () async {
                                  final current = parseStrictLocalDate(
                                    _startController.text,
                                  );
                                  final picked = await pickAdaptiveDateTime(
                                    context,
                                    initialDateTime: current,
                                  );
                                  if (picked != null && mounted) {
                                    setState(() {
                                      _startController.text =
                                          formatLocalIsoDate(picked);
                                    });
                                  }
                                },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: KiteRadius.allSm,
                          borderSide: BorderSide(color: c.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // End time
              SizedBox(
                width: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l.temporalEndTime} ($tzOffset)', style: t.small),
                    const SizedBox(height: 4),
                    TextField(
                      key: const ValueKey('temporal-end-time-field'),
                      controller: _endController,
                      style: t.small.copyWith(fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: KiteSpace.sm,
                          vertical: 8,
                        ),
                        suffixIcon: IconButton(
                          key: const ValueKey('temporal-end-time-picker-btn'),
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                          ),
                          tooltip: l.temporalPickDateTime,
                          splashRadius: 16,
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.isLoading
                              ? null
                              : () async {
                                  final current = parseStrictLocalDate(
                                    _endController.text,
                                  );
                                  final picked = await pickAdaptiveDateTime(
                                    context,
                                    initialDateTime: current,
                                  );
                                  if (picked != null && mounted) {
                                    setState(() {
                                      _endController.text = formatLocalIsoDate(
                                        picked,
                                      );
                                    });
                                  }
                                },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: KiteRadius.allSm,
                          borderSide: BorderSide(color: c.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Mode: Raw vs Aggregated
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.temporalMode, style: t.small),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<TemporalQueryMode>(
                      initialValue: _mode,
                      isDense: true,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: KiteSpace.sm,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: KiteRadius.allSm,
                          borderSide: BorderSide(color: c.border),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: TemporalQueryMode.aggregated,
                          child: Text(l.temporalModeAggregated, style: t.small),
                        ),
                        DropdownMenuItem(
                          value: TemporalQueryMode.raw,
                          child: Text(l.temporalModeRaw, style: t.small),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _mode = val);
                      },
                    ),
                  ],
                ),
              ),

              // Aggregation Duration
              if (_mode == TemporalQueryMode.aggregated)
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.temporalDuration, style: t.small),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _duration,
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: KiteSpace.sm,
                            vertical: 6,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: KiteRadius.allSm,
                            borderSide: BorderSide(color: c.border),
                          ),
                        ),
                        items: [
                          for (final d
                              in TemporalQueryParameters.canonicalDurations)
                            DropdownMenuItem(
                              value: d,
                              child: Text(d, style: t.small),
                            ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _duration = val);
                        },
                      ),
                    ],
                  ),
                ),

              // Attribute: measurement vs sample_interval_us
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.temporalAttribute, style: t.small),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _attrs,
                      isDense: true,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: KiteSpace.sm,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: KiteRadius.allSm,
                          borderSide: BorderSide(color: c.border),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'measurement',
                          child: Text(
                            l.temporalAttrMeasurement,
                            style: t.small,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'sample_interval_us',
                          child: Text(
                            l.temporalAttrSampleInterval,
                            style: t.small,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _attrs = val);
                      },
                    ),
                  ],
                ),
              ),

              // Max Points Control
              SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.temporalMaxPoints, style: t.small),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: _maxPoints,
                      isDense: true,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: KiteSpace.sm,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: KiteRadius.allSm,
                          borderSide: BorderSide(color: c.border),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 500, child: Text('500')),
                        DropdownMenuItem(value: 1000, child: Text('1000')),
                        DropdownMenuItem(value: 2000, child: Text('2000')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _maxPoints = val);
                      },
                    ),
                  ],
                ),
              ),

              // Action buttons
              Wrap(
                spacing: KiteSpace.sm,
                children: [
                  KiteButton(
                    onPressed: widget.isLoading ? null : _handleApply,
                    leading: const Icon(Icons.play_arrow, size: 16),
                    child: Text(l.temporalApply),
                  ),
                  KiteButton.outline(
                    onPressed: widget.isLoading ? null : widget.onRefresh,
                    leading: const Icon(Icons.refresh, size: 16),
                    child: Text(l.actionRefresh),
                  ),
                ],
              ),
            ],
          ),

          if (_validationError != null) ...[
            const SizedBox(height: KiteSpace.md),
            Text(
              _validationError!,
              style: t.small.copyWith(color: c.destructive),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required VoidCallback onPressed,
    required KiteColors c,
    required KiteText t,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 26),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: c.muted.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: KiteRadius.allSm,
          side: BorderSide(color: c.border),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: t.small.copyWith(fontSize: 11, color: c.foreground),
      ),
    );
  }
}
