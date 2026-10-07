import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/session.dart';
import '../../core/router/routes.dart';
import '../../l10n/app_localizations.dart';

/// Screen presenting read-only account and session information.
///
/// Complies with strict Stage 2 boundaries:
/// - Displays identity fields exclusively from the active [SessionUser].
/// - Never exposes JWT tokens, refresh tokens, anon keys, or secrets.
/// - Never infers or fabricates platform_admin or gateway permissions from session metadata.
/// - Gateway and Platform Admin permissions are evaluated dynamically by Go Backend on each query.
/// - Accounts are centrally managed via Supabase Studio / Admin scripts.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  void _copyUserId(BuildContext context, String userId) {
    Clipboard.setData(ClipboardData(text: userId));
    KiteToast.show(
      context,
      title: L.of(context).accountCopiedId,
      tone: KiteTone.success,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);
    final isMobile = KiteBreak.isMobile(context);

    if (user == null) {
      return Center(
        child: Text('Không tìm thấy thông tin phiên làm việc.', style: t.muted),
      );
    }

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KiteSpace.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Navigation action bar
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: KiteSpace.md,
                  runSpacing: KiteSpace.sm,
                  children: [
                    KiteButton.outline(
                      onPressed: () => context.go(R.dashboard),
                      leading: const Icon(Icons.arrow_back, size: 16),
                      child: Text(
                        isMobile ? 'Quay lại' : l.accountBackToDashboard,
                      ),
                    ),
                    KiteButton.destructive(
                      onPressed: () =>
                          ref.read(sessionProvider.notifier).signOut(),
                      leading: const Icon(Icons.logout, size: 16),
                      child: Text(l.actionSignOut),
                    ),
                  ],
                ),
                const SizedBox(height: KiteSpace.lg),

                // Profile Header Card
                Container(
                  padding: const EdgeInsets.all(KiteSpace.xl),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: KiteRadius.allLg,
                    border: Border.all(color: c.border),
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KiteAvatar(name: user.name, size: 56),
                            const SizedBox(height: KiteSpace.md),
                            _buildProfileHeaderTexts(user, c, t, l),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            KiteAvatar(name: user.name, size: 64),
                            const SizedBox(width: KiteSpace.xl),
                            Expanded(
                              child: _buildProfileHeaderTexts(user, c, t, l),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: KiteSpace.xl),

                // Identity Information Card
                KiteCard(
                  title: l.accountIdentityTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldRow(
                        label: l.accountFullName,
                        value: user.name.isNotEmpty
                            ? user.name
                            : 'Chưa cập nhật',
                        c: c,
                        t: t,
                      ),
                      const SizedBox(height: KiteSpace.lg),
                      _buildFieldRow(
                        label: l.accountEmail,
                        value: user.email,
                        c: c,
                        t: t,
                      ),
                      const SizedBox(height: KiteSpace.lg),
                      _buildUserIdField(
                        context,
                        user.userId,
                        isMobile,
                        c,
                        t,
                        l,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KiteSpace.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderTexts(
    SessionUser user,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: KiteSpace.sm,
          runSpacing: KiteSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(user.name, style: t.h3),
            const KiteBadge('Đã xác thực', tone: KiteTone.success),
          ],
        ),
        const SizedBox(height: KiteSpace.xs),
        Text(user.email, style: t.muted),
      ],
    );
  }

  Widget _buildFieldRow({
    required String label,
    required String value,
    required KiteColors c,
    required KiteText t,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.muted.copyWith(fontSize: 13)),
        const SizedBox(height: KiteSpace.xs),
        Text(value, style: t.p.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildUserIdField(
    BuildContext context,
    String userId,
    bool isMobile,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.accountUserId, style: t.muted.copyWith(fontSize: 13)),
        const SizedBox(height: KiteSpace.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KiteSpace.md,
            vertical: KiteSpace.sm,
          ),
          decoration: BoxDecoration(
            color: c.muted,
            borderRadius: KiteRadius.allMd,
            border: Border.all(color: c.border),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userId.isNotEmpty ? userId : 'Chưa xác định',
                      style: t.small.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: KiteSpace.xs),
                    KiteButton.ghost(
                      onPressed: userId.isNotEmpty
                          ? () => _copyUserId(context, userId)
                          : null,
                      leading: const Icon(Icons.copy, size: 14),
                      child: Text(l.accountCopyId),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        userId.isNotEmpty ? userId : 'Chưa xác định',
                        style: t.small.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: KiteSpace.sm),
                    KiteButton.ghost(
                      onPressed: userId.isNotEmpty
                          ? () => _copyUserId(context, userId)
                          : null,
                      leading: const Icon(Icons.copy, size: 14),
                      child: Text(l.accountCopyId),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
