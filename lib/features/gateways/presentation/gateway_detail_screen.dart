import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/states.dart';
import '../data/gateway_dto.dart';
import '../providers/gateway_detail_provider.dart';

/// Screen presenting Gateway Details and associated Sensor Catalog.
///
/// Features:
/// - Composed via `GET /v1/gateways` (metadata & role) and `GET /v1/gateways/{id}/sensors`.
/// - Strict ASCII 1-64 validation and reserved `backend_service` check.
/// - Anti-enumeration defense: returns 404 on missing/foreign gateways while preserving URL.
/// - Distinct failure handling: displays gateway metadata even when sensors fail.
/// - Read-only policy: displays gateway role without fake stats or downlink controls.
/// - Responsive card view for mobile (<640px) and data table for desktop/tablet (>=640px).
/// - Client-side sensor search filtering by ID, name, or unit.
class GatewayDetailScreen extends ConsumerStatefulWidget {
  const GatewayDetailScreen({super.key, required this.gatewayId});

  final String gatewayId;

  @override
  ConsumerState<GatewayDetailScreen> createState() =>
      _GatewayDetailScreenState();
}

class _GatewayDetailScreenState extends ConsumerState<GatewayDetailScreen> {
  late final TextEditingController _sensorSearchController;

  @override
  void initState() {
    super.initState();
    _sensorSearchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(gatewayDetailProvider(widget.gatewayId).notifier).load();
      }
    });
  }

  @override
  void didUpdateWidget(covariant GatewayDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gatewayId != widget.gatewayId) {
      _sensorSearchController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(gatewayDetailProvider(widget.gatewayId).notifier).load();
        }
      });
    }
  }

  @override
  void dispose() {
    _sensorSearchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm UTC';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gatewayDetailProvider(widget.gatewayId));
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);
    final isMobile = KiteBreak.isMobile(context);

    return SelectionArea(
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(gatewayDetailProvider(widget.gatewayId).notifier).load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(KiteSpace.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button and header
                  _buildHeader(context, ref, state, isMobile, c, t, l),
                  const SizedBox(height: KiteSpace.lg),

                  // Stage 2 read-only banner
                  _buildReadOnlyNotice(c, t, l),
                  const SizedBox(height: KiteSpace.xl),

                  // Body content
                  _buildBody(context, ref, state, isMobile, c, t, l),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    GatewayDetailState state,
    bool isMobile,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: KiteButton.outline(
            onPressed: () => context.go(R.gateways),
            leading: const Icon(Icons.arrow_back, size: 16),
            child: Text(isMobile ? 'Quay lại' : l.gatewayBackToList),
          ),
        ),
        const SizedBox(height: KiteSpace.lg),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: KiteSpace.md,
          runSpacing: KiteSpace.sm,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.gatewayDetailTitle}: ${widget.gatewayId}',
                  style: t.h3,
                ),
                const SizedBox(height: KiteSpace.xs),
                Text(l.gatewayDetailSubtitle, style: t.muted),
              ],
            ),
            KiteButton.outline(
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(gatewayDetailProvider(widget.gatewayId).notifier)
                        .load(),
              leading: const Icon(Icons.refresh, size: 16),
              child: Text(l.actionRefresh),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReadOnlyNotice(KiteColors c, KiteText t, L l) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KiteSpace.lg,
        vertical: KiteSpace.md,
      ),
      decoration: BoxDecoration(
        color: c.muted.withValues(alpha: 0.3),
        borderRadius: KiteRadius.allMd,
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: c.mutedForeground),
          const SizedBox(width: KiteSpace.md),
          Expanded(
            child: Text(
              l.gatewayReadOnlyNotice,
              style: t.small.copyWith(color: c.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    GatewayDetailState state,
    bool isMobile,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    // 1. Initial or Loading
    if ((state.status == GatewayDetailStatus.initial || state.isLoading) &&
        state.gateway == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: KiteSpace.xxl * 2),
        child: LoadingState(),
      );
    }

    // 2. Anti-enumeration 404 or Invalid Gateway ID
    if (state.isNotFound) {
      final msg = state.invalidId
          ? l.gatewayInvalidIdMessage
          : l.gatewayNotFoundMessage;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KiteSpace.xxl),
        child: EmptyState(
          title: l.gatewayNotFoundTitle,
          message: msg,
          actionLabel: isMobile ? 'Quay lại' : 'Quay lại danh sách',
          onAction: () => context.go(R.gateways),
        ),
      );
    }

    // 3. Metadata Failure
    if (state.hasGeneralError && state.gateway == null) {
      String errorMsg = 'Không thể tải thông tin Gateway.';
      if (state.metadataError is ApiException) {
        final apiErr = state.metadataError as ApiException;
        errorMsg = apiErr.message;
        if (apiErr.requestId != null) {
          errorMsg = '$errorMsg (Mã tra cứu: ${apiErr.requestId})';
        }
      } else if (state.metadataError is NetworkException) {
        errorMsg = (state.metadataError as NetworkException).message;
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KiteSpace.xxl),
        child: ErrorState(
          message: errorMsg,
          onRetry: () =>
              ref.read(gatewayDetailProvider(widget.gatewayId).notifier).load(),
        ),
      );
    }

    // 4. Gateway Metadata Loaded
    if (state.gateway == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: KiteSpace.xxl * 2),
        child: LoadingState(),
      );
    }
    final gateway = state.gateway!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section A: Gateway Metadata Card
        _buildGatewayMetadataCard(gateway, isMobile, c, t, l),
        const SizedBox(height: KiteSpace.xl),

        // Section B: Sensor Catalog Header & Actions
        _buildSensorsSection(context, ref, state, isMobile, c, t, l),
      ],
    );
  }

  Widget _buildGatewayMetadataCard(
    GatewayItem item,
    bool isMobile,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return Container(
      padding: const EdgeInsets.all(KiteSpace.xl),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: KiteRadius.allLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.router_outlined, size: 28, color: c.primary),
              const SizedBox(width: KiteSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: t.large.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.gatewayId,
                      style: t.muted.copyWith(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              KiteBadge(item.role.label, tone: item.role.tone),
            ],
          ),
          const SizedBox(height: KiteSpace.xl),
          const Divider(height: 1),
          const SizedBox(height: KiteSpace.xl),

          // Metadata Grid
          Wrap(
            spacing: KiteSpace.xxl,
            runSpacing: KiteSpace.lg,
            children: [
              _buildMetadataField(
                label: l.gatewayId,
                value: item.gatewayId,
                isMonospace: true,
                c: c,
                t: t,
              ),
              _buildMetadataField(
                label: l.gatewayRole,
                value: item.role.label,
                c: c,
                t: t,
              ),
              _buildMetadataField(
                label: l.gatewayCreatedAt,
                value: _formatDate(item.createdAt),
                c: c,
                t: t,
              ),
            ],
          ),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: KiteSpace.lg),
            _buildMetadataField(
              label: l.gatewayDescription,
              value: item.description!,
              c: c,
              t: t,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataField({
    required String label,
    required String value,
    bool isMonospace = false,
    required KiteColors c,
    required KiteText t,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.muted.copyWith(fontSize: 12)),
        const SizedBox(height: KiteSpace.xs),
        SelectableText(
          value,
          style: isMonospace
              ? t.p.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                )
              : t.p.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSensorsSection(
    BuildContext context,
    WidgetRef ref,
    GatewayDetailState state,
    bool isMobile,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    final filtered = state.filteredSensors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: KiteSpace.md,
          runSpacing: KiteSpace.sm,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: KiteSpace.sm,
              children: [
                Text(l.gatewaySectionSensors, style: t.h4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KiteSpace.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.muted.withValues(alpha: 0.3),
                    borderRadius: KiteRadius.allSm,
                  ),
                  child: Text(
                    '${state.sensors.length}',
                    style: t.small.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: KiteSpace.lg),

        // Sensor Failure Banner (when metadata succeeded but sensors failed)
        if (state.hasSensorsError) ...[
          Container(
            padding: const EdgeInsets.all(KiteSpace.lg),
            decoration: BoxDecoration(
              color: c.destructive.withValues(alpha: 0.08),
              borderRadius: KiteRadius.allMd,
              border: Border.all(color: c.destructive.withValues(alpha: 0.3)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: KiteSpace.md,
              runSpacing: KiteSpace.sm,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 20, color: c.destructive),
                    const SizedBox(width: KiteSpace.md),
                    Text(
                      l.sensorErrorTitle,
                      style: t.p.copyWith(
                        color: c.destructive,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                KiteButton.outline(
                  onPressed: () => ref
                      .read(gatewayDetailProvider(widget.gatewayId).notifier)
                      .load(reloadSensorsOnly: true),
                  leading: const Icon(Icons.refresh, size: 14),
                  child: Text(l.sensorErrorRetry),
                ),
              ],
            ),
          ),
          const SizedBox(height: KiteSpace.lg),
        ],

        // Search Bar (shown when sensor list has items)
        if (state.sensors.isNotEmpty) ...[
          KiteInput(
            controller: _sensorSearchController,
            placeholder: l.sensorSearchPlaceholder,
            leading: Icon(Icons.search, size: 18, color: c.mutedForeground),
            trailing: _sensorSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    splashRadius: 16,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _sensorSearchController.clear();
                      ref
                          .read(
                            gatewayDetailProvider(widget.gatewayId).notifier,
                          )
                          .setSearchQuery('');
                    },
                  )
                : null,
            onChanged: (val) {
              ref
                  .read(gatewayDetailProvider(widget.gatewayId).notifier)
                  .setSearchQuery(val);
            },
          ),
          const SizedBox(height: KiteSpace.lg),
        ],

        // Empty sensors state
        if (state.isSensorsEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KiteSpace.xl),
            child: EmptyState(
              title: l.sensorEmptyTitle,
              message: l.sensorEmptyMessage,
            ),
          ),
        ] else if (state.sensors.isNotEmpty && filtered.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KiteSpace.xl),
            child: EmptyState(
              title: l.sensorSearchEmptyTitle,
              message: l.sensorSearchEmptyMessage,
              actionLabel: l.actionClear,
              onAction: () {
                _sensorSearchController.clear();
                ref
                    .read(gatewayDetailProvider(widget.gatewayId).notifier)
                    .setSearchQuery('');
              },
            ),
          ),
        ] else if (filtered.isNotEmpty) ...[
          if (isMobile)
            _buildMobileSensorCards(filtered, c, t, l)
          else
            _buildDesktopSensorTable(filtered, c, t, l),
        ],
      ],
    );
  }

  Widget _buildMobileSensorCards(
    List<SensorItem> items,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: KiteSpace.md),
      itemBuilder: (context, index) {
        final item = items[index];
        final unitDisplay = (item.unit != null && item.unit!.isNotEmpty)
            ? item.unit!
            : '—';

        return Material(
          color: c.card,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: c.border),
            borderRadius: KiteRadius.allMd,
          ),
          child: Padding(
            padding: const EdgeInsets.all(KiteSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sensors, size: 20, color: c.primary),
                    const SizedBox(width: KiteSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: t.p.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.sensorId,
                            style: t.muted.copyWith(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.unit != null && item.unit!.isNotEmpty)
                      KiteBadge(item.unit!, tone: KiteTone.neutral),
                  ],
                ),
                const SizedBox(height: KiteSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l.sensorUnit}: $unitDisplay',
                      style: t.small.copyWith(color: c.mutedForeground),
                    ),
                    Text(
                      _formatDate(item.createdAt),
                      style: t.muted.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopSensorTable(
    List<SensorItem> items,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: KiteRadius.allMd,
      ),
      child: ClipRRect(
        borderRadius: KiteRadius.allMd,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 800),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                c.muted.withValues(alpha: 0.3),
              ),
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              horizontalMargin: KiteSpace.xl,
              columnSpacing: KiteSpace.xl,
              showCheckboxColumn: false,
              columns: [
                DataColumn(
                  label: Text(
                    l.sensorId,
                    style: t.small.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.sensorName,
                    style: t.small.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.sensorUnit,
                    style: t.small.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.sensorCreatedAt,
                    style: t.small.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              rows: [
                for (final item in items)
                  DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sensors, size: 16, color: c.primary),
                            const SizedBox(width: KiteSpace.sm),
                            SelectableText(
                              item.sensorId,
                              style: t.small.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        SelectableText(
                          item.name,
                          style: t.small.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      DataCell(
                        SelectableText(
                          (item.unit != null && item.unit!.isNotEmpty)
                              ? item.unit!
                              : '—',
                          style: t.small.copyWith(
                            color: item.unit != null ? null : c.mutedForeground,
                          ),
                        ),
                      ),
                      DataCell(
                        SelectableText(
                          _formatDate(item.createdAt),
                          style: t.small.copyWith(color: c.mutedForeground),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
