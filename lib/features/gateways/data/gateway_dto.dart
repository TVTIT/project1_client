import 'package:flutter/foundation.dart';
import 'package:kite_ui/kite_ui.dart';

/// Role assigned to a user for a specific gateway via `user_gateways`.
enum GatewayRole {
  owner('owner'),
  operator('operator'),
  viewer('viewer');

  const GatewayRole(this.value);
  final String value;

  static GatewayRole fromString(String? val) => switch (val?.toLowerCase()) {
    'owner' => GatewayRole.owner,
    'operator' => GatewayRole.operator,
    'viewer' => GatewayRole.viewer,
    _ => GatewayRole.viewer,
  };

  String get label => switch (this) {
    GatewayRole.owner => 'Chủ sở hữu',
    GatewayRole.operator => 'Vận hành',
    GatewayRole.viewer => 'Chỉ xem',
  };

  KiteTone get tone => switch (this) {
    GatewayRole.owner => KiteTone.info,
    GatewayRole.operator => KiteTone.success,
    GatewayRole.viewer => KiteTone.neutral,
  };
}

/// Typed DTO for a Gateway item from `GET /v1/gateways`.
@immutable
class GatewayItem {
  const GatewayItem({
    required this.gatewayId,
    required this.name,
    this.description,
    required this.role,
    this.createdAt,
  });

  /// Authoritative unique gateway ID (regex `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`).
  final String gatewayId;

  /// Gateway display name.
  final String name;

  /// Optional plain text description (nullable).
  final String? description;

  /// User's specific role for this gateway from `user_gateways`.
  final GatewayRole role;

  /// ISO 8601 UTC creation timestamp (nullable).
  final DateTime? createdAt;

  factory GatewayItem.fromJson(Map<String, dynamic> json) {
    return GatewayItem(
      gatewayId: json['gateway_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      role: GatewayRole.fromString(json['role'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'gateway_id': gatewayId,
    'name': name,
    'description': description,
    'role': role.value,
    'created_at': createdAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GatewayItem &&
          runtimeType == other.runtimeType &&
          gatewayId == other.gatewayId &&
          name == other.name &&
          description == other.description &&
          role == other.role &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      Object.hash(gatewayId, name, description, role, createdAt);
}

/// DTO for response payload of `GET /v1/gateways`.
@immutable
class GatewayListResponse {
  const GatewayListResponse({required this.items});

  final List<GatewayItem> items;

  factory GatewayListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException(
        'Expected "items" array in gateway list response',
      );
    }
    return GatewayListResponse(
      items: rawItems
          .map((e) => GatewayItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Regex pattern for validating gateway ID (1-64 ASCII chars matching `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`).
final RegExp kGatewayIdRegex = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');

/// Reserved gateway ID forbidden in Go Backend router.
const String kReservedGatewayId = 'backend_service';

/// Validates gateway ID according to Stage 2 Go Backend contract:
/// - Exact ASCII 1-64 characters matching `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`.
/// - Reserved string `backend_service` is strictly forbidden.
/// - Preserves exact casing.
bool isValidGatewayId(String gatewayId) {
  if (gatewayId.isEmpty || gatewayId.length > 64) return false;
  if (gatewayId == kReservedGatewayId) return false;
  return kGatewayIdRegex.hasMatch(gatewayId);
}

/// Typed DTO for a Sensor item from `GET /v1/gateways/{gateway_id}/sensors`.
@immutable
class SensorItem {
  const SensorItem({
    required this.sensorId,
    required this.name,
    this.unit,
    this.createdAt,
  });

  /// Authoritative sensor ID (regex `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`).
  final String sensorId;

  /// Sensor display name.
  final String name;

  /// Sensor unit string (nullable, e.g. "°C", "%", or null).
  /// Note: Distinguishes null from empty string or '0'.
  final String? unit;

  /// ISO 8601 UTC creation timestamp (nullable).
  final DateTime? createdAt;

  factory SensorItem.fromJson(Map<String, dynamic> json) {
    final rawSensorId = json['sensor_id'];
    if (rawSensorId is! String || rawSensorId.isEmpty) {
      throw const FormatException(
        'Expected non-empty string "sensor_id" in sensor item',
      );
    }
    final rawName = json['name'];
    if (rawName is! String) {
      throw const FormatException('Expected string "name" in sensor item');
    }

    String? parsedUnit;
    if (json.containsKey('unit') && json['unit'] != null) {
      parsedUnit = json['unit'].toString();
    }

    DateTime? parsedCreatedAt;
    if (json['created_at'] != null) {
      parsedCreatedAt = DateTime.tryParse(json['created_at'].toString());
    }

    return SensorItem(
      sensorId: rawSensorId,
      name: rawName,
      unit: parsedUnit,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'sensor_id': sensorId,
    'name': name,
    'unit': unit,
    'created_at': createdAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorItem &&
          runtimeType == other.runtimeType &&
          sensorId == other.sensorId &&
          name == other.name &&
          unit == other.unit &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(sensorId, name, unit, createdAt);
}

/// DTO for response payload of `GET /v1/gateways/{gateway_id}/sensors`.
@immutable
class SensorListResponse {
  const SensorListResponse({required this.gatewayId, required this.items});

  /// The gateway ID echoed in the response envelope.
  final String gatewayId;

  /// List of sensors belonging to this gateway (empty list is valid empty state).
  final List<SensorItem> items;

  factory SensorListResponse.fromJson(
    Map<String, dynamic> json, {
    String? expectedGatewayId,
  }) {
    final rawGatewayId = json['gateway_id'];
    if (rawGatewayId is! String) {
      throw const FormatException(
        'Expected "gateway_id" in sensor list response',
      );
    }

    if (expectedGatewayId != null && rawGatewayId != expectedGatewayId) {
      throw FormatException(
        'Response gateway_id "$rawGatewayId" does not match expected "$expectedGatewayId"',
      );
    }

    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException(
        'Expected "items" array in sensor list response',
      );
    }

    return SensorListResponse(
      gatewayId: rawGatewayId,
      items: rawItems
          .map((e) => SensorItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
