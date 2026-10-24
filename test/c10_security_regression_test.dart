import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/auth/permissions.dart';
import 'package:kite/core/auth/session.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/providers/metadata_edit_provider.dart';
import 'package:kite/features/digital_twin/providers/twin_list_provider.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';
import 'package:kite/features/gateways/providers/gateway_detail_provider.dart';

import 'c9_patch_metadata_test.dart' show FakeC9TwinRepo;
import 'gateway_list_provider_test.dart';
import 'permissions_test.dart';
import 'session_test.dart';
import 'twin_list_page_test.dart' show twinRow;
import 'twin_list_provider_test.dart';

const urn = 'urn:ngsi-ld:Gateway:gw-01';

class DeferredPatchRepo extends FakeC9TwinRepo {
  final pending = Completer<PatchTwinResponseDto>();
  @override
  Future<PatchTwinResponseDto> patchTwinAttrs(
    String entityId,
    PatchTwinAttrsInput input,
  ) {
    capturedInput = input;
    return pending.future;
  }
}

void main() {
  late ProviderContainer container;
  late FakeAuthRepository auth;
  late FakeC9TwinRepo repo;
  late FakePermissionsRepository permissions;
  void signIn() => container
      .read(sessionProvider.notifier)
      .setSession(
        const SessionUser(
          userId: 'u1',
          name: 'Member',
          email: 'u1@example.com',
        ),
      );
  setUp(() async {
    auth = FakeAuthRepository();
    repo = FakeC9TwinRepo();
    permissions = FakePermissionsRepository()
      ..resultToReturn = const UserPermissions(isPlatformAdmin: true);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        digitalTwinRepositoryProvider.overrideWithValue(repo),
        permissionsRepositoryProvider.overrideWithValue(permissions),
      ],
    );
    signIn();
    await container.read(userPermissionsProvider.notifier).loadPermissions();
    container.listen(metadataEditProvider(urn), (_, _) {});
  });
  tearDown(() {
    container.dispose();
    auth.dispose();
  });

  test(
    'unknown outcome blocks direct replay, reset and token refresh replay',
    () async {
      repo.patchError = TimeoutException('private transport details');
      final notifier = container.read(metadataEditProvider(urn).notifier);
      await notifier.submit(
        entityUrn: EntityUrn.parse(urn),
        name: 'New',
        authority: MetadataEditAuthority.admin,
      );
      repo.capturedInput = null;
      notifier.reset();
      signIn();
      expect(
        container.read(metadataEditProvider(urn)).isUnknownOutcome,
        isTrue,
      );
      expect(
        await notifier.submit(
          entityUrn: EntityUrn.parse(urn),
          name: 'Again',
          authority: MetadataEditAuthority.admin,
        ),
        isFalse,
      );
      expect(repo.capturedInput, isNull);
    },
  );
  test('caller cannot forge scope, authority or anonymous mutation', () async {
    final notifier = container.read(metadataEditProvider(urn).notifier);
    expect(
      await notifier.submit(
        entityUrn: EntityUrn.parse('urn:ngsi-ld:Gateway:other'),
        name: 'New',
        authority: MetadataEditAuthority.admin,
      ),
      isFalse,
    );
    expect(repo.capturedInput, isNull);
    permissions.resultToReturn = const UserPermissions(isPlatformAdmin: false);
    await container.read(userPermissionsProvider.notifier).loadPermissions();
    expect(
      await notifier.submit(
        entityUrn: EntityUrn.parse(urn),
        name: 'New',
        authority: MetadataEditAuthority.admin,
      ),
      isFalse,
    );
    container.read(sessionProvider.notifier).setSession(null);
    expect(
      await notifier.submit(
        entityUrn: EntityUrn.parse(urn),
        name: 'New',
        authority: MetadataEditAuthority.admin,
      ),
      isFalse,
    );
    expect(repo.capturedInput, isNull);
  });
  test('readback wrong identity cannot confirm an unknown mutation', () async {
    repo.patchError = const NetworkException('unknown');
    final notifier = container.read(metadataEditProvider(urn).notifier);
    await notifier.submit(
      entityUrn: EntityUrn.parse(urn),
      name: 'Main Gateway',
      authority: MetadataEditAuthority.admin,
    );
    await notifier.reconcile(EntityUrn.parse('urn:ngsi-ld:Gateway:other'));
    expect(container.read(metadataEditProvider(urn)).isUnknownOutcome, isTrue);
  });
  test('PATCH response rejects malformed identity, type and timestamps', () {
    final json = <String, dynamic>{
      'id': urn,
      'type': 'Gateway',
      'gateway_id': 'gw-01',
      'name': 'Name',
      'updated_at': '2026-10-23T12:00:00Z',
    };
    for (final entry in <String, Object>{
      'id': 'bad',
      'type': 'gateway',
      'gateway_id': 'other',
      'sensor_id': 'unexpected',
      'updated_at': '2026-02-30T12:00:00Z',
    }.entries) {
      expect(
        () => PatchTwinResponseDto.fromJson({...json, entry.key: entry.value}),
        throwsFormatException,
        reason: entry.key,
      );
    }
  });
  test(
    'temporal rejects absent Property and invalid tuple timestamps/length',
    () {
      expect(
        () => TwinTemporalResponse.fromJson({
          'id': 'urn:ngsi-ld:Sensor:gw:s',
          'type': 'Sensor',
        }),
        throwsFormatException,
      );
      for (final stamp in [
        '2026-02-30T00:00:00Z',
        '2026-10-23T00:00:00+00:00',
        '2026-10-23T00:00:00.1234567Z',
      ]) {
        expect(
          () => TemporalRawPoint.fromTuple([1, stamp]),
          throwsFormatException,
        );
      }
      expect(
        () => TemporalBucketPoint.doubleTriple([
          1,
          '2026-10-23T00:00:00Z',
          '2026-10-23T00:01:00Z',
          4,
        ]),
        throwsFormatException,
      );
      expect(
        () => TwinTemporalResponse.fromJson({
          'id': 'urn:ngsi-ld:Sensor:gw:s',
          'type': 'Sensor',
          'measurement': {'values': <Object>[]},
        }),
        throwsFormatException,
      );
    },
  );
  test('same identity refresh retains Twin list', () async {
    final listRepo = ListTwinRepository()
      ..handler = (_) async => twinResponse([twinRow('gw')]);
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        digitalTwinRepositoryProvider.overrideWithValue(listRepo),
        twinListEndpointProvider.overrideWithValue(
          Uri.parse('https://api.example/v1/digital-twins'),
        ),
      ],
    );
    addTearDown(c.dispose);
    void login() => c
        .read(sessionProvider.notifier)
        .setSession(
          const SessionUser(userId: 'u1', name: 'M', email: 'u1@example.com'),
        );
    login();
    await c.read(twinListProvider.notifier).load();
    login();
    expect(c.read(twinListProvider).items, hasLength(1));
  });
  test('explicit null clears obsolete mutation errors and result', () {
    final state = MetadataEditState(
      error: StateError('old'),
      errorMessage: 'old',
      requestId: 'old',
    );
    final cleared = state.copyWith(
      error: null,
      errorMessage: null,
      requestId: null,
    );
    expect(cleared.error, isNull);
    expect(cleared.errorMessage, isNull);
    expect(cleared.requestId, isNull);
  });
  test(
    'new identity does not inherit an old pending permission refresh lock',
    () async {
      final oldResult = Completer<UserPermissions>();
      permissions.pendingCompleter = oldResult;
      final old = container
          .read(userPermissionsProvider.notifier)
          .loadPermissions();
      container
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(
              userId: 'u2',
              name: 'Other',
              email: 'other@example.com',
            ),
          );
      container.read(userPermissionsProvider);
      permissions.pendingCompleter = null;
      permissions.resultToReturn = const UserPermissions(
        isPlatformAdmin: false,
      );
      final before = permissions.callCount;
      final fresh = container
          .read(userPermissionsProvider.notifier)
          .loadPermissions();
      await Future<void>.delayed(Duration.zero);
      try {
        expect(permissions.callCount, greaterThan(before));
        expect(container.read(userPermissionsProvider).isLoading, isFalse);
      } finally {
        oldResult.complete(const UserPermissions(isPlatformAdmin: true));
        await Future.wait([old, fresh]);
      }
      expect(container.read(userPermissionsProvider).isPlatformAdmin, isFalse);
    },
  );
  for (final dispose in [false, true]) {
    test(
      'late mutation completion is fenced after ${dispose ? 'disposal' : 'logout/relogin'}',
      () async {
        final deferred = DeferredPatchRepo();
        final c = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            digitalTwinRepositoryProvider.overrideWithValue(deferred),
            permissionsRepositoryProvider.overrideWithValue(permissions),
            gatewayRepositoryProvider.overrideWithValue(
              FakeGatewayRepository(),
            ),
          ],
        );
        c
            .read(sessionProvider.notifier)
            .setSession(
              const SessionUser(
                userId: 'u1',
                name: 'M',
                email: 'm@example.com',
              ),
            );
        await c.read(userPermissionsProvider.notifier).loadPermissions();
        c.listen(metadataEditProvider(urn), (_, _) {});
        final pending = c
            .read(metadataEditProvider(urn).notifier)
            .submit(
              entityUrn: EntityUrn.parse(urn),
              name: 'New',
              authority: MetadataEditAuthority.admin,
            );
        await Future<void>.delayed(Duration.zero);
        if (dispose) {
          c.dispose();
        } else {
          c.read(sessionProvider.notifier).setSession(null);
          c
              .read(sessionProvider.notifier)
              .setSession(
                const SessionUser(
                  userId: 'u2',
                  name: 'Other',
                  email: 'other@example.com',
                ),
              );
          c.read(metadataEditProvider(urn));
        }
        deferred.pending.complete(
          const PatchTwinResponseDto(
            id: urn,
            type: EntityType.gateway,
            gatewayId: 'gw-01',
            name: 'New',
            updatedAt: '2026-10-23T12:00:00Z',
          ),
        );
        expect(await pending, isFalse);
        if (!dispose) {
          expect(c.read(metadataEditProvider(urn)).isSuccess, isFalse);
          c.dispose();
        }
      },
    );
  }
  test(
    'unknown mismatch and denied readback never enable mutation replay',
    () async {
      repo.patchError = TimeoutException('unknown');
      final n = container.read(metadataEditProvider(urn).notifier);
      await n.submit(
        entityUrn: EntityUrn.parse(urn),
        name: 'Different',
        authority: MetadataEditAuthority.admin,
      );
      await n.reconcile(EntityUrn.parse(urn));
      expect(
        container.read(metadataEditProvider(urn)).reconcileStatus,
        MetadataReconcileStatus.mismatch,
      );
      for (final status in [403, 404, 503]) {
        repo.detailError = ApiException(
          statusCode: status,
          code: 'test',
          message: 'private',
        );
        await n.reconcile(EntityUrn.parse(urn));
        expect(
          container.read(metadataEditProvider(urn)).isUnknownOutcome,
          isTrue,
        );
        repo.capturedInput = null;
        expect(
          await n.submit(
            entityUrn: EntityUrn.parse(urn),
            name: 'Again',
            authority: MetadataEditAuthority.admin,
          ),
          isFalse,
        );
        expect(repo.capturedInput, isNull);
      }
    },
  );
  test(
    'pending mutation authority revocation fences completion without unlocking',
    () async {
      final deferred = DeferredPatchRepo();
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          digitalTwinRepositoryProvider.overrideWithValue(deferred),
          permissionsRepositoryProvider.overrideWithValue(permissions),
          gatewayRepositoryProvider.overrideWithValue(FakeGatewayRepository()),
        ],
      );
      addTearDown(c.dispose);
      c
          .read(sessionProvider.notifier)
          .setSession(
            const SessionUser(userId: 'u1', name: 'M', email: 'm@example.com'),
          );
      await c.read(userPermissionsProvider.notifier).loadPermissions();
      c.listen(metadataEditProvider(urn), (_, _) {});
      final pending = c
          .read(metadataEditProvider(urn).notifier)
          .submit(
            entityUrn: EntityUrn.parse(urn),
            name: 'New',
            authority: MetadataEditAuthority.admin,
          );
      await Future<void>.delayed(Duration.zero);
      c.read(userPermissionsProvider.notifier).invalidateAdminPermissions();
      deferred.pending.complete(
        const PatchTwinResponseDto(
          id: urn,
          type: EntityType.gateway,
          gatewayId: 'gw-01',
          name: 'New',
          updatedAt: '2026-10-23T12:00:00Z',
        ),
      );
      expect(await pending, isFalse);
      expect(c.read(metadataEditProvider(urn)).isUnknownOutcome, isTrue);
    },
  );
  test('owner transfer is rechecked before PATCH without demoting independent admin', () async {
    final gateways = FakeGatewayRepository()
      ..items = [
        const GatewayItem(
          gatewayId: 'gw-01',
          name: 'G',
          role: GatewayRole.owner,
        ),
      ];
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        digitalTwinRepositoryProvider.overrideWithValue(repo),
        gatewayRepositoryProvider.overrideWithValue(gateways),
        permissionsRepositoryProvider.overrideWithValue(permissions),
      ],
    );
    addTearDown(c.dispose);
    c
        .read(sessionProvider.notifier)
        .setSession(
          const SessionUser(userId: 'u1', name: 'M', email: 'm@example.com'),
        );
    permissions.resultToReturn = const UserPermissions(isPlatformAdmin: false);
    await c.read(userPermissionsProvider.notifier).loadPermissions();
    await c.read(gatewayDetailProvider('gw-01').notifier).load();
    const sensor = 'urn:ngsi-ld:Sensor:gw-01:s';
    c.listen(metadataEditProvider(sensor), (_, _) {});
    gateways.items = [
      const GatewayItem(
        gatewayId: 'gw-01',
        name: 'G',
        role: GatewayRole.viewer,
      ),
    ];
    expect(
      await c
          .read(metadataEditProvider(sensor).notifier)
          .submit(
            entityUrn: EntityUrn.parse(sensor),
            name: 'New',
            authority: MetadataEditAuthority.owner,
          ),
      isFalse,
    );
    expect(repo.capturedInput, isNull);
    permissions.resultToReturn = const UserPermissions(isPlatformAdmin: true);
    await c.read(userPermissionsProvider.notifier).loadPermissions();
    expect(
      await c
          .read(metadataEditProvider(sensor).notifier)
          .submit(
            entityUrn: EntityUrn.parse(sensor),
            name: 'Admin rename',
            authority: MetadataEditAuthority.admin,
          ),
      isTrue,
    );
  });
  test('temporal query binding rejects wrong mode, range, ordering and overflow; permits partial edges', () {
    final start = DateTime.utc(2026, 10, 23);
    final end = start.add(const Duration(seconds: 10));
    final raw = TemporalQueryParameters(
      timeAt: start,
      endTimeAt: end,
      mode: TemporalQueryMode.raw,
    );
    TwinTemporalResponse response(List<TemporalRawPoint> points) =>
        TwinTemporalResponse(
          id: 'urn:ngsi-ld:Sensor:gw:s',
          type: 'Sensor',
          attrName: 'measurement',
          rawPoints: points,
        );
    for (final points in [
      [TemporalRawPoint(value: 1, observedAt: end)],
      [
        TemporalRawPoint(
          value: 1,
          observedAt: end.subtract(const Duration(seconds: 1)),
        ),
        TemporalRawPoint(value: 1, observedAt: start),
      ],
      List.generate(101, (_) => TemporalRawPoint(value: 1, observedAt: start)),
    ]) {
      final capped = TemporalQueryParameters(
        timeAt: start,
        endTimeAt: end,
        mode: TemporalQueryMode.raw,
        maxPoints: 100,
      );
      expect(
        () => response(points).validateFor('urn:ngsi-ld:Sensor:gw:s', capped),
        throwsFormatException,
      );
    }
    response([
      TemporalRawPoint(value: 1, observedAt: start),
      TemporalRawPoint(value: 2, observedAt: start),
    ]).validateFor('urn:ngsi-ld:Sensor:gw:s', raw);
    final bucket = TwinTemporalResponse(
      id: 'urn:ngsi-ld:Sensor:gw:s',
      type: 'Sensor',
      attrName: 'measurement',
      isAggregated: true,
      avgBuckets: [
        TemporalBucketPoint(
          value: 1.0,
          bucketStart: start.subtract(const Duration(seconds: 1)),
          bucketEnd: end.add(const Duration(seconds: 1)),
        ),
      ],
    );
    expect(() => bucket.validateFor(bucket.id, raw), throwsFormatException);
    expect(
      () => bucket.validateFor(
        bucket.id,
        TemporalQueryParameters(timeAt: start, endTimeAt: end),
      ),
      returnsNormally,
    );
  });
}
