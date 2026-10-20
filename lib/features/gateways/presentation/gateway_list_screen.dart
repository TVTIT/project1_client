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
  late final ScrollController _scrollController;
  int _loadGeneration = 0;
  bool _isFillScheduled = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(gatewayListProvider).searchQuery,
    );
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(gatewayListProvider.notifier).loadGateways();
      }
    });
  }

  @override
  void dispose() {
    _resetViewportFill();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetViewportFill() {
    _loadGeneration++;
    _isFillScheduled = false;
  }

  void _triggerLoadMore() {
    final state = ref.read(gatewayListProvider);
    if (!state.isAdminMode) return;
    if (!state.hasMore ||
        state.isLoading ||
        state.isLoadingMore ||
        state.hasError ||
        state.hasLoadMoreError ||
        state.searchQuery.trim().isNotEmpty) {
      return;
    }
    ref.read(gatewayListProvider.notifier).loadNextPage();
  }

  void _checkViewportFill() {
    if (_isFillScheduled) return;
    _isFillScheduled = true;
    final capturedGeneration = _loadGeneration;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isFillScheduled = false;
      if (!mounted || _loadGeneration != capturedGeneration) return;
      final state = ref.read(gatewayListProvider);
      if (!state.isAdminMode ||
          !state.hasMore ||
          state.isLoading ||
          state.isLoadingMore ||
          state.hasError ||
          state.hasLoadMoreError ||
          state.searchQuery.trim().isNotEmpty) {
        return;
      }
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        if (position.maxScrollExtent <= 0) {
          ref.read(gatewayListProvider.notifier).loadNextPage();
        }
      }
    });
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

    ref.listen<GatewayListState>(gatewayListProvider, (prev, next) {
      if (next.isLoading) {
        _resetViewportFill();
      } else if (prev?.isLoading == true && !next.isLoading) {
        _resetViewportFill();
        if (!next.hasError) {
          _checkViewportFill();
        }
      } else if (prev?.isLoadingMore == true && !next.isLoadingMore) {
        if (!next.hasLoadMoreError) {
          _checkViewportFill();
        }
      } else if (prev?.searchQuery.trim().isNotEmpty == true &&
          next.searchQuery.trim().isEmpty) {
        _checkViewportFill();
      }
    });

    return SelectionArea(
      child: RefreshIndicator(
        onRefresh: () {
          _resetViewportFill();
          return ref.read(gatewayListProvider.notifier).loadGateways();
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical &&
                notification.depth == 0 &&
                (notification is ScrollUpdateNotification ||
                    notification is ScrollEndNotification)) {
              final metrics = notification.metrics;
              if (metrics.maxScrollExtent > 0 &&
                  metrics.pixels >= metrics.maxScrollExtent - 200) {
                _triggerLoadMore();
              }
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _scrollController,
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

                    // Search input (only shown when catalog has items)
                    if (state.gateways.isNotEmpty) ...[
                      _buildSearchBar(ref, state, c, t, l),
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
                  : () {
                      _resetViewportFill();
                      ref.read(gatewayListProvider.notifier).loadGateways();
                    },
              leading: const Icon(Icons.refresh, size: 16),
              child: Text(l.actionRefresh),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    WidgetRef ref,
    GatewayListState state,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    final countText = state.searchQuery.trim().isEmpty
        ? l.gatewayLoadedCount(state.gateways.length)
        : l.gatewayLoadedCountFiltered(
            state.filteredGateways.length,
            state.gateways.length,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KiteInput(
          controller: _searchController,
          placeholder: l.gatewaySearchPlaceholder,
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
        ),
        const SizedBox(height: KiteSpace.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KiteSpace.xs),
          child: Text(countText, style: t.muted.copyWith(fontSize: 12)),
        ),
      ],
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

    final listWidget = isMobile
        ? _buildMobileCardList(filtered, c, t, l)
        : _buildDesktopTable(filtered, c, t, l);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        listWidget,
        if (state.isLoadingMore) ...[
          const SizedBox(height: KiteSpace.lg),
          const Center(child: LoadingState()),
        ],
        if (state.hasLoadMoreError) ...[
          const SizedBox(height: KiteSpace.lg),
          _buildLoadMoreError(state),
        ],
      ],
    );
  }

  Widget _buildLoadMoreError(GatewayListState state) {
    String errorMsg = 'Không thể tải thêm Gateway.';
    if (state.loadMoreError is ApiException) {
      final apiErr = state.loadMoreError as ApiException;
      errorMsg = apiErr.message;
      if (apiErr.requestId != null) {
        errorMsg = '$errorMsg (Mã tra cứu: ${apiErr.requestId})';
      }
    } else if (state.loadMoreError is NetworkException) {
      errorMsg = (state.loadMoreError as NetworkException).message;
    }

    return KiteAlert(title: errorMsg, tone: KiteTone.danger);
  }

  Widget _buildMobileCardList(
    List<GatewayCatalogItem> items,
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
                      if (item.role != null)
                        KiteBadge(item.role!.label, tone: item.role!.tone)
                      else
                        const Text('—'),
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
    List<GatewayCatalogItem> items,
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
                            item.role != null
                                ? KiteBadge(
                                    item.role!.label,
                                    tone: item.role!.tone,
                                  )
                                : const Text('—'),
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
