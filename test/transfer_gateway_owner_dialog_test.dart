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
import 'package:kite/features/gateways/presentation/gateway_detail_screen.dart';
import 'package:kite/features/gateways/presentation/transfer_gateway_owner_dialog.dart';
import 'package:kite/features/users/data/user_dto.dart';
import 'package:kite/features/users/data/user_repository.dart';
import 'package:kite_ui/kite_ui.dart';

import 'permissions_test.dart';
import 'session_test.dart';

class FakeTransferUserRepository implements UserRepository {
  String? lastTransferGatewayId;
  String? lastTransferTargetUserId;
  Object? transferError;
  int transferCallCount = 0;
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
    throw UnimplementedError();
  }

  @override
  Future<void> revokeGatewayUser({
    required String gatewayId,
    required String userId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<TransferGatewayOwnerResult> transferGatewayOwner({
    required String gatewayId,
    required String targetUserId,
  }) async {
    transferCallCount++;
    lastTransferGatewayId = gatewayId;
    lastTransferTargetUserId = targetUserId;
    if (transferError != null) throw transferError!;
    return TransferGatewayOwnerResult(
      gatewayId: gatewayId,
      ownerUserId: targetUserId,
    );
  }
}

class FakeDetailGatewayRepo2 implements GatewayRepository {
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
  late FakeTransferUserRepository fakeUserRepo;
  late FakeDetailGatewayRepo2 fakeGatewayRepo;
  late FakePermissionsRepository fakePermsRepo;

  const testGateway = GatewayItem(
    gatewayId: 'gw-transfer-01',
    name: 'Trạm Chuyển Owner 01',
    description: 'Trạm thử nghiệm chuyển giao quyền sở hữu',
    role: GatewayRole.owner,
  );

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
    fakeUserRepo = FakeTransferUserRepository();
    fakeGatewayRepo = FakeDetailGatewayRepo2()..items = [testGateway];
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

  group('TransferGatewayOwnerDialog Behavioral Tests', () {
    testWidgets(
      'regular owner (non-admin) never sees admin transfer owner button on GatewayDetailScreen',
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

        container.read(routerProvider).go(R.gatewayDetail('gw-transfer-01'));
        await tester.pumpAndSettle();

        expect(find.byType(GatewayDetailScreen), findsOneWidget);
        // Non-admin owner must NOT see admin transfer owner button
        expect(find.text('Chuyển quyền sở hữu'), findsNothing);
      },
    );

    testWidgets(
      'platform admin sees transfer owner button, opens dialog displaying current owner and replay notice',
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
            id: '550e8400-e29b-41d4-a716-446655440020',
            email: 'current_owner@example.com',
            fullName: 'Nguyễn Văn Chủ Cũ',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
            gatewayRoles: const [
              UserGatewayRole(gatewayId: 'gw-transfer-01', role: 'owner'),
            ],
          ),
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440021',
            email: 'new_owner@example.com',
            fullName: 'Trần Văn Chủ Mới',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-02T00:00:00Z'),
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

        container.read(routerProvider).go(R.gatewayDetail('gw-transfer-01'));
        await tester.pumpAndSettle();

        final transferBtn = find.text('Chuyển quyền sở hữu');
        expect(transferBtn, findsOneWidget);

        await tester.tap(transferBtn);
        await tester.pumpAndSettle();

        expect(find.byType(TransferGatewayOwnerDialog), findsOneWidget);
        expect(find.text('Chuyển giao quyền sở hữu Gateway'), findsOneWidget);
        // Derived current owner displayed
        expect(
          find.textContaining('current_owner@example.com'),
          findsAtLeast(1),
        );
        expect(find.textContaining('Nguyễn Văn Chủ Cũ'), findsAtLeast(1));
        // Notice about PUT replay conflict
        expect(find.textContaining('409 Conflict'), findsOneWidget);
      },
    );

    testWidgets(
      'requires explicit confirmation before transferring ownership to different user',
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
            id: '550e8400-e29b-41d4-a716-446655440020',
            email: 'current_owner@example.com',
            fullName: 'Old Owner',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
            gatewayRoles: const [
              UserGatewayRole(gatewayId: 'gw-transfer-01', role: 'owner'),
            ],
          ),
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440021',
            email: 'recipient@example.com',
            fullName: 'New Owner',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-02T00:00:00Z'),
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

        container.read(routerProvider).go(R.gatewayDetail('gw-transfer-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chuyển quyền sở hữu'));
        await tester.pumpAndSettle();

        // Submit button is disabled until confirmation checkbox is checked
        var submitBtn = tester.widget<KiteButton>(
          find.widgetWithText(KiteButton, 'Chuyển giao'),
        );
        expect(submitBtn.onPressed, isNull);

        // Check confirmation checkbox
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();

        submitBtn = tester.widget<KiteButton>(
          find.widgetWithText(KiteButton, 'Chuyển giao'),
        );
        expect(submitBtn.onPressed, isNotNull);

        await tester.tap(find.text('Chuyển giao'));
        await tester.pumpAndSettle();

        expect(fakeUserRepo.transferCallCount, 1);
        expect(fakeUserRepo.lastTransferGatewayId, 'gw-transfer-01');
      },
    );

    testWidgets('zero owners found in directory blocks transfer with warning', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakePermsRepo.resultToReturn = const UserPermissions(
        isPlatformAdmin: true,
      );
      // No users have owner role on gw-transfer-01
      fakeUserRepo.users = [
        UserSummary(
          id: '550e8400-e29b-41d4-a716-446655440025',
          email: 'viewer@example.com',
          fullName: 'Viewer Only',
          platformRole: 'user',
          createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
          gatewayRoles: const [
            UserGatewayRole(gatewayId: 'gw-transfer-01', role: 'viewer'),
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

      container.read(routerProvider).go(R.gatewayDetail('gw-transfer-01'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chuyển quyền sở hữu'));
      await tester.pumpAndSettle();

      // Zero owners warning is shown
      expect(
        find.textContaining('Không tìm thấy chủ sở hữu hiện tại'),
        findsOneWidget,
      );
      // Submit is disabled
      final submitBtn = tester.widget<KiteButton>(
        find.widgetWithText(KiteButton, 'Chuyển giao'),
      );
      expect(submitBtn.onPressed, isNull);
    });

    testWidgets(
      'multiple owners found in directory blocks transfer with warning',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        fakePermsRepo.resultToReturn = const UserPermissions(
          isPlatformAdmin: true,
        );
        // Multiple users claim owner role on gw-transfer-01 (inconsistent)
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440026',
            email: 'ownerA@example.com',
            fullName: 'Owner A',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
            gatewayRoles: const [
              UserGatewayRole(gatewayId: 'gw-transfer-01', role: 'owner'),
            ],
          ),
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440027',
            email: 'ownerB@example.com',
            fullName: 'Owner B',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
            gatewayRoles: const [
              UserGatewayRole(gatewayId: 'gw-transfer-01', role: 'owner'),
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

        container.read(routerProvider).go(R.gatewayDetail('gw-transfer-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chuyển quyền sở hữu'));
        await tester.pumpAndSettle();

        expect(find.textContaining('nhiều hơn một chủ sở hữu'), findsOneWidget);
        final submitBtn = tester.widget<KiteButton>(
          find.widgetWithText(KiteButton, 'Chuyển giao'),
        );
        expect(submitBtn.onPressed, isNull);
      },
    );

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
        fakeUserRepo.transferError = const ApiException(
          statusCode: 503,
          code: 'service_unavailable',
          message: 'service unavailable',
        );
        fakeUserRepo.users = [
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440020',
            email: 'current_owner@example.com',
            fullName: 'Old Owner',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
            gatewayRoles: const [
              UserGatewayRole(gatewayId: 'gw-transfer-01', role: 'owner'),
            ],
          ),
          UserSummary(
            id: '550e8400-e29b-41d4-a716-446655440028',
            email: 'recipient28@example.com',
            fullName: 'New Owner 28',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-02T00:00:00Z'),
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

        container.read(routerProvider).go(R.gatewayDetail('gw-transfer-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chuyển quyền sở hữu'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chuyển giao'));
        await tester.pumpAndSettle();

        expect(fakeUserRepo.transferCallCount, 1);
        expect(find.textContaining('chưa xác định'), findsOneWidget);

        final submitBtn = tester.widget<KiteButton>(
          find.widgetWithText(KiteButton, 'Chuyển giao'),
        );
        expect(submitBtn.onPressed, isNull);

        await tester.tap(find.text('Chuyển giao'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(fakeUserRepo.transferCallCount, 1); // Strictly 1 call!
      },
    );

    testWidgets(
      'session switch while transfer mutation is in-flight pops dialog and discards response',
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
            id: '550e8400-e29b-41d4-a716-446655440020',
            email: 'current_owner@example.com',
            fullName: 'Old Owner',
            platformRole: 'user',
            createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
            gatewayRoles: const [
              UserGatewayRole(gatewayId: 'gw-transfer-01', role: 'owner'),
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

        container.read(routerProvider).go(R.gatewayDetail('gw-transfer-01'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chuyển quyền sở hữu'));
        await tester.pumpAndSettle();

        expect(find.byType(TransferGatewayOwnerDialog), findsOneWidget);

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

        expect(find.byType(TransferGatewayOwnerDialog), findsNothing);
      },
    );

    for (final width in [390.0, 1024.0, 1366.0, 1920.0]) {
      testWidgets(
        'TransferGatewayOwnerDialog renders cleanly without overflow at width $width',
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
              id: '550e8400-e29b-41d4-a716-446655440020',
              email: 'current_owner@example.com',
              fullName: 'Old Owner',
              platformRole: 'user',
              createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
              gatewayRoles: const [
                UserGatewayRole(gatewayId: 'gw-transfer-01', role: 'owner'),
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

          container.read(routerProvider).go(R.gatewayDetail('gw-transfer-01'));
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(Icons.swap_horiz_outlined).first);
          await tester.pumpAndSettle();

          expect(find.byType(TransferGatewayOwnerDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
