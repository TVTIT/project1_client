import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/uuid_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../data/gateway_dto.dart';
import '../data/gateway_repository.dart';
import '../data/mqtt_credential_dto.dart';

/// Shows the MQTT Credential management dialog.
Future<void> showMqttCredentialDialog(
  BuildContext context, {
  String? initialGatewayId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => MqttCredentialDialog(initialGatewayId: initialGatewayId),
  );
}

/// Dialog allowing Platform Administrators to inspect, provision, rotate, and revoke
/// MQTT credentials for a gateway according to Stage 2 Go Backend contracts.
class MqttCredentialDialog extends ConsumerStatefulWidget {
  const MqttCredentialDialog({super.key, this.initialGatewayId});

  final String? initialGatewayId;

  @override
  ConsumerState<MqttCredentialDialog> createState() =>
      _MqttCredentialDialogState();
}

class _MqttCredentialDialogState extends ConsumerState<MqttCredentialDialog> {
  late final TextEditingController _gatewayIdController;

  bool _isLoading = false;
  bool _isSubmitting = false;
  Object? _error;
  MqttCredentialMetadata? _metadata;
  bool _isRuntimeDisabled = false;

  // Transient secret state: NEVER logged, persisted, or held outside this widget instance
  String? _deliveredPassword;
  bool _isSecretRevealed = false;

  // Idempotency tracking for explicit approved same-key retry on timeout
  String? _lastAttemptedIdempotencyKey;
  String? _lastAttemptedAction; // 'provision', 'rotate', 'revoke'
  int _opSeq = 0;
  bool _isReconciledAfterTimeout = false;

  @override
  void initState() {
    super.initState();
    _gatewayIdController = TextEditingController(
      text: widget.initialGatewayId ?? '',
    );

    if (widget.initialGatewayId != null &&
        widget.initialGatewayId!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMetadata();
      });
    }
  }

  @override
  void dispose() {
    _gatewayIdController.dispose();
    _clearSecret();
    super.dispose();
  }

  void _clearSecret() {
    _deliveredPassword = null;
    _isSecretRevealed = false;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm UTC';
  }

  Future<void> _loadMetadata() async {
    final gatewayId = _gatewayIdController.text.trim();
    if (gatewayId.isEmpty || !isValidGatewayId(gatewayId)) return;

    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(currentUserProvider)?.userId;
    final seq = ++_opSeq;

    setState(() {
      _isLoading = true;
      _error = null;
      _isRuntimeDisabled = false;
      _clearSecret();
    });

    try {
      final repo = ref.read(gatewayRepositoryProvider);
      final meta = await repo.getMqttCredential(gatewayId);

      if (!mounted) return;
      if (seq != _opSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId ||
          !ref.read(isPlatformAdminProvider)) {
        return;
      }

      setState(() {
        _isLoading = false;
        _metadata = meta;
        _error = null;
        _isReconciledAfterTimeout = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (seq != _opSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      bool runtimeDisabled = false;
      if (e is ApiException) {
        if (e.code == 'credential_runtime_disabled') {
          runtimeDisabled = true;
        } else if (e.statusCode == 403) {
          ref
              .read(userPermissionsProvider.notifier)
              .invalidateAdminPermissions();
        }
      }

      setState(() {
        _isLoading = false;
        _error = e;
        _isRuntimeDisabled = runtimeDisabled;
      });
    }
  }

  Future<void> _confirmAndExecute({
    required String action, // 'provision', 'rotate', 'revoke'
    required String title,
    required String warningMessage,
    required Future<Object> Function(String gatewayId, String key) requestFn,
    String? approvedKey,
  }) async {
    if (_isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: KiteColors.of(ctx).destructive,
            ),
            const SizedBox(width: KiteSpace.sm),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(warningMessage),
        actions: [
          KiteButton.outline(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(L.of(ctx).actionCancel),
          ),
          KiteButton.destructive(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận thực hiện'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final gatewayId = _gatewayIdController.text.trim();
    final idempotencyKey = approvedKey ?? generateUuidV4();
    _lastAttemptedIdempotencyKey = idempotencyKey;
    _lastAttemptedAction = action;

    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(currentUserProvider)?.userId;
    final seq = ++_opSeq;

    setState(() {
      _isSubmitting = true;
      _error = null;
      _clearSecret();
    });

    try {
      final res = await requestFn(gatewayId, idempotencyKey);

      if (!mounted) return;
      if (seq != _opSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId ||
          !ref.read(isPlatformAdminProvider)) {
        return;
      }

      if (res is MqttCredentialSecretResult) {
        setState(() {
          _isSubmitting = false;
          _metadata = res.metadata;
          _deliveredPassword = res.password;
          _error = null;
        });
      } else if (res is MqttCredentialMutationResult) {
        setState(() {
          _isSubmitting = false;
          _metadata = res.metadata;
          _clearSecret();
          _error = null;
        });
      }

      KiteToast.show(
        context,
        title: action == 'revoke'
            ? 'Thu hồi thông tin xác thực MQTT thành công (HTTP 200 OK).'
            : 'Thực hiện thao tác MQTT thành công.',
        tone: KiteTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      if (seq != _opSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      bool runtimeDisabled = false;
      if (e is ApiException) {
        if (e.code == 'credential_runtime_disabled') {
          runtimeDisabled = true;
        } else if (e.statusCode == 403) {
          ref
              .read(userPermissionsProvider.notifier)
              .invalidateAdminPermissions();
        }
      }

      setState(() {
        _isSubmitting = false;
        _error = e;
        _isRuntimeDisabled = runtimeDisabled;
        if (e is TimeoutException ||
            (e is ApiException && e.statusCode == 504)) {
          _isReconciledAfterTimeout = false;
        }
      });
    }
  }

  void _copyPassword() {
    if (_deliveredPassword == null) return;
    Clipboard.setData(ClipboardData(text: _deliveredPassword!));
    KiteToast.show(
      context,
      title: 'Đã sao chép mật khẩu. Lưu ý: Mật khẩu chỉ hiển thị một lần duy nhất, hãy bảo mật thông tin này.',
      tone: KiteTone.success,
    );
  }

  bool _forceClosing = false;

  void _forceClose() {
    _forceClosing = true;
    _clearSecret();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // If admin permission is revoked while dialog is open, auto-dismiss fail-closed
    final isPlatformAdmin = ref.watch(isPlatformAdminProvider);
    if (!isPlatformAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _forceClose();
      });
      return const SizedBox.shrink();
    }

    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);
    final isFixedGateway = widget.initialGatewayId != null;

    return PopScope(
      canPop: _forceClosing || !_isSubmitting,
      child: Dialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: KiteRadius.allLg,
          side: BorderSide(color: c.border),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: KiteSpace.lg,
          vertical: KiteSpace.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KiteSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Thông tin xác thực MQTT (DynSec)', style: t.h4),
                          const SizedBox(height: KiteSpace.xs),
                          Text(
                            'Quản lý thông tin xác thực MQTT cho Gateway (Chỉ dành cho Quản trị viên nền tảng).',
                            style: t.muted,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      color: c.mutedForeground,
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: KiteSpace.lg),

                // Gateway ID selector or fixed display
                if (isFixedGateway)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KiteSpace.md,
                      vertical: KiteSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: c.muted,
                      borderRadius: KiteRadius.allMd,
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.router_outlined,
                          size: 16,
                          color: c.mutedForeground,
                        ),
                        const SizedBox(width: KiteSpace.sm),
                        Expanded(
                          child: Text(
                            'Mã trạm Gateway: ${widget.initialGatewayId}',
                            style: t.small.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _gatewayIdController,
                          enabled: !_isSubmitting && !_isLoading,
                          onChanged: (_) {
                            // Clear secret, metadata and errors when target gateway changes
                            if (_metadata != null ||
                                _deliveredPassword != null ||
                                _error != null) {
                              setState(() {
                                _metadata = null;
                                _error = null;
                                _clearSecret();
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Nhập mã Gateway cần quản trị',
                            hintText: 'ví dụ: gw-station-alpha',
                            border: OutlineInputBorder(
                              borderRadius: KiteRadius.allMd,
                              borderSide: BorderSide(color: c.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: KiteSpace.md,
                              vertical: KiteSpace.sm,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: KiteSpace.sm),
                      KiteButton(
                        onPressed: _isLoading || _isSubmitting
                            ? null
                            : _loadMetadata,
                        leading: _isLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search, size: 16),
                        child: const Text('Tra cứu'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: KiteSpace.lg),

                // Error / Runtime Disabled Banner
                if (_error != null) ...[
                  _buildErrorBanner(_error!, c, t, l),
                  const SizedBox(height: KiteSpace.lg),
                ],

                // Secret Display Card (delivered once!)
                if (_deliveredPassword != null) ...[
                  _buildDeliveredSecretCard(c, t),
                  const SizedBox(height: KiteSpace.lg),
                ],

                // Metadata Card
                if (_metadata != null) ...[
                  _buildMetadataCard(_metadata!, c, t),
                  const SizedBox(height: KiteSpace.lg),
                ],

                // Action Controls
                _buildActionButtons(c, t, l),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveredSecretCard(KiteColors c, KiteText t) {
    const successColor = Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.all(KiteSpace.md),
      decoration: BoxDecoration(
        color: successColor.withAlpha(20),
        borderRadius: KiteRadius.allMd,
        border: Border.all(color: successColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: KiteSpace.sm,
            runSpacing: KiteSpace.xs,
            children: [
              const Icon(Icons.vpn_key_outlined, size: 18, color: successColor),
              Text(
                'Mật khẩu MQTT mới (Chỉ hiển thị một lần duy nhất)',
                style: t.p.copyWith(
                  fontWeight: FontWeight.w600,
                  color: successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: KiteSpace.xs),
          Text(
            'Lưu ý bảo mật: Mật khẩu này chỉ được chuyển giao 1 lần duy nhất qua phản hồi này. Vui lòng sao chép và cập nhật ngay vào Gateway qua nạp an toàn.',
            style: t.small.copyWith(color: c.mutedForeground),
          ),
          const SizedBox(height: KiteSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KiteSpace.md,
              vertical: KiteSpace.sm,
            ),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: KiteRadius.allSm,
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isSecretRevealed
                        ? _deliveredPassword!
                        : '•' * (_deliveredPassword!.length.clamp(8, 24)),
                    style: t.p.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isSecretRevealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSecretRevealed = !_isSecretRevealed;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: _copyPassword,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(
    MqttCredentialMetadata meta,
    KiteColors c,
    KiteText t,
  ) {
    return Container(
      padding: const EdgeInsets.all(KiteSpace.md),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: KiteRadius.allMd,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: KiteSpace.sm,
            runSpacing: KiteSpace.xs,
            children: [
              Text(
                'Trạng thái xác thực',
                style: t.p.copyWith(fontWeight: FontWeight.w600),
              ),
              KiteBadge(meta.status.label, tone: meta.status.tone),
            ],
          ),
          const Divider(height: KiteSpace.lg),
          _buildInfoRow('Tên đăng nhập (Username):', meta.username, t),
          const SizedBox(height: KiteSpace.xs),
          _buildInfoRow(
            'Phiên bản Credential:',
            'v${meta.credentialVersion}',
            t,
          ),
          const SizedBox(height: KiteSpace.xs),
          _buildInfoRow('Trạng thái thao tác:', meta.operationStatus.label, t),
          const SizedBox(height: KiteSpace.xs),
          _buildInfoRow('Kích hoạt lúc:', _formatDate(meta.activatedAt), t),
          const SizedBox(height: KiteSpace.xs),
          _buildInfoRow('Thu hồi lúc:', _formatDate(meta.revokedAt), t),
          if (meta.lastErrorCode != null) ...[
            const SizedBox(height: KiteSpace.xs),
            _buildInfoRow(
              'Mã lỗi gần nhất:',
              meta.lastErrorCode!,
              t,
              isError: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    KiteText t, {
    bool isError = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: KiteSpace.sm,
          runSpacing: KiteSpace.xs,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Text(label, style: t.small.copyWith(color: Colors.grey)),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Text(
                value,
                style: t.small.copyWith(
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                  color: isError ? Colors.red : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(KiteColors c, KiteText t, L l) {
    final gatewayId = _gatewayIdController.text.trim();
    final isValid = isValidGatewayId(gatewayId);
    final hasUnreconciledTimeout =
        _lastAttemptedAction != null && !_isReconciledAfterTimeout;
    final isBusy =
        _isSubmitting ||
        _isLoading ||
        !isValid ||
        _isRuntimeDisabled ||
        hasUnreconciledTimeout;

    final isAlreadyActive = _metadata?.status == MqttCredentialStatus.active;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: KiteSpace.sm,
          runSpacing: KiteSpace.sm,
          alignment: WrapAlignment.end,
          children: [
            KiteButton.outline(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(l.actionCancel),
            ),

            // Refresh metadata button
            KiteButton.outline(
              onPressed: _isSubmitting || !isValid ? null : _loadMetadata,
              leading: const Icon(Icons.refresh, size: 14),
              child: const Text('Làm mới'),
            ),

            // 1. Provision button (initial provision or after revoked)
            if (!isAlreadyActive)
              KiteButton(
                onPressed: isBusy
                    ? null
                    : () => _confirmAndExecute(
                        action: 'provision',
                        title: 'Cấp phát Thông tin Xác thực MQTT',
                        warningMessage: 'Cảnh báo vận hành: Cấp phát mới sẽ kích hoạt khởi động nguội broker (cold restart), ngắt kết nối tạm thời TOÀN BỘ Gateway trên hệ thống! Vui lòng xác nhận trước khi tiếp tục.',
                        requestFn: (id, key) => ref
                            .read(gatewayRepositoryProvider)
                            .provisionMqttCredential(id, idempotencyKey: key),
                      ),
                leading: const Icon(Icons.add_moderator, size: 14),
                child: const Text('Cấp phát ban đầu'),
              ),

            // 2. Rotate button (when active)
            if (isAlreadyActive)
              KiteButton(
                onPressed: isBusy
                    ? null
                    : () => _confirmAndExecute(
                        action: 'rotate',
                        title: 'Xoay vòng Mật khẩu MQTT',
                        warningMessage: 'Cảnh báo vận hành: Xoay vòng mật khẩu sẽ kích hoạt khởi động nguội broker (cold restart), ngắt kết nối tạm thời TOÀN BỘ Gateway trên hệ thống! Vui lòng xác nhận trước khi tiếp tục.',
                        requestFn: (id, key) => ref
                            .read(gatewayRepositoryProvider)
                            .rotateMqttCredential(id, idempotencyKey: key),
                      ),
                leading: const Icon(Icons.sync, size: 14),
                child: const Text('Xoay vòng mật khẩu'),
              ),

            // 3. Revoke button (when active)
            if (isAlreadyActive)
              KiteButton.destructive(
                onPressed: isBusy
                    ? null
                    : () => _confirmAndExecute(
                        action: 'revoke',
                        title: 'Thu hồi Thông tin Xác thực MQTT',
                        warningMessage: 'Cảnh báo vận hành: Thu hồi thông tin xác thực sẽ ngắt kết nối socket ngay lập tức và vô hiệu hóa quyền truy cập broker của trạm Gateway này (thao tác cục bộ cho riêng trạm). Vui lòng xác nhận trước khi tiếp tục.',
                        requestFn: (id, key) => ref
                            .read(gatewayRepositoryProvider)
                            .revokeMqttCredential(id, idempotencyKey: key),
                      ),
                leading: const Icon(Icons.delete_forever, size: 14),
                child: const Text('Thu hồi'),
              ),

            // 4. Approved Retry button when reconciled after timeout
            if (_isReconciledAfterTimeout &&
                _lastAttemptedAction != null &&
                _lastAttemptedIdempotencyKey != null)
              KiteButton.outline(
                onPressed: isBusy
                    ? null
                    : () {
                        final key = _lastAttemptedIdempotencyKey!;
                        final action = _lastAttemptedAction!;
                        if (action == 'provision') {
                          _confirmAndExecute(
                            action: 'provision',
                            title: 'Thử lại Cấp phát (Cùng Idempotency-Key)',
                            warningMessage:
                                'Thao tác sẽ gửi lại yêu cầu cấp phát với cùng khóa lũy quyền được phê duyệt ($key).',
                            requestFn: (id, k) => ref
                                .read(gatewayRepositoryProvider)
                                .provisionMqttCredential(id, idempotencyKey: k),
                            approvedKey: key,
                          );
                        } else if (action == 'rotate') {
                          _confirmAndExecute(
                            action: 'rotate',
                            title: 'Thử lại Xoay vòng (Cùng Idempotency-Key)',
                            warningMessage:
                                'Thao tác sẽ gửi lại yêu cầu xoay vòng với cùng khóa lũy quyền được phê duyệt ($key).',
                            requestFn: (id, k) => ref
                                .read(gatewayRepositoryProvider)
                                .rotateMqttCredential(id, idempotencyKey: k),
                            approvedKey: key,
                          );
                        } else if (action == 'revoke') {
                          _confirmAndExecute(
                            action: 'revoke',
                            title: 'Thử lại Thu hồi (Cùng Idempotency-Key)',
                            warningMessage:
                                'Thao tác sẽ gửi lại yêu cầu thu hồi với cùng khóa lũy quyền được phê duyệt ($key).',
                            requestFn: (id, k) => ref
                                .read(gatewayRepositoryProvider)
                                .revokeMqttCredential(id, idempotencyKey: k),
                            approvedKey: key,
                          );
                        }
                      },
                leading: const Icon(Icons.refresh, size: 14),
                child: const Text('Thử lại (Cùng Idempotency-Key)'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner(Object error, KiteColors c, KiteText t, L l) {
    String message = 'Đã xảy ra lỗi trong thao tác xác thực MQTT.';
    String? requestId;
    bool isRetryable = false;

    if (error is ApiException) {
      requestId = error.requestId;
      if (error.code == 'credential_runtime_disabled' ||
          error.statusCode == 503) {
        message = 'Tính năng Quản lý MQTT Credential hiện đang bị vô hiệu hóa trên máy chủ (MQTT_CREDENTIAL_API_ENABLED=false). Vui lòng liên hệ quản trị viên hạ tầng để kích hoạt.';
      } else if (error.statusCode == 404) {
        message = 'Trạm Gateway chưa có thông tin xác thực MQTT hoặc không tồn tại (HTTP 404 Not Found).';
      } else if (error.statusCode == 409) {
        message = 'Xung đột trạng thái Credential (HTTP 409 Conflict): Thao tác đang được xử lý hoặc xung đột với trạng thái hiện tại.';
      } else if (error.statusCode == 403) {
        message = 'Từ chối truy cập (HTTP 403 Forbidden). Bạn không có quyền Quản trị viên nền tảng.';
      } else if (error.message.isNotEmpty) {
        message = error.message;
      }
      if (error.statusCode == 504) {
        isRetryable = true;
      }
    } else if (error is NetworkException) {
      message = error.message;
      isRetryable = true;
    }

    return Container(
      padding: const EdgeInsets.all(KiteSpace.md),
      decoration: BoxDecoration(
        color: c.destructive.withAlpha(20),
        borderRadius: KiteRadius.allMd,
        border: Border.all(color: c.destructive.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: KiteSpace.sm,
            runSpacing: KiteSpace.xs,
            children: [
              Icon(Icons.error_outline, size: 18, color: c.destructive),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message,
                  style: t.p.copyWith(
                    color: c.destructive,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (requestId != null && requestId.isNotEmpty) ...[
            const SizedBox(height: KiteSpace.xs),
            Text(
              'Mã yêu cầu (Request ID): $requestId',
              style: t.small.copyWith(
                color: c.mutedForeground,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (isRetryable &&
              _lastAttemptedAction != null &&
              _lastAttemptedIdempotencyKey != null) ...[
            const SizedBox(height: KiteSpace.sm),
            Wrap(
              spacing: KiteSpace.sm,
              children: [
                KiteButton.outline(
                  onPressed: _loadMetadata,
                  leading: const Icon(Icons.info_outline, size: 14),
                  child: const Text('Đọc metadata'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
