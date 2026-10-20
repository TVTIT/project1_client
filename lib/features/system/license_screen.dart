import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../core/auth/session.dart';
import '../../core/router/routes.dart';
import '../../shared/widgets/app_brand.dart';

const _kFallbackLicense = '''MIT License

Copyright (c) 2026 Trần Vĩnh Trung

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

MIT License

Copyright (c) 2026 Colorlib

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

class LicenseScreen extends ConsumerWidget {
  const LicenseScreen({super.key});

  Future<String> _loadLicense() async {
    try {
      final text = await rootBundle.loadString('LICENSE');
      if (text.trim().isNotEmpty) return text;
    } catch (_) {
      // Fallback below
    }
    return _kFallbackLicense;
  }

  void _handleBack(BuildContext context, WidgetRef ref) {
    if (context.canPop()) {
      context.pop();
    } else {
      final signedIn = ref.read(sessionProvider).isAuthenticated;
      context.go(signedIn ? R.dashboard : R.signIn);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KiteColors.of(context);
    final t = KiteText.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KiteSpace.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      KiteButton.outline(
                        onPressed: () => _handleBack(context, ref),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back, size: 16),
                            SizedBox(width: KiteSpace.xs),
                            Text('Quay lại'),
                          ],
                        ),
                      ),
                      const SizedBox(width: KiteSpace.sm),
                      const Expanded(
                        child: AppBrand(
                          logoSize: 18,
                          spacing: KiteSpace.xs,
                          mainAxisAlignment: MainAxisAlignment.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KiteSpace.xl),
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 28,
                        color: c.primary,
                      ),
                      const SizedBox(width: KiteSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Giấy phép bản quyền · Open Source License',
                              style: t.h3,
                            ),
                            const SizedBox(height: KiteSpace.xs),
                            Text(
                              'Thông tin bản quyền MIT của dự án và Kite Flutter Admin Dashboard.',
                              style: t.muted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KiteSpace.xl),
                  FutureBuilder<String>(
                    future: _loadLicense(),
                    builder: (context, snapshot) {
                      final licenseText = snapshot.data ?? _kFallbackLicense;
                      return KiteCard(
                        title: 'MIT License Notices',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(KiteSpace.md),
                              decoration: BoxDecoration(
                                color: c.muted,
                                borderRadius: KiteRadius.allSm,
                                border: Border.all(color: c.border),
                              ),
                              child: SelectableText(
                                licenseText,
                                style: t.small.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: c.foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: KiteSpace.xl),
                  Text(
                    'Dự án tuân thủ đầy đủ điều khoản giấy phép mã nguồn mở MIT của Colorlib và Trần Vĩnh Trung.',
                    style: t.muted.copyWith(fontSize: 12),
                    textAlign: TextAlign.center,
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
