import 'package:flutter/material.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../shared/widgets/app_brand.dart';

class ConfigurationErrorScreen extends StatelessWidget {
  const ConfigurationErrorScreen({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);

    return ColoredBox(
      color: c.background,
      child: SelectionArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KiteSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppBrand(
                    logoSize: 24,
                    mainAxisAlignment: MainAxisAlignment.center,
                  ),
                  const SizedBox(height: KiteSpace.xxl),
                  KiteCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.settings_suggest_outlined,
                              size: 28,
                              color: c.destructive,
                            ),
                            const SizedBox(width: KiteSpace.md),
                            Expanded(
                              child: Text(
                                'Cấu hình ứng dụng chưa sẵn sàng',
                                style: t.h4.copyWith(color: c.destructive),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: KiteSpace.md),
                        Text(
                          'Ứng dụng phát hiện cấu hình môi trường chưa hợp lệ hoặc thiếu thông số khởi chạy cần thiết:',
                          style: t.small,
                        ),
                        const SizedBox(height: KiteSpace.md),
                        Container(
                          padding: const EdgeInsets.all(KiteSpace.md),
                          decoration: BoxDecoration(
                            color: c.muted,
                            borderRadius: KiteRadius.allSm,
                            border: Border.all(color: c.border),
                          ),
                          child: Text(
                            message,
                            style: t.small.copyWith(
                              fontFamily: 'monospace',
                              color: c.foreground,
                            ),
                          ),
                        ),
                        const SizedBox(height: KiteSpace.md),
                        Text(
                          'Vui lòng sao chép tệp .env.example sang .env và cung cấp các giá trị cấu hình hợp lệ trước khi khởi chạy.',
                          style: t.muted.copyWith(fontSize: 12),
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(height: KiteSpace.lg),
                          KiteButton(
                            onPressed: onRetry!,
                            expands: true,
                            child: const Text('Thử tải lại cấu hình'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
