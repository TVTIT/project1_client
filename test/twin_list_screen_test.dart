import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/core/router/routes.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/presentation/twin_list_screen.dart';
import 'package:kite/features/digital_twin/providers/twin_list_provider.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';

import 'gateway_list_provider_test.dart';
import 'permissions_test.dart';
import 'session_test.dart';
import 'twin_list_page_test.dart' show twinRow;
import 'twin_list_provider_test.dart' show ListTwinRepository, twinResponse;

void main() {
  late FakeAuthRepository auth;
  late ListTwinRepository repo;
  late FakeGatewayRepository gateways;
  late FakePermissionsRepository permissions;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    repo = ListTwinRepository();
    gateways = FakeGatewayRepository();
    permissions = FakePermissionsRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        digitalTwinRepositoryProvider.overrideWithValue(repo),
        gatewayRepositoryProvider.overrideWithValue(gateways),
        permissionsRepositoryProvider.overrideWithValue(permissions),
        twinListEndpointProvider.overrideWithValue(
          Uri.parse('https://api.example/v1/digital-twins'),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    auth.dispose();
  });

  void viewport(WidgetTester tester, double width, double height) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> open(WidgetTester tester, {bool signedIn = true}) async {
    await container.read(sessionProvider.notifier).restoreSession();
    if (signedIn) {
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u1',
              name: 'Member',
              email: 'member@example.com',
            ),
          );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KiteApp()),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(R.digitalTwins);
    await tester.pumpAndSettle();
  }

  test('Twin route helper single-encodes raw URNs', () {
    expect(
      R.gatewayTwin('Gw-1'),
      '/digital-twins/urn%3Angsi-ld%3AGateway%3AGw-1',
    );
    expect(
      R.sensorTwin('gw', 'backend_service'),
      '/digital-twins/urn%3Angsi-ld%3ASensor%3Agw%3Abackend_service',
    );
  });

  testWidgets('anonymous Twin deep link redirects without any Twin fetch', (
    tester,
  ) async {
    viewport(tester, 1366, 768);
    await open(tester, signedIn: false);
    expect(find.byType(TwinListScreen), findsNothing);
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      R.signIn,
    );
    expect(repo.calls, isEmpty);
  });

  testWidgets(
    'admin without memberships sees authorized empty and no inventory bypass',
    (tester) async {
      viewport(tester, 1366, 768);
      permissions.resultToReturn = const UserPermissions(isPlatformAdmin: true);
      await open(tester);
      expect(find.byType(TwinListScreen), findsOneWidget);
      expect(
        find.text('Không có bản sao số được gán phù hợp với bộ lọc.'),
        findsOneWidget,
      );
      expect(gateways.adminGatewaysCallCount, 0);
      expect(gateways.callCount, 1);
      expect(repo.calls, hasLength(1));
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(1024, 768),
    const Size(1366, 768),
    const Size(1920, 1080),
  ]) {
    testWidgets(
      'Twin list renders at ${size.width} without overflow or row fetches',
      (tester) async {
        viewport(tester, size.width, size.height);
        repo.handler = (_) async =>
            twinResponse([twinRow('one'), twinRow('two')], next: 'next');
        await open(tester);
        expect(find.text('Temperature one'), findsOneWidget);
        expect(find.text('urn:ngsi-ld:Sensor:gw:one'), findsOneWidget);
        expect(repo.calls, hasLength(1));
        expect(tester.takeException(), isNull);
        final next = find.text('Tải trang tiếp theo');
        await tester.ensureVisible(next);
        repo.handler = (_) async => twinResponse([twinRow('three')]);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(repo.calls, hasLength(2));
        expect(find.text('Temperature three'), findsOneWidget);
        expect(find.text('Tải trang tiếp theo'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'type and assigned gateway dropdown reset cursor and request filters',
    (tester) async {
      viewport(tester, 1366, 768);
      gateways.items = const [
        GatewayItem(
          gatewayId: 'gw',
          name: 'Assigned',
          role: GatewayRole.viewer,
        ),
      ];
      await open(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sensor').last);
      await tester.pumpAndSettle();
      expect(repo.calls.last['type'].toString(), 'EntityType.sensor');
      expect(repo.calls.last['cursor'], isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assigned (gw)').last);
      await tester.pumpAndSettle();
      expect(repo.calls.last['gateway_id'], 'gw');
      expect(repo.calls.last['cursor'], isNull);
      expect(gateways.adminGatewaysCallCount, 0);
    },
  );

  testWidgets('clicking row navigates to twin detail', (tester) async {
    viewport(tester, 1366, 768);
    repo.handler = (_) async => twinResponse([twinRow('one'), twinRow('two')]);
    await open(tester);

    final router = container.read(routerProvider);

    // Tap on row cell
    await tester.tap(find.text('Temperature one'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      R.twinDetail('urn:ngsi-ld:Sensor:gw:one'),
    );
  });
}
