import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../data/gateway_dto.dart';
import '../data/gateway_repository.dart';

/// Status of the Gateway Detail screen data composition.
enum GatewayDetailStatus { initial, loading, notFound, error, loaded }

/// State for the Gateway Detail and Sensor List screen.
@immutable
class GatewayDetailState {
  const GatewayDetailState({
    required this.gatewayId,
    this.status = GatewayDetailStatus.initial,
    this.gateway,
    this.sensors = const [],
    this.metadataError,
    this.sensorsError,
    this.searchQuery = '',
    this.invalidId = false,
  });

  /// The requested gateway identifier.
  final String gatewayId;

  /// High-level page status.
  final GatewayDetailStatus status;

  /// Gateway metadata and role obtained from `GET /v1/gateways`.
  final GatewayItem? gateway;

  /// Sensors list obtained from `GET /v1/gateways/{id}/sensors`.
  final List<SensorItem> sensors;

  /// Error encountered when fetching gateway metadata catalog.
  final Object? metadataError;

  /// Error encountered when fetching sensor list specifically.
  final Object? sensorsError;

  /// Local client-side search query for filtering sensors.
  final String searchQuery;

  /// Whether the requested gateway ID failed syntax or reserved-word validation.
  final bool invalidId;

  bool get isLoading => status == GatewayDetailStatus.loading;
  bool get isNotFound => status == GatewayDetailStatus.notFound;
  bool get hasGeneralError => status == GatewayDetailStatus.error;
  bool get hasSensorsError => sensorsError != null;
  bool get isLoaded => status == GatewayDetailStatus.loaded;
  bool get isSensorsEmpty =>
      isLoaded && sensors.isEmpty && sensorsError == null;

  List<SensorItem> get filteredSensors {
    if (searchQuery.trim().isEmpty) return sensors;
    final q = searchQuery.trim().toLowerCase();
    return sensors.where((s) {
      return s.sensorId.toLowerCase().contains(q) ||
          s.name.toLowerCase().contains(q) ||
          (s.unit != null && s.unit!.toLowerCase().contains(q));
    }).toList();
  }

  GatewayDetailState copyWith({
    String? gatewayId,
    GatewayDetailStatus? status,
    GatewayItem? Function()? gateway,
    List<SensorItem>? sensors,
    Object? Function()? metadataError,
    Object? Function()? sensorsError,
    String? searchQuery,
    bool? invalidId,
  }) {
    return GatewayDetailState(
      gatewayId: gatewayId ?? this.gatewayId,
      status: status ?? this.status,
      gateway: gateway != null ? gateway() : this.gateway,
      sensors: sensors ?? this.sensors,
      metadataError: metadataError != null
          ? metadataError()
          : this.metadataError,
      sensorsError: sensorsError != null ? sensorsError() : this.sensorsError,
      searchQuery: searchQuery ?? this.searchQuery,
      invalidId: invalidId ?? this.invalidId,
    );
  }
}

/// Notifier managing composition of Gateway metadata and Sensor catalog.
class GatewayDetailNotifier extends Notifier<GatewayDetailState> {
  GatewayDetailNotifier(this.gatewayId);

  final String gatewayId;
  int _seq = 0;

  @override
  GatewayDetailState build() {
    final session = ref.watch(sessionProvider);

    // If session is unauthenticated, reset to initial empty state
    if (!session.isAuthenticated) {
      return GatewayDetailState(gatewayId: gatewayId);
    }

    return GatewayDetailState(gatewayId: gatewayId);
  }

  /// Composes Gateway details using `GET /v1/gateways` for metadata/role
  /// and `GET /v1/gateways/{id}/sensors` for sensor list.
  ///
  /// Adheres strictly to Stage 2 boundaries:
  /// - No single-gateway GET invented (`GET /v1/gateways/{id}` does not exist).
  /// - Exact gateway ASCII 1-64 validation and reserved `backend_service` check.
  /// - Anti-enumeration defense: returns 404 NotFound on foreign/unknown gateways.
  /// - Session epoch isolation & out-of-order response discarding.
  /// - Distinguishes metadata failure vs sensor failure.
  Future<void> load({bool reloadSensorsOnly = false}) async {
    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final seq = ++_seq;

    // 1. Syntax & Reserved Word Validation
    if (!isValidGatewayId(gatewayId)) {
      state = state.copyWith(
        status: GatewayDetailStatus.notFound,
        invalidId: true,
      );
      return;
    }

    // 2. Partial reload: sensors only when metadata is already loaded
    if (reloadSensorsOnly && state.gateway != null) {
      state = state.copyWith(sensorsError: () => null);
      try {
        final repo = ref.read(gatewayRepositoryProvider);
        final sensorResponse = await repo.getGatewaySensors(gatewayId);

        if (seq != _seq ||
            expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch) {
          return;
        }

        state = state.copyWith(
          sensors: sensorResponse.items,
          sensorsError: () => null,
        );
      } catch (e) {
        if (seq != _seq ||
            expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch) {
          return;
        }
        state = state.copyWith(sensorsError: () => e);
      }
      return;
    }

    state = state.copyWith(
      status: GatewayDetailStatus.loading,
      metadataError: () => null,
      sensorsError: () => null,
    );

    final repo = ref.read(gatewayRepositoryProvider);

    // Concurrently fetch gateway catalog and sensors with error capture
    final results = await Future.wait([
      repo.getGateways().then<dynamic>((v) => v, onError: (Object e) => e),
      repo
          .getGatewaySensors(gatewayId)
          .then<dynamic>((v) => v, onError: (Object e) => e),
    ]);

    if (seq != _seq ||
        expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch) {
      return;
    }

    final rawGateways = results[0];
    final rawSensors = results[1];

    // Handle metadata failure
    if (rawGateways is! List<GatewayItem>) {
      final metaErr = rawGateways;
      if (metaErr is ApiException && metaErr.statusCode == 404) {
        state = state.copyWith(status: GatewayDetailStatus.notFound);
        return;
      }
      state = state.copyWith(
        status: GatewayDetailStatus.error,
        metadataError: () => metaErr,
      );
      return;
    }

    final gateways = rawGateways;

    // Verify existence in user's accessible gateways (preserving exact casing)
    final found = gateways.cast<GatewayItem?>().firstWhere(
      (g) => g?.gatewayId == gatewayId,
      orElse: () => null,
    );

    // Anti-enumeration: Missing or foreign gateway always yields 404 Not Found
    if (found == null) {
      state = state.copyWith(status: GatewayDetailStatus.notFound);
      return;
    }

    // Handle sensor response
    if (rawSensors is! SensorListResponse) {
      final sensErr = rawSensors;
      if (sensErr is ApiException && sensErr.statusCode == 404) {
        state = state.copyWith(status: GatewayDetailStatus.notFound);
        return;
      }
      state = state.copyWith(
        status: GatewayDetailStatus.loaded,
        gateway: () => found,
        sensors: const [],
        sensorsError: () => sensErr,
        metadataError: () => null,
      );
      return;
    }

    final sensorResp = rawSensors;

    state = state.copyWith(
      status: GatewayDetailStatus.loaded,
      gateway: () => found,
      sensors: sensorResp.items,
      sensorsError: () => null,
      metadataError: () => null,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final gatewayDetailProvider =
    NotifierProvider.family<GatewayDetailNotifier, GatewayDetailState, String>(
      (arg) => GatewayDetailNotifier(arg),
    );
