import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permissions.dart';
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
    this.membershipRole,
    this.isSensorReadDenied = false,
    this.isOwner = false,
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

  /// Unified gateway metadata (role is nullable for admin inventory lookup).
  final GatewayCatalogItem? gateway;

  /// User's specific role for this gateway from `user_gateways` (null if not a member).
  final GatewayRole? membershipRole;

  /// True when confirmed admin accesses a gateway absent from user_gateways.
  final bool isSensorReadDenied;

  /// Prepared owner capability property for task 4 (true if membershipRole == GatewayRole.owner).
  final bool isOwner;

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
      isLoaded &&
      sensors.isEmpty &&
      sensorsError == null &&
      !isSensorReadDenied;

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
    GatewayCatalogItem? Function()? gateway,
    GatewayRole? Function()? membershipRole,
    bool? isSensorReadDenied,
    bool? isOwner,
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
      membershipRole: membershipRole != null
          ? membershipRole()
          : this.membershipRole,
      isSensorReadDenied: isSensorReadDenied ?? this.isSensorReadDenied,
      isOwner: isOwner ?? this.isOwner,
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
  int _authorityGen = 0;
  bool _adminLookupInFlight = false;

  @override
  GatewayDetailState build() {
    ref.watch(sessionProvider.select((s) => (s.status, s.user?.userId)));
    _seq++;
    final session = ref.read(sessionProvider);

    // If session is unauthenticated, reset to initial empty state
    if (!session.isAuthenticated) {
      _adminLookupInFlight = false;
      return GatewayDetailState(gatewayId: gatewayId);
    }

    ref.listen<UserPermissionsState>(userPermissionsProvider, (prev, next) {
      final wasConfirmedAdmin =
          prev != null &&
          !prev.isLoading &&
          !prev.hasError &&
          prev.isPlatformAdmin;
      final isConfirmedAdmin =
          !next.isLoading && !next.hasError && next.isPlatformAdmin;

      final isDowngradeOrUncertainty =
          (wasConfirmedAdmin ||
              state.isSensorReadDenied ||
              (state.gateway != null && state.membershipRole == null) ||
              _adminLookupInFlight) &&
          !isConfirmedAdmin;
      final isUpgrade =
          prev != null &&
          !prev.isLoading &&
          !wasConfirmedAdmin &&
          isConfirmedAdmin;

      if (isDowngradeOrUncertainty) {
        _authorityGen++;
        _seq++;
        _adminLookupInFlight = false;

        // Clear admin-only metadata (not valid user membership data) immediately
        if (state.membershipRole != null) {
          // User is a valid member in user_gateways; retain membership data & catalog
          if (state.isSensorReadDenied) {
            state = state.copyWith(isSensorReadDenied: false);
          }
        } else {
          // Admin-only metadata: clear immediately
          state = state.copyWith(
            status: next.hasError
                ? GatewayDetailStatus.error
                : GatewayDetailStatus.notFound,
            gateway: () => null,
            sensors: const [],
            isSensorReadDenied: false,
            isOwner: false,
            metadataError: () => next.hasError ? next.error : null,
          );
        }
      } else if (isUpgrade) {
        _authorityGen++;
        _seq++;
      }
    });

    return GatewayDetailState(gatewayId: gatewayId);
  }

  /// Composes Gateway details using `GET /v1/gateways` for metadata/role
  /// and `GET /v1/gateways/{id}/sensors` for sensor list.
  ///
  /// For confirmed Platform Admins:
  /// - Admin inventory lookup via keyset cursor pagination resolves real metadata
  ///   even when not assigned to `user_gateways`.
  /// - Sensor read access is not bypassed; absent gateway renders exact denial notice.
  /// - 404 on sensor reads preserves admin metadata rather than whole gateway 404.
  Future<void> load({bool reloadSensorsOnly = false}) async {
    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(currentUserProvider)?.userId;
    final seq = ++_seq;
    final capturedAuthGen = _authorityGen;

    // 1. Syntax & Reserved Word Validation
    if (!isValidGatewayId(gatewayId)) {
      state = state.copyWith(
        status: GatewayDetailStatus.notFound,
        invalidId: true,
        gateway: () => null,
        membershipRole: () => null,
        isOwner: false,
        isSensorReadDenied: false,
        sensors: const [],
      );
      return;
    }

    // 2. Partial reload: sensors only when metadata is already loaded
    if (reloadSensorsOnly && state.gateway != null) {
      if (state.isSensorReadDenied) {
        return;
      }
      state = state.copyWith(sensorsError: () => null);
      try {
        final repo = ref.read(gatewayRepositoryProvider);
        final sensorResponse = await repo.getGatewaySensors(gatewayId);

        if (!ref.mounted) return;
        if (seq != _seq ||
            capturedAuthGen != _authorityGen ||
            expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
            expectedUserId != ref.read(currentUserProvider)?.userId) {
          return;
        }

        state = state.copyWith(
          sensors: sensorResponse.items,
          sensorsError: () => null,
        );
      } catch (e) {
        if (!ref.mounted) return;
        if (seq != _seq ||
            capturedAuthGen != _authorityGen ||
            expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
            expectedUserId != ref.read(currentUserProvider)?.userId) {
          return;
        }
        if (e is ApiException && e.statusCode == 404) {
          final isAdminMetadata =
              state.gateway != null && state.membershipRole == null;
          if (isAdminMetadata) {
            state = state.copyWith(
              status: GatewayDetailStatus.loaded,
              membershipRole: () => null,
              isOwner: false,
              isSensorReadDenied: true,
              sensors: const [],
              sensorsError: () => null,
            );
            return;
          }
          state = state.copyWith(
            status: GatewayDetailStatus.notFound,
            gateway: () => null,
            membershipRole: () => null,
            isOwner: false,
            isSensorReadDenied: false,
            sensors: const [],
            sensorsError: () => null,
          );
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
      isSensorReadDenied: false,
    );

    // Verify system permissions first
    var permState = ref.read(userPermissionsProvider);
    if (permState.isLoading) {
      try {
        await ref.read(userPermissionsProvider.notifier).loadPermissions();
      } catch (_) {}
      permState = ref.read(userPermissionsProvider);
    }

    if (!ref.mounted) return;
    if (seq != _seq ||
        capturedAuthGen != _authorityGen ||
        expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
        expectedUserId != ref.read(currentUserProvider)?.userId) {
      return;
    }

    final repo = ref.read(gatewayRepositoryProvider);

    // Fetch user gateways to determine membership & role
    dynamic rawGateways;
    try {
      rawGateways = await repo.getGateways();
    } catch (e) {
      rawGateways = e;
    }

    if (!ref.mounted) return;
    if (seq != _seq ||
        capturedAuthGen != _authorityGen ||
        expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
        expectedUserId != ref.read(currentUserProvider)?.userId) {
      return;
    }

    // If user catalog failed with an error, show honest error (do NOT infer denied!)
    if (rawGateways is! List<GatewayItem>) {
      final metaErr = rawGateways;
      if (metaErr is ApiException && metaErr.statusCode == 404) {
        state = state.copyWith(
          status: GatewayDetailStatus.notFound,
          gateway: () => null,
          membershipRole: () => null,
          isOwner: false,
          isSensorReadDenied: false,
          sensors: const [],
        );
        return;
      }
      state = state.copyWith(
        status: GatewayDetailStatus.error,
        metadataError: () => metaErr,
        gateway: () => null,
        membershipRole: () => null,
        isOwner: false,
        isSensorReadDenied: false,
        sensors: const [],
      );
      return;
    }

    final userGateways = rawGateways;
    final foundUserGateway = userGateways.cast<GatewayItem?>().firstWhere(
      (g) => g?.gatewayId == gatewayId,
      orElse: () => null,
    );

    if (foundUserGateway != null) {
      // User has assigned membership on this gateway!
      final role = foundUserGateway.role;
      final catalogItem = GatewayCatalogItem.fromUserGateway(foundUserGateway);

      dynamic rawSensors;
      try {
        rawSensors = await repo.getGatewaySensors(gatewayId);
      } catch (e) {
        rawSensors = e;
      }

      if (!ref.mounted) return;
      if (seq != _seq ||
          capturedAuthGen != _authorityGen ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      if (rawSensors is SensorListResponse) {
        state = state.copyWith(
          status: GatewayDetailStatus.loaded,
          gateway: () => catalogItem,
          membershipRole: () => role,
          isOwner: role == GatewayRole.owner,
          isSensorReadDenied: false,
          sensors: rawSensors.items,
          sensorsError: () => null,
          metadataError: () => null,
        );
      } else {
        if (rawSensors is ApiException && rawSensors.statusCode == 404) {
          state = state.copyWith(
            status: GatewayDetailStatus.notFound,
            gateway: () => null,
            membershipRole: () => null,
            isOwner: false,
            isSensorReadDenied: false,
            sensors: const [],
          );
          return;
        }
        state = state.copyWith(
          status: GatewayDetailStatus.loaded,
          gateway: () => catalogItem,
          membershipRole: () => role,
          isOwner: role == GatewayRole.owner,
          isSensorReadDenied: false,
          sensors: const [],
          sensorsError: () => rawSensors,
          metadataError: () => null,
        );
      }
      return;
    }

    // User is NOT in user_gateways for this gatewayId.
    // Check permissions honestly before attempting foreign lookup:
    if (permState.hasError) {
      state = state.copyWith(
        status: GatewayDetailStatus.error,
        metadataError: () => permState.error,
        gateway: () => null,
        membershipRole: () => null,
        isOwner: false,
        isSensorReadDenied: false,
        sensors: const [],
      );
      return;
    }

    if (permState.isLoading) {
      state = state.copyWith(
        status: GatewayDetailStatus.error,
        metadataError: () => const ApiException(
          statusCode: 503,
          code: 'service_unavailable',
          message: 'Đang xác thực quyền truy cập hệ thống.',
        ),
        gateway: () => null,
        membershipRole: () => null,
        isOwner: false,
        isSensorReadDenied: false,
        sensors: const [],
      );
      return;
    }

    if (!permState.isPlatformAdmin) {
      // Ordinary foreign user: Anti-enumeration 404 Not Found
      state = state.copyWith(
        status: GatewayDetailStatus.notFound,
        gateway: () => null,
        membershipRole: () => null,
        isOwner: false,
        isSensorReadDenied: false,
        sensors: const [],
      );
      return;
    }

    // Confirmed Platform Admin: Resolve real metadata via keyset cursor lookup in Admin Inventory
    AdminGatewayItem? foundAdminGateway;
    String? cursor;
    const int kMaxLookupPages = 20;
    int pageCount = 0;
    final visitedCursors = <String>{};

    while (pageCount < kMaxLookupPages) {
      pageCount++;

      // Check authority and sequence before fetching subsequent pages:
      final currentPermsBefore = ref.read(userPermissionsProvider);
      final isConfirmedBefore =
          !currentPermsBefore.isLoading &&
          !currentPermsBefore.hasError &&
          currentPermsBefore.isPlatformAdmin;

      if (seq != _seq ||
          capturedAuthGen != _authorityGen ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId ||
          !isConfirmedBefore) {
        return;
      }

      if (cursor != null) {
        if (visitedCursors.contains(cursor)) {
          state = state.copyWith(
            status: GatewayDetailStatus.error,
            metadataError: () => const ApiException(
              statusCode: 500,
              code: 'cursor_loop_detected',
              message:
                  'Phát hiện vòng lặp con trỏ khi tra cứu Gateway trong kho.',
            ),
            gateway: () => null,
            membershipRole: () => null,
            isOwner: false,
            isSensorReadDenied: false,
            sensors: const [],
          );
          return;
        }
        visitedCursors.add(cursor);
      }

      final AdminGatewayInventoryResponse inventoryPage;
      try {
        _adminLookupInFlight = true;
        inventoryPage = await repo.getAdminGateways(after: cursor);
        _adminLookupInFlight = false;
      } catch (e) {
        _adminLookupInFlight = false;
        if (!ref.mounted) return;
        if (seq != _seq ||
            capturedAuthGen != _authorityGen ||
            expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
            expectedUserId != ref.read(currentUserProvider)?.userId) {
          return;
        }

        if (e is ApiException && e.statusCode == 403) {
          ref
              .read(userPermissionsProvider.notifier)
              .invalidateAdminPermissions();
          unawaited(
            ref.read(userPermissionsProvider.notifier).loadPermissions(),
          );
          state = state.copyWith(
            status: GatewayDetailStatus.error,
            metadataError: () => e,
            gateway: () => null,
            membershipRole: () => null,
            isOwner: false,
            sensors: const [],
            isSensorReadDenied: false,
          );
          return;
        }

        state = state.copyWith(
          status: GatewayDetailStatus.error,
          metadataError: () => e,
          gateway: () => null,
          membershipRole: () => null,
          isOwner: false,
          isSensorReadDenied: false,
          sensors: const [],
        );
        return;
      }

      if (!ref.mounted) return;
      final currentPermsAfter = ref.read(userPermissionsProvider);
      final isConfirmedAfter =
          !currentPermsAfter.isLoading &&
          !currentPermsAfter.hasError &&
          currentPermsAfter.isPlatformAdmin;

      if (seq != _seq ||
          capturedAuthGen != _authorityGen ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId ||
          !isConfirmedAfter) {
        return;
      }

      for (final item in inventoryPage.items) {
        if (item.gatewayId == gatewayId) {
          foundAdminGateway = item;
          break;
        }
        if (item.gatewayId.compareTo(gatewayId) > 0) {
          break;
        }
      }

      if (foundAdminGateway != null) {
        break;
      }

      // Check if order passed on this page (sorted ascending ASCII)
      if (inventoryPage.items.isNotEmpty &&
          inventoryPage.items.last.gatewayId.compareTo(gatewayId) > 0) {
        break;
      }

      if (!inventoryPage.hasMore ||
          inventoryPage.nextCursor == null ||
          inventoryPage.nextCursor!.isEmpty ||
          inventoryPage.items.isEmpty) {
        break;
      }

      cursor = inventoryPage.nextCursor;
    }

    if (foundAdminGateway == null && pageCount >= kMaxLookupPages) {
      state = state.copyWith(
        status: GatewayDetailStatus.error,
        metadataError: () => const ApiException(
          statusCode: 504,
          code: 'lookup_limit_exceeded',
          message: 'Vượt quá giới hạn tìm kiếm trạm trong kho lưu trữ Gateway.',
        ),
        gateway: () => null,
        membershipRole: () => null,
        isOwner: false,
        isSensorReadDenied: false,
        sensors: const [],
      );
      return;
    }

    final currentPermsFinal = ref.read(userPermissionsProvider);
    final isConfirmedFinal =
        !currentPermsFinal.isLoading &&
        !currentPermsFinal.hasError &&
        currentPermsFinal.isPlatformAdmin;

    if (seq != _seq ||
        capturedAuthGen != _authorityGen ||
        expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
        expectedUserId != ref.read(currentUserProvider)?.userId ||
        !isConfirmedFinal) {
      return;
    }

    if (foundAdminGateway == null) {
      // Gateway does not exist in inventory either
      state = state.copyWith(
        status: GatewayDetailStatus.notFound,
        gateway: () => null,
        membershipRole: () => null,
        isOwner: false,
        isSensorReadDenied: false,
        sensors: const [],
      );
      return;
    }

    // Found in admin inventory:
    // Render real metadata; sensor read is explicitly denied since admin is not in user_gateways
    final catalogItem = GatewayCatalogItem.fromAdminGateway(foundAdminGateway);
    state = state.copyWith(
      status: GatewayDetailStatus.loaded,
      gateway: () => catalogItem,
      membershipRole: () => null,
      isOwner: false,
      isSensorReadDenied: true,
      sensors: const [],
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
