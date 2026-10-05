import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Route paths in one place so the router, the sidebar and every `context.go`
/// call agree. Typed constants rather than string literals scattered around.
abstract final class R {
  static const signIn = '/sign-in';
  static const dashboard = '/';
  static const license = '/license';
  static const serverError = '/500';

  static bool isAuthRoute(String location) => location.startsWith(signIn);
}

@immutable
class NavItem {
  const NavItem(this.label, this.path, this.icon, {this.inSidebar = true});

  /// English/Vietnamese label. Also the fallback if a translation is missing.
  final String label;
  final String path;
  final IconData icon;

  /// Whether the sidebar lists this item.
  final bool inSidebar;

  /// Localised label.
  String labelOf(L l) => switch (path) {
    R.dashboard => l.navDashboard,
    _ => label,
  };
}

@immutable
class NavGroup {
  const NavGroup(this.label, this.items);
  final String label;
  final List<NavItem> items;

  String labelOf(L l) => switch (label) {
    'Overview' => l.navOverview,
    _ => label,
  };
}

const kNavGroups = <NavGroup>[
  NavGroup('Overview', [
    NavItem('Bảng điều khiển', R.dashboard, Icons.dashboard_outlined),
    NavItem('Giấy phép', R.license, Icons.description_outlined),
  ]),
];

/// Flattened, for resolving the page title and responsive mobile bar.
final kNav = [for (final g in kNavGroups) ...g.items];
