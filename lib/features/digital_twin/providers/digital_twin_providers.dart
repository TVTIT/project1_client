import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../data/digital_twin_dto.dart';
import '../data/digital_twin_repository.dart';

/// State of a Digital Twin flat state view (`twin_states`).
@immutable
class TwinStateViewState {
  const TwinStateViewState({this.isLoading = false, this.state, this.error});

  final bool isLoading;
  final TwinStateResponse? state;
  final Object? error;

  bool get hasError => error != null;

  TwinStateViewState copyWith({
    bool? isLoading,
    TwinStateResponse? state,
    Object? Function()? error,
  }) {
    return TwinStateViewState(
      isLoading: isLoading ?? this.isLoading,
      state: state ?? this.state,
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
    final session = ref.watch(sessionProvider);
    if (!session.isAuthenticated) {
      return const TwinStateViewState();
    }
    return const TwinStateViewState();
  }

  /// Triggers a fetch of the entity flat state view.
  Future<void> loadState() {
    if (_inFlight != null) return _inFlight!;
    _inFlight = _performLoad().whenComplete(() {
      _inFlight = null;
    });
    return _inFlight!;
  }

  Future<void> _performLoad() async {
    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(currentUserProvider)?.userId;
    final seq = ++_seq;

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final repo = ref.read(digitalTwinRepositoryProvider);
      final twinState = await repo.getTwinState(entityId);

      if (!ref.mounted) return;
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
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

      state = state.copyWith(isLoading: false, error: () => e);
    }
  }
}

final twinStateViewProvider =
    NotifierProvider.family<TwinStateViewNotifier, TwinStateViewState, String>(
      (arg) => TwinStateViewNotifier(arg),
    );
