import 'package:flutter/foundation.dart';
import 'package:kite_ui/kite_ui.dart';

/// Business lifecycle status of the MQTT credential in Go backend.
enum MqttCredentialStatus {
  provisioning('provisioning'),
  active('active'),
  rotating('rotating'),
  revoking('revoking'),
  revoked('revoked'),
  failed('failed'),
  recoveryNeeded('recovery_needed');

  const MqttCredentialStatus(this.value);
  final String value;

  static MqttCredentialStatus fromString(String? val) =>
      switch (val?.toLowerCase()) {
        'provisioning' => MqttCredentialStatus.provisioning,
        'active' => MqttCredentialStatus.active,
        'rotating' => MqttCredentialStatus.rotating,
        'revoking' => MqttCredentialStatus.revoking,
        'revoked' => MqttCredentialStatus.revoked,
        'failed' => MqttCredentialStatus.failed,
        'recovery_needed' => MqttCredentialStatus.recoveryNeeded,
        _ => MqttCredentialStatus.failed,
      };

  String get label => switch (this) {
    MqttCredentialStatus.provisioning => 'Đang khởi tạo',
    MqttCredentialStatus.active => 'Hoạt động (Active)',
    MqttCredentialStatus.rotating => 'Đang xoay vòng',
    MqttCredentialStatus.revoking => 'Đang thu hồi',
    MqttCredentialStatus.revoked => 'Đã thu hồi (Revoked)',
    MqttCredentialStatus.failed => 'Thất bại (Failed)',
    MqttCredentialStatus.recoveryNeeded => 'Cần khôi phục (Recovery Needed)',
  };

  KiteTone get tone => switch (this) {
    MqttCredentialStatus.active => KiteTone.success,
    MqttCredentialStatus.provisioning ||
    MqttCredentialStatus.rotating => KiteTone.info,
    MqttCredentialStatus.revoked => KiteTone.neutral,
    MqttCredentialStatus.failed ||
    MqttCredentialStatus.revoking ||
    MqttCredentialStatus.recoveryNeeded => KiteTone.danger,
  };
}

/// Operation execution status.
enum MqttOperationStatus {
  pending('pending'),
  succeeded('succeeded'),
  failed('failed'),
  recoveryNeeded('recovery_needed');

  const MqttOperationStatus(this.value);
  final String value;

  static MqttOperationStatus fromString(String? val) =>
      switch (val?.toLowerCase()) {
        'pending' => MqttOperationStatus.pending,
        'succeeded' => MqttOperationStatus.succeeded,
        'failed' => MqttOperationStatus.failed,
        'recovery_needed' => MqttOperationStatus.recoveryNeeded,
        _ => MqttOperationStatus.pending,
      };

  String get label => switch (this) {
    MqttOperationStatus.pending => 'Đang xử lý',
    MqttOperationStatus.succeeded => 'Thành công',
    MqttOperationStatus.failed => 'Thất bại',
    MqttOperationStatus.recoveryNeeded => 'Cần phục hồi',
  };
}

/// Typed metadata returned from `GET /v1/admin/gateways/{id}/mqtt-credential`.
@immutable
class MqttCredentialMetadata {
  const MqttCredentialMetadata({
    required this.gatewayId,
    required this.username,
    required this.credentialVersion,
    required this.status,
    required this.lastOperationId,
    required this.operationStatus,
    this.activatedAt,
    this.revokedAt,
    this.lastErrorCode,
  });

  final String gatewayId;
  final String username;
  final int credentialVersion;
  final MqttCredentialStatus status;
  final String lastOperationId;
  final MqttOperationStatus operationStatus;
  final DateTime? activatedAt;
  final DateTime? revokedAt;
  final String? lastErrorCode;

  factory MqttCredentialMetadata.fromJson(Map<String, dynamic> json) {
    return MqttCredentialMetadata(
      gatewayId: json['gateway_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      credentialVersion: json['credential_version'] is int
          ? json['credential_version'] as int
          : int.tryParse(json['credential_version']?.toString() ?? '0') ?? 0,
      status: MqttCredentialStatus.fromString(json['status'] as String?),
      lastOperationId: json['last_operation_id'] as String? ?? '',
      operationStatus: MqttOperationStatus.fromString(
        json['operation_status'] as String?,
      ),
      activatedAt: json['activated_at'] != null
          ? DateTime.tryParse(json['activated_at'] as String)?.toUtc()
          : null,
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'] as String)?.toUtc()
          : null,
      lastErrorCode: json['last_error_code'] as String?,
    );
  }
}

/// Transient result returned on first `POST` (201 Created) or `POST /rotate` (200 OK)
/// containing the plaintext password delivered ONCE only.
///
/// Security: Must ONLY be held in transient widget memory, never persisted or logged.
@immutable
class MqttCredentialSecretResult {
  const MqttCredentialSecretResult({
    required this.metadata,
    required this.operationId,
    required this.password,
    required this.secretReturned,
  });

  final MqttCredentialMetadata metadata;
  final String operationId;
  final String password;
  final bool secretReturned;

  factory MqttCredentialSecretResult.fromJson(Map<String, dynamic> json) {
    return MqttCredentialSecretResult(
      metadata: MqttCredentialMetadata.fromJson(json),
      operationId: json['operation_id'] as String? ?? '',
      password: json['password'] as String? ?? '',
      secretReturned: json['secret_returned'] == true,
    );
  }
}

/// Result returned on `DELETE` (200 OK, revoked) or on idempotent replay with matching key (no password).
@immutable
class MqttCredentialMutationResult {
  const MqttCredentialMutationResult({
    required this.metadata,
    required this.operationId,
    required this.secretReturned,
    this.nextAction,
    this.replayedStatus,
    this.errorCode,
  });

  final MqttCredentialMetadata metadata;
  final String operationId;
  final bool secretReturned;
  final String? nextAction;
  final MqttOperationStatus? replayedStatus;
  final String? errorCode;

  factory MqttCredentialMutationResult.fromJson(Map<String, dynamic> json) {
    return MqttCredentialMutationResult(
      metadata: MqttCredentialMetadata.fromJson(json),
      operationId: json['operation_id'] as String? ?? '',
      secretReturned: json['secret_returned'] == true,
      nextAction: json['next_action'] as String?,
      replayedStatus: json['replayed_status'] != null
          ? MqttOperationStatus.fromString(json['replayed_status'] as String?)
          : null,
      errorCode: json['error_code'] as String?,
    );
  }
}
