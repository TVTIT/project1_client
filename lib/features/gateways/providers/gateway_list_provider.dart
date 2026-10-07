import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../data/gateway_dto.dart';
import '../data/gateway_repository.dart';

@immutable
class GatewayListState {
  const GatewayListState({
    this.isLoading = false,
    this.gateways = const [],
    this.error,
    this.searchQuery = '',
  });

  final bool isLoading;
  final List<GatewayItem> gateways;
  final Object? error;
  final String searchQuery;

  bool get hasError => error != null;
  bool get isEmpty => !isLoading && !hasError && gateways.isEmpty;

  List<GatewayItem> get filteredGateways {
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
    List<GatewayItem>? gateways,
    Object? Function()? error,
    String? searchQuery,
  }) {
    return GatewayListState(
      isLoading: isLoading ?? this.isLoading,
      gateways: gateways ?? this.gateways,
      error: error != null ? error() : this.error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class GatewayListNotifier extends Notifier<GatewayListState> {
  int _seq = 0;

  @override
  GatewayListState build() {
    final session = ref.watch(sessionProvider);

    // If session is unauthenticated or restoring, purge any cached gateways from memory immediately
    if (!session.isAuthenticated) {
      return const GatewayListState();
    }

    return const GatewayListState();
  }

  Future<void> loadGateways() async {
    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final seq = ++_seq;

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final repo = ref.read(gatewayRepositoryProvider);
      final items = await repo.getGateways();

      // Epoch isolation & out-of-order guard:
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        gateways: items,
        error: () => null,
      );
    } catch (e) {
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch) {
        return;
      }
      state = state.copyWith(isLoading: false, error: () => e);
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
