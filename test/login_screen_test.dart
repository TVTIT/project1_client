import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite_ui/kite_ui.dart';

import 'session_test.dart';

void main() {
  late FakeAuthRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeAuthRepository();
  });

  tearDown(() {
    fakeRepo.dispose();
  });

  testWidgets(
    'license button has keyboard focus and Enter opens license across widths',
    (tester) async {
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      await container.read(sessionProvider.notifier).restoreSession();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KiteApp()),
      );
      for (final size in [
        const Size(1366, 768),
        const Size(1920, 1080),
        const Size(1024, 768),
        const Size(390, 844),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final button = find.widgetWithText(KiteButton, 'Giấy phép (License)');
      // Tab through actual controls, rather than manually invoking callback.
      for (var i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus;
        if (focus?.context != null &&
            find
                .ancestor(
                  of: find.byWidget(focus!.context!.widget),
                  matching: button,
                )
                .evaluate()
                .isNotEmpty) {
          break;
        }
      }
      final focus = FocusManager.instance.primaryFocus!;
      expect(
        find.ancestor(
          of: find.byWidget(focus.context!.widget),
          matching: button,
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.textContaining('Colorlib'), findsWidgets);
    },
  );

  testWidgets('SignInScreen validates empty inputs and displays error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);

    // Initial restore to unauthenticated so SignInScreen is active
    await container.read(sessionProvider.notifier).restoreSession();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KiteApp()),
    );
    await tester.pumpAndSettle();

    // Verify UI components exist
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Quản lý tài khoản tập trung'), findsOneWidget);

    // Click Sign In with empty fields
    await tester.tap(find.widgetWithText(KiteButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    // Error message shown
    expect(
      find.text('Vui lòng nhập đầy đủ email và mật khẩu.'),
      findsOneWidget,
    );
  });

  testWidgets('SignInScreen enters credentials and calls signInWithPassword', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).restoreSession();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KiteApp()),
    );
    await tester.pumpAndSettle();

    // Enter email and password into KiteInput widgets
    final inputs = find.byType(KiteInput);
    expect(inputs, findsNWidgets(2));

    await tester.enterText(inputs.at(0), 'operator@company.com');
    await tester.enterText(inputs.at(1), 'secretPass123');
    await tester.pumpAndSettle();

    // Tap sign in
    await tester.tap(find.widgetWithText(KiteButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    // Verify successful sign in in container state
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
    expect(container.read(sessionProvider).user?.email, 'operator@company.com');
  });

  testWidgets(
    'SignInScreen double Enter while loading triggers only one signIn call',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeRepo.signInDelayMs = 100;

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).restoreSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KiteApp()),
      );
      await tester.pumpAndSettle();

      final inputs = find.byType(KiteInput);
      await tester.enterText(inputs.at(0), 'operator@company.com');
      await tester.enterText(inputs.at(1), 'secretPass123');
      await tester.pump();

      // Submit via Enter on password field
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Second Enter immediately while first request is inflight
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Also tap button while loading
      await tester.tap(find.byType(KiteButton).first);
      await tester.pump();

      // Fast forward delay
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Only 1 call executed
      expect(fakeRepo.signInCallCount, 1);
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
    },
  );

  testWidgets('SignInScreen displays error message on invalid credentials', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    fakeRepo.throwOnSignIn = true;
    fakeRepo.signInErrorMessage =
        'Email hoặc mật khẩu không chính xác. Vui lòng kiểm tra lại.';

    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).restoreSession();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KiteApp()),
    );
    await tester.pumpAndSettle();

    final inputs = find.byType(KiteInput);
    expect(inputs, findsNWidgets(2));

    await tester.enterText(inputs.at(0), 'wrong@company.com');
    await tester.enterText(inputs.at(1), 'wrongpassword');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(KiteButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(
      find.text('Email hoặc mật khẩu không chính xác. Vui lòng kiểm tra lại.'),
      findsOneWidget,
    );
  });
}
