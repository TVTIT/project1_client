import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'session.dart';

/// Exception thrown when authentication operations fail.
class AuthException implements Exception {
  const AuthException(this.message, {this.code, this.cause});
  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => 'AuthException: $message (${code ?? "unknown"})';
}

/// Abstract contract for authentication repository.
abstract class AuthRepository {
  Stream<SessionUser?> get authStateChanges;
  Future<SessionUser?> restoreSession();
  Future<String?> getAccessToken({bool forceRefresh = false});
  Future<String?> refreshSession();
  Future<SessionUser> signInWithPassword({
    required String email,
    required String password,
  });
  Future<void> signOut();
  void dispose();
}

/// Concrete implementation of [AuthRepository] using `supabase_flutter`.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({supa.SupabaseClient? client})
    : _client = client ?? supa.Supabase.instance.client {
    _identity = _client.auth.currentUser?.id;
    _initListener();
  }

  final supa.SupabaseClient _client;
  final _controller = StreamController<SessionUser?>.broadcast();
  StreamSubscription<supa.AuthState>? _sub;

  // Monotonic generation counter to invalidate pending asynchronous signin/restore operations
  int _generation = 0;
  int get generation => _generation;

  // Single-flight refresh mutex/completer
  Completer<String?>? _refreshCompleter;
  Future<void> _tail = Future<void>.value();
  int _pending = 0;
  bool _disposed = false;
  String? _identity;
  bool _refreshing = false;
  String? _refreshIdentity;
  SessionUser? _lastPublished;
  void _emit(SessionUser? user) {
    if (_disposed || user == _lastPublished) return;
    _lastPublished = user;
    _controller.add(user);
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    _pending++;
    final result = _tail.then((_) => action());
    _tail = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => _pending--);
    return result;
  }

  void _publish(supa.Session? session) {
    if (_disposed) return;
    final id = session?.user.id;
    if (id != _identity) {
      _generation++;
      _identity = id;
    }
    _emit(session == null ? null : _mapUser(session.user));
  }

  bool _valid(int gen, String? id) =>
      !_disposed &&
      _pending == 0 &&
      gen == _generation &&
      _client.auth.currentSession?.user.id == id;

  Future<void> _clearLocal() async {
    await _client.auth.signOut(scope: supa.SignOutScope.local);
  }

  void _initListener() {
    _sub = _client.auth.onAuthStateChange.listen(
      (data) {
        if (_disposed) return;
        if (_pending > 0) {
          if (_refreshing && data.session?.user.id != _refreshIdentity) {
            _generation++;
          }
          return;
        }
        if (data.session?.accessToken !=
            _client.auth.currentSession?.accessToken) {
          return;
        }
        _publish(data.session);
      },
      onError: (Object _) {
        // Safe generic logging without logging raw credentials or tokens
        debugPrint(
          'SupabaseAuthRepository: authentication event stream encountered a transient error.',
        );
      },
    );
  }

  @override
  Stream<SessionUser?> get authStateChanges => _controller.stream;

  @override
  Future<SessionUser?> restoreSession() async {
    if (_disposed || _pending > 0) return null;
    final currentGen = _generation;
    try {
      final session = _client.auth.currentSession;
      if (session != null && _generation == currentGen) {
        return _mapUser(session.user);
      }
      return null;
    } catch (_) {
      if (!_disposed && _client.auth.currentSession == null) _publish(null);
      return null;
    }
  }

  @override
  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    if (!_disposed && _refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    if (_disposed || _pending > 0) return null;
    final currentGen = _generation;
    final currentSession = _client.auth.currentSession;
    if (currentSession == null) return null;

    final expiresAt = currentSession.expiresAt;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final isExpiringSoon = expiresAt != null && (expiresAt - now < 30);

    if (!forceRefresh &&
        !isExpiringSoon &&
        currentSession.accessToken.isNotEmpty) {
      return currentSession.accessToken;
    }

    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = _refreshCompleter = Completer<String?>();
    final identity = currentSession.user.id;
    try {
      // Serialize SDK refresh writes with login/logout as well.
      await _serialize(() async {
        if (_disposed || _generation != currentGen) return;
        _refreshing = true;
        _refreshIdentity = identity;
        try {
          await _client.auth.refreshSession();
          if (_disposed || _generation != currentGen) await _clearLocal();
        } finally {
          _refreshing = false;
        }
      });
      await _tail;
      final newToken = _valid(currentGen, identity)
          ? _client.auth.currentSession?.accessToken
          : null;
      completer.complete(newToken);
      return newToken;
    } catch (error) {
      // Refresh failed; check if current session is still valid or invalid
      if (error is supa.AuthException &&
          {
            'invalid_grant',
            'refresh_token_not_found',
            'refresh_token_already_used',
          }.contains(error.code) &&
          !_disposed &&
          _generation == currentGen) {
        _generation++;
        _identity = null;
        _emit(null);
        await _serialize(_clearLocal);
      }
      if (!_disposed && _client.auth.currentSession == null) _publish(null);
      if (_generation != currentGen) {
        completer.complete(null);
        return null;
      }
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  @override
  Future<String?> refreshSession() async {
    final token = await getAccessToken(forceRefresh: true);
    if (token == null && _client.auth.currentSession == null) {
      throw const AuthException(
        'Phiên làm việc đã hết hạn hoặc không hợp lệ.',
        code: 'invalid_grant',
      );
    }
    return token;
  }

  @override
  Future<SessionUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final opGen = ++_generation;
    return _serialize(() async {
      try {
        if (_disposed || _generation != opGen) {
          throw const AuthException(
            'Yêu cầu đăng nhập đã bị hủy do phiên làm việc đã thay đổi.',
          );
        }
        final res = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );

        // If user signed out or generation advanced while network call was inflight
        if (_disposed || _generation != opGen) {
          // Invalidate stale SDK session immediately to prevent stale persistence
          try {
            await _clearLocal();
          } catch (_) {}
          throw const AuthException(
            'Yêu cầu đăng nhập đã bị hủy do phiên làm việc đã thay đổi.',
          );
        }

        final user = res.user;
        final session = res.session;
        if (user == null || session == null) {
          throw const AuthException(
            'Đăng nhập không thành công: Không nhận được phiên xác thực.',
          );
        }

        _identity = user.id;
        _emit(_mapUser(user));
        return _mapUser(user);
      } on supa.AuthException catch (e) {
        if (_generation != opGen) {
          throw const AuthException('Yêu cầu đăng nhập đã bị hủy.');
        }
        throw AuthException(
          _mapSupabaseErrorMessage(e),
          code: e.statusCode?.toString() ?? e.code,
          cause: e,
        );
      } catch (e) {
        if (e is AuthException) rethrow;
        throw const AuthException(
          'Không thể kết nối đến máy chủ xác thực. Vui lòng kiểm tra mạng.',
        );
      }
    });
  }

  @override
  Future<void> signOut() async {
    // Invalidate any inflight signin operations immediately
    _generation++;
    _identity = null;
    _emit(null);
    await _serialize(() async {
      await _clearLocal();
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _sub?.cancel();
    _controller.close();
  }

  static SessionUser _mapUser(supa.User user) {
    final meta = user.userMetadata ?? {};
    String name = '';
    if (meta['full_name'] != null &&
        meta['full_name'].toString().trim().isNotEmpty) {
      name = meta['full_name'].toString().trim();
    } else if (meta['name'] != null &&
        meta['name'].toString().trim().isNotEmpty) {
      name = meta['name'].toString().trim();
    } else {
      final email = user.email ?? 'Người dùng';
      name = email.split('@').first;
    }

    return SessionUser(userId: user.id, name: name, email: user.email ?? '');
  }

  static String _mapSupabaseErrorMessage(supa.AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        e.code == 'invalid_grant' ||
        e.statusCode == '400') {
      return 'Email hoặc mật khẩu không chính xác. Vui lòng kiểm tra lại.';
    }
    if (msg.contains('signup_disabled') || e.code == 'signup_disabled') {
      return 'Hệ thống không mở tính năng tự đăng ký. Vui lòng liên hệ Quản trị viên để được cấp tài khoản.';
    }
    if (msg.contains('rate limit') ||
        msg.contains('too many requests') ||
        e.statusCode == '429') {
      return 'Bạn đã thử đăng nhập quá nhiều lần. Vui lòng chờ ít phút trước khi thử lại.';
    }
    if (msg.contains('network') ||
        msg.contains('failed to fetch') ||
        msg.contains('connection')) {
      return 'Không thể kết nối đến máy chủ xác thực. Vui lòng kiểm tra kết nối mạng.';
    }
    return 'Đăng nhập không thành công. Vui lòng thử lại sau.';
  }
}
