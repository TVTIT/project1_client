import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../data/digital_twin_dto.dart';
import '../data/digital_twin_repository.dart';

final twinSessionScopeProvider = Provider((ref) {
  final session = ref.watch(sessionProvider);
  return (
    session.status,
    session.user?.userId,
    ref.read(sessionProvider.notifier).sessionEpoch,
  );
});

/// State of a Digital Twin flat state view (`twin_states`).
@immutable
class TwinStateViewState {
  static const _unchanged = Object();
  const TwinStateViewState({this.isLoading = false, this.state, this.error});

  final bool isLoading;
  final TwinStateResponse? state;
  final Object? error;

  bool get hasError => error != null;

  TwinStateViewState copyWith({
    bool? isLoading,
    Object? state = _unchanged,
    Object? Function()? error,
  }) {
    return TwinStateViewState(
      isLoading: isLoading ?? this.isLoading,
      state: identical(state, _unchanged)
          ? this.state
          : state as TwinStateResponse?,
      error: error != null ? error() : this.error,
    );
  }
}

/// Notifier managing entity state view with session and sequence fencing.
class TwinStateViewNotifier extends Notifier<TwinStateViewState> {
  TwinStateViewNotifier(this.entityId);

  final String entityId;
  int _seq = 0;
  Future<void>? _inFlight;

  @override
  TwinStateViewState build() {
    // Token refresh for the same identity is not a new data scope.
    ref.watch(twinSessionScopeProvider);
    _seq++;
    _inFlight = null;
    return const TwinStateViewState();
  }

  /// Triggers a fetch of the entity flat state view.
  Future<void> loadState() {
    if (!ref.read(sessionProvider).isAuthenticated) return Future.value();
    if (_inFlight != null) return _inFlight!;
    late final Future<void> request;
    request = _performLoad().whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
    _inFlight = request;
    return _inFlight!;
  }

  Future<void> _performLoad() async {
    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(currentUserProvider)?.userId;
    final seq = ++_seq;

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final entity = EntityUrn.parse(entityId);
      final repo = ref.read(digitalTwinRepositoryProvider);
      final twinState = await repo.getTwinState(entityId);

      if (!ref.mounted) return;
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      if (twinState.id != entityId ||
          twinState.type != entity.type.value ||
          twinState.gatewayId != entity.gatewayId) {
        throw const FormatException('Wrong state identity');
      }

      state = TwinStateViewState(
        isLoading: false,
        state: twinState,
        error: null,
      );
    } catch (e) {
      if (!ref.mounted) return;
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      final denied =
          e is ApiException &&
          (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404);
      state = state.copyWith(
        isLoading: false,
        state: denied ? null : state.state,
        error: () => e,
      );
    }
  }
}

final twinStateViewProvider = NotifierProvider.autoDispose
    .family<TwinStateViewNotifier, TwinStateViewState, String>(
      (arg) => TwinStateViewNotifier(arg),
    );
