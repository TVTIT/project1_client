import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../data/user_dto.dart';
import '../data/user_repository.dart';

/// State of the full bounded admin user list.
@immutable
class UserListState {
  const UserListState({
    this.isLoading = false,
    this.users = const [],
    this.error,
  });

  final bool isLoading;
  final List<UserSummary> users;
  final Object? error;

  bool get hasError => error != null;

  UserListState copyWith({
    bool? isLoading,
    List<UserSummary>? users,
    Object? Function()? error,
  }) {
    return UserListState(
      isLoading: isLoading ?? this.isLoading,
      users: users ?? this.users,
      error: error != null ? error() : this.error,
    );
  }
}

/// Notifier managing admin user list with session epoch and request sequence fencing.
class UserListNotifier extends Notifier<UserListState> {
  int _seq = 0;
  Future<void>? _inFlight;

  @override
  UserListState build() {
    final session = ref.watch(sessionProvider);
    final permissions = ref.watch(userPermissionsProvider);

    // Fail closed: if unauthenticated or not confirmed platform admin, keep empty unprivileged state
    if (!session.isAuthenticated || !permissions.isPlatformAdmin) {
      return const UserListState();
    }

    return const UserListState();
  }

  /// Triggers a fetch of the full bounded user list.
  Future<void> loadUsers() {
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
      final repo = ref.read(userRepositoryProvider);
      final users = await repo.listUsers();

      // Epoch & sequence fencing
      if (!ref.mounted) return;
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      state = UserListState(isLoading: false, users: users, error: null);
    } catch (e) {
      if (!ref.mounted) return;
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      // 403 on admin endpoint invalidates admin permissions while retaining auth session
      if (e is ApiException && e.statusCode == 403) {
        ref.read(userPermissionsProvider.notifier).invalidateAdminPermissions();
      }

      // 409 capacity exceeded must wipe users so stale/partial list is NEVER displayed as complete
      final isCapacity =
          e is ApiException &&
          e.statusCode == 409 &&
          e.code == 'user_list_capacity_exceeded';

      state = UserListState(
        isLoading: false,
        users: isCapacity ? const [] : state.users,
        error: e,
      );
    }
  }
}

final userListProvider = NotifierProvider<UserListNotifier, UserListState>(
  UserListNotifier.new,
);

/// Generic mutation action state for user creation, update, and gateway assignment.
@immutable
class UserActionState<T> {
  const UserActionState({this.isLoading = false, this.result, this.error});

  final bool isLoading;
  final T? result;
  final Object? error;

  bool get isSuccess => result != null && error == null;
  bool get hasError => error != null;
}
