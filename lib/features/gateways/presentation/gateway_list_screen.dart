import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/states.dart';
import '../data/gateway_dto.dart';
import '../providers/gateway_list_provider.dart';
import 'mqtt_credential_dialog.dart';

/// Screen presenting the user's accessible Gateway catalog.
///
/// Features:
/// - Real Go REST API integration via `GET /v1/gateways`.
/// - Role display per gateway (`owner`, `operator`, `viewer`) from `user_gateways`.
/// - Honest loading, empty, and error states with safe retry.
/// - Responsive card view for mobile (<640px) and data table for desktop/tablet (>=640px).
/// - Client-side search filtering by ID, name, or description.
/// - Selecting a gateway navigates to `/gateways/:gatewayId`.
class GatewayListScreen extends ConsumerStatefulWidget {
  const GatewayListScreen({super.key});

  @override
  ConsumerState<GatewayListScreen> createState() => _GatewayListScreenState();
}

class _GatewayListScreenState extends ConsumerState<GatewayListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(gatewayListProvider.notifier).loadGateways();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    final state = ref.watch(gatewayListProvider);
    final isPlatformAdmin = ref.watch(isPlatformAdminProvider);
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);
    final isMobile = KiteBreak.isMobile(context);

    return SelectionArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(gatewayListProvider.notifier).loadGateways(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(KiteSpace.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page Header
                  _buildHeader(
                    context,
                    ref,
                    state,
                    isPlatformAdmin,
                    isMobile,
                    c,
                    t,
                    l,
                  ),
                  const SizedBox(height: KiteSpace.lg),

                  // Search input (only shown when catalog is loaded or has items)
                  if (!state.isLoading && state.gateways.isNotEmpty) ...[
                    _buildSearchBar(ref, c),
                    const SizedBox(height: KiteSpace.lg),
                  ],

                  // Content states
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
    GatewayListState state,
    bool isPlatformAdmin,
    bool isMobile,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: KiteSpace.md,
      runSpacing: KiteSpace.sm,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.gatewayListTitle, style: t.h3),
            const SizedBox(height: KiteSpace.xs),
            Text(l.gatewayListSubtitle, style: t.muted),
          ],
        ),
        Wrap(
          spacing: KiteSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (isPlatformAdmin) ...[
              KiteButton(
                onPressed: () => context.go(R.gatewayProvision),
                leading: const Icon(Icons.add, size: 16),
                child: Text(l.gatewayAddButton),
              ),
              KiteButton.outline(
                onPressed: () => showMqttCredentialDialog(context),
                leading: const Icon(Icons.vpn_key_outlined, size: 16),
                child: const Text('Quản lý MQTT theo mã trạm'),
              ),
            ],
            KiteButton.outline(
              onPressed: state.isLoading
                  ? null
                  : () => ref.read(gatewayListProvider.notifier).loadGateways(),
              leading: const Icon(Icons.refresh, size: 16),
              child: Text(l.actionRefresh),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(WidgetRef ref, KiteColors c) {
    return KiteInput(
      controller: _searchController,
      placeholder: L.of(context).gatewaySearchPlaceholder,
      leading: Icon(Icons.search, size: 18, color: c.mutedForeground),
      trailing: _searchController.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, size: 16),
              splashRadius: 16,
              visualDensity: VisualDensity.compact,
              onPressed: () {
                _searchController.clear();
                ref.read(gatewayListProvider.notifier).setSearchQuery('');
              },
            )
          : null,
      onChanged: (val) {
        ref.read(gatewayListProvider.notifier).setSearchQuery(val);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    GatewayListState state,
    bool isMobile,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    if (state.isLoading && state.gateways.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: KiteSpace.xxl * 2),
        child: LoadingState(),
      );
    }

    if (state.hasError && state.gateways.isEmpty) {
      String errorMsg = 'Không thể tải danh sách Gateway.';
      if (state.error is ApiException) {
        final apiErr = state.error as ApiException;
        errorMsg = apiErr.message;
        if (apiErr.requestId != null) {
          errorMsg = '$errorMsg (Mã tra cứu: ${apiErr.requestId})';
        }
      } else if (state.error is NetworkException) {
        errorMsg = (state.error as NetworkException).message;
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KiteSpace.xxl),
        child: ErrorState(
          message: errorMsg,
          onRetry: () => ref.read(gatewayListProvider.notifier).loadGateways(),
        ),
      );
    }

    if (state.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KiteSpace.xxl),
        child: EmptyState(
          title: l.gatewayEmptyTitle,
          message: l.gatewayEmptyMessage,
          actionLabel: l.actionRefresh,
          onAction: () => ref.read(gatewayListProvider.notifier).loadGateways(),
        ),
      );
    }

    final filtered = state.filteredGateways;
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KiteSpace.xxl),
        child: EmptyState(
          title: l.gatewaySearchEmptyTitle,
          message: l.gatewaySearchEmptyMessage,
          actionLabel: l.actionClear,
          onAction: () {
            _searchController.clear();
            ref.read(gatewayListProvider.notifier).setSearchQuery('');
          },
        ),
      );
    }

    if (isMobile) {
      return _buildMobileCardList(filtered, c, t, l);
    }

    return _buildDesktopTable(filtered, c, t, l);
  }

  Widget _buildMobileCardList(
    List<GatewayItem> items,
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
        return Material(
          color: c.card,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: c.border),
            borderRadius: KiteRadius.allMd,
          ),
          child: InkWell(
            borderRadius: KiteRadius.allMd,
            onTap: () => context.go(R.gatewayDetail(item.gatewayId)),
            child: Padding(
              padding: const EdgeInsets.all(KiteSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.router_outlined, size: 20, color: c.primary),
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
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: KiteSpace.sm),
                    Text(
                      item.description!,
                      style: t.small.copyWith(color: c.mutedForeground),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: KiteSpace.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(item.createdAt),
                        style: t.muted.copyWith(fontSize: 11),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l.gatewayActionDetail,
                            style: t.small.copyWith(
                              color: c.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14, color: c.primary),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(
    List<GatewayItem> items,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth < 900
                      ? 900
                      : constraints.maxWidth,
                ),
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
                        l.gatewayId,
                        style: t.small.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l.gatewayName,
                        style: t.small.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l.gatewayDescription,
                        style: t.small.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l.gatewayRole,
                        style: t.small.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l.gatewayCreatedAt,
                        style: t.small.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          l.gatewayActionDetail,
                          style: t.small.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                  rows: [
                    for (final item in items)
                      DataRow(
                        onSelectChanged: (_) =>
                            context.go(R.gatewayDetail(item.gatewayId)),
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.router_outlined,
                                  size: 16,
                                  color: c.primary,
                                ),
                                const SizedBox(width: KiteSpace.sm),
                                Text(
                                  item.gatewayId,
                                  style: t.small.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              item.name,
                              style: t.small.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.description ?? '—',
                              style: t.muted.copyWith(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DataCell(
                            KiteBadge(item.role.label, tone: item.role.tone),
                          ),
                          DataCell(
                            Text(
                              _formatDate(item.createdAt),
                              style: t.muted.copyWith(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_forward, size: 16),
                                tooltip: l.gatewayActionDetail,
                                color: c.mutedForeground,
                                splashRadius: 16,
                                onPressed: () =>
                                    context.go(R.gatewayDetail(item.gatewayId)),
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
    );
  }
}
