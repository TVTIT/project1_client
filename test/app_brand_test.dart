import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/features/system/configuration_error_app.dart';
import 'package:kite/features/system/license_screen.dart';
import 'package:kite/l10n/app_localizations.dart';
import 'package:kite/shared/widgets/app_brand.dart';
import 'package:kite/shared/widgets/app_logo.dart';
import 'package:kite_ui/shadcn.dart';

import 'session_test.dart';

void main() {
  group('AppLogo unit & widget tests', () {
    test('assetPath points to sanslab_logo.png', () {
      expect(AppLogo.assetPath, 'assets/images/sanslab_logo.png');
    });

    testWidgets('renders Image.asset with default properties', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppLogo())),
      );
      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, 'assets/images/sanslab_logo.png');
      expect(imageWidget.fit, BoxFit.contain);
    });

    testWidgets('respects custom size, width, height, and fit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppLogo(size: 24),
                AppLogo(width: 40, height: 20, fit: BoxFit.cover),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(2));

      // First logo uses size for both width and height
      expect(images[0].width, 24);
      expect(images[0].height, 24);

      // Second logo uses explicit width, height, and fit
      expect(images[1].width, 40);
      expect(images[1].height, 20);
      expect(images[1].fit, BoxFit.cover);
    });

    testWidgets('semantics: excluded when semanticLabel is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppLogo())),
      );
      await tester.pumpAndSettle();

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.excludeFromSemantics, isTrue);
      expect(imageWidget.semanticLabel, isNull);
    });

    testWidgets('semantics: included when semanticLabel is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppLogo(semanticLabel: 'SANSLAB Brandmark')),
        ),
      );
      await tester.pumpAndSettle();

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.excludeFromSemantics, isFalse);
      expect(imageWidget.semanticLabel, 'SANSLAB Brandmark');
    });

    testWidgets('semantics: explicit excludeFromSemantics overrides label', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo(
              semanticLabel: 'Ignored Label',
              excludeFromSemantics: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.excludeFromSemantics, isTrue);
      expect(imageWidget.semanticLabel, isNull);
    });
  });

  group('AppBrand localization, asset & layout', () {
    testWidgets('renders AppLogo and appName from localization', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ShadApp(
          supportedLocales: L.supportedLocales,
          localizationsDelegates: L.localizationsDelegates,
          locale: Locale('vi'),
          home: Scaffold(body: AppBrand()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.text('SANSLAB IoT Server'), findsOneWidget);
    });

    for (final loc in ['en', 'vi', 'ja', 'ar', 'es', 'fr']) {
      test('lookupL for locale $loc returns SANSLAB IoT Server', () {
        expect(lookupL(Locale(loc)).appName, 'SANSLAB IoT Server');
      });
    }

    testWidgets('appName localized correctly across all supported locales', (
      tester,
    ) async {
      for (final loc in ['en', 'vi', 'ja', 'ar', 'es', 'fr']) {
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: L.supportedLocales,
            localizationsDelegates: L.localizationsDelegates,
            locale: Locale(loc),
            home: Builder(
              builder: (context) {
                return Scaffold(body: Text(L.of(context).appName));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('SANSLAB IoT Server'),
          findsOneWidget,
          reason: 'Failed for locale: $loc',
        );
      }
    });

    testWidgets('custom appName parameter overrides localization', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ShadApp(
          supportedLocales: L.supportedLocales,
          localizationsDelegates: L.localizationsDelegates,
          home: Scaffold(body: AppBrand(appName: 'Custom IoT Gateway')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom IoT Gateway'), findsOneWidget);
      expect(find.text('SANSLAB IoT Server'), findsNothing);
    });

    testWidgets('gracefully falls back when Localizations is not present', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ShadApp(
          // No localizationsDelegates for L provided
          home: Scaffold(body: AppBrand()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SANSLAB IoT Server'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'semantics: AppLogo is excluded so no duplicate brand announcement',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            const ShadApp(
              supportedLocales: L.supportedLocales,
              localizationsDelegates: L.localizationsDelegates,
              home: Scaffold(body: AppBrand()),
            ),
          );
          await tester.pumpAndSettle();

          final logo = tester.widget<AppLogo>(find.byType(AppLogo));
          expect(logo.excludeFromSemantics, isTrue);

          // Verify Image itself is excluded from semantics
          final image = tester.widget<Image>(find.byType(Image));
          expect(image.excludeFromSemantics, isTrue);
          expect(image.semanticLabel, isNull);

          // Semantics tree announces the brand name text
          final textSemantics = tester.getSemantics(
            find.text('SANSLAB IoT Server'),
          );
          expect(textSemantics.label, 'SANSLAB IoT Server');
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets('constrained narrow width uses Flexible with ellipsis', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ShadApp(
          home: Scaffold(body: SizedBox(width: 100, child: AppBrand())),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.overflow, TextOverflow.ellipsis);
      expect(find.byType(Flexible), findsOneWidget);
    });

    testWidgets(
      'unbounded horizontal layout avoids Flexible and does not crash',
      (tester) async {
        await tester.pumpWidget(
          const ShadApp(
            home: Scaffold(
              body: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AppBrand(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // LayoutBuilder correctly branches to unbounded path without Flexible
        expect(tester.takeException(), isNull);
        expect(find.byType(Flexible), findsNothing);
        expect(find.text('SANSLAB IoT Server'), findsOneWidget);
      },
    );

    testWidgets('supports wrap configuration: maxLines, overflow and styles', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ShadApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              child: AppBrand(
                maxLines: 2,
                overflow: TextOverflow.clip,
                spacing: 12.0,
                logoSize: 28.0,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.clip);

      final rowWidget = tester.widget<Row>(find.byType(Row));
      expect(rowWidget.mainAxisAlignment, MainAxisAlignment.center);
      expect(rowWidget.crossAxisAlignment, CrossAxisAlignment.center);

      final logoWidget = tester.widget<AppLogo>(find.byType(AppLogo));
      expect(logoWidget.size, 28.0);
    });
  });

  group('Responsive multi-breakpoint verification (390, 1024, 1366, 1920 px)', () {
    const testSizes = [
      Size(390, 844),
      Size(1024, 768),
      Size(1366, 768),
      Size(1920, 1080),
    ];

    late FakeAuthRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeAuthRepository();
    });

    tearDown(() {
      fakeRepo.dispose();
    });

    for (final size in testSizes) {
      testWidgets(
        'Login screen with AppBrand at ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final container = ProviderContainer(
            overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
          );
          addTearDown(container.dispose);

          await container.read(sessionProvider.notifier).restoreSession();

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const KiteApp(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(AppBrand), findsOneWidget);
          expect(find.text('SANSLAB IoT Server'), findsOneWidget);
          expect(find.text('Đăng nhập'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Sidebar / Shell with AppBrand at ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final container = ProviderContainer(
            overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
          );
          addTearDown(container.dispose);

          container
              .read(sessionProvider.notifier)
              .setSession(
                const SessionUser(
                  userId: 'test-user',
                  name: 'Kiểm thử viên',
                  email: 'tester@sanslab.vn',
                ),
              );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const KiteApp(),
            ),
          );
          await tester.pumpAndSettle();

          // On tablet/desktop (>= 1024px), sidebar is visible with AppBrand
          if (size.width >= 1024) {
            expect(find.byType(AppBrand), findsOneWidget);
            expect(find.text('SANSLAB IoT Server'), findsWidgets);
          }
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'License screen with AppBrand at ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            const ProviderScope(
              child: ShadApp(
                supportedLocales: L.supportedLocales,
                localizationsDelegates: L.localizationsDelegates,
                home: LicenseScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(AppBrand), findsOneWidget);
          expect(find.text('SANSLAB IoT Server'), findsOneWidget);
          expect(
            find.text('Giấy phép bản quyền · Open Source License'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Configuration error screen with AppBrand at ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            const ConfigurationErrorApp(
              message: 'Kiểm thử lỗi cấu hình biến môi trường',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(AppBrand), findsOneWidget);
          expect(find.text('SANSLAB IoT Server'), findsOneWidget);
          expect(
            find.text('Kiểm thử lỗi cấu hình biến môi trường'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
