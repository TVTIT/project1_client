import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../data/gateway_dto.dart';
import '../data/gateway_repository.dart';

/// State for the Gateway Provisioning flow.
@immutable
class GatewayProvisionState {
  const GatewayProvisionState({
    this.isSubmitting = false,
    this.result,
    this.error,
    this.lastAttemptedInput,
  });

  final bool isSubmitting;
  final ProvisionGatewayResult? result;
  final Object? error;
  final ProvisionGatewayInput? lastAttemptedInput;

  bool get hasError => error != null;
  bool get isSuccess => result != null;

  GatewayProvisionState copyWith({
    bool? isSubmitting,
    ProvisionGatewayResult? Function()? result,
    Object? Function()? error,
    ProvisionGatewayInput? Function()? lastAttemptedInput,
  }) {
    return GatewayProvisionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result != null ? result() : this.result,
      error: error != null ? error() : this.error,
      lastAttemptedInput: lastAttemptedInput != null
          ? lastAttemptedInput()
          : this.lastAttemptedInput,
    );
  }
}

/// Controller managing Platform Admin gateway provisioning mutations.
///
/// Complies with Stage 2 requirements:
/// - Mutation via `PUT /v1/admin/gateways/{gateway_id}`.
/// - Preserves 201 Created vs 200 OK replay semantics.
/// - Does NOT auto-retry on 401 or network failure; preserves [lastAttemptedInput] for explicit operator retry.
/// - Epoch-fenced to prevent cross-session request/response leakage.
/// - Authoritative result shown in-page; does NOT blindly navigate to foreign gateway details.
class GatewayProvisionNotifier extends Notifier<GatewayProvisionState> {
  int _seq = 0;

  @override
  GatewayProvisionState build() {
    // Session-isolated: purge any provisioning state on session change
    ref.watch(sessionProvider);
    return const GatewayProvisionState();
  }

  Future<bool> submit(ProvisionGatewayInput input) async {
    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(currentUserProvider)?.userId;
    final seq = ++_seq;

    state = state.copyWith(
      isSubmitting: true,
      error: () => null,
      lastAttemptedInput: () => input,
    );

    try {
      final repo = ref.read(gatewayRepositoryProvider);
      final res = await repo.provisionGateway(input);

      // Epoch & sequence fencing:
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return false;
      }

      state = state.copyWith(
        isSubmitting: false,
        result: () => res,
        error: () => null,
      );
      return true;
    } catch (e) {
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return false;
      }

      state = state.copyWith(isSubmitting: false, error: () => e);
      return false;
    }
  }

  /// Explicitly retries the mutation using the exact last attempted input payload.
  Future<bool> retryLastAttempt() async {
    final input = state.lastAttemptedInput;
    if (input == null) return false;
    return submit(input);
  }

  /// Resets state to allow provisioning another gateway.
  void reset() {
    state = const GatewayProvisionState();
  }
}

final gatewayProvisionProvider =
    NotifierProvider<GatewayProvisionNotifier, GatewayProvisionState>(
      GatewayProvisionNotifier.new,
    );
