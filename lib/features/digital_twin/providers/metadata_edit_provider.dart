import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../../gateways/data/gateway_dto.dart';
import '../../gateways/data/gateway_repository.dart';
import '../../gateways/providers/gateway_detail_provider.dart';
import '../../gateways/providers/gateway_list_provider.dart';
import '../data/digital_twin_dto.dart';
import '../data/digital_twin_repository.dart';
import 'digital_twin_providers.dart';
import 'twin_detail_provider.dart';
import 'twin_list_provider.dart';

/// Role authority classification for editing Digital Twin metadata.
enum MetadataEditAuthority {
  /// Confirmed Platform Admin (authority to edit Gateway or Sensor metadata).
  admin,

  /// Confirmed Gateway Owner in user_gateways (authority to edit Sensor metadata only).
  owner,
}

/// Resolves whether the current user is authorized to edit metadata for the given entity.
///
/// Authority rules:
/// - Gateway: Platform Admin ONLY. (Gateway Owner returns 403 on backend; operator/viewer denied).
/// - Sensor: Platform Admin OR Gateway Owner. (Operator/viewer denied).
/// - Loading / error permission state: fail closed (returns null).
MetadataEditAuthority? resolveMetadataEditAuthority({
  required UserPermissionsState permissionsState,
  required EntityType entityType,
  GatewayRole? membershipRole,
}) {
  if (permissionsState.isLoading || permissionsState.hasError) return null;

  // Confirmed Platform Admin takes precedence and can edit both Gateway and Sensor.
  if (permissionsState.isPlatformAdmin) {
    return MetadataEditAuthority.admin;
  }

  // Non-admin can NEVER edit Gateway metadata (backend returns 403 Forbidden).
  if (entityType == EntityType.gateway) {
    return null;
  }

  // For Sensor: non-admin can edit if confirmed Gateway Owner in user_gateways.
  if (membershipRole == GatewayRole.owner) {
    return MetadataEditAuthority.owner;
  }

  return null;
}

enum MetadataEditStatus { initial, submitting, success, error, unknownOutcome }

enum MetadataReconcileStatus {
  none,
  checking,
  confirmed,
  mismatch,
  cannotVerify,
}

@immutable
class MetadataEditState {
  static const _unchanged = Object();
  const MetadataEditState({
    this.status = MetadataEditStatus.initial,
    this.authority,
    this.result,
    this.error,
    this.errorMessage,
    this.requestId,
    this.requestedInput,
    this.reconcileStatus = MetadataReconcileStatus.none,
    this.reconcileMessage,
  });

  final MetadataEditStatus status;
  final MetadataEditAuthority? authority;
  final PatchTwinResponseDto? result;
  final Object? error;
  final String? errorMessage;
  final String? requestId;
  final PatchTwinAttrsInput? requestedInput;
  final MetadataReconcileStatus reconcileStatus;
  final String? reconcileMessage;

  bool get isSubmitting => status == MetadataEditStatus.submitting;
  bool get isSuccess => status == MetadataEditStatus.success;
  bool get isUnknownOutcome => status == MetadataEditStatus.unknownOutcome;
  bool get isReconciling => reconcileStatus == MetadataReconcileStatus.checking;

  MetadataEditState copyWith({
    MetadataEditStatus? status,
    Object? authority = _unchanged,
    Object? result = _unchanged,
    Object? error = _unchanged,
    Object? errorMessage = _unchanged,
    Object? requestId = _unchanged,
    Object? requestedInput = _unchanged,
    MetadataReconcileStatus? reconcileStatus,
    Object? reconcileMessage = _unchanged,
  }) {
    return MetadataEditState(
      status: status ?? this.status,
      authority: identical(authority, _unchanged)
          ? this.authority
          : authority as MetadataEditAuthority?,
      result: identical(result, _unchanged)
          ? this.result
          : result as PatchTwinResponseDto?,
      error: identical(error, _unchanged) ? this.error : error,
      errorMessage: identical(errorMessage, _unchanged)
          ? this.errorMessage
          : errorMessage as String?,
      requestId: identical(requestId, _unchanged)
          ? this.requestId
          : requestId as String?,
      requestedInput: identical(requestedInput, _unchanged)
          ? this.requestedInput
          : requestedInput as PatchTwinAttrsInput?,
      reconcileStatus: reconcileStatus ?? this.reconcileStatus,
      reconcileMessage: identical(reconcileMessage, _unchanged)
          ? this.reconcileMessage
          : reconcileMessage as String?,
    );
  }
}

class MetadataEditNotifier extends Notifier<MetadataEditState> {
  MetadataEditNotifier(this.entityUrn);
  final String entityUrn;

  int _submitSeq = 0;
  VoidCallback? _releaseLock;

  @override
  MetadataEditState build() {
    ref.watch(twinSessionScopeProvider);
    _submitSeq++;
    final entity = EntityUrn.parse(entityUrn);
    void authorityChanged() {
      final authority = resolveMetadataEditAuthority(
        permissionsState: ref.read(userPermissionsProvider),
        entityType: entity.type,
        membershipRole: ref
            .read(gatewayDetailProvider(entity.gatewayId))
            .membershipRole,
      );
      if (authority == null && state.isSubmitting) {
        _submitSeq++;
        // A request may already have reached the server. Losing authority is
        // not evidence of failure, and must never enable a blind resend.
        state = state.copyWith(status: MetadataEditStatus.unknownOutcome);
      }
    }

    ref.listen(userPermissionsProvider, (_, _) => authorityChanged());
    ref.listen(
      gatewayDetailProvider(entity.gatewayId).select((s) => s.membershipRole),
      (_, _) => authorityChanged(),
    );
    return const MetadataEditState();
  }

  /// Submits the metadata patch mutation.
  Future<bool> submit({
    required EntityUrn entityUrn,
    String? name,
    String? description,
    bool clearDescription = false,
    required MetadataEditAuthority authority,
  }) async {
    final scoped = EntityUrn.parse(this.entityUrn);
    if (state.isSubmitting ||
        state.isUnknownOutcome ||
        state.isSuccess ||
        !ref.read(sessionProvider).isAuthenticated ||
        entityUrn.urn != this.entityUrn ||
        entityUrn.type != scoped.type ||
        entityUrn.gatewayId != scoped.gatewayId ||
        entityUrn.sensorId != scoped.sensorId ||
        (entityUrn.type == EntityType.sensor &&
            (description != null || clearDescription))) {
      return false;
    }
    final resolved = resolveMetadataEditAuthority(
      permissionsState: ref.read(userPermissionsProvider),
      entityType: entityUrn.type,
      membershipRole: ref
          .read(gatewayDetailProvider(entityUrn.gatewayId))
          .membershipRole,
    );
    if (resolved == null || resolved != authority) return false;

    final input = PatchTwinAttrsInput(
      name: name,
      description: description,
      clearDescription: clearDescription,
    );

    try {
      input.validate();
    } catch (e) {
      state = state.copyWith(status: MetadataEditStatus.error, error: e);
      return false;
    }

    final seq = ++_submitSeq;
    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(sessionProvider).user?.userId;

    // Keep uncertain outcomes locked even if the dialog is dismissed/reopened.
    _releaseLock = ref.keepAlive().close;
    state = MetadataEditState(
      status: MetadataEditStatus.submitting,
      authority: authority,
      requestedInput: input,
      error: null,
      errorMessage: null,
      requestId: null,
      reconcileStatus: MetadataReconcileStatus.none,
      reconcileMessage: null,
    );

    var dispatched = false;
    try {
      final permissions = await ref
          .read(permissionsRepositoryProvider)
          .getMyPermissions();
      if (!ref.mounted ||
          seq != _submitSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(sessionProvider).user?.userId) {
        return false;
      }
      var permitted = permissions.isPlatformAdmin;
      if (!permitted && entityUrn.type == EntityType.sensor) {
        final gateways = await ref
            .read(gatewayRepositoryProvider)
            .getGateways();
        permitted = gateways.any(
          (g) =>
              g.gatewayId == entityUrn.gatewayId && g.role == GatewayRole.owner,
        );
      }
      if (!ref.mounted ||
          seq != _submitSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(sessionProvider).user?.userId) {
        return false;
      }
      if (!permitted) {
        _releaseLock?.call();
        state = const MetadataEditState(status: MetadataEditStatus.error);
        unawaited(
          ref.read(gatewayDetailProvider(entityUrn.gatewayId).notifier).load(),
        );
        return false;
      }
      final repo = ref.read(digitalTwinRepositoryProvider);
      dispatched = true;
      final result = await repo.patchTwinAttrs(entityUrn.urn, input);

      // Late response / session switch guard:
      if (!ref.mounted ||
          seq != _submitSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(sessionProvider).user?.userId) {
        return false;
      }

      if (result.id != entityUrn.urn ||
          result.type != entityUrn.type ||
          result.gatewayId != entityUrn.gatewayId ||
          result.sensorId != entityUrn.sensorId) {
        throw const FormatException('Wrong mutation response identity');
      }
      state = MetadataEditState(
        status: MetadataEditStatus.success,
        result: result,
      );
      _releaseLock?.call();

      // Invalidate relevant scopes only:
      _invalidateRelevantScopes(entityUrn);
      return true;
    } catch (e) {
      if (!ref.mounted ||
          seq != _submitSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(sessionProvider).user?.userId) {
        return false;
      }

      if (e is TimeoutException ||
          e is NetworkException ||
          e is FormatException ||
          (dispatched && e is! ApiException) ||
          (e is ApiException && e.statusCode >= 500)) {
        // Timeout / 503 / network failure: outcome is UNKNOWN!
        final reqId = e is ApiException ? e.requestId : null;
        state = state.copyWith(
          status: MetadataEditStatus.unknownOutcome,
          error: e,
          requestId: reqId,
        );
        return false;
      }

      if (e is ApiException) {
        _releaseLock?.call();
        // Definite failure (400, 403, 404, etc.):
        state = state.copyWith(
          status: MetadataEditStatus.error,
          error: e,
          requestId: e.requestId,
        );

        if (e.statusCode == 403 && authority == MetadataEditAuthority.owner) {
          // Owner received 403: gateway role might have changed. Invalidate authority.
          unawaited(
            ref
                .read(gatewayDetailProvider(entityUrn.gatewayId).notifier)
                .load(),
          );
        }
        return false;
      }

      state = state.copyWith(status: MetadataEditStatus.error, error: e);
      _releaseLock?.call();
      return false;
    }
  }

  /// Reconciles an unknown mutation outcome via metadata readback.
  Future<void> reconcile(EntityUrn entityUrn) async {
    if (!state.isUnknownOutcome ||
        state.isReconciling ||
        entityUrn.urn != this.entityUrn ||
        !ref.read(sessionProvider).isAuthenticated) {
      return;
    }
    final requested = state.requestedInput;
    if (requested == null) return;

    state = state.copyWith(
      reconcileStatus: MetadataReconcileStatus.checking,
      reconcileMessage: null,
    );

    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(sessionProvider).user?.userId;
    final seq = ++_submitSeq;

    try {
      final repo = ref.read(digitalTwinRepositoryProvider);
      final detailPage = await repo.getTwinDetail(entityUrn.urn);

      if (!ref.mounted ||
          seq != _submitSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(sessionProvider).user?.userId) {
        return;
      }

      final detail = detailPage.detail;
      if (detail.entity.urn != this.entityUrn) {
        throw const FormatException('Wrong readback identity');
      }
      bool matches = true;

      if (requested.name != null && detail.name?.value != requested.name) {
        matches = false;
      }
      if (requested.clearDescription && detail.description != null) {
        matches = false;
      } else if (requested.description != null &&
          detail.description?.value != requested.description) {
        matches = false;
      }

      if (matches) {
        _releaseLock?.call();
        state = state.copyWith(
          status: MetadataEditStatus.success,
          error: null,
          errorMessage: null,
          reconcileStatus: MetadataReconcileStatus.confirmed,
        );
        _invalidateRelevantScopes(entityUrn);
      } else {
        state = state.copyWith(
          reconcileStatus: MetadataReconcileStatus.mismatch,
        );
      }
    } catch (e) {
      if (!ref.mounted ||
          seq != _submitSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(sessionProvider).user?.userId) {
        return;
      }

      if (e is ApiException && e.statusCode == 404) {
        // Admin mutation authority is independent from read authority.
        // If readback returns 404, we cannot verify without membership.
        // Do NOT report patch failure, do NOT force unlock/blind retry.
        state = state.copyWith(
          reconcileStatus: MetadataReconcileStatus.cannotVerify,
        );
        return;
      }

      state = state.copyWith(
        reconcileStatus: MetadataReconcileStatus.cannotVerify,
      );
    }
  }

  void _invalidateRelevantScopes(EntityUrn entityUrn) {
    unawaited(
      ref.read(gatewayDetailProvider(entityUrn.gatewayId).notifier).load(),
    );
    unawaited(ref.read(gatewayListProvider.notifier).loadGateways());
    ref.invalidate(twinDetailProvider(entityUrn.urn)); // auto-loads on build
    final list = ref.read(twinListProvider);
    unawaited(
      ref
          .read(twinListProvider.notifier)
          .load(type: list.type, gatewayId: list.gatewayId),
    );
  }

  void reset() {
    if (state.isSubmitting || state.isUnknownOutcome || state.isSuccess) return;
    state = const MetadataEditState();
  }
}

final metadataEditProvider = NotifierProvider.autoDispose
    .family<MetadataEditNotifier, MetadataEditState, String>(
      MetadataEditNotifier.new,
    );
