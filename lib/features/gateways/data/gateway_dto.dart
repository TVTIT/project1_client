import 'dart:convert';

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

/// UUID validation constants.
final RegExp kUuidRegex = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
const String kNilUuid = '00000000-0000-0000-0000-000000000000';

/// Input payload for Platform Admin provisioning `PUT /v1/admin/gateways/{gateway_id}`.
///
/// Complies with Go backend `parseGatewayProvisioning`:
/// - `gateway_id`: 1–64 ASCII chars, `backend_service` strictly forbidden.
/// - `name`: required string, max 256 UTF-8 bytes.
/// - `description`: optional string (or null), max 4096 UTF-8 bytes.
/// - `owner_user_id`: required non-nil UUID string.
@immutable
class ProvisionGatewayInput {
  const ProvisionGatewayInput({
    required this.gatewayId,
    required this.name,
    this.description,
    required this.ownerUserId,
  });

  final String gatewayId;
  final String name;
  final String? description;
  final String ownerUserId;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim()
      else
        'description': null,
      'owner_user_id': ownerUserId.trim(),
    };
  }
}

/// Result returned from `PUT /v1/admin/gateways/{gateway_id}`.
///
/// Status code is preserved:
/// - [isCreated] == true for 201 Created (newly created)
/// - [isCreated] == false for 200 OK (identical idempotent replay)
@immutable
class ProvisionGatewayResult {
  const ProvisionGatewayResult({
    required this.isCreated,
    required this.gatewayId,
    required this.name,
    this.description,
    required this.ownerUserId,
    required this.entityId,
    this.createdAt,
  });

  final bool isCreated;
  final String gatewayId;
  final String name;
  final String? description;
  final String ownerUserId;
  final String entityId;
  final DateTime? createdAt;

  factory ProvisionGatewayResult.fromJson(
    Map<String, dynamic> json, {
    required int statusCode,
  }) {
    return ProvisionGatewayResult(
      isCreated: statusCode == 201,
      gatewayId: json['gateway_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      ownerUserId: json['owner_user_id'] as String? ?? '',
      entityId: json['entity_id'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toUtc()
          : null,
    );
  }
}

/// Validates gateway_id for provisioning input.
String? validateProvisionGatewayId(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập mã Gateway.';
  }
  final trimmed = value.trim();
  if (trimmed == kReservedGatewayId) {
    return 'Mã "$kReservedGatewayId" là định danh hệ thống dành riêng.';
  }
  if (!kGatewayIdRegex.hasMatch(trimmed)) {
    return 'Mã Gateway phải từ 1–64 ký tự (chữ cái, số, gạch ngang hoặc gạch dưới).';
  }
  return null;
}

/// Validates name for provisioning input (max 256 UTF-8 bytes).
String? validateProvisionName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập tên trạm Gateway.';
  }
  final trimmed = value.trim();
  if (utf8.encode(trimmed).length > 256) {
    return 'Tên trạm Gateway không được vượt quá 256 bytes UTF-8.';
  }
  return null;
}

/// Validates description for provisioning input (optional, max 4096 UTF-8 bytes).
String? validateProvisionDescription(String? value) {
  if (value == null || value.isEmpty) return null;
  if (utf8.encode(value).length > 4096) {
    return 'Mô tả trạm không được vượt quá 4096 bytes UTF-8.';
  }
  return null;
}

/// Validates owner_user_id for provisioning input (valid non-nil UUID).
String? validateProvisionOwnerUserId(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập mã người dùng sở hữu (owner_user_id).';
  }
  final trimmed = value.trim();
  if (!kUuidRegex.hasMatch(trimmed)) {
    return 'Mã người dùng phải là chuỗi định dạng UUID hợp lệ.';
  }
  if (trimmed.toLowerCase() == kNilUuid) {
    return 'Không được sử dụng nil UUID.';
  }
  return null;
}

/// Regex pattern for validating sensor ID (1–64 ASCII characters matching `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`).
/// Note: backend_service IS allowed for sensors (unlike gateways).
final RegExp kSensorIdRegex = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');

/// Validates sensor ID according to Stage 2 Go Backend contract:
/// - Exact ASCII 1-64 characters matching `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`.
/// - Preserves exact casing.
/// - `backend_service` IS allowed for sensors.
bool isValidSensorId(String sensorId) {
  if (sensorId.isEmpty || sensorId.length > 64) return false;
  return kSensorIdRegex.hasMatch(sensorId);
}

/// Input payload for Platform Admin sensor provisioning `PUT /v1/admin/gateways/{gateway_id}/sensors/{sensor_id}`.
///
/// Complies with Go backend `parseSensorProvisioning`:
/// - `name`: required string, max 256 UTF-8 bytes.
/// - `unit`: optional string (or null), max 64 UTF-8 bytes.
/// - Strictly NO `sensor_type` or extra fields.
@immutable
class ProvisionSensorInput {
  const ProvisionSensorInput({
    required this.gatewayId,
    required this.sensorId,
    required this.name,
    this.unit,
  });

  final String gatewayId;
  final String sensorId;
  final String name;
  final String? unit;

  Map<String, dynamic> toJson() {
    return {'name': name.trim(), 'unit': unit};
  }
}

/// Result returned from `PUT /v1/admin/gateways/{gateway_id}/sensors/{sensor_id}`.
///
/// Status code is preserved:
/// - [isCreated] == true for 201 Created (newly created)
/// - [isCreated] == false for 200 OK (identical idempotent replay)
@immutable
class ProvisionSensorResult {
  const ProvisionSensorResult({
    required this.isCreated,
    required this.gatewayId,
    required this.sensorId,
    required this.name,
    this.unit,
    required this.entityId,
    this.createdAt,
  });

  final bool isCreated;
  final String gatewayId;
  final String sensorId;
  final String name;
  final String? unit;
  final String entityId;
  final DateTime? createdAt;

  factory ProvisionSensorResult.fromJson(
    Map<String, dynamic> json, {
    required int statusCode,
  }) {
    return ProvisionSensorResult(
      isCreated: statusCode == 201,
      gatewayId: json['gateway_id'] as String? ?? '',
      sensorId: json['sensor_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String?,
      entityId: json['entity_id'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toUtc()
          : null,
    );
  }
}

/// Validates sensor_id for provisioning input.
String? validateProvisionSensorId(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập mã cảm biến (Sensor ID).';
  }
  final trimmed = value.trim();
  if (!kSensorIdRegex.hasMatch(trimmed)) {
    return 'Mã cảm biến phải từ 1–64 ký tự (chữ cái, số, gạch ngang hoặc gạch dưới).';
  }
  return null;
}

/// Validates name for sensor provisioning input (max 256 UTF-8 bytes).
String? validateProvisionSensorName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập tên cảm biến.';
  }
  final trimmed = value.trim();
  if (utf8.encode(trimmed).length > 256) {
    return 'Tên cảm biến không được vượt quá 256 bytes UTF-8.';
  }
  return null;
}

/// Validates unit for sensor provisioning input (optional, max 64 UTF-8 bytes).
String? validateProvisionSensorUnit(String? value) {
  if (value == null) return null;
  if (utf8.encode(value).length > 64) {
    return 'Đơn vị đo không được vượt quá 64 bytes UTF-8.';
  }
  return null;
}
