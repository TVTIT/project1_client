import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/core/router/routes.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite/features/gateways/data/mqtt_credential_dto.dart';
import 'package:kite/features/gateways/presentation/mqtt_credential_dialog.dart';
import 'package:kite_ui/kite_ui.dart';

import 'gateway_list_provider_test.dart';
import 'permissions_test.dart';
import 'session_test.dart';

void main() {
  late FakeAuthRepository fakeAuthRepo;
  late FakeGatewayRepository fakeGatewayRepo;
  late FakePermissionsRepository fakePermsRepo;

  const testGateway = GatewayItem(
    gatewayId: 'gw-mqtt-01',
    name: 'Trạm MQTT 01',
    description: 'Trạm kiểm thử MQTT',
    role: GatewayRole.owner,
  );

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeGatewayRepo = FakeGatewayRepository()..items = [testGateway];
    fakePermsRepo = FakePermissionsRepository();
  });

  tearDown(() {
    fakeAuthRepo.dispose();
  });

  Widget createTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const KiteApp(),
    );
  }

  group('Admin Button Visibility & Dialog Triggers', () {
    testWidgets(
      'non-admin user does NOT see MQTT button on GatewayDetailScreen or GatewayListScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: false,
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const user = SessionUser(
          userId: '11111111-1111-1111-1111-111111111111',
          name: 'Regular User',
          email: 'user@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        expect(find.text('Quản lý MQTT theo mã trạm'), findsNothing);

        container.read(routerProvider).go(R.gatewayDetail('gw-mqtt-01'));
        await tester.pumpAndSettle();

        expect(find.text('Thông tin xác thực MQTT'), findsNothing);
      },
    );

    testWidgets(
      'confirmed admin on GatewayDetailScreen sees button and opens dialog with fixed gatewayId',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-mqtt-01'));
        await tester.pumpAndSettle();

        final mqttBtn = find.text('Thông tin xác thực MQTT');
        expect(mqttBtn, findsOneWidget);

        await tester.tap(mqttBtn);
        await tester.pumpAndSettle();

        expect(find.byType(MqttCredentialDialog), findsOneWidget);
        expect(find.text('Mã trạm Gateway: gw-mqtt-01'), findsOneWidget);
      },
    );

    testWidgets(
      'confirmed admin on GatewayListScreen sees "Quản lý MQTT theo mã trạm" and opens dialog with editable input',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gateways);
        await tester.pumpAndSettle();

        final manageBtn = find.text('Quản lý MQTT theo mã trạm');
        expect(manageBtn, findsOneWidget);

        await tester.tap(manageBtn);
        await tester.pumpAndSettle();

        expect(find.byType(MqttCredentialDialog), findsOneWidget);
        expect(find.text('Nhập mã Gateway cần quản trị'), findsOneWidget);
      },
    );
  });

  group('Metadata, Status & 503 Disabled Fail-Closed Handling', () {
    testWidgets(
      'queries metadata and displays active status and metadata attributes',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.metadataResultToReturn = MqttCredentialMetadata(
          gatewayId: 'gw-mqtt-01',
          username: 'gw-mqtt-01',
          credentialVersion: 3,
          status: MqttCredentialStatus.active,
          lastOperationId: '11111111-2222-3333-4444-555555555555',
          operationStatus: MqttOperationStatus.succeeded,
          activatedAt: DateTime.parse('2026-10-01T12:00:00Z'),
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-mqtt-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thông tin xác thực MQTT'));
        await tester.pumpAndSettle();

        expect(fakeGatewayRepo.metadataCallCount, 1);
        expect(find.text('Hoạt động (Active)'), findsOneWidget);
        expect(find.text('v3'), findsOneWidget);
        expect(find.text('gw-mqtt-01'), findsWidgets);
        // Active status enables Rotate and Revoke buttons:
        expect(find.text('Xoay vòng mật khẩu'), findsOneWidget);
        expect(find.text('Thu hồi'), findsOneWidget);
      },
    );

    testWidgets(
      '503 credential_runtime_disabled displays explanatory fail-closed warning and disables mutations',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.shouldThrowMetadata = true;
        fakeGatewayRepo.metadataErrorToThrow = const ApiException(
          statusCode: 503,
          code: 'credential_runtime_disabled',
          message: 'credential request failed',
          requestId: 'req-disabled-503',
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-mqtt-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thông tin xác thực MQTT'));
        await tester.pumpAndSettle();

        // Real explanatory fail-closed warning must be visible:
        expect(
          find.text(
            'Tính năng Quản lý MQTT Credential hiện đang bị vô hiệu hóa trên máy chủ (MQTT_CREDENTIAL_API_ENABLED=false). Vui lòng liên hệ quản trị viên hạ tầng để kích hoạt.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Mã yêu cầu (Request ID): req-disabled-503'),
          findsOneWidget,
        );

        // Never fake success!
        expect(find.text('Hoạt động (Active)'), findsNothing);
      },
    );
  });

  group('Explicit Confirmations & Operational Warnings', () {
    testWidgets(
      'provision and rotate mutations require confirmation with broker cold restart warning',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.metadataResultToReturn = const MqttCredentialMetadata(
          gatewayId: 'gw-mqtt-01',
          username: 'gw-mqtt-01',
          credentialVersion: 1,
          status: MqttCredentialStatus
              .revoked, // not active -> provision is visible
          lastOperationId: '00000000-0000-0000-0000-000000000001',
          operationStatus: MqttOperationStatus.succeeded,
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-mqtt-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thông tin xác thực MQTT'));
        await tester.pumpAndSettle();

        final provBtn = find.widgetWithText(KiteButton, 'Cấp phát ban đầu');
        expect(provBtn, findsOneWidget);

        // Tap provision button
        await tester.tap(provBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog pops up with broker restart warning:
        expect(find.text('Cấp phát Thông tin Xác thực MQTT'), findsOneWidget);
        expect(
          find.textContaining('khởi động nguội broker (cold restart)'),
          findsOneWidget,
        );

        // Cancel confirmation -> mutation NOT called!
        final cancelConfirmBtn = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Hủy'),
        );
        await tester.tap(cancelConfirmBtn);
        await tester.pumpAndSettle();
        expect(fakeGatewayRepo.provisionMqttCallCount, 0);

        // Tap again and confirm
        await tester.tap(provBtn);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Xác nhận thực hiện'));
        await tester.pumpAndSettle();

        // Provision executed with secure UUID idempotency key:
        expect(fakeGatewayRepo.provisionMqttCallCount, 1);
        expect(fakeGatewayRepo.lastProvisionMqttIdempotencyKey, isNotNull);
      },
    );

    testWidgets(
      'revoke mutation requires confirmation with targeted socket disconnect warning',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.metadataResultToReturn = const MqttCredentialMetadata(
          gatewayId: 'gw-mqtt-01',
          username: 'gw-mqtt-01',
          credentialVersion: 1,
          status: MqttCredentialStatus.active, // active -> revoke is visible
          lastOperationId: '00000000-0000-0000-0000-000000000001',
          operationStatus: MqttOperationStatus.succeeded,
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-mqtt-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thông tin xác thực MQTT'));
        await tester.pumpAndSettle();

        final revokeBtn = find.widgetWithText(KiteButton, 'Thu hồi');
        await tester.tap(revokeBtn);
        await tester.pumpAndSettle();

        // Warning specifies targeted disconnect:
        expect(find.text('Thu hồi Thông tin Xác thực MQTT'), findsOneWidget);
        expect(
          find.textContaining(
            'ngắt kết nối socket ngay lập tức và vô hiệu hóa quyền truy cập broker của trạm Gateway này (thao tác cục bộ cho riêng trạm)',
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Xác nhận thực hiện'));
        await tester.pumpAndSettle();

        expect(fakeGatewayRepo.revokeMqttCallCount, 1);
        expect(
          find.text(
            'Thu hồi thông tin xác thực MQTT thành công (HTTP 200 OK).',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('Secret Lifecycle, Masking, Copy & Replay', () {
    testWidgets(
      'first provision delivers secret, displays masked password, eye reveals, and copy button copies',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        String? clipboardText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              clipboardText = (methodCall.arguments as Map)['text'] as String?;
              return null;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.metadataResultToReturn = const MqttCredentialMetadata(
          gatewayId: 'gw-mqtt-01',
          username: 'gw-mqtt-01',
          credentialVersion: 0,
          status: MqttCredentialStatus.revoked,
          lastOperationId: '00000000-0000-0000-0000-000000000001',
          operationStatus: MqttOperationStatus.succeeded,
        );
        fakeGatewayRepo.provisionMqttResultToReturn =
            const MqttCredentialSecretResult(
              metadata: MqttCredentialMetadata(
                gatewayId: 'gw-mqtt-01',
                username: 'gw-mqtt-01',
                credentialVersion: 1,
                status: MqttCredentialStatus.active,
                lastOperationId: '00000000-0000-0000-0000-000000000002',
                operationStatus: MqttOperationStatus.succeeded,
                activatedAt: null,
              ),
              operationId: '00000000-0000-0000-0000-000000000002',
              password: 'SUPER_SECRET_PLAINTEXT_PW',
              secretReturned: true,
            );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-mqtt-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thông tin xác thực MQTT'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(KiteButton, 'Cấp phát ban đầu'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Xác nhận thực hiện'));
        await tester.pumpAndSettle();

        // Secret card appears:
        expect(
          find.text('Mật khẩu MQTT mới (Chỉ hiển thị một lần duy nhất)'),
          findsOneWidget,
        );
        // Masked initially:
        expect(find.text('SUPER_SECRET_PLAINTEXT_PW'), findsNothing);
        expect(find.textContaining('••••••••'), findsOneWidget);

        // Tap eye icon to reveal:
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pumpAndSettle();
        expect(find.text('SUPER_SECRET_PLAINTEXT_PW'), findsOneWidget);

        // Tap copy icon:
        await tester.tap(find.byIcon(Icons.copy));
        await tester.pumpAndSettle();
        expect(clipboardText, equals('SUPER_SECRET_PLAINTEXT_PW'));
      },
    );

    testWidgets(
      'idempotent replay returns secretReturned == false and does not show secret card',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.metadataResultToReturn = const MqttCredentialMetadata(
          gatewayId: 'gw-mqtt-01',
          username: 'gw-mqtt-01',
          credentialVersion: 0,
          status: MqttCredentialStatus.revoked,
          lastOperationId: '00000000-0000-0000-0000-000000000001',
          operationStatus: MqttOperationStatus.succeeded,
        );
        // Replay outcome:
        fakeGatewayRepo.provisionMqttResultToReturn =
            const MqttCredentialMutationResult(
              metadata: MqttCredentialMetadata(
                gatewayId: 'gw-mqtt-01',
                username: 'gw-mqtt-01',
                credentialVersion: 1,
                status: MqttCredentialStatus.active,
                lastOperationId: '00000000-0000-0000-0000-000000000002',
                operationStatus: MqttOperationStatus.succeeded,
                activatedAt: null,
              ),
              operationId: '00000000-0000-0000-0000-000000000002',
              secretReturned: false, // NO secret on replay!
            );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-mqtt-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thông tin xác thực MQTT'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(KiteButton, 'Cấp phát ban đầu'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Xác nhận thực hiện'));
        await tester.pumpAndSettle();

        // Secret card must NOT be rendered on replay:
        expect(
          find.text('Mật khẩu MQTT mới (Chỉ hiển thị một lần duy nhất)'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'permission revocation while dialog is open auto-dismisses dialog fail-closed and drops secret',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-mqtt-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thông tin xác thực MQTT'));
        await tester.pumpAndSettle();

        expect(find.byType(MqttCredentialDialog), findsOneWidget);

        // Admin permission revoked dynamically:
        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: false,
        );
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();
        await tester.pumpAndSettle();

        // Dialog is auto-dismissed:
        expect(find.byType(MqttCredentialDialog), findsNothing);
      },
    );
  });

  group('Timeout Handling & Approved Same-Key Retry', () {
    testWidgets(
      'unknown timeout displays error, allows metadata readback and approved same-key retry',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.metadataResultToReturn = const MqttCredentialMetadata(
          gatewayId: 'gw-mqtt-01',
          username: 'gw-mqtt-01',
          credentialVersion: 1,
          status: MqttCredentialStatus.active,
          lastOperationId: '00000000-0000-0000-0000-000000000001',
          operationStatus: MqttOperationStatus.succeeded,
        );
        // Timeout on rotate mutation:
        fakeGatewayRepo.shouldThrowRotateMqtt = true;
        fakeGatewayRepo.rotateMqttErrorToThrow = const ApiException(
          statusCode: 504,
          code: 'gateway_timeout',
          message: 'Timeout rotating credentials',
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: '99999999-9999-9999-9999-999999999999',
          name: 'Platform Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-mqtt-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thông tin xác thực MQTT'));
        await tester.pumpAndSettle();

        // Tap rotate
        await tester.tap(find.widgetWithText(KiteButton, 'Xoay vòng mật khẩu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận thực hiện'));
        await tester.pumpAndSettle();

        final firstAttemptKey = fakeGatewayRepo.lastRotateMqttIdempotencyKey;
        expect(firstAttemptKey, isNotNull);

        // Timeout occurred:
        expect(find.text('Timeout rotating credentials'), findsOneWidget);
        // Readback metadata button is available:
        final readbackBtn = find.text('Đọc metadata');
        expect(readbackBtn, findsOneWidget);
        // Approved same-key retry button is NOT visible yet before reconciliation:
        expect(find.text('Thử lại (Cùng Idempotency-Key)'), findsNothing);

        // Now read metadata to reconcile status:
        fakeGatewayRepo.shouldThrowRotateMqtt = false;
        await tester.tap(readbackBtn);
        await tester.pumpAndSettle();

        // After reconciliation, retry button is now enabled:
        final retrySameKeyBtn = find.text('Thử lại (Cùng Idempotency-Key)');
        expect(retrySameKeyBtn, findsOneWidget);

        await tester.tap(retrySameKeyBtn);
        await tester.pumpAndSettle();

        // Shows confirmation with the approved key:
        expect(find.textContaining(firstAttemptKey!), findsOneWidget);
        await tester.tap(find.text('Xác nhận thực hiện'));
        await tester.pumpAndSettle();

        // Second attempt reused the EXACT SAME idempotency key:
        expect(fakeGatewayRepo.rotateMqttCallCount, 2);
        expect(
          fakeGatewayRepo.lastRotateMqttIdempotencyKey,
          equals(firstAttemptKey),
        );
      },
    );
  });

  group('Responsive Layout Widths for MqttCredentialDialog', () {
    for (final size in [
      const Size(390, 844),
      const Size(1024, 768),
      const Size(1366, 768),
      const Size(1920, 1080),
    ]) {
      testWidgets(
        'dialog renders cleanly without overflow at width ${size.width}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          fakePermsRepo.resultToReturn = const UserPermissions(
            isPlatformAdmin: true,
          );

          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
              permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            ],
          );
          addTearDown(container.dispose);

          const adminUser = SessionUser(
            userId: '99999999-9999-9999-9999-999999999999',
            name: 'Platform Admin',
            email: 'admin@example.com',
          );
          container.read(sessionProvider.notifier).setSession(adminUser);

          await tester.pumpWidget(createTestWidget(container));
          await tester.pumpAndSettle();

          container.read(routerProvider).go(R.gatewayDetail('gw-mqtt-01'));
          await tester.pumpAndSettle();

          final addBtn = find.byIcon(Icons.vpn_key_outlined);
          await tester.ensureVisible(addBtn);
          await tester.tap(addBtn);
          await tester.pumpAndSettle();

          expect(find.byType(MqttCredentialDialog), findsOneWidget);
        },
      );
    }
  });
}
