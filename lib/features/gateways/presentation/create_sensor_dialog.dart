import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../data/gateway_dto.dart';
import '../data/gateway_repository.dart';
import '../providers/gateway_detail_provider.dart';

/// Shows the create sensor modal dialog for confirmed platform administrators.
Future<ProvisionSensorResult?> showCreateSensorDialog(
  BuildContext context, {
  required String gatewayId,
}) {
  return showDialog<ProvisionSensorResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CreateSensorDialog(gatewayId: gatewayId),
  );
}

/// Dialog allowing Platform Administrators to provision a new sensor under a fixed parent Gateway.
///
/// Complies with Stage 2 requirements:
/// - Parent gateway ID is fixed and read-only.
/// - ONLY fields: `sensor_id`, `name`, `unit` (optional).
/// - `backend_service` is allowed for sensors.
/// - Distinguishes `null` unit vs empty string vs `'0'`.
/// - NO auto-retry mutations.
/// - Non-dismissible while submitting (`PopScope`).
/// - Double-submission prevention.
/// - Epoch, session, and permission revocation guards.
/// - On success: invalidates ONLY the relevant sensor catalog and pops dialog.
class CreateSensorDialog extends ConsumerStatefulWidget {
  const CreateSensorDialog({super.key, required this.gatewayId});

  final String gatewayId;

  @override
  ConsumerState<CreateSensorDialog> createState() => _CreateSensorDialogState();
}

class _CreateSensorDialogState extends ConsumerState<CreateSensorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _sensorIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;

  bool _isSubmitting = false;
  Object? _error;
  ProvisionSensorInput? _lastAttemptedInput;
  int _submitSeq = 0;

  @override
  void initState() {
    super.initState();
    _sensorIdController = TextEditingController();
    _nameController = TextEditingController();
    _unitController = TextEditingController();
  }

  @override
  void dispose() {
    _sensorIdController.dispose();
    _nameController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_formKey.currentState?.validate() != true) return;

    final unitRaw = _unitController.text.trim();
    final String? unitValue = unitRaw.isNotEmpty ? unitRaw : null;

    final input = ProvisionSensorInput(
      gatewayId: widget.gatewayId,
      sensorId: _sensorIdController.text.trim(),
      name: _nameController.text.trim(),
      unit: unitValue,
    );

    await _executeSubmit(input);
  }

  Future<void> _retry() async {
    final input = _lastAttemptedInput;
    if (input == null || _isSubmitting) return;
    await _executeSubmit(input);
  }

  Future<void> _executeSubmit(ProvisionSensorInput input) async {
    // Permission & session check before starting:
    final isAdmin = ref.read(isPlatformAdminProvider);
    if (!isAdmin) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(currentUserProvider)?.userId;
    final seq = ++_submitSeq;

    setState(() {
      _isSubmitting = true;
      _error = null;
      _lastAttemptedInput = input;
    });

    try {
      final repo = ref.read(gatewayRepositoryProvider);
      final result = await repo.provisionSensor(input);

      // Late response, disposal, or session switch guard:
      if (!mounted) return;
      if (seq != _submitSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId ||
          !ref.read(isPlatformAdminProvider)) {
        return;
      }

      // Invalidate ONLY relevant sensor catalog:
      unawaited(
        ref
            .read(gatewayDetailProvider(widget.gatewayId).notifier)
            .load(reloadSensorsOnly: true),
      );

      // Close dialog with authoritative result:
      Navigator.of(context).pop(result);

      // Display authoritative toast:
      final l = L.of(context);
      final toastTitle = result.isCreated
          ? l.sensorCreateSuccessCreated
          : l.sensorCreateSuccessReplayed;
      KiteToast.show(context, title: toastTitle, tone: KiteTone.success);
    } catch (e) {
      if (!mounted) return;
      if (seq != _submitSeq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      // If backend returns 403 Forbidden, immediately invalidate permissions fail-closed:
      if (e is ApiException && e.statusCode == 403) {
        ref.read(userPermissionsProvider.notifier).invalidateAdminPermissions();
      }

      setState(() {
        _isSubmitting = false;
        _error = e;
      });
    }
  }

  bool _forceClosing = false;

  void _forceClose() {
    _forceClosing = true;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // If admin permission is revoked while dialog is open, auto-dismiss
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
          constraints: const BoxConstraints(maxWidth: 540),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KiteSpace.xl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.sensorCreateDialogTitle, style: t.h4),
                            const SizedBox(height: KiteSpace.xs),
                            Text(l.sensorCreateDialogSubtitle, style: t.muted),
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

                  // Error Banner
                  if (_error != null) ...[
                    _buildErrorBanner(_error!, c, t, l),
                    const SizedBox(height: KiteSpace.lg),
                  ],

                  // 1. Parent Gateway ID (Read-only, fixed)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.sensorParentGateway,
                        style: t.p.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: KiteSpace.xs),
                      Container(
                        width: double.infinity,
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
                              Icons.lock_outline,
                              size: 16,
                              color: c.mutedForeground,
                            ),
                            const SizedBox(width: KiteSpace.sm),
                            Expanded(
                              child: Text(
                                widget.gatewayId,
                                style: t.small.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KiteSpace.lg),

                  // 2. Sensor ID
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.sensorFieldId,
                        style: t.p.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: KiteSpace.xs),
                      Text(
                        l.sensorFieldIdHint,
                        style: t.small.copyWith(color: c.mutedForeground),
                      ),
                      const SizedBox(height: KiteSpace.xs),
                      TextFormField(
                        controller: _sensorIdController,
                        enabled: !_isSubmitting,
                        validator: validateProvisionSensorId,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'ví dụ: sensor-dht22-temp',
                          hintStyle: t.muted,
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
                    ],
                  ),
                  const SizedBox(height: KiteSpace.lg),

                  // 3. Sensor Name
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.sensorFieldName,
                        style: t.p.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: KiteSpace.xs),
                      Text(
                        l.sensorFieldNameHint,
                        style: t.small.copyWith(color: c.mutedForeground),
                      ),
                      const SizedBox(height: KiteSpace.xs),
                      TextFormField(
                        controller: _nameController,
                        enabled: !_isSubmitting,
                        validator: validateProvisionSensorName,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'ví dụ: Cảm biến Nhiệt độ Môi trường',
                          hintStyle: t.muted,
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
                    ],
                  ),
                  const SizedBox(height: KiteSpace.lg),

                  // 4. Sensor Unit (Optional, distinguishes null vs empty vs "0")
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.sensorFieldUnit,
                        style: t.p.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: KiteSpace.xs),
                      Text(
                        l.sensorFieldUnitHint,
                        style: t.small.copyWith(color: c.mutedForeground),
                      ),
                      const SizedBox(height: KiteSpace.xs),
                      TextFormField(
                        controller: _unitController,
                        enabled: !_isSubmitting,
                        validator: validateProvisionSensorUnit,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'ví dụ: °C hoặc để trống',
                          hintStyle: t.muted,
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
                    ],
                  ),
                  const SizedBox(height: KiteSpace.xl),

                  // Action Buttons
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: KiteSpace.md,
                    runSpacing: KiteSpace.sm,
                    children: [
                      KiteButton.outline(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l.actionCancel),
                      ),
                      KiteButton(
                        onPressed: _isSubmitting ? null : _submit,
                        leading: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add, size: 16),
                        child: Text(
                          _isSubmitting
                              ? l.sensorCreateSubmitting
                              : l.sensorCreateSubmit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(Object error, KiteColors c, KiteText t, L l) {
    String message = 'Đã xảy ra lỗi khi khởi tạo cảm biến.';
    String? requestId;
    bool isRetryable = false;

    if (error is ApiException) {
      requestId = error.requestId;
      if (error.statusCode == 409) {
        message = l.sensorProvisionConflictError;
      } else if (error.statusCode == 404) {
        message = l.sensorProvisionNotFoundError;
      } else if (error.statusCode == 403) {
        message = l.sensorProvisionForbiddenError;
      } else if (error.message.isNotEmpty) {
        message = error.message;
      }
      if (error.statusCode == 503 || error.statusCode == 504) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 18, color: c.destructive),
              const SizedBox(width: KiteSpace.sm),
              Expanded(
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
          if (isRetryable) ...[
            const SizedBox(height: KiteSpace.sm),
            KiteButton.outline(
              onPressed: _retry,
              leading: const Icon(Icons.refresh, size: 14),
              child: Text(l.gatewayProvisionRetrySamePayload),
            ),
          ],
        ],
      ),
    );
  }
}
