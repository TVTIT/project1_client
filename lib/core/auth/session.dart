import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

enum AuthStatus { restoring, authenticated, unauthenticated }

@immutable
class SessionUser {
  const SessionUser({
    required this.name,
    required this.email,
    this.userId = '',
    this.role,
  });

  /// Authoritative Supabase user UUID.
  final String userId;
  final String name;
  final String email;

  /// Gateway/Platform role from Go Backend (null until loaded from backend user_gateways).
  /// Auth layer must never infer or fabricate a default role such as 'viewer' or 'admin'.
  final String? role;

  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((p) => p.isEmpty ? '' : p[0].toUpperCase())
      .join();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionUser &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          name == other.name &&
          email == other.email &&
          role == other.role;

  @override
  int get hashCode => Object.hash(userId, name, email, role);
}

@immutable
class SessionState {
  const SessionState({required this.status, this.user, this.errorMessage});

  final AuthStatus status;
  final SessionUser? user;
  final String? errorMessage;

  bool get isRestoring => status == AuthStatus.restoring;
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;

  SessionState copyWith({
    AuthStatus? status,
    SessionUser? Function()? user,
    String? Function()? errorMessage,
  }) {
    return SessionState(
      status: status ?? this.status,
      user: user != null ? user() : this.user,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = SupabaseAuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

class SessionController extends Notifier<SessionState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  StreamSubscription<SessionUser?>? _authSub;

  int _sessionEpoch = 0;
  bool _alive = true;
  int get sessionEpoch => _sessionEpoch;

  @override
  SessionState build() {
    _listenToAuthChanges();

    ref.onDispose(() {
      _alive = false;
      _sessionEpoch++;
      _authSub?.cancel();
    });

    return const SessionState(status: AuthStatus.restoring);
  }

  void _listenToAuthChanges() {
    _authSub?.cancel();
    _authSub = _repo.authStateChanges.listen(
      (user) {
        if (!_alive) return;
        if (user != null) {
          // If different user or transitioning to authenticated
          if (state.user?.userId != user.userId || !state.isAuthenticated) {
            _sessionEpoch++;
          }
          state = SessionState(status: AuthStatus.authenticated, user: user);
        } else {
          _sessionEpoch++;
          state = const SessionState(status: AuthStatus.unauthenticated);
        }
      },
      onError: (Object _) {
        // Safe logging without credentials
        debugPrint('SessionController: auth state change stream error.');
      },
    );
  }

  bool get isSignedIn => state.isAuthenticated;
  SessionUser? get currentUser => state.user;

  Future<void> restoreSession() async {
    final expectedEpoch = _sessionEpoch;
    state = state.copyWith(status: AuthStatus.restoring);
    try {
      final user = await _repo.restoreSession();
      if (!_alive || _sessionEpoch != expectedEpoch) return;

      state = user != null
          ? SessionState(status: AuthStatus.authenticated, user: user)
          : const SessionState(status: AuthStatus.unauthenticated);
    } catch (_) {
      if (!_alive || _sessionEpoch != expectedEpoch) return;
      state = const SessionState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final expectedEpoch = ++_sessionEpoch;
    try {
      final user = await _repo.signInWithPassword(
        email: email,
        password: password,
      );

      if (!_alive || _sessionEpoch != expectedEpoch) {
        return;
      }

      state = SessionState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      if (!_alive || _sessionEpoch != expectedEpoch) {
        return;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    _sessionEpoch++;
    state = const SessionState(status: AuthStatus.unauthenticated);
    try {
      await _repo.signOut();
    } catch (_) {}
  }

  @visibleForTesting
  void setSession(SessionUser? user) {
    if (user != null) {
      state = SessionState(status: AuthStatus.authenticated, user: user);
    } else {
      _sessionEpoch++;
      state = const SessionState(status: AuthStatus.unauthenticated);
    }
  }

  @visibleForTesting
  void setStatusForTesting(AuthStatus status, {SessionUser? user}) {
    state = SessionState(status: status, user: user);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

final currentUserProvider = Provider<SessionUser?>((ref) {
  return ref.watch(sessionProvider).user;
});
