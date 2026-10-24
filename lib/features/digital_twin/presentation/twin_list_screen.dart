import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/states.dart';
import '../../gateways/data/gateway_dto.dart';
import '../data/digital_twin_dto.dart';
import '../providers/digital_twin_providers.dart';
import '../providers/twin_list_provider.dart';

class TwinListScreen extends ConsumerStatefulWidget {
  const TwinListScreen({super.key});
  @override
  ConsumerState<TwinListScreen> createState() => _TwinListScreenState();
}

class _TwinListScreenState extends ConsumerState<TwinListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(twinListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(twinSessionScopeProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(sessionProvider).isAuthenticated) {
          ref.read(twinListProvider.notifier).load();
        }
      });
    });
    final session = ref.watch(sessionProvider);
    if (!session.isAuthenticated) return const LoadingState();
    final state = ref.watch(twinListProvider);
    final gateways = ref.watch(twinMemberGatewaysProvider);
    final memberItems = !gateways.isLoading && !gateways.hasError
        ? gateways.asData?.value ?? const <GatewayItem>[]
        : const <GatewayItem>[];
    final notifier = ref.read(twinListProvider.notifier);
    final l = L.of(context);
    final text = KiteText.of(context);
    final colors = KiteColors.of(context);
    void refresh() {
      ref.invalidate(twinMemberGatewaysProvider);
      notifier.load(type: state.type, gatewayId: state.gatewayId);
    }

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KiteSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: KiteSpace.md,
              runSpacing: KiteSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l.navDigitalTwins, style: text.h3),
                KiteButton.outline(
                  onPressed: state.isLoading ? null : refresh,
                  leading: const Icon(Icons.refresh, size: 16),
                  child: Text(l.actionRefresh),
                ),
              ],
            ),
            const SizedBox(height: KiteSpace.lg),
            Wrap(
              spacing: KiteSpace.md,
              runSpacing: KiteSpace.md,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 160,
                    maxWidth: 260,
                  ),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('type-${state.type}'),
                    initialValue: state.type?.value ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.twinTypeFilter),
                    items: [
                      DropdownMenuItem(value: '', child: Text(l.twinAll)),
                      for (final type in EntityType.values)
                        DropdownMenuItem(
                          value: type.value,
                          child: Text(type.value),
                        ),
                    ],
                    onChanged: (value) => notifier.load(
                      type: value == '' || value == null
                          ? null
                          : EntityType.fromString(value),
                      gatewayId: state.gatewayId,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 200,
                    maxWidth: 300,
                  ),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'gateway-${state.gatewayId}-${gateways.asData?.value}',
                    ),
                    initialValue:
                        memberItems.any(
                              (g) => g.gatewayId == state.gatewayId,
                            ) ==
                            true
                        ? state.gatewayId
                        : '',
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.twinGatewayFilter),
                    items: [
                      DropdownMenuItem(value: '', child: Text(l.twinAll)),
                      for (final gateway in memberItems)
                        DropdownMenuItem(
                          value: gateway.gatewayId,
                          child: Text(
                            '${gateway.name} (${gateway.gatewayId})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: !gateways.isLoading && !gateways.hasError
                        ? (value) => notifier.load(
                            type: state.type,
                            gatewayId: value == '' ? null : value,
                          )
                        : null,
                  ),
                ),
              ],
            ),
            if (gateways.hasError) ...[
              const SizedBox(height: KiteSpace.md),
              Text(
                l.twinGatewayError,
                style: text.small.copyWith(color: colors.destructive),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: KiteButton.outline(
                  onPressed: () => ref.invalidate(twinMemberGatewaysProvider),
                  child: Text(l.actionRetry),
                ),
              ),
            ],
            const SizedBox(height: KiteSpace.lg),
            if (state.isLoading) const LoadingState(),
            if (state.error != null) ...[
              Text(
                l.twinLoadError,
                style: text.p.copyWith(color: colors.destructive),
              ),
              if (state.error case ApiException(:final requestId?))
                Text('Request ID: $requestId', style: text.small),
              Align(
                alignment: Alignment.centerLeft,
                child: KiteButton.outline(
                  onPressed: state.isLoading
                      ? null
                      : state.nextCursor != null
                      ? notifier.loadMore
                      : refresh,
                  child: Text(l.actionRetry),
                ),
              ),
            ],
            if (!state.isLoading && state.error == null && state.items.isEmpty)
              EmptyState(title: l.navDigitalTwins, message: l.twinEmpty),
            if (state.items.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 640) {
                    return Column(
                      children: [
                        for (final item in state.items)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: KiteSpace.md,
                            ),
                            child: Material(
                              color: colors.card,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: colors.border),
                                borderRadius: KiteRadius.allMd,
                              ),
                              child: InkWell(
                                borderRadius: KiteRadius.allMd,
                                onTap: () => context.go(R.twinDetail(item.id)),
                                child: Padding(
                                  padding: const EdgeInsets.all(KiteSpace.lg),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            item.type == 'Sensor'
                                                ? Icons.sensors
                                                : Icons.router_outlined,
                                            size: 20,
                                            color: colors.primary,
                                          ),
                                          const SizedBox(width: KiteSpace.sm),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name ?? '—',
                                                  style: text.p.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.id,
                                                  style: text.muted.copyWith(
                                                    fontSize: 12,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          KiteBadge(
                                            item.type,
                                            tone: item.type == 'Sensor'
                                                ? KiteTone.info
                                                : KiteTone.neutral,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: KiteSpace.md),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Gateway: ${item.gatewayId}',
                                              style: text.small.copyWith(
                                                fontFamily: 'monospace',
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: KiteSpace.sm),
                                          Text(
                                            _date(item.modifiedAt),
                                            style: text.muted.copyWith(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      border: Border.all(color: colors.border),
                      borderRadius: KiteRadius.allMd,
                    ),
                    child: ClipRRect(
                      borderRadius: KiteRadius.allMd,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth < 900
                                ? 900
                                : constraints.maxWidth,
                          ),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              colors.muted.withValues(alpha: 0.3),
                            ),
                            dataRowMinHeight: 52,
                            dataRowMaxHeight: 64,
                            horizontalMargin: KiteSpace.xl,
                            columnSpacing: KiteSpace.xl,
                            showCheckboxColumn: false,
                            columns: [
                              DataColumn(
                                label: Text(
                                  l.twinName,
                                  style: text.small.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  l.twinType,
                                  style: text.small.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'URN',
                                  style: text.small.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Gateway',
                                  style: text.small.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  l.twinModifiedAt,
                                  style: text.small.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    l.twinOpen,
                                    style: text.small.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            rows: [
                              for (final item in state.items)
                                DataRow(
                                  onSelectChanged: (_) =>
                                      context.go(R.twinDetail(item.id)),
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            item.type == 'Sensor'
                                                ? Icons.sensors
                                                : Icons.router_outlined,
                                            size: 16,
                                            color: colors.primary,
                                          ),
                                          const SizedBox(width: KiteSpace.sm),
                                          Text(
                                            item.name ?? '—',
                                            style: text.small.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      KiteBadge(
                                        item.type,
                                        tone: item.type == 'Sensor'
                                            ? KiteTone.info
                                            : KiteTone.neutral,
                                      ),
                                    ),
                                    DataCell(
                                      SelectableText(
                                        item.id,
                                        style: text.small.copyWith(
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        item.gatewayId,
                                        style: text.small.copyWith(
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _date(item.modifiedAt),
                                        style: text.muted.copyWith(
                                          fontSize: 12,
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
                                          color: colors.mutedForeground,
                                          splashRadius: 16,
                                          onPressed: () =>
                                              context.go(R.twinDetail(item.id)),
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
                  );
                },
              ),
            if (state.atCapacity) Text(l.twinCapacity, style: text.muted),
            if (state.nextCursor != null)
              Align(
                alignment: Alignment.centerLeft,
                child: KiteButton.outline(
                  onPressed: state.isLoading ? null : notifier.loadMore,
                  child: Text(l.twinLoadMore),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime? date) => date?.toUtc().toIso8601String() ?? '—';
}
