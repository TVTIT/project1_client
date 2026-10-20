import 'dart:async';

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
import 'package:kite/features/gateways/data/mqtt_credential_dto.dart';
import 'package:kite/features/gateways/presentation/assign_gateway_user_dialog.dart';
import 'package:kite/features/gateways/presentation/gateway_detail_screen.dart';
import 'package:kite/features/users/data/user_dto.dart';
import 'package:kite/features/users/data/user_repository.dart';
import 'package:kite_ui/kite_ui.dart';

import 'permissions_test.dart';
import 'session_test.dart';

class FakeAssignUserRepository implements UserRepository {
  String? lastAssignedGatewayId;
  String? lastAssignedUserId;
  String? lastAssignedRole;
  Object? assignError;
  int assignCallCount = 0;

  String? lastRevokedGatewayId;
  String? lastRevokedUserId;
  Object? revokeError;
  int revokeCallCount = 0;

  List<UserSummary> users = [];

  @override
  Future<List<UserSummary>> listUsers() async => users;

  @override
  Future<CreatedUser> createUser(CreateUserInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<UpdatedUser> updateUser(String userId, UpdateUserInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<AssignGatewayUserResult> assignGatewayUser({
    required String gatewayId,
    required String userId,
    required String role,
  }) async {
    assignCallCount++;
    lastAssignedGatewayId = gatewayId;
    lastAssignedUserId = userId;
    lastAssignedRole = role;
    if (assignError != null) throw assignError!;
    return AssignGatewayUserResult(
      gatewayId: gatewayId,
      userId: userId,
      role: role,
    );
  }

  @override
  Future<void> revokeGatewayUser({
    required String gatewayId,
    required String userId,
  }) async {
    revokeCallCount++;
    lastRevokedGatewayId = gatewayId;
    lastRevokedUserId = userId;
    if (revokeError != null) throw revokeError!;
  }

  @override
  Future<TransferGatewayOwnerResult> transferGatewayOwner({
    required String gatewayId,
    required String targetUserId,
  }) async {
    throw UnimplementedError();
  }
}

class FakeDetailGatewayRepo implements GatewayRepository {
  List<GatewayItem> items = [];
  SensorListResponse? sensorsResponse;

  @override
  Future<List<GatewayItem>> getGateways() async => items;

  @override
  Future<SensorListResponse> getGatewaySensors(String gatewayId) async {
    return sensorsResponse ??
        SensorListResponse(gatewayId: gatewayId, items: const []);
  }

  @override
  Future<AdminGatewayInventoryResponse> getAdminGateways({
    int? limit,
    String? after,
  }) async {
    return const AdminGatewayInventoryResponse(items: []);
  }

  @override
  Future<ProvisionGatewayResult> provisionGateway(
    ProvisionGatewayInput input,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<ProvisionSensorResult> provisionSensor(
    ProvisionSensorInput input,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<ProvisionSensorResult> provisionOwnerSensor(
    ProvisionSensorInput input,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<MqttCredentialMetadata> getMqttCredential(String gatewayId) async {
    throw UnimplementedError();
  }

  @override
  Future<Object> provisionMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Object> rotateMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<MqttCredentialMutationResult> revokeMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  late FakeAuthRepository fakeAuthRepo;
  late FakeAssignUserRepository fakeUserRepo;
  late FakeDetailGatewayRepo fakeGatewayRepo;
  late FakePermissionsRepository fakePermsRepo;

  const testGateway = GatewayItem(
    gatewayId: 'gw-assign-01',
    name: 'Trạm Gán Quyền 01',
    description: 'Trạm thử nghiệm phân quyền',
    role: GatewayRole.owner,
  );

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeUserRepo = FakeAssignUserRepository();
    fakeGatewayRepo = FakeDetailGatewayRepo()..items = [testGateway];
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

  group('AssignGatewayUserDialog Behavioral Tests', () {
    Future<void> openRoleDialog(
      WidgetTester tester, {
      String? preselectedUserId,
    }) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          userRepositoryProvider.overrideWithValue(fakeUserRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'admin-uuid',
              name: 'Admin',
              email: 'admin@example.com',
            ),
          );
      await container.read(userPermissionsProvider.notifier).loadPermissions();
      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();
      container.read(routerProvider).go(R.gatewayDetail('gw-assign-01'));
      await tester.pumpAndSettle();
      unawaited(
        showAssignGatewayUserDialog(
          tester.element(find.byType(GatewayDetailScreen)),
          gatewayId: 'gw-assign-01',
          preselectedUserId: preselectedUserId,
        ),
      );
      await tester.pumpAndSettle();
    }

    UserSummary roleUser(String id, String? role) => UserSummary(
      id: id,
      email: '$id@example.com',
      fullName: id,
      platformRole: 'user',
      createdAt: DateTime.utc(2026),
      gatewayRoles: [
        const UserGatewayRole(gatewayId: 'other-gateway', role: 'owner'),
        if (role != null)
          UserGatewayRole(gatewayId: 'gw-assign-01', role: role),
      ],
    );

    for (final role in ['operator', 'viewer', 'none']) {
      testWidgets('initial selection matches current gateway role $role', (
        tester,
      ) async {
        fakeUserRepo.users = [roleUser('target', role == 'none' ? null : role)];
        await openRoleDialog(tester, preselectedUserId: 'target');
        expect(
          tester
              .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
              .groupValue,
          role,
        );
        expect(
          find.descendant(
            of: find.byType(AssignGatewayUserDialog),
            matching: find.byType(KiteBadge),
          ),
          findsNothing,
        ); // Owner elsewhere is irrelevant.
      });
    }

    testWidgets('switching user resets draft role but search preserves edits', (
      tester,
    ) async {
      fakeUserRepo.users = [
        roleUser('operator-user', 'operator'),
        roleUser('viewer-user', 'viewer'),
      ];
      await openRoleDialog(tester);
      await tester.tap(find.text('viewer-user'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'viewer',
      );
      await tester.tap(find.text('Vận hành (Operator)'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AssignGatewayUserDialog),
          matching: find.byType(TextField),
        ),
        'viewer',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'operator',
      );
    });

    testWidgets(
      'owner has badge and red guidance, disabled roles and no writes',
      (tester) async {
        fakeUserRepo.users = [
          roleUser('owner-user', 'owner'),
          roleUser('viewer-user', 'viewer'),
        ];
        await openRoleDialog(tester);
        final ownerTile = find.widgetWithText(ListTile, 'owner-user');
        expect(
          find.descendant(of: ownerTile, matching: find.byType(KiteBadge)),
          findsOneWidget,
        );
        const warning =
            'Để thay vai trò của chủ sở hữu, bạn hãy dùng tính năng chuyển quyền sở hữu.';
        final warningText = tester.widget<Text>(find.text(warning));
        expect(
          warningText.style?.color,
          KiteColors.of(tester.element(ownerTile)).destructive,
        );
        for (final tile in tester.widgetList<RadioListTile<String>>(
          find.byType(RadioListTile<String>),
        )) {
          expect(tile.enabled, isFalse);
        }
        expect(
          tester
              .widget<KiteButton>(
                find.widgetWithText(KiteButton, 'Lưu phân quyền'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Không có quyền'));
        await tester.pumpAndSettle();
        expect(fakeUserRepo.assignCallCount, 0);
        expect(fakeUserRepo.revokeCallCount, 0);
        await tester.tap(find.text('viewer-user'));
        await tester.pumpAndSettle();
        expect(find.text(warning), findsNothing);
        expect(
          tester
              .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
              .groupValue,
          'viewer',
        );
        expect(
          tester
              .widget<KiteButton>(
                find.widgetWithText(KiteButton, 'Lưu phân quyền'),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      'regular owner (non-admin) never sees admin assign button on GatewayDetailScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: false,
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const ownerUser = SessionUser(
          userId: 'owner-uuid-1',
          name: 'Regular Owner',
          email: 'owner@example.com',
        );
        container.read(sessionProvider.notifier).setSession(ownerUser);
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-assign-01'));
        await tester.pumpAndSettle();

        expect(find.byType(GatewayDetailScreen), findsOneWidget);
        // Non-admin owner must NOT see admin assign button
        expect(find.text('Phân quyền'), findsNothing);
        expect(find.text('Gán vai trò'), findsNothing);
      },
    );

    testWidgets(
      'platform admin sees assign button, opens dialog with operator and viewer options (no owner)',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440010',
            email: 'operator1@example.com',
            fullName: 'Nguyễn Văn Operator',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
            gatewayRoles: const [],
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: 'admin-uuid',
          name: 'System Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-assign-01'));
        await tester.pumpAndSettle();

        final assignBtn = find.text('Phân quyền');
        expect(assignBtn, findsOneWidget);

        await tester.tap(assignBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AssignGatewayUserDialog), findsOneWidget);
        expect(find.text('Gán vai trò thành viên Gateway'), findsOneWidget);
        // Radio options allow operator, viewer, and none
        expect(find.text('Vận hành (Operator)'), findsOneWidget);
        expect(find.text('Chỉ xem (Viewer)'), findsOneWidget);
        expect(find.text('Không có quyền'), findsOneWidget);
        expect(find.text('Chủ sở hữu (Owner)'), findsNothing);
      },
    );

    testWidgets(
      'selecting none option calls DELETE /v1/admin/gateways/{id}/users/{id}',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440010',
            email: 'operator1@example.com',
            fullName: 'Nguyễn Văn Operator',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
            gatewayRoles: const [
              UserGatewayRole(gatewayId: 'gw-assign-01', role: 'operator'),
            ],
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: 'admin-uuid',
          name: 'System Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-assign-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Phân quyền'));
        await tester.pumpAndSettle();

        // Select the "Không có quyền" option
        await tester.tap(find.text('Không có quyền'));
        await tester.pumpAndSettle();

        // Submit form
        await tester.tap(find.text('Lưu phân quyền'));
        await tester.pumpAndSettle();

        // Verify revokeGatewayUser was called and assignGatewayUser was NOT called
        expect(fakeUserRepo.revokeCallCount, 1);
        expect(fakeUserRepo.lastRevokedGatewayId, 'gw-assign-01');
        expect(
          fakeUserRepo.lastRevokedUserId,
          '550e8400-e29b-41d4-a716-446655440010',
        );
        expect(fakeUserRepo.assignCallCount, 0);

        // Dialog should be popped on success
        expect(find.byType(AssignGatewayUserDialog), findsNothing);
      },
    );

    testWidgets('handles 409 when cached operator became owner on the server', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      fakeUserRepo.assignError = const ApiException(
        statusCode: 409,
        code: 'owner_transfer_required',
        message: 'owner transfer required',
      );
      fakeUserRepo.users = [
        UserSummary(
          id: '550e8400-e29b-41d4-a716-446655440011',
          email: 'current_owner@example.com',
          fullName: 'Current Owner',
          platformRole: 'user',
          createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
          gatewayRoles: const [
            UserGatewayRole(gatewayId: 'gw-assign-01', role: 'operator'),
          ],
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          userRepositoryProvider.overrideWithValue(fakeUserRepo),
          gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
          permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
        ],
      );
      addTearDown(container.dispose);

      const adminUser = SessionUser(
        userId: 'admin-uuid',
        name: 'System Admin',
        email: 'admin@example.com',
      );
      container.read(sessionProvider.notifier).setSession(adminUser);
      await container.read(userPermissionsProvider.notifier).loadPermissions();

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      container.read(routerProvider).go(R.gatewayDetail('gw-assign-01'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Phân quyền'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lưu phân quyền'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('dùng chức năng Chuyển giao quyền sở hữu'),
        findsOneWidget,
      );
    });

    testWidgets(
      'unknown outcome on 503 locks resend; second submit attempt is blocked',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.assignError = const ApiException(
          statusCode: 503,
          code: 'service_unavailable',
          message: 'service unavailable',
        );
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440012',
            email: 'target12@example.com',
            fullName: 'Target 12',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
            gatewayRoles: const [
              UserGatewayRole(gatewayId: 'gw-assign-01', role: 'operator'),
            ],
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: 'admin-uuid',
          name: 'System Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-assign-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Phân quyền'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Lưu phân quyền'));
        await tester.pumpAndSettle();

        expect(fakeUserRepo.assignCallCount, 1);
        expect(find.textContaining('chưa xác định'), findsOneWidget);

        // Submit button is now disabled due to unknown outcome
        final submitBtn = tester.widget<KiteButton>(
          find.widgetWithText(KiteButton, 'Lưu phân quyền'),
        );
        expect(submitBtn.onPressed, isNull);

        // Attempt tapping again -> no second write!
        await tester.tap(find.text('Lưu phân quyền'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(fakeUserRepo.assignCallCount, 1); // Strictly 1 call!
      },
    );

    testWidgets(
      'session switch while assignment mutation is in-flight pops dialog and discards response',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440013',
            email: 'target13@example.com',
            fullName: 'Target 13',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
            gatewayRoles: const [],
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
            permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
          ],
        );
        addTearDown(container.dispose);

        const adminUser = SessionUser(
          userId: 'admin-uuid',
          name: 'System Admin',
          email: 'admin@example.com',
        );
        container.read(sessionProvider.notifier).setSession(adminUser);
        await container
            .read(userPermissionsProvider.notifier)
            .loadPermissions();

        await tester.pumpWidget(createTestWidget(container));
        await tester.pumpAndSettle();

        container.read(routerProvider).go(R.gatewayDetail('gw-assign-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Phân quyền'));
        await tester.pumpAndSettle();

        expect(find.byType(AssignGatewayUserDialog), findsOneWidget);

        // Session switches to user B
        container
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'admin-user-b',
                name: 'Admin B',
                email: 'b@example.com',
              ),
            );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Dialog was closed because session epoch/actor changed!
        expect(find.byType(AssignGatewayUserDialog), findsNothing);
      },
    );

    for (final width in [390.0, 1024.0, 1366.0, 1920.0]) {
      testWidgets(
        'AssignGatewayUserDialog renders cleanly without overflow at width $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          fakePermsRepo.resultToReturn = const UserPermissions(
            isPlatformAdmin: true,
          );
          fakeUserRepo.users = [
            UserSummary(
              id: '550e8400-e29b-41d4-a716-446655440010',
              email: 'operator1@example.com',
              fullName: 'Nguyễn Văn Operator',
              platformRole: 'user',
              createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
              gatewayRoles: const [],
            ),
          ];

          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              userRepositoryProvider.overrideWithValue(fakeUserRepo),
              gatewayRepositoryProvider.overrideWithValue(fakeGatewayRepo),
              permissionsRepositoryProvider.overrideWithValue(fakePermsRepo),
            ],
          );
          addTearDown(container.dispose);

          const adminUser = SessionUser(
            userId: 'admin-uuid',
            name: 'System Admin',
            email: 'admin@example.com',
          );
          container.read(sessionProvider.notifier).setSession(adminUser);
          await container
              .read(userPermissionsProvider.notifier)
              .loadPermissions();

          await tester.pumpWidget(createTestWidget(container));
          await tester.pumpAndSettle();

          container.read(routerProvider).go(R.gatewayDetail('gw-assign-01'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Phân quyền'));
          await tester.pumpAndSettle();

          expect(find.byType(AssignGatewayUserDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
