import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/session.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// The persistent shell.
///
/// Desktop gets a sidebar; mobile gets a bottom bar and a drawer.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final mobile = KiteBreak.isMobile(context);

    // If session is restoring, present a stable loading shell barrier (no placeholder leakage)
    if (session.isRestoring) {
      return Scaffold(
        backgroundColor: c.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.primary,
                ),
              ),
              const SizedBox(height: KiteSpace.md),
              Text(
                'Đang kiểm tra phiên làm việc...',
                style: t.muted.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      drawer: mobile ? Drawer(child: _SidebarBody(location: location)) : null,
      bottomNavigationBar: mobile ? _BottomBar(location: location) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!mobile)
              SizedBox(
                width: 248,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.card,
                    border: BorderDirectional(end: BorderSide(color: c.border)),
                  ),
                  child: _SidebarBody(location: location),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(location: location, mobile: mobile),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarBody extends StatelessWidget {
  const _SidebarBody({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KiteSpace.xl,
            KiteSpace.xl,
            KiteSpace.xl,
            KiteSpace.lg,
          ),
          child: Row(
            children: [
              Icon(Icons.change_history, size: 20, color: c.primary),
              const SizedBox(width: KiteSpace.sm),
              Text('Kite', style: t.h4),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: KiteSpace.md),
            children: [
              for (final group in kNavGroups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KiteSpace.md,
                    KiteSpace.sm,
                    KiteSpace.md,
                    KiteSpace.xs,
                  ),
                  child: Text(
                    group.labelOf(L.of(context)).toUpperCase(),
                    style: t.muted.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final item in group.items)
                  if (item.inSidebar)
                    _NavTile(item: item, active: location == item.path),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        const _UserTile(),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.active});
  final NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? c.accent : Colors.transparent,
        borderRadius: KiteRadius.allSm,
        child: InkWell(
          borderRadius: KiteRadius.allSm,
          onTap: () => context.go(item.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KiteSpace.md,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: active ? c.foreground : c.mutedForeground,
                ),
                const SizedBox(width: KiteSpace.md),
                Text(
                  item.labelOf(L.of(context)),
                  style: t.small.copyWith(
                    color: active ? c.foreground : c.mutedForeground,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    if (user == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(KiteSpace.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.muted, shape: BoxShape.circle),
            child: Text(user.initials, style: t.small.copyWith(fontSize: 12)),
          ),
          const SizedBox(width: KiteSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: t.small,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.role != null)
                  Text(
                    user.role!,
                    style: t.muted.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    user.email,
                    style: t.muted.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: L.of(context).actionSignOut,
            iconSize: 18,
            color: c.mutedForeground,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.location, required this.mobile});
  final String location;
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);
    final matches = [
      for (final n in kNav)
        if (location == n.path ||
            (n.path != '/' && location.startsWith('${n.path}/')))
          n,
    ]..sort((a, b) => b.path.length.compareTo(a.path.length));
    final title = matches.isEmpty ? 'Kite' : matches.first.labelOf(l);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: KiteSpace.xl),
      decoration: BoxDecoration(
        color: c.card,
        border: BorderDirectional(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          if (mobile)
            IconButton(
              icon: const Icon(Icons.menu),
              color: c.mutedForeground,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          Text(title, style: t.large),
          const Spacer(),
          KiteTooltip(
            message: isDark ? l.lightMode : l.darkMode,
            child: IconButton(
              iconSize: 18,
              color: c.mutedForeground,
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              ),
              onPressed: () =>
                  ref.read(themeProvider.notifier).toggleBrightness(context),
            ),
          ),
          const SizedBox(width: KiteSpace.sm),
          const _AccountMenu(),
        ],
      ),
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName = user?.name ?? 'Người dùng';

    return KiteMenu(
      width: 248,
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KiteSpace.sm),
        child: Row(
          children: [
            KiteAvatar(name: displayName, size: 34),
            const SizedBox(width: KiteSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: t.small.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    user?.email ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: t.muted.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      items: [
        KiteMenuItem(
          label: 'Giấy phép bản quyền',
          icon: Icons.description_outlined,
          onPressed: () => context.go(R.license),
        ),
        KiteMenuItem(
          label: isDark ? l.lightMode : l.darkMode,
          icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          onPressed: () =>
              ref.read(themeProvider.notifier).toggleBrightness(context),
        ),
        const KiteMenuItem.separator(),
        KiteMenuItem(
          label: l.actionSignOut,
          icon: Icons.logout,
          destructive: true,
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
        ),
      ],
      trigger: (context, open) => InkWell(
        borderRadius: KiteRadius.allSm,
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KiteAvatar(name: displayName, size: 28),
              const SizedBox(width: KiteSpace.xs),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: c.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final items = kNav;
    var index = items.indexWhere((n) => n.path == location);
    if (index < 0) index = 0;

    return NavigationBar(
      backgroundColor: c.card,
      selectedIndex: index,
      onDestinationSelected: (i) => context.go(items[i].path),
      destinations: [
        for (final n in items)
          NavigationDestination(icon: Icon(n.icon, size: 20), label: n.label),
      ],
    );
  }
}
