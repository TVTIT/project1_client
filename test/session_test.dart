import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/auth_repository.dart';
import 'package:kite/core/auth/session.dart';

class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<SessionUser?>.broadcast();
  SessionUser? _currentSession;
  final String _mockToken = 'mock_jwt_token';
  bool throwOnSignIn = false;
  bool throwInvalidOnRefresh = false;
  bool throwTransientOnRefresh = false;
  int refreshCallCount = 0;
  String? signInErrorMessage;
  int signInDelayMs = 0;
  int signInCallCount = 0;
  Completer<SessionUser?>? pendingRestore;
  Completer<SessionUser>? pendingSignIn;

  int _generation = 0;
  int get generation => _generation;

  @override
  Stream<SessionUser?> get authStateChanges => _controller.stream;

  @override
  Future<SessionUser?> restoreSession() async {
    if (pendingRestore != null) return pendingRestore!.future;
    return _currentSession;
  }

  @override
  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    return _currentSession != null ? _mockToken : null;
  }

  @override
  Future<String?> refreshSession() async {
    refreshCallCount++;
    if (throwInvalidOnRefresh) {
      _currentSession = null;
      _controller.add(null);
      throw const AuthException('invalid_grant', code: 'invalid_grant');
    }
    if (throwTransientOnRefresh) {
      throw Exception('Network error');
    }
    return getAccessToken(forceRefresh: true);
  }

  @override
  Future<SessionUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (pendingSignIn != null) return pendingSignIn!.future;
    signInCallCount++;
    final opGen = ++_generation;

    if (signInDelayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: signInDelayMs));
    }

    if (_generation != opGen) {
      throw const AuthException('Yêu cầu đăng nhập đã bị hủy.');
    }

    if (throwOnSignIn) {
      throw AuthException(
        signInErrorMessage ?? 'Email hoặc mật khẩu không chính xác.',
        code: 'invalid_grant',
      );
    }
    final user = SessionUser(
      userId: 'test-user-uuid',
      name: email.split('@').first,
      email: email,
    );
    _currentSession = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _generation++;
    _currentSession = null;
    _controller.add(null);
  }

  void emitAuthState(SessionUser? user) {
    _currentSession = user;
    _controller.add(user);
  }

  @override
  void dispose() {
    _generation++;
    _controller.close();
  }
}

void main() {
  late FakeAuthRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
  });

  tearDown(() {
    container.dispose();
    fakeRepo.dispose();
  });

  test('initial state is restoring, then restores to unauthenticated if no session', () async {
    final notifier = container.read(sessionProvider.notifier);
    expect(container.read(sessionProvider).isRestoring, isTrue);

    await notifier.restoreSession();

    expect(container.read(sessionProvider).isUnauthenticated, isTrue);
    expect(container.read(sessionProvider).user, isNull);
  });

  test('restores active session if present in repository', () async {
    const user = SessionUser(
      userId: 'user-001',
      name: 'Nguyen Van A',
      email: 'a@example.com',
    );
    fakeRepo.emitAuthState(user);

    final notifier = container.read(sessionProvider.notifier);
    await notifier.restoreSession();

    expect(container.read(sessionProvider).isAuthenticated, isTrue);
    expect(container.read(sessionProvider).user, equals(user));
  });

  test('signIn updates state to authenticated and sets user', () async {
    final notifier = container.read(sessionProvider.notifier);
    await notifier.signIn(
      email: 'operator@example.com',
      password: 'secretPassword',
    );

    expect(container.read(sessionProvider).isAuthenticated, isTrue);
    expect(container.read(sessionProvider).user?.email, 'operator@example.com');
  });

  test('signIn handles AuthException and rethrows', () async {
    fakeRepo.throwOnSignIn = true;
    fakeRepo.signInErrorMessage = 'Email hoặc mật khẩu không chính xác.';

    final notifier = container.read(sessionProvider.notifier);

    expect(
      () => notifier.signIn(email: 'wrong@example.com', password: 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('chính xác'),
        ),
      ),
    );

    expect(container.read(sessionProvider).isAuthenticated, isFalse);
  });

  test('signOut increments session epoch and clears state', () async {
    final notifier = container.read(sessionProvider.notifier);
    await notifier.signIn(email: 'operator@example.com', password: 'secret');
    expect(container.read(sessionProvider).isAuthenticated, isTrue);

    final initialEpoch = notifier.sessionEpoch;
    await notifier.signOut();

    expect(container.read(sessionProvider).isUnauthenticated, isTrue);
    expect(container.read(sessionProvider).user, isNull);
    expect(notifier.sessionEpoch, greaterThan(initialEpoch));
  });

  test('late signIn response after signOut is suppressed and does not overwrite unauthenticated state', () async {
    fakeRepo.signInDelayMs = 50;

    final notifier = container.read(sessionProvider.notifier);
    // Start login
    final loginFuture = notifier.signIn(
      email: 'delayed@example.com',
      password: 'pass',
    );

    // Immediately trigger signOut before login completes
    await notifier.signOut();
    expect(container.read(sessionProvider).isUnauthenticated, isTrue);

    // Wait for delayed login to complete or throw
    try {
      await loginFuture;
    } catch (_) {}

    // State must remain unauthenticated
    expect(container.read(sessionProvider).isUnauthenticated, isTrue);
    expect(container.read(sessionProvider).user, isNull);
  });

  test('external authStateChanges updates session controller state', () async {
    const user = SessionUser(
      userId: 'user-002',
      name: 'Supervisor',
      email: 'sup@example.com',
    );
    container.read(sessionProvider);

    fakeRepo.emitAuthState(user);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(sessionProvider).isAuthenticated, isTrue);
    expect(container.read(sessionProvider).user?.name, 'Supervisor');

    fakeRepo.emitAuthState(null);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(sessionProvider).isUnauthenticated, isTrue);
    expect(container.read(sessionProvider).user, isNull);
  });

  test('restore finishing after logout does not resurrect session', () async {
    fakeRepo.pendingRestore = Completer<SessionUser?>();
    final notifier = container.read(sessionProvider.notifier);
    final restore = notifier.restoreSession();
    await notifier.signOut();
    fakeRepo.pendingRestore!.complete(
      const SessionUser(userId: 'A', name: 'A', email: 'A@example.com'),
    );
    await restore;
    expect(container.read(sessionProvider).isUnauthenticated, true);
  });

  test(
    'restore and login completion after provider disposal cannot write state',
    () async {
      fakeRepo.pendingRestore = Completer<SessionUser?>();
      fakeRepo.pendingSignIn = Completer<SessionUser>();
      final notifier = container.read(sessionProvider.notifier);
      final restore = notifier.restoreSession();
      final login = notifier.signIn(
        email: 'A@example.com',
        password: 'synthetic',
      );
      container.dispose();
      const user = SessionUser(userId: 'A', name: 'A', email: 'A@example.com');
      fakeRepo.pendingRestore!.complete(user);
      fakeRepo.pendingSignIn!.complete(user);
      await restore;
      await login;
    },
  );

  test('external identity event invalidates pending restore result', () async {
    fakeRepo.pendingRestore = Completer<SessionUser?>();
    final notifier = container.read(sessionProvider.notifier);
    final restore = notifier.restoreSession();
    const b = SessionUser(userId: 'B', name: 'B', email: 'B@example.com');
    fakeRepo.emitAuthState(b);
    await Future<void>.delayed(Duration.zero);
    fakeRepo.pendingRestore!.complete(
      const SessionUser(userId: 'A', name: 'A', email: 'A@example.com'),
    );
    await restore;
    expect(container.read(sessionProvider).user, b);
  });
}
