import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'session.dart';

/// Strongly-typed system-level platform permissions from `GET /v1/me/permissions`.
@immutable
class UserPermissions {
  const UserPermissions({required this.isPlatformAdmin});

  final bool isPlatformAdmin;

  static const unprivileged = UserPermissions(isPlatformAdmin: false);

  factory UserPermissions.fromJson(Map<String, dynamic> json) {
    return UserPermissions(isPlatformAdmin: json['is_platform_admin'] == true);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPermissions &&
          runtimeType == other.runtimeType &&
          isPlatformAdmin == other.isPlatformAdmin;

  @override
  int get hashCode => isPlatformAdmin.hashCode;
}

/// Abstract contract for fetching system-level permissions.
abstract class PermissionsRepository {
  Future<UserPermissions> getMyPermissions();
}

/// Concrete implementation of [PermissionsRepository] using `GET /v1/me/permissions`.
class HttpPermissionsRepository implements PermissionsRepository {
  const HttpPermissionsRepository(this._client);

  final ApiClient _client;

  @override
  Future<UserPermissions> getMyPermissions() async {
    final json = await _client.get('me/permissions');
    return UserPermissions.fromJson(json);
  }
}

final permissionsRepositoryProvider = Provider<PermissionsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HttpPermissionsRepository(client);
});

/// UI state for user permissions, strictly fail-closed.
@immutable
class UserPermissionsState {
  const UserPermissionsState({
    this.isLoading = false,
    this.permissions = UserPermissions.unprivileged,
    this.error,
  });

  final bool isLoading;
  final UserPermissions permissions;
  final Object? error;

  bool get isPlatformAdmin => permissions.isPlatformAdmin;
  bool get hasError => error != null;

  UserPermissionsState copyWith({
    bool? isLoading,
    UserPermissions? permissions,
    Object? Function()? error,
  }) {
    return UserPermissionsState(
      isLoading: isLoading ?? this.isLoading,
      permissions: permissions ?? this.permissions,
      error: error != null ? error() : this.error,
    );
  }
}

/// Session-isolated Notifier managing platform permissions.
///
/// Complies with fail-closed requirements:
/// - Defaults to `isPlatformAdmin = false` while restoring, unauthenticated, loading, or on error.
/// - Automatically refetches when a new authenticated session is established.
/// - Resets immediately to unprivileged state on sign-out or session switch.
/// - Epoch and sequence guarded to discard stale/delayed out-of-order responses.
class UserPermissionsNotifier extends Notifier<UserPermissionsState> {
  int _seq = 0;
  Future<void>? _inFlight;

  @override
  UserPermissionsState build() {
    final session = ref.watch(sessionProvider);

    // If unauthenticated or restoring, fail closed immediately with empty unprivileged state
    if (!session.isAuthenticated) {
      return const UserPermissionsState();
    }

    // Schedule microtask to fetch permissions for authenticated session
    Future.microtask(() {
      if (ref.mounted) {
        loadPermissions();
      }
    });
    return const UserPermissionsState(isLoading: true);
  }

  Future<void> loadPermissions() {
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
      final repo = ref.read(permissionsRepositoryProvider);
      final perms = await repo.getMyPermissions();

      // Epoch & sequence fencing:
      if (!ref.mounted) return;
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      state = UserPermissionsState(
        isLoading: false,
        permissions: perms,
        error: null,
      );
    } catch (e) {
      // Epoch & sequence fencing:
      if (!ref.mounted) return;
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      // Fail-closed on any error (503, 401, timeout, network error):
      state = UserPermissionsState(
        isLoading: false,
        permissions: UserPermissions.unprivileged,
        error: e,
      );
    }
  }

  /// Invalidates and resets cached permissions to unprivileged fail-closed state
  /// (e.g. when an admin API call receives 403 Forbidden).
  void invalidateAdminPermissions() {
    state = const UserPermissionsState(
      isLoading: false,
      permissions: UserPermissions.unprivileged,
    );
  }
}

final userPermissionsProvider =
    NotifierProvider<UserPermissionsNotifier, UserPermissionsState>(
      UserPermissionsNotifier.new,
    );

/// Convenient typed boolean provider for Platform Admin status.
///
/// Always fail-closed: returns `false` when loading, error, or unauthenticated.
final isPlatformAdminProvider = Provider<bool>((ref) {
  final state = ref.watch(userPermissionsProvider);
  return state.isPlatformAdmin;
});
