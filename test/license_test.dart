import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/features/system/license_screen.dart';
import 'package:kite_ui/shadcn.dart';

void main() {
  test('LICENSE file contains both Trần Vĩnh Trung and Colorlib notices', () {
    final file = File('LICENSE');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'LICENSE file must exist at root',
    );

    final content = file.readAsStringSync();
    expect(content, contains('Copyright (c) 2026 Trần Vĩnh Trung'));
    expect(content, contains('Copyright (c) 2026 Colorlib'));
    expect(content, contains('MIT License'));
  });

  testWidgets('LicenseScreen renders and displays copyright notices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: ShadApp(home: LicenseScreen())),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Giấy phép bản quyền · Open Source License'),
      findsOneWidget,
    );
    expect(find.text('MIT License Notices'), findsOneWidget);
    expect(find.text('Quay lại'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    expect(selectable.data, contains('Copyright (c) 2026 Trần Vĩnh Trung'));
    expect(selectable.data, contains('Copyright (c) 2026 Colorlib'));
  });
}
