import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/temporal_history_controls.dart';
import '../../../shared/widgets/temporal_history_panel.dart';
import '../../gateways/data/gateway_dto.dart';
import '../../gateways/providers/gateway_detail_provider.dart';
import '../../gateways/providers/gateway_list_provider.dart';
import '../data/digital_twin_dto.dart';
import '../data/twin_json_display.dart';
import '../providers/digital_twin_providers.dart';
import '../providers/metadata_edit_provider.dart';
import '../providers/twin_detail_provider.dart';
import '../providers/twin_list_provider.dart';
import 'edit_metadata_dialog.dart';

/// Read-only detail. C8 can add a lazy history pane for [entityId] (raw URN)
/// alongside these panes, without importing Gateway presentation internals.
/// C9 may attach an explicitly authorized metadata action to the info pane.
class TwinDetailScreen extends ConsumerStatefulWidget {
  const TwinDetailScreen({super.key, required this.entityId});
  final String entityId;
  @override
  ConsumerState<TwinDetailScreen> createState() => _TwinDetailScreenState();
}

class _TwinDetailScreenState extends ConsumerState<TwinDetailScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = KiteText.of(context);
    final colors = KiteColors.of(context);
    final session = ref.watch(sessionProvider);
    if (!session.isAuthenticated) return const LoadingState();
    EntityUrn? entity;
    try {
      entity = EntityUrn.parse(widget.entityId);
    } on FormatException {
      /* safe not-found */
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KiteSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back button and header
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go(R.digitalTwins),
              child: Text(l.twinBackToList),
            ),
          ),
          const SizedBox(height: KiteSpace.lg),
          if (entity == null)
            Text(l.twinNotFound)
          else ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: KiteSpace.md,
              runSpacing: KiteSpace.sm,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.twinOpen, style: text.h3),
                    const SizedBox(height: KiteSpace.xs),
                    SelectableText(
                      entity.urn,
                      style: text.muted.copyWith(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: KiteSpace.xl),

            // Tabs
            Builder(
              builder: (context) {
                final tabs = entity!.type == EntityType.sensor
                    ? [l.twinInformation, l.twinState, l.twinHistory]
                    : [l.twinInformation, l.twinState];
                final currentTab = _tab >= tabs.length ? 0 : _tab;
                return Row(
                  children: [
                    for (int i = 0; i < tabs.length; i++)
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: currentTab == i
                                ? colors.muted
                                : null,
                          ),
                          onPressed: () => setState(() => _tab = i),
                          child: Text(tabs[i]),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: KiteSpace.lg),
            if (_tab == 0)
              _TwinInfoPane(
                key: ValueKey('info-${entity.urn}'),
                entityId: entity.urn,
              )
            else if (_tab == 1)
              _TwinStatePane(
                key: ValueKey('state-${entity.urn}'),
                entityId: entity.urn,
              )
            else if (_tab == 2 && entity.type == EntityType.sensor)
              Consumer(
                builder: (context, ref, _) {
                  final detail = ref
                      .watch(twinDetailProvider(entity!.urn))
                      .detail;
                  return TemporalHistoryPanel(
                    key: ValueKey('history-${entity.urn}'),
                    sensorUrn: entity.urn,
                    unit: detail?.displayUnit,
                    sensorName: detail?.name?.value,
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _TwinReadError extends StatelessWidget {
  const _TwinReadError(this.error, {required this.stale, required this.retry});
  final Object error;
  final bool stale;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final denied =
        error is ApiException &&
        [401, 403, 404].contains((error as ApiException).statusCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          denied
              ? l.twinNotFound
              : stale
              ? l.twinStale
              : l.twinLoadError,
        ),
        if (error case ApiException(:final requestId?))
          Text('Request ID: $requestId'),
        if (!denied) TextButton(onPressed: retry, child: Text(l.actionRetry)),
      ],
    );
  }
}

class _TwinInfoPane extends ConsumerWidget {
  const _TwinInfoPane({super.key, required this.entityId});
  final String entityId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(twinDetailProvider(entityId));
    final notifier = ref.read(twinDetailProvider(entityId).notifier);
    final l = L.of(context);
    final text = KiteText.of(context);
    final colors = KiteColors.of(context);
    final detail = state.detail;
    final entity = detail?.entity;
    final isSensor = entity?.type == EntityType.sensor;
    final isMobile = KiteBreak.isMobile(context);

    String date(DateTime? dt) =>
        dt != null ? formatLocalIsoDate(dt) : l.twinNoData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isLoading) const LoadingState(),
        if (state.error != null)
          _TwinReadError(
            state.error!,
            stale: detail != null,
            retry: state.isLoading ? null : notifier.retry,
          ),
        if (detail != null && entity != null) ...[
          Container(
            padding: const EdgeInsets.all(KiteSpace.xl),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border.all(color: colors.border),
              borderRadius: KiteRadius.allLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: KiteSpace.md,
                  runSpacing: KiteSpace.sm,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? 320 : 600,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSensor
                                    ? Icons.sensors
                                    : Icons.router_outlined,
                                size: 26,
                                color: colors.primary,
                              ),
                              const SizedBox(width: KiteSpace.sm),
                              Expanded(
                                child: Text(
                                  detail.name != null
                                      ? detail.entity.urn
                                      : (entity.sensorId ?? entity.gatewayId),
                                  style: text.h3.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            entity.urn,
                            style: text.muted.copyWith(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final permissionsState = ref.watch(
                          userPermissionsProvider,
                        );
                        GatewayRole? membershipRole;
                        if (detail.entity.type == EntityType.sensor) {
                          final members = ref
                              .watch(twinMemberGatewaysProvider)
                              .asData
                              ?.value;
                          for (final gw in members ?? const <GatewayItem>[]) {
                            if (gw.gatewayId == detail.entity.gatewayId) {
                              membershipRole = gw.role;
                            }
                          }
                        }
                        final gwDetail = ref.watch(
                          gatewayDetailProvider(detail.entity.gatewayId),
                        );
                        if (gwDetail.status == GatewayDetailStatus.loaded) {
                          membershipRole = gwDetail.membershipRole;
                        } else {
                          final gwList = ref.watch(gatewayListProvider);
                          for (final gw in gwList.gateways) {
                            if (gw.gatewayId == detail.entity.gatewayId) {
                              membershipRole = gw.role;
                              break;
                            }
                          }
                        }

                        final authority = resolveMetadataEditAuthority(
                          permissionsState: permissionsState,
                          entityType: detail.entity.type,
                          membershipRole: membershipRole,
                        );
                        if (authority == null) return const SizedBox.shrink();
                        return KiteButton.outline(
                          key: const ValueKey('edit-twin-metadata-btn'),
                          onPressed: () {
                            showEditMetadataDialog(
                              context,
                              entityUrn: detail.entity.urn,
                              initialName: detail.name?.value,
                              initialDescription: detail.description?.value,
                            );
                          },
                          leading: const Icon(
                            Icons.edit_note_outlined,
                            size: 16,
                          ),
                          child: Text(
                            isMobile
                                ? l.actionEditMetadata
                                : l.twinEditMetadata,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: KiteSpace.xl),
                const Divider(height: 1),
                const SizedBox(height: KiteSpace.xl),

                // Metadata grid fields in card
                Wrap(
                  spacing: KiteSpace.xxl,
                  runSpacing: KiteSpace.lg,
                  children: [
                    _buildField(
                      label: l.twinName,
                      value: detail.name?.value ?? l.twinNoData,
                      t: text,
                    ),
                    _buildField(
                      label: l.twinType,
                      value: entity.type.value,
                      badgeTone: isSensor ? KiteTone.info : KiteTone.neutral,
                      t: text,
                    ),
                    _buildField(
                      label: l.twinGatewayId,
                      value: entity.gatewayId,
                      isMonospace: true,
                      t: text,
                    ),
                    if (isSensor) ...[
                      _buildField(
                        label: l.twinSensorId,
                        value: entity.sensorId ?? '—',
                        isMonospace: true,
                        t: text,
                      ),
                      _buildField(
                        label: l.twinUnit,
                        value: detail.displayUnit ?? l.twinNoData,
                        t: text,
                      ),
                      if (detail.measurement != null)
                        _buildField(
                          label: l.twinMeasurement,
                          value:
                              '${detail.measurement!.value}${detail.displayUnit != null ? " ${detail.displayUnit}" : ""}',
                          isMonospace: true,
                          t: text,
                        ),
                      if (detail.sampleInterval != null)
                        _buildField(
                          label: 'sample_interval_us',
                          value: '${detail.sampleInterval!.value} µs',
                          isMonospace: true,
                          t: text,
                        ),
                    ],
                    if (detail.name?.modifiedAt != null)
                      _buildField(
                        label: l.twinModifiedAt,
                        value: date(detail.name!.modifiedAt),
                        t: text,
                      ),
                  ],
                ),

                if (detail.description != null &&
                    detail.description!.value.isNotEmpty) ...[
                  const SizedBox(height: KiteSpace.lg),
                  _buildField(
                    label: l.twinDescription,
                    value: detail.description!.value,
                    t: text,
                  ),
                ],

                if (isSensor && detail.hostedBy != null) ...[
                  const SizedBox(height: KiteSpace.lg),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.twinHostedBy,
                        style: text.muted.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: KiteSpace.xs),
                      InkWell(
                        onTap: () =>
                            context.go(R.twinDetail(detail.hostedBy!.urn)),
                        borderRadius: KiteRadius.allSm,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.router_outlined,
                                size: 16,
                                color: colors.primary,
                              ),
                              const SizedBox(width: KiteSpace.xs),
                              Text(
                                detail.hostedBy!.urn,
                                style: text.p.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (detail.measurement?.observedAt != null) ...[
                  const SizedBox(height: KiteSpace.lg),
                  _buildField(
                    label: l.twinObservedAt,
                    value: date(detail.measurement!.observedAt),
                    t: text,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: KiteSpace.xl),

          // Section B: Relationships (if Gateway)
          if (!isSensor) ...[
            _buildSensorsRelationshipSection(
              context,
              state,
              notifier,
              isMobile,
              colors,
              text,
              l,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildField({
    required String label,
    required String value,
    bool isMonospace = false,
    KiteTone? badgeTone,
    required KiteText t,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.muted.copyWith(fontSize: 12)),
        const SizedBox(height: KiteSpace.xs),
        badgeTone != null
            ? KiteBadge(value, tone: badgeTone)
            : SelectableText(
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

  Widget _buildSensorsRelationshipSection(
    BuildContext context,
    TwinDetailState state,
    TwinDetailNotifier notifier,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: KiteSpace.sm,
                children: [
                  Icon(Icons.sensors, size: 20, color: c.primary),
                  Text(l.twinRelationships, style: t.h4),
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
          if (state.sensors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KiteSpace.md),
              child: Text(l.twinNoData, style: t.muted),
            )
          else if (isMobile)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.sensors.length,
              separatorBuilder: (_, _) => const SizedBox(height: KiteSpace.sm),
              itemBuilder: (context, index) {
                final sensor = state.sensors[index];
                return Material(
                  color: c.muted.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: c.border),
                    borderRadius: KiteRadius.allMd,
                  ),
                  child: InkWell(
                    borderRadius: KiteRadius.allMd,
                    onTap: () => context.go(R.twinDetail(sensor.urn)),
                    child: Padding(
                      padding: const EdgeInsets.all(KiteSpace.md),
                      child: Row(
                        children: [
                          Icon(Icons.sensors, size: 16, color: c.primary),
                          const SizedBox(width: KiteSpace.sm),
                          Expanded(
                            child: Text(
                              sensor.urn,
                              style: t.small.copyWith(fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: c.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: c.border),
                borderRadius: KiteRadius.allMd,
              ),
              child: ClipRRect(
                borderRadius: KiteRadius.allMd,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth < 600
                              ? 600
                              : constraints.maxWidth,
                        ),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            c.muted.withValues(alpha: 0.3),
                          ),
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 56,
                          horizontalMargin: KiteSpace.lg,
                          columnSpacing: KiteSpace.lg,
                          showCheckboxColumn: false,
                          columns: [
                            DataColumn(
                              label: Text(
                                '#',
                                style: t.small.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                l.twinSensorId,
                                style: t.small.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const DataColumn(
                              label: Text(
                                'URN',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  l.twinOpen,
                                  style: t.small.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          rows: [
                            for (int i = 0; i < state.sensors.length; i++)
                              DataRow(
                                onSelectChanged: (_) => context.go(
                                  R.twinDetail(state.sensors[i].urn),
                                ),
                                cells: [
                                  DataCell(Text('${i + 1}')),
                                  DataCell(
                                    Text(
                                      state.sensors[i].sensorId ?? '—',
                                      style: t.small.copyWith(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SelectableText(
                                      state.sensors[i].urn,
                                      style: t.small.copyWith(
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.arrow_forward,
                                          size: 16,
                                        ),
                                        tooltip: l.twinOpen,
                                        splashRadius: 16,
                                        onPressed: () => context.go(
                                          R.twinDetail(state.sensors[i].urn),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (state.atCapacity) ...[
            const SizedBox(height: KiteSpace.sm),
            Text(
              l.twinRelationshipCapacity,
              style: t.muted.copyWith(fontSize: 12),
            ),
          ],
          if (state.nextCursor != null) ...[
            const SizedBox(height: KiteSpace.md),
            Align(
              alignment: Alignment.centerLeft,
              child: KiteButton.outline(
                onPressed: state.isLoading ? null : notifier.loadMore,
                child: Text(l.twinLoadMore),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TwinStatePane extends ConsumerStatefulWidget {
  const _TwinStatePane({super.key, required this.entityId});
  final String entityId;
  @override
  ConsumerState<_TwinStatePane> createState() => _TwinStatePaneState();
}

class _TwinStatePaneState extends ConsumerState<_TwinStatePane> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(twinSessionScopeProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(twinStateViewProvider(widget.entityId).notifier).loadState();
        }
      });
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(twinStateViewProvider(widget.entityId));
    final l = L.of(context);
    final data = state.state;
    String date(DateTime? value) =>
        value?.toUtc().toIso8601String() ?? l.twinNoData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isLoading) const LoadingState(),
        if (state.error != null)
          _TwinReadError(
            state.error!,
            stale: data != null,
            retry: state.isLoading
                ? null
                : () => ref
                      .read(twinStateViewProvider(widget.entityId).notifier)
                      .loadState(),
          ),
        if (data != null) ...[
          Text(l.twinReadOnly, style: KiteText.of(context).muted),
          const SizedBox(height: KiteSpace.md),
          Text('reported_state', style: KiteText.of(context).large),
          SelectableText(formatTwinJson(data.reportedState)),
          Text('${l.twinVersion}: ${data.reportedVersion}'),
          Text('${l.twinReportedAt}: ${date(data.lastReportedAt)}'),
          const SizedBox(height: KiteSpace.md),
          Text('desired_state', style: KiteText.of(context).large),
          SelectableText(formatTwinJson(data.desiredState)),
          Text('${l.twinVersion}: ${data.desiredVersion}'),
          Text('${l.twinDesiredAt}: ${date(data.lastDesiredAt)}'),
          Text('${l.twinModifiedAt}: ${date(data.updatedAt)}'),
        ],
      ],
    );
  }
}
