import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_screens.dart';
import '../../features/dashboard/placeholder_screen.dart';
import '../../features/system/error_screen.dart';
import '../../features/system/license_screen.dart';
import '../../shared/layout/app_shell.dart';
import '../auth/session.dart';
import 'routes.dart';

class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: R.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final matched = state.matchedLocation;
      final onAuth = R.isAuthRoute(matched);
      final onLicense = matched == R.license;

      // License page is accessible publicly from both login and dashboard.
      if (onLicense) return null;

      // When session is still restoring, keep current location/URL without redirect loop.
      // Protected shell will display a non-flickering loading barrier.
      if (session.isRestoring) {
        return null;
      }

      final signedIn = session.isAuthenticated;

      if (!signedIn && !onAuth) return R.signIn;
      if (signedIn && onAuth) return R.dashboard;
      return null;
    },
    errorBuilder: (context, state) => NotFoundScreen(location: state.uri.path),
    routes: [
      GoRoute(path: R.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: R.license, builder: (_, _) => const LicenseScreen()),
      GoRoute(
        path: R.serverError,
        builder: (_, _) => const ServerErrorScreen(),
      ),

      // Protected shell: AppShell with sidebar and top bar survives navigation.
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: R.dashboard,
            builder: (_, _) => const PlaceholderScreen(),
          ),
        ],
      ),
    ],
  );
});
