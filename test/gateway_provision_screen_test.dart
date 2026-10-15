import 'package:flutter/material.dart';
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
import 'package:kite/features/gateways/presentation/gateway_detail_screen.dart';
import 'package:kite/features/gateways/presentation/gateway_list_screen.dart';
import 'package:kite/features/gateways/presentation/gateway_provision_screen.dart';
import 'package:kite_ui/kite_ui.dart';

import 'gateway_list_provider_test.dart';
import 'permissions_test.dart';
import 'session_test.dart';

void main() {
  late FakeAuthRepository fakeAuthRepo;
  late FakeGatewayRepository fakeGatewayRepo;
  late FakePermissionsRepository fakePermsRepo;

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeGatewayRepo = FakeGatewayRepository();
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

  group('Gateway Provisioning Route & Permission Protection', () {
    testWidgets(
      'non-admin user on /gateways does NOT see "Thêm Gateway mới" button',
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

        expect(find.text('Quản lý Gateway'), findsWidgets);
        // Non-admin must NOT see provision button
        expect(find.text('Thêm Gateway mới'), findsNothing);
      },
    );

    testWidgets(
      'confirmed admin user on /gateways sees "Thêm Gateway mới" button and clicking navigates to /gateways/provision',
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

        // Confirmed admin sees the button
        final addBtn = find.text('Thêm Gateway mới');
        expect(addBtn, findsOneWidget);

        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // Should now be on GatewayProvisionScreen
        expect(find.byType(GatewayProvisionScreen), findsOneWidget);
        expect(find.text('Khởi tạo Gateway'), findsWidgets);
      },
    );

    testWidgets(
      'non-admin attempting to access /gateways/provision is redirected to /gateways',
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
          userId: '22222222-2222-2222-2222-222222222222',
          name: 'Regular User',
          email: 'user@example.com',
        );
        container.read(sessionProvider.notifier).setSession(user);

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        // Try deep link to /gateways/provision
        container.read(routerProvider).go(R.gatewayProvision);
        await tester.pumpAndSettle();

        // Router redirect must block non-admin and redirect to /gateways
        expect(find.byType(GatewayProvisionScreen), findsNothing);
        expect(find.byType(GatewayListScreen), findsOneWidget);
      },
    );

    testWidgets(
      'static route priority: /gateways/provision resolves to GatewayProvisionScreen, NOT GatewayDetailScreen with id provision',
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

        container.read(routerProvider).go('/gateways/provision');
        await tester.pumpAndSettle();

        // Must be GatewayProvisionScreen, NOT GatewayDetailScreen
        expect(find.byType(GatewayProvisionScreen), findsOneWidget);
        expect(find.byType(GatewayDetailScreen), findsNothing);
      },
    );
  });

  group('New Gateway Form Scope & Read-Only Invariants', () {
    testWidgets(
      'form contains ONLY gateway_id, name, description, owner_user_id; NO inline sensors',
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

        container.read(routerProvider).go(R.gatewayProvision);
        await tester.pumpAndSettle();

        // Check fields:
        expect(find.text('Gateway ID'), findsOneWidget);
        expect(find.text('Tên trạm Gateway'), findsOneWidget);
        expect(find.text('Mô tả trạm (Không bắt buộc)'), findsOneWidget);
        expect(
          find.text('Mã người dùng sở hữu (owner_user_id)'),
          findsOneWidget,
        );

        // Verify NO sensor fields, inline sensors, or sensor dialogs:
        expect(find.text('Mã cảm biến (Sensor ID)'), findsNothing);
        expect(find.text('Tên cảm biến'), findsNothing);
        expect(find.text('Đơn vị đo'), findsNothing);
        expect(find.text('Thêm cảm biến'), findsNothing);
        expect(find.text('Danh sách Cảm biến'), findsNothing);
      },
    );
  });

  group('Form Input Validation', () {
    testWidgets(
      'rejects invalid or reserved gateway_id, empty name, name > 256 bytes, invalid UUID, nil UUID',
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

        container.read(routerProvider).go(R.gatewayProvision);
        await tester.pumpAndSettle();

        // Submit empty form
        final submitBtn = find.widgetWithText(KiteButton, 'Khởi tạo Gateway');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Validations trigger:
        expect(find.text('Vui lòng nhập mã Gateway.'), findsOneWidget);
        expect(find.text('Vui lòng nhập tên trạm Gateway.'), findsOneWidget);
        expect(
          find.text('Vui lòng nhập mã người dùng sở hữu (owner_user_id).'),
          findsOneWidget,
        );

        // Test reserved gateway ID: backend_service
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'backend_service',
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Mã "backend_service" là định danh hệ thống dành riêng.'),
          findsOneWidget,
        );

        // Test nil UUID
        await tester.enterText(find.byType(TextFormField).at(0), 'gw-valid-01');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Valid Gateway',
        );
        await tester.enterText(
          find.byType(TextFormField).at(3),
          '00000000-0000-0000-0000-000000000000',
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(find.text('Không được sử dụng nil UUID.'), findsOneWidget);

        // Test invalid non-UUID string
        await tester.enterText(
          find.byType(TextFormField).at(3),
          'not-a-valid-uuid',
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Mã người dùng phải là chuỗi định dạng UUID hợp lệ.'),
          findsOneWidget,
        );

        // Test name exceeding 256 bytes UTF-8
        final longName = 'A' * 257;
        await tester.enterText(find.byType(TextFormField).at(1), longName);
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Tên trạm Gateway không được vượt quá 256 bytes UTF-8.'),
          findsOneWidget,
        );
      },
    );
  });

  group('Provisioning Submission & Status Scenarios', () {
    testWidgets(
      '201 Created displays authoritative result card and does NOT blindly navigate to detail',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeGatewayRepo.provisionResultToReturn = ProvisionGatewayResult(
          isCreated: true,
          gatewayId: 'gw-new-001',
          name: 'Trạm Quan Trắc Mới',
          description: 'Mô tả trạm mới',
          ownerUserId: '123e4567-e89b-12d3-a456-426614174000',
          entityId: 'urn:ngsi-ld:Gateway:gw-new-001',
          createdAt: DateTime.parse('2026-10-08T00:00:00Z'),
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

        container.read(routerProvider).go(R.gatewayProvision);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 'gw-new-001');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Trạm Quan Trắc Mới',
        );
        await tester.enterText(
          find.byType(TextFormField).at(2),
          'Mô tả trạm mới',
        );
        await tester.enterText(
          find.byType(TextFormField).at(3),
          '123e4567-e89b-12d3-a456-426614174000',
        );

        final submitBtn = find.widgetWithText(KiteButton, 'Khởi tạo Gateway');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Verify repository was called
        expect(fakeGatewayRepo.provisionCallCount, 1);
        expect(fakeGatewayRepo.lastProvisionInput?.gatewayId, 'gw-new-001');

        // Crucially: Remains on GatewayProvisionScreen (does NOT navigate to detail)
        expect(find.byType(GatewayProvisionScreen), findsOneWidget);
        expect(find.byType(GatewayDetailScreen), findsNothing);

        // Authoritative result card rendered:
        expect(
          find.text('Khởi tạo Gateway thành công (HTTP 201 Created)'),
          findsOneWidget,
        );
        expect(find.text('gw-new-001'), findsWidgets);
        expect(find.text('Trạm Quan Trắc Mới'), findsWidgets);
        expect(find.text('Mô tả trạm mới'), findsOneWidget);
        expect(
          find.text('123e4567-e89b-12d3-a456-426614174000'),
          findsOneWidget,
        );
        expect(find.text('urn:ngsi-ld:Gateway:gw-new-001'), findsOneWidget);
        expect(
          find.text(
            'Lưu ý phân quyền: Quản trị viên nền tảng không tự động là thành viên danh mục trạm (user_gateways) trừ khi được phân quyền sở hữu. Trạm này có thể không xuất hiện trong danh mục cá nhân của bạn nếu bạn không phải là người sở hữu được gán.',
          ),
          findsOneWidget,
        );

        // Buttons to create another or back to list:
        expect(find.text('Khởi tạo thêm Gateway khác'), findsOneWidget);
        expect(find.text('Quay lại danh sách Gateway'), findsWidgets);
      },
    );

    testWidgets('200 OK replay displays idempotent replay banner', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.provisionResultToReturn = ProvisionGatewayResult(
        isCreated: false, // 200 OK replay
        gatewayId: 'gw-existing-001',
        name: 'Trạm Đã Tồn Tại',
        description: null,
        ownerUserId: '123e4567-e89b-12d3-a456-426614174000',
        entityId: 'urn:ngsi-ld:Gateway:gw-existing-001',
        createdAt: DateTime.parse('2026-09-01T00:00:00Z'),
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

      container.read(routerProvider).go(R.gatewayProvision);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'gw-existing-001',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Trạm Đã Tồn Tại',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        '123e4567-e89b-12d3-a456-426614174000',
      );

      final submitBtn = find.widgetWithText(KiteButton, 'Khởi tạo Gateway');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Displays idempotent replay banner
      expect(
        find.text(
          'Trạm Gateway đã tồn tại với thông tin trùng khớp (HTTP 200 OK - Lặp lại an toàn)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('409 Conflict displays representation conflict error message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.shouldThrowProvision = true;
      fakeGatewayRepo.provisionErrorToThrow = const ApiException(
        statusCode: 409,
        code: 'conflict',
        message: 'resource conflict',
        requestId: 'req-conflict-409',
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

      container.read(routerProvider).go(R.gatewayProvision);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'gw-conflict');
      await tester.enterText(find.byType(TextFormField).at(1), 'Conflict Name');
      await tester.enterText(
        find.byType(TextFormField).at(3),
        '123e4567-e89b-12d3-a456-426614174000',
      );

      final submitBtn = find.widgetWithText(KiteButton, 'Khởi tạo Gateway');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Conflict error banner:
      expect(
        find.text(
          'Trạm Gateway đã tồn tại với thông tin khác biệt (HTTP 409 Conflict). Cơ chế khởi tạo không hỗ trợ cập nhật thay đổi dữ liệu.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Mã yêu cầu (Request ID): req-conflict-409'),
        findsOneWidget,
      );
    });

    testWidgets('404 Not Found displays owner user not found error message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.shouldThrowProvision = true;
      fakeGatewayRepo.provisionErrorToThrow = const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'resource not found',
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

      container.read(routerProvider).go(R.gatewayProvision);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'gw-unknown-owner',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Unknown Owner Station',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'ffffffff-ffff-ffff-ffff-ffffffffffff',
      );

      final submitBtn = find.widgetWithText(KiteButton, 'Khởi tạo Gateway');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Không tìm thấy người dùng sở hữu trong hệ thống (HTTP 404 Not Found). Vui lòng kiểm tra lại UUID.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('network timeout allows approved retry of same payload', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeGatewayRepo.shouldThrowProvision = true;
      fakeGatewayRepo.provisionErrorToThrow = const ApiException(
        statusCode: 504,
        code: 'gateway_timeout',
        message: 'Quá thời gian chờ phản hồi từ máy chủ.',
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

      container.read(routerProvider).go(R.gatewayProvision);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'gw-retry-test');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Retry Test Station',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        '123e4567-e89b-12d3-a456-426614174000',
      );

      final submitBtn = find.widgetWithText(KiteButton, 'Khởi tạo Gateway');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(fakeGatewayRepo.provisionCallCount, 1);
      expect(
        find.text('Quá thời gian chờ phản hồi từ máy chủ.'),
        findsOneWidget,
      );
    });
  });

  group('Responsive Layout Widths', () {
    for (final size in [
      const Size(390, 844),
      const Size(1024, 768),
      const Size(1366, 768),
      const Size(1920, 1080),
    ]) {
      testWidgets('renders cleanly without overflow at width ${size.width}', (
        tester,
      ) async {
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

        container.read(routerProvider).go(R.gatewayProvision);
        await tester.pumpAndSettle();

        expect(find.byType(GatewayProvisionScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
