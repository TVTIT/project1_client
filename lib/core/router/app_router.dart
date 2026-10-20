import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_screen.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/dashboard/placeholder_screen.dart';
import '../../features/gateways/presentation/gateway_detail_screen.dart';
import '../../features/gateways/presentation/gateway_list_screen.dart';
import '../../features/gateways/presentation/gateway_provision_screen.dart';
import '../../features/system/error_screen.dart';
import '../../features/system/license_screen.dart';
import '../../features/users/presentation/user_list_screen.dart';
import '../../shared/layout/app_shell.dart';
import '../auth/permissions.dart';
import '../auth/session.dart';
import 'routes.dart';

class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
    ref.listen(userPermissionsProvider, (_, _) => notifyListeners());
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

      // Protected route: /gateways/provision is accessible only by confirmed Platform Admins.
      if (signedIn && matched == R.gatewayProvision) {
        final permState = ref.read(userPermissionsProvider);
        if (permState.isLoading) {
          // Do not redirect while checking permissions to preserve URL and avoid kicking admin on reload
          return null;
        }
        if (!permState.isPlatformAdmin) {
          return R.gateways;
        }
      }

      // Protected route: /admin/users is accessible only by confirmed Platform Admins.
      if (signedIn && matched == R.adminUsers) {
        final permState = ref.read(userPermissionsProvider);
        if (permState.isLoading) {
          // Do not redirect while checking permissions to preserve URL and avoid kicking admin on reload
          return null;
        }
        if (!permState.isPlatformAdmin) {
          return R.dashboard;
        }
      }

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
          GoRoute(
            path: R.gateways,
            builder: (_, _) => const GatewayListScreen(),
          ),
          GoRoute(
            path: R.gatewayProvision,
            builder: (_, _) => const GatewayProvisionScreen(),
          ),
          GoRoute(
            path: R.adminUsers,
            builder: (_, _) => const UserListScreen(),
          ),
          GoRoute(
            path: R.gatewayDetailPattern,
            builder: (_, state) => GatewayDetailScreen(
              gatewayId: state.pathParameters['gatewayId'] ?? '',
            ),
          ),
          GoRoute(path: R.account, builder: (_, _) => const AccountScreen()),
        ],
      ),
    ],
  );
});
