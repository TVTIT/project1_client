import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/l10n/locale_controller.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/core/router/routes.dart';
import 'package:kite/core/theme/app_theme.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/data/twin_detail.dart';

import 'c7_detail_http_test.dart' show detailFixture, gatewayUrn;
import 'c7_state_regression_test.dart';
import 'permissions_test.dart';
import 'session_test.dart';

class DetailRepository extends StateRepository {
  final details = <(String, String?)>[];
  Future<TwinDetailPage> Function(String, String?)? detailHandler;
  @override
  Future<TwinDetailPage> getTwinDetail(
    String entityId, {
    int relationshipLimit = 20,
    String? relationshipAfter,
  }) {
    details.add((entityId, relationshipAfter));
    return detailHandler?.call(entityId, relationshipAfter) ??
        Future.value(
          TwinDetailPage(
            TwinDetail.fromJson(detailFixture(sensor: entityId == sensorUrn)),
            null,
          ),
        );
  }
}

void main() {
  late ProviderContainer container;
  late FakeAuthRepository auth;
  late DetailRepository repo;
  setUp(() {
    auth = FakeAuthRepository();
    repo = DetailRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        digitalTwinRepositoryProvider.overrideWithValue(repo),
        permissionsRepositoryProvider.overrideWithValue(
          FakePermissionsRepository(),
        ),
      ],
    );
    container
        .read(sessionProvider.notifier)
        .setSession(
          const SessionUser(
            userId: 'u1',
            name: 'Member',
            email: 'member@example.com',
          ),
        );
  });
  tearDown(() {
    container.dispose();
    auth.dispose();
  });
  Future<void> open(
    WidgetTester tester,
    String urn, {
    double width = 1366,
    double height = 768,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(routerProvider).go(R.twinDetail(urn));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KiteApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'deep link normalized metadata first; state is lazy and exact JSONB renders',
    (tester) async {
      await open(tester, sensorUrn);
      expect(repo.details, [(sensorUrn, null)]);
      expect(repo.stateCalls, 0);
      expect(find.text('<script>plain text</script>'), findsOneWidget);
      await tester.tap(find.text('Trạng thái'));
      await tester.pumpAndSettle();
      expect(repo.stateCalls, 1);
      expect(find.textContaining('9223372036854775807'), findsWidgets);
      expect(find.textContaining('"small": 12'), findsOneWidget);
      expect(find.textContaining('Không có dữ liệu'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Thông tin'));
      await tester.pumpAndSettle();
      expect(
        repo.details,
        hasLength(2),
      ); // inactive data is disposed, never eagerly fetched
      expect(repo.stateCalls, 1);
    },
  );
  for (final width in [390.0, 1024.0, 1366.0, 1920.0]) {
    testWidgets('detail responsive $width vi/light and en/dark', (
      tester,
    ) async {
      await open(
        tester,
        gatewayUrn,
        width: width,
        height: width == 1920 ? 1080 : 768,
      );
      expect(repo.details, hasLength(1));
      expect(repo.stateCalls, 0);
      expect(tester.takeException(), isNull);
      container.read(localeProvider.notifier).set(KiteLocale.en);
      container.read(themeProvider.notifier).setMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(find.text('Information'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final urn in [
    'bad',
    'urn:ngsi-ld:Gateway:backend_service',
    'urn%3Angsi-ld%3AGateway%3Agw',
  ]) {
    testWidgets('invalid deep link $urn does not fetch', (tester) async {
      await open(tester, urn);
      expect(repo.details, isEmpty);
      expect(repo.stateCalls, 0);
      expect(
        find.text('Không tìm thấy thực thể hoặc không có quyền truy cập.'),
        findsOneWidget,
      );
      expect(
        container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .toString(),
        R.twinDetail(urn),
      );
    });
  }
  testWidgets('404 preserves URL, session and back-to-list', (tester) async {
    repo.detailHandler = (_, _) => Future.error(
      const ApiException(statusCode: 404, code: 'not_found', message: 'safe'),
    );
    await open(tester, gatewayUrn);
    expect(
      find.text('Không tìm thấy thực thể hoặc không có quyền truy cập.'),
      findsOneWidget,
    );
    expect(
      container
          .read(routerProvider)
          .routeInformationProvider
          .value
          .uri
          .toString(),
      R.twinDetail(gatewayUrn),
    );
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
    expect(find.text('Về danh sách bản sao số'), findsOneWidget);
  });
  testWidgets(
    'restoring keeps deep link without login flash and loads after restore',
    (tester) async {
      container
          .read(sessionProvider.notifier)
          .setStatusForTesting(AuthStatus.restoring);
      // Do not pumpAndSettle an intentional loading animation.
      container.read(routerProvider).go(R.twinDetail(sensorUrn));
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KiteApp()),
      );
      await tester.pump();
      expect(repo.details, isEmpty);
      expect(
        container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .toString(),
        R.twinDetail(sensorUrn),
      );
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u1',
              name: 'Member',
              email: 'member@example.com',
            ),
          );
      await tester.pumpAndSettle();
      expect(repo.details, hasLength(1));
    },
  );
  testWidgets('tab and resource switches fence late metadata success', (
    tester,
  ) async {
    final pending = Completer<TwinDetailPage>();
    repo.detailHandler = (id, _) => id == gatewayUrn
        ? pending.future
        : Future.value(
            TwinDetailPage(
              TwinDetail.fromJson(detailFixture(sensor: true)),
              null,
            ),
          );
    container.read(routerProvider).go(R.twinDetail(gatewayUrn));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KiteApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repo.details, hasLength(1));
    container.read(routerProvider).go(R.twinDetail(sensorUrn));
    await tester.pumpAndSettle();
    pending.complete(
      TwinDetailPage(TwinDetail.fromJson(detailFixture()), null),
    );
    await tester.pumpAndSettle();
    expect(repo.details.map((e) => e.$1), [gatewayUrn, sensorUrn]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('inactive state pane never displays late denied response', (
    tester,
  ) async {
    final pending = Completer<TwinStateResponse>();
    repo.stateHandler = () async => await pending.future;
    await open(tester, sensorUrn);
    await tester.tap(find.text('Trạng thái'));
    await tester.pump();
    await tester.pump();
    expect(repo.stateCalls, 1);
    await tester.tap(find.text('Thông tin'));
    await tester.pumpAndSettle();
    pending.completeError(
      const ApiException(statusCode: 404, code: 'not_found', message: 'safe'),
    );
    await tester.pumpAndSettle();
    expect(find.text('<script>plain text</script>'), findsOneWidget);
    expect(
      find.text('Không tìm thấy thực thể hoặc không có quyền truy cập.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
