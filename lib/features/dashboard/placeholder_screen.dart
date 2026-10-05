import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/session.dart';

class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final c = KiteColors.of(context);
    final t = KiteText.of(context);

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KiteSpace.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header banner
                Container(
                  padding: const EdgeInsets.all(KiteSpace.xl),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: KiteRadius.allMd,
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: KiteSpace.sm,
                        runSpacing: KiteSpace.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const KiteBadge(
                            'Giai đoạn 1 · Khung giao diện',
                            tone: KiteTone.success,
                          ),
                          const KiteBadge(
                            'Xác thực hoạt động (Stage 2 Auth Active)',
                            tone: KiteTone.info,
                          ),
                          if (user?.role != null)
                            KiteBadge(
                              'Vai trò: ${user!.role!}',
                              tone: KiteTone.warning,
                            ),
                        ],
                      ),
                      const SizedBox(height: KiteSpace.md),
                      Text('Hệ thống Quản lý IoT & Digital Twin', style: t.h3),
                      const SizedBox(height: KiteSpace.xs),
                      Text(
                        'Chào mừng ${user?.name ?? "Người dùng"} (${user?.email ?? ""}) đã đăng nhập vào hệ thống.',
                        style: t.muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KiteSpace.xl),
      
                // Status card
                KiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trạng thái Hệ thống Client', style: t.h4),
                      const SizedBox(height: KiteSpace.sm),
                      Text(
                        'Bạn đã đăng nhập bằng Supabase Auth. '
                        'Trang này là Placeholder; các tính năng Gateway và Sensor chưa được tích hợp.',
                        style: t.small,
                      ),
                      const SizedBox(height: KiteSpace.lg),
                      Container(
                        padding: const EdgeInsets.all(KiteSpace.md),
                        decoration: BoxDecoration(
                          color: c.muted,
                          borderRadius: KiteRadius.allSm,
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: c.primary,
                                ),
                                const SizedBox(width: KiteSpace.sm),
                                Expanded(
                                  child: Text(
                                    'Phiên đăng nhập Supabase Auth đang hoạt động',
                                    style: t.small.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: KiteSpace.xs),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.hourglass_empty,
                                  size: 16,
                                  color: c.mutedForeground,
                                ),
                                const SizedBox(width: KiteSpace.sm),
                                Expanded(
                                  child: Text(
                                    'Danh mục Gateway và Sensor: Chưa tích hợp',
                                    style: t.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
