import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Regex pattern for RFC 5322 email validation without surrounding whitespace.
final RegExp kEmailRegex = RegExp(
  r'^[a-zA-Z0-9.!#$%&'
  "'"
  r'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
);

/// UUID validation constants.
final RegExp kUuidRegex = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
const String kNilUuid = '00000000-0000-0000-0000-000000000000';

/// Normalizes email by trimming outside whitespace only, preserving exact casing.
String normalizeEmail(String raw) {
  return raw.trim();
}

/// Validates full_name for user creation/update (1–256 UTF-8 bytes, non-blank).
String? validateFullName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Họ và tên không được để trống.';
  }
  final bytes = utf8.encode(value);
  if (bytes.length > 256) {
    return 'Họ và tên không được vượt quá 256 bytes UTF-8.';
  }
  return null;
}

/// Validates email format according to backend rules (RFC 5322, max 254 bytes).
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email không được để trống.';
  }
  final trimmed = value.trim();
  if (trimmed.length > 254) {
    return 'Email không được vượt quá 254 ký tự.';
  }
  if (!kEmailRegex.hasMatch(trimmed)) {
    return 'Địa chỉ email không đúng định dạng.';
  }
  return null;
}

/// Validates password (6 runes to max 72 UTF-8 bytes).
///
/// Security: password is NEVER normalized, trimmed, cached, or logged.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Mật khẩu không được để trống.';
  }
  if (value.runes.length < 6) {
    return 'Mật khẩu phải có ít nhất 6 ký tự.';
  }
  final bytes = utf8.encode(value);
  if (bytes.length > 72) {
    return 'Mật khẩu không được vượt quá 72 bytes UTF-8.';
  }
  return null;
}

/// Input payload for creating a user account (`POST /v1/admin/users`).
@immutable
class CreateUserInput {
  const CreateUserInput({
    required this.fullName,
    required this.email,
    required this.password,
  });

  final String fullName;
  final String email;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName.trim(),
      'email': normalizeEmail(email),
      'password': password, // Never trim or normalize password
    };
  }
}

/// Response payload from creating a user account (`POST /v1/admin/users`).
@immutable
class CreatedUser {
  const CreatedUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.platformRole,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String platformRole;
  final DateTime createdAt;

  factory CreatedUser.fromJson(Map<String, dynamic> json) {
    return CreatedUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      platformRole: json['platform_role'] as String? ?? 'user',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toUtc() ??
                DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }
}

/// Input payload for updating user profile or role (`PATCH /v1/admin/users/{user_id}`).
@immutable
class UpdateUserInput {
  const UpdateUserInput({this.fullName, this.platformRole});

  final String? fullName;
  final String? platformRole;

  /// Serializes to JSON, strictly omitting null fields (backend rejects null literals with 400).
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (fullName != null) {
      map['full_name'] = fullName!.trim();
    }
    if (platformRole != null) {
      map['platform_role'] = platformRole;
    }
    return map;
  }
}

/// Response payload from updating user (`PATCH /v1/admin/users/{user_id}`).
@immutable
class UpdatedUser {
  const UpdatedUser({
    required this.id,
    this.fullName,
    required this.platformRole,
  });

  final String id;
  final String? fullName;
  final String platformRole;

  factory UpdatedUser.fromJson(Map<String, dynamic> json) {
    return UpdatedUser(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String?,
      platformRole: json['platform_role'] as String? ?? 'user',
    );
  }
}

/// Membership role of a user on a specific gateway.
@immutable
class UserGatewayRole {
  const UserGatewayRole({required this.gatewayId, required this.role});

  final String gatewayId;
  final String role;

  factory UserGatewayRole.fromJson(Map<String, dynamic> json) {
    return UserGatewayRole(
      gatewayId: json['gateway_id'] as String? ?? '',
      role: json['role'] as String? ?? 'viewer',
    );
  }
}

/// User item from the full bounded user list (`GET /v1/admin/users`).
@immutable
class UserSummary {
  const UserSummary({
    required this.id,
    required this.email,
    this.fullName,
    required this.platformRole,
    required this.createdAt,
    required this.gatewayRoles,
  });

  final String id;
  final String email;
  final String? fullName;
  final String platformRole;
  final DateTime createdAt;
  final List<UserGatewayRole> gatewayRoles;

  bool get isPlatformAdmin => platformRole == 'platform_admin';

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['gateway_roles'] as List<dynamic>? ?? const [];
    return UserSummary(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String?,
      platformRole: json['platform_role'] as String? ?? 'user',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toUtc() ??
                DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      gatewayRoles: rawRoles
          .map((r) => UserGatewayRole.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Full bounded response envelope for `GET /v1/admin/users`.
@immutable
class UserListResponse {
  const UserListResponse({required this.items});

  final List<UserSummary> items;

  factory UserListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException(
        'Expected "items" array in user list response',
      );
    }
    return UserListResponse(
      items: rawItems
          .map((item) => UserSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Result of assigning gateway user membership (`PUT /v1/admin/gateways/{gateway_id}/users/{user_id}`).
@immutable
class AssignGatewayUserResult {
  const AssignGatewayUserResult({
    required this.gatewayId,
    required this.userId,
    required this.role,
  });

  final String gatewayId;
  final String userId;
  final String role;

  factory AssignGatewayUserResult.fromJson(Map<String, dynamic> json) {
    return AssignGatewayUserResult(
      gatewayId: json['gateway_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }
}

/// Result of transferring gateway ownership (`PUT /v1/admin/gateways/{gateway_id}/owner`).
@immutable
class TransferGatewayOwnerResult {
  const TransferGatewayOwnerResult({
    required this.gatewayId,
    required this.ownerUserId,
  });

  final String gatewayId;
  final String ownerUserId;

  factory TransferGatewayOwnerResult.fromJson(Map<String, dynamic> json) {
    return TransferGatewayOwnerResult(
      gatewayId: json['gateway_id'] as String? ?? '',
      ownerUserId: json['owner_user_id'] as String? ?? '',
    );
  }
}
