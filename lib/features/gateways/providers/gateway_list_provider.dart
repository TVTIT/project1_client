import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../data/gateway_dto.dart';
import '../data/gateway_repository.dart';

@immutable
class GatewayListState {
  const GatewayListState({
    this.isLoading = false,
    this.gateways = const [],
    this.error,
    this.searchQuery = '',
    this.hasMore = false,
    this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.isAdminMode = false,
  });

  final bool isLoading;
  final List<GatewayCatalogItem> gateways;
  final Object? error;
  final String searchQuery;
  final bool hasMore;
  final String? nextCursor;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final bool isAdminMode;

  bool get hasError => error != null;
  bool get hasLoadMoreError => loadMoreError != null;
  bool get isEmpty => !isLoading && !hasError && gateways.isEmpty;

  List<GatewayCatalogItem> get filteredGateways {
    if (searchQuery.trim().isEmpty) return gateways;
    final q = searchQuery.trim().toLowerCase();
    return gateways.where((g) {
      return g.gatewayId.toLowerCase().contains(q) ||
          g.name.toLowerCase().contains(q) ||
          (g.description != null && g.description!.toLowerCase().contains(q));
    }).toList();
  }

  GatewayListState copyWith({
    bool? isLoading,
    List<GatewayCatalogItem>? gateways,
    Object? Function()? error,
    String? searchQuery,
    bool? hasMore,
    String? Function()? nextCursor,
    bool? isLoadingMore,
    Object? Function()? loadMoreError,
    bool? isAdminMode,
  }) {
    return GatewayListState(
      isLoading: isLoading ?? this.isLoading,
      gateways: gateways ?? this.gateways,
      error: error != null ? error() : this.error,
      searchQuery: searchQuery ?? this.searchQuery,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: loadMoreError != null
          ? loadMoreError()
          : this.loadMoreError,
      isAdminMode: isAdminMode ?? this.isAdminMode,
    );
  }
}

class GatewayListNotifier extends Notifier<GatewayListState> {
  int _seq = 0;
  int _authorityGen = 0;
  bool _adminFetchInFlight = false;
  final Set<String> _requestedCursors = {};

  @override
  GatewayListState build() {
    ref.watch(sessionProvider.select((s) => (s.status, s.user?.userId)));
    _seq++;
    final session = ref.read(sessionProvider);

    // If session is unauthenticated or restoring, purge any cached gateways from memory immediately
    if (!session.isAuthenticated) {
      _requestedCursors.clear();
      _adminFetchInFlight = false;
      return const GatewayListState();
    }

    // Authority changes listener:
    // Clear cached admin items immediately on downgrade/permission uncertainty so no stale inventory shown.
    ref.listen<UserPermissionsState>(userPermissionsProvider, (prev, next) {
      final wasConfirmedAdmin =
          prev != null &&
          !prev.isLoading &&
          !prev.hasError &&
          prev.isPlatformAdmin;
      final isConfirmedAdmin =
          !next.isLoading && !next.hasError && next.isPlatformAdmin;

      final isDowngradeOrUncertainty =
          (wasConfirmedAdmin || state.isAdminMode || _adminFetchInFlight) &&
          !isConfirmedAdmin;
      final isUpgrade =
          prev != null &&
          !prev.isLoading &&
          !wasConfirmedAdmin &&
          isConfirmedAdmin;

      if (isDowngradeOrUncertainty) {
        _requestedCursors.clear();
        _adminFetchInFlight = false;
        _authorityGen++;
        _seq++;
        state = state.copyWith(
          gateways: const [],
          hasMore: false,
          nextCursor: () => null,
          isAdminMode: false,
          isLoading: false,
          isLoadingMore: false,
          error: () => next.hasError ? next.error : null,
        );
      } else if (isUpgrade) {
        _authorityGen++;
        _seq++;
      }
    });

    return const GatewayListState();
  }

  Future<void> loadGateways() async {
    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(currentUserProvider)?.userId;
    final seq = ++_seq;
    final capturedAuthGen = _authorityGen;

    _requestedCursors.clear();
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      error: () => null,
      loadMoreError: () => null,
      hasMore: false,
      nextCursor: () => null,
    );

    // Await confirmed successful userPermissionsProvider before choosing admin or user GET
    var permState = ref.read(userPermissionsProvider);
    if (permState.isLoading) {
      try {
        await ref.read(userPermissionsProvider.notifier).loadPermissions();
      } catch (_) {}
      permState = ref.read(userPermissionsProvider);
    }

    // Fence check after awaiting permissions
    if (!ref.mounted) return;
    if (seq != _seq ||
        capturedAuthGen != _authorityGen ||
        expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
        expectedUserId != ref.read(currentUserProvider)?.userId) {
      return;
    }

    // If permissions check failed with error or is still loading/uncertain, fail closed:
    if (permState.hasError) {
      _requestedCursors.clear();
      _adminFetchInFlight = false;
      state = state.copyWith(
        isLoading: false,
        error: () => permState.error,
        gateways: const [],
        hasMore: false,
        nextCursor: () => null,
        isAdminMode: false,
      );
      return;
    }

    if (permState.isLoading) {
      _requestedCursors.clear();
      _adminFetchInFlight = false;
      state = state.copyWith(
        isLoading: false,
        error: () => const ApiException(
          statusCode: 503,
          code: 'service_unavailable',
          message: 'Đang xác thực quyền truy cập hệ thống.',
        ),
        gateways: const [],
        hasMore: false,
        nextCursor: () => null,
        isAdminMode: false,
      );
      return;
    }

    final isPlatformAdmin = permState.isPlatformAdmin;

    try {
      final repo = ref.read(gatewayRepositoryProvider);
      if (isPlatformAdmin) {
        _requestedCursors.clear();
        _adminFetchInFlight = true;
        final response = await repo.getAdminGateways();
        _adminFetchInFlight = false;

        if (!ref.mounted) return;
        final currentPerms = ref.read(userPermissionsProvider);
        final isConfirmedAdmin =
            !currentPerms.isLoading &&
            !currentPerms.hasError &&
            currentPerms.isPlatformAdmin;

        if (seq != _seq ||
            capturedAuthGen != _authorityGen ||
            expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
            expectedUserId != ref.read(currentUserProvider)?.userId ||
            !isConfirmedAdmin) {
          return;
        }

        final items = response.items
            .map(GatewayCatalogItem.fromAdminGateway)
            .toList();

        state = state.copyWith(
          isLoading: false,
          gateways: items,
          error: () => null,
          hasMore: response.hasMore,
          nextCursor: () => response.nextCursor,
          isAdminMode: true,
        );
      } else {
        _requestedCursors.clear();
        final items = await repo.getGateways();

        if (!ref.mounted) return;
        final currentPerms = ref.read(userPermissionsProvider);
        if (seq != _seq ||
            capturedAuthGen != _authorityGen ||
            expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
            expectedUserId != ref.read(currentUserProvider)?.userId ||
            currentPerms.isLoading ||
            currentPerms.hasError ||
            currentPerms.isPlatformAdmin) {
          return;
        }

        state = state.copyWith(
          isLoading: false,
          gateways: items.map(GatewayCatalogItem.fromUserGateway).toList(),
          error: () => null,
          hasMore: false,
          nextCursor: () => null,
          isAdminMode: false,
        );
      }
    } catch (e) {
      _adminFetchInFlight = false;
      if (!ref.mounted) return;
      if (seq != _seq ||
          capturedAuthGen != _authorityGen ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      if (isPlatformAdmin && e is ApiException && e.statusCode == 403) {
        // 403 admin inventory clears data, invalidate admin permission state, safely recheck permissions without endless loop
        ref.read(userPermissionsProvider.notifier).invalidateAdminPermissions();
        unawaited(ref.read(userPermissionsProvider.notifier).loadPermissions());
        _requestedCursors.clear();
        state = state.copyWith(
          isLoading: false,
          gateways: const [],
          error: () => e,
          hasMore: false,
          nextCursor: () => null,
          isAdminMode: false,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: () => e,
      );
    }
  }

  Future<void> loadNextPage() async {
    if (!state.isAdminMode) return;
    if (!state.hasMore ||
        state.nextCursor == null ||
        state.nextCursor!.isEmpty) {
      return;
    }
    if (state.isLoading || state.isLoadingMore) return;
    if (state.hasError) return;

    final cursor = state.nextCursor!;
    if (_requestedCursors.contains(cursor)) {
      // Loop detected: cursor already requested
      state = state.copyWith(hasMore: false, nextCursor: () => null);
      return;
    }

    _requestedCursors.add(cursor);

    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(currentUserProvider)?.userId;
    final seq = ++_seq;
    final capturedAuthGen = _authorityGen;

    state = state.copyWith(isLoadingMore: true, loadMoreError: () => null);

    try {
      _adminFetchInFlight = true;
      final repo = ref.read(gatewayRepositoryProvider);
      final response = await repo.getAdminGateways(after: cursor);
      _adminFetchInFlight = false;

      if (!ref.mounted) return;
      final currentPerms = ref.read(userPermissionsProvider);
      final isConfirmedAdmin =
          !currentPerms.isLoading &&
          !currentPerms.hasError &&
          currentPerms.isPlatformAdmin;

      if (seq != _seq ||
          capturedAuthGen != _authorityGen ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId ||
          !isConfirmedAdmin) {
        return;
      }

      final newCursor = response.nextCursor;
      final bool cursorAdvanced =
          newCursor != null &&
          newCursor.isNotEmpty &&
          newCursor != cursor &&
          !_requestedCursors.contains(newCursor);

      final bool hasMore =
          response.items.isNotEmpty && response.hasMore && cursorAdvanced;

      // Dedup exact IDs:
      final existingIds = state.gateways.map((g) => g.gatewayId).toSet();
      final merged = List<GatewayCatalogItem>.from(state.gateways);
      for (final item in response.items) {
        if (existingIds.add(item.gatewayId)) {
          merged.add(GatewayCatalogItem.fromAdminGateway(item));
        }
      }

      state = state.copyWith(
        isLoadingMore: false,
        gateways: merged,
        hasMore: hasMore,
        nextCursor: () => hasMore ? newCursor : null,
        loadMoreError: () => null,
      );
    } catch (e) {
      _adminFetchInFlight = false;
      if (!ref.mounted) return;
      if (seq != _seq ||
          capturedAuthGen != _authorityGen ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      _requestedCursors.remove(cursor);

      if (e is ApiException && e.statusCode == 403) {
        ref.read(userPermissionsProvider.notifier).invalidateAdminPermissions();
        unawaited(ref.read(userPermissionsProvider.notifier).loadPermissions());
        _requestedCursors.clear();
        state = state.copyWith(
          isLoadingMore: false,
          gateways: const [],
          error: () => e,
          hasMore: false,
          nextCursor: () => null,
          isAdminMode: false,
        );
        return;
      }

      state = state.copyWith(isLoadingMore: false, loadMoreError: () => e);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final gatewayListProvider =
    NotifierProvider<GatewayListNotifier, GatewayListState>(
      GatewayListNotifier.new,
    );
