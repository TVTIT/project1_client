import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/app.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/l10n/locale_controller.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/core/router/app_router.dart';
import 'package:kite/core/router/routes.dart';
import 'package:kite/core/theme/app_theme.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/data/twin_detail.dart';
import 'package:kite/features/digital_twin/presentation/edit_metadata_dialog.dart';
import 'package:kite/features/digital_twin/providers/metadata_edit_provider.dart';
import 'package:kite/features/digital_twin/providers/temporal_history_provider.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite/features/gateways/providers/gateway_detail_provider.dart';
import 'package:kite/features/gateways/providers/gateway_list_provider.dart';
import 'package:kite/l10n/app_localizations.dart';
import 'package:kite/shared/widgets/temporal_history_controls.dart';
import 'package:kite/shared/widgets/temporal_history_panel.dart';
import 'package:kite/shared/widgets/temporal_history_table.dart';
import 'package:kite_ui/kite_ui.dart';

import 'c8_temporal_panel_test.dart' show FakePanelTwinRepository;
import 'c9_patch_metadata_test.dart' show FakeC9TwinRepo;
import 'gateway_list_provider_test.dart';
import 'permissions_test.dart';
import 'session_test.dart';

const sensor = 'urn:ngsi-ld:Sensor:gw-01:temp';
const gateway = 'urn:ngsi-ld:Gateway:gw-01';

class IntegrationRepo extends FakeC9TwinRepo {
  final history = FakePanelTwinRepository();
  String name = 'Temp Sensor';
  String gatewayName = 'Main Gateway';
  int patches = 0;
  bool uncertain = false;
  Object? historyError;
  void Function(String, PatchTwinAttrsInput)? onPatch;
  @override
  Future<TwinDetailPage> getTwinDetail(
    String id, {
    int relationshipLimit = 20,
    String? relationshipAfter,
  }) async {
    if (detailError != null) throw detailError!;
    return TwinDetailPage(
      TwinDetail(
        entity: EntityUrn.parse(id),
        name: TwinProperty(id == gateway ? gatewayName : name),
      ),
      null,
    );
  }

  @override
  Future<PatchTwinResponseDto> patchTwinAttrs(
    String id,
    PatchTwinAttrsInput input,
  ) async {
    patches++;
    if (patchError != null) return super.patchTwinAttrs(id, input);
    if (id == gateway) {
      gatewayName = input.name ?? gatewayName;
    } else {
      name = input.name ?? name;
    }
    onPatch?.call(id, input);
    if (uncertain) throw TimeoutException('PRIVATE transport diagnostics');
    return super.patchTwinAttrs(id, input);
  }

  @override
  Future<ApiResponse> listTwins({
    EntityType? type,
    String? gatewayId,
    int? limit,
    String? cursor,
    bool simplified = true,
  }) async => const ApiResponse(statusCode: 200, rawBody: <Object>[]);
  @override
  Future<TwinTemporalResponse> getSensorTemporal(
    String id, {
    required String attrs,
    required DateTime timeAt,
    required DateTime endTimeAt,
    String? aggrPeriodDuration,
    String? aggrMethods,
    int? maxPoints,
  }) {
    if (historyError != null) return Future.error(historyError!);
    if (aggrPeriodDuration == null) {
      return Future.value(
        TwinTemporalResponse(
          id: id,
          type: 'Sensor',
          attrName: attrs,
          rawPoints: [
            TemporalRawPoint(
              value: 12.5,
              observedAt: timeAt.add(const Duration(microseconds: 123456)),
            ),
            TemporalRawPoint(
              value: 13.5,
              observedAt: timeAt.add(const Duration(microseconds: 123456)),
            ),
          ],
        ),
      );
    }
    return history.getSensorTemporal(
      id,
      attrs: attrs,
      timeAt: timeAt,
      endTimeAt: endTimeAt,
      aggrPeriodDuration: aggrPeriodDuration,
      aggrMethods: aggrMethods,
      maxPoints: maxPoints,
    );
  }
}

void main() {
  late ProviderContainer container;
  late IntegrationRepo twins;
  late FakeGatewayRepository gateways;
  late FakeAuthRepository auth;
  late FakePermissionsRepository permissions;
  setUp(() async {
    auth = FakeAuthRepository();
    twins = IntegrationRepo();
    gateways = FakeGatewayRepository()
      ..items = [
        const GatewayItem(
          gatewayId: 'gw-01',
          name: 'Main Gateway',
          role: GatewayRole.owner,
        ),
      ]
      ..sensorsMap = {
        'gw-01': [
          const SensorItem(sensorId: 'temp', name: 'Temp Sensor', unit: '°C'),
        ],
      };
    permissions = FakePermissionsRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        digitalTwinRepositoryProvider.overrideWithValue(twins),
        gatewayRepositoryProvider.overrideWithValue(gateways),
        permissionsRepositoryProvider.overrideWithValue(permissions),
      ],
    );
    container
        .read(sessionProvider.notifier)
        .setSession(
          const SessionUser(
            userId: 'u1',
            name: 'Owner',
            email: 'owner@example.com',
          ),
        );
    await container.read(userPermissionsProvider.notifier).loadPermissions();
  });
  tearDown(() {
    container.dispose();
    auth.dispose();
  });
  Future<void> open(
    WidgetTester tester,
    String route, {
    Size size = const Size(1366, 768),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(routerProvider).go(route);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KiteApp()),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(390, 844),
    const Size(1024, 768),
    const Size(1366, 768),
    const Size(1920, 1080),
  ]) {
    for (final locale in KiteLocale.values) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets(
          'Gateway two tabs / Sensor deep link / keyboard ${size.width} ${locale.name} ${mode.name}',
          (tester) async {
            container.read(localeProvider.notifier).set(locale);
            container.read(themeProvider.notifier).setMode(mode);
            await open(tester, R.gatewayDetail('gw-01'), size: size);
            expect(find.text('Main Gateway'), findsOneWidget);
            expect(find.byType(DropdownMenu<String>), findsOneWidget);
            expect(find.byType(TemporalHistoryPanel), findsOneWidget);
            final l = L.of(tester.element(find.byType(TemporalHistoryPanel)));
            final tab = find.text(l.gatewayTabSensors).first;
            await tester.ensureVisible(tab);
            await tester.tap(tab);
            await tester.pumpAndSettle();
            expect(find.byType(TemporalHistoryPanel), findsNothing);
            expect(find.text('Temp Sensor'), findsWidgets);
            container.read(routerProvider).go(R.twinDetail(sensor));
            await tester.pumpAndSettle();
            final edit = find.byKey(const ValueKey('edit-twin-metadata-btn'));
            expect(
              edit,
              findsOneWidget,
              reason: 'Owner direct link must not require a previously loaded catalog',
            );
            await tester.ensureVisible(edit);
            await tester.tap(edit);
            await tester.pumpAndSettle();
            expect(find.byType(EditMetadataDialog), findsOneWidget);
            await tester.tap(
              find.byKey(const ValueKey('metadata-edit-name-field')),
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            expect(FocusManager.instance.primaryFocus, isNotNull);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'uncertain update survives refresh/reopen; reconciliation closes with confirmed values',
    (tester) async {
      twins.uncertain = true;
      await open(tester, R.twinDetail(sensor));
      await tester.tap(find.byKey(const ValueKey('edit-twin-metadata-btn')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('metadata-edit-name-field')),
        'Updated name',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('metadata-edit-submit-btn')));
      await tester.pumpAndSettle();
      expect(
        container.read(metadataEditProvider(sensor)).isUnknownOutcome,
        isTrue,
      );
      expect(find.textContaining('PRIVATE'), findsNothing);
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u1',
              name: 'Owner',
              email: 'owner@example.com',
            ),
          );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<KiteButton>(
              find.byKey(const ValueKey('metadata-edit-submit-btn')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(EditMetadataDialog),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EditMetadataDialog), findsNothing);
      await tester.tap(find.byKey(const ValueKey('edit-twin-metadata-btn')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<KiteButton>(
              find.byKey(const ValueKey('metadata-edit-submit-btn')),
            )
            .onPressed,
        isNull,
      );
      twins.name = 'Old name';
      await tester.tap(
        find.byKey(const ValueKey('metadata-edit-reconcile-btn')),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(metadataEditProvider(sensor)).reconcileStatus,
        MetadataReconcileStatus.mismatch,
      );
      expect(find.byType(EditMetadataDialog), findsOneWidget);
      twins.detailError = const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'PRIVATE details',
      );
      await tester.tap(
        find.byKey(const ValueKey('metadata-edit-reconcile-btn')),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(metadataEditProvider(sensor)).reconcileStatus,
        MetadataReconcileStatus.cannotVerify,
      );
      expect(find.textContaining('PRIVATE'), findsNothing);
      twins.detailError = null;
      twins.name = 'Updated name';
      await tester.tap(
        find.byKey(const ValueKey('metadata-edit-reconcile-btn')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EditMetadataDialog), findsNothing);
      expect(find.text('Updated name'), findsWidgets);
      expect(twins.patches, 1);
    },
  );
  testWidgets(
    'raw history renders duplicate microsecond rows and µs unit; stale errors retain request ID safely',
    (tester) async {
      await open(tester, R.gatewayDetail('gw-01'));
      final start = DateTime.utc(2026, 10, 23);
      await container
          .read(temporalHistoryProvider(sensor).notifier)
          .fetchTemporal(
            TemporalQueryParameters(
              attrs: 'sample_interval_us',
              timeAt: start,
              endTimeAt: start.add(const Duration(seconds: 10)),
              mode: TemporalQueryMode.raw,
            ),
          );
      await tester.pumpAndSettle();
      expect(find.byType(TemporalHistoryTable), findsOneWidget);
      final expectedLocalTime = formatLocalIsoDate(
        start.add(const Duration(microseconds: 123456)),
        includeMicroseconds: true,
      );
      expect(find.text(expectedLocalTime), findsNWidgets(2));
      expect(find.text('12.50 µs'), findsWidgets);
      final table = tester.widget<TemporalHistoryTable>(
        find.byType(TemporalHistoryTable),
      );
      expect(table.response.rawPoints, hasLength(2));
      twins.historyError = const ApiException(
        statusCode: 503,
        code: 'service_unavailable',
        message: 'PRIVATE exception body',
        requestId: 'req-c10',
      );
      await container
          .read(temporalHistoryProvider(sensor).notifier)
          .refreshApplied();
      await tester.pumpAndSettle();
      expect(find.textContaining('req-c10'), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(find.byType(TemporalHistoryTable), findsOneWidget);
    },
  );
  testWidgets(
    'Gateway PATCH refreshes actual catalogs instead of resetting manual loaders',
    (tester) async {
      permissions.resultToReturn = const UserPermissions(isPlatformAdmin: true);
      await container.read(userPermissionsProvider.notifier).loadPermissions();
      twins.onPatch = (_, input) {
        gateways.items = [
          GatewayItem(
            gatewayId: 'gw-01',
            name: input.name!,
            role: GatewayRole.owner,
          ),
        ];
        gateways.adminGatewaysResultToReturn = AdminGatewayInventoryResponse(
          items: [AdminGatewayItem(gatewayId: 'gw-01', name: input.name!)],
          nextCursor: null,
        );
      };
      await open(tester, R.gatewayDetail('gw-01'));
      await tester.tap(find.byKey(const ValueKey('gateway-edit-metadata-btn')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('metadata-edit-name-field')),
        'Renamed Gateway',
      );
      // Clearing an already-null description must not hide an independent name change.
      await tester.tap(
        find.byKey(const ValueKey('metadata-edit-clear-desc-check')),
      );
      await tester.pump();
      expect(
        tester
            .widget<KiteButton>(
              find.byKey(const ValueKey('metadata-edit-submit-btn')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('metadata-edit-submit-btn')));
      await tester.pumpAndSettle();
      expect(find.byType(EditMetadataDialog), findsNothing);
      expect(find.text('Renamed Gateway'), findsOneWidget);
      expect(container.read(gatewayDetailProvider('gw-01')).isLoaded, isTrue);
      expect(
        container.read(gatewayListProvider).gateways.single.name,
        'Renamed Gateway',
      );
      expect(twins.capturedInput!.clearDescription, isFalse);
    },
  );
  testWidgets(
    'active history automatically requeries after identity switch, not token refresh',
    (tester) async {
      await open(tester, R.gatewayDetail('gw-01'));
      final before = twins.history.callCount;
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u1',
              name: 'Owner',
              email: 'owner@example.com',
            ),
          );
      await tester.pumpAndSettle();
      expect(twins.history.callCount, before);
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u2',
              name: 'Other member',
              email: 'other@example.com',
            ),
          );
      await tester.pumpAndSettle();
      expect(twins.history.callCount, greaterThan(before));
      expect(find.byType(TemporalHistoryPanel), findsOneWidget);
      expect(find.byType(DropdownMenu<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'definite metadata error shows safe localized message and request ID',
    (tester) async {
      twins.patchError = const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'PRIVATE parser internals',
        requestId: 'req-patch',
      );
      await open(tester, R.twinDetail(sensor));
      await tester.tap(find.byKey(const ValueKey('edit-twin-metadata-btn')));
      await tester.pumpAndSettle();
      final l = L.of(tester.element(find.byType(EditMetadataDialog)));
      await tester.enterText(
        find.byKey(const ValueKey('metadata-edit-name-field')),
        'New',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('metadata-edit-submit-btn')));
      await tester.pumpAndSettle();
      expect(find.text(l.twinEditFailed), findsOneWidget);
      expect(find.textContaining('req-patch'), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      twins.patchError = null;
      await tester.tap(find.byKey(const ValueKey('metadata-edit-submit-btn')));
      await tester.pumpAndSettle();
      expect(find.byType(EditMetadataDialog), findsNothing);
      expect(twins.patches, 2);
    },
  );
  testWidgets(
    'metadata validates changed fields only and localizes invalid input',
    (tester) async {
      permissions.resultToReturn = const UserPermissions(isPlatformAdmin: true);
      await container.read(userPermissionsProvider.notifier).loadPermissions();
      await open(tester, R.twinDetail(gateway));
      final original =
          'x' * 1024; // Existing legacy metadata can exceed PATCH bounds.
      unawaited(
        showEditMetadataDialog(
          tester.element(find.text('Main Gateway')),
          entityUrn: gateway,
          initialName: 'Main Gateway',
          initialDescription: original,
        ),
      );
      await tester.pumpAndSettle();
      final l = L.of(tester.element(find.byType(EditMetadataDialog)));
      final name = find.byKey(const ValueKey('metadata-edit-name-field'));
      final desc = find.byKey(const ValueKey('metadata-edit-desc-field'));
      final submit = find.byKey(const ValueKey('metadata-edit-submit-btn'));
      Future<void> save() async {
        await tester.pump();
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
      }

      await tester.enterText(desc, 'd' * 513);
      await save();
      expect(find.text(l.twinEditDescriptionTooLong), findsOneWidget);
      await tester.enterText(desc, original);
      await tester.enterText(name, ' ');
      await save();
      expect(find.text(l.twinEditNameRequired), findsOneWidget);
      await tester.enterText(name, 'n' * 257);
      await save();
      expect(find.text(l.twinEditNameTooLong), findsOneWidget);
      await tester.enterText(name, 'NUL\u0000');
      await save();
      expect(find.text(l.twinEditInvalidText), findsOneWidget);
      await tester.enterText(name, 'New name');
      await save();
      expect(find.byType(EditMetadataDialog), findsNothing);
      expect(twins.capturedInput!.description, isNull);
      expect(twins.capturedInput!.name, 'New name');
    },
  );
}
