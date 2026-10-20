import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/states.dart';
import '../data/user_dto.dart';
import '../data/user_repository.dart';
import '../providers/user_providers.dart';

/// Opens the dialog to edit a user's full name and/or platform role.
Future<UpdatedUser?> showEditUserDialog(
  BuildContext context, {
  required UserSummary user,
}) {
  return showDialog<UpdatedUser>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => EditUserDialog(user: user),
  );
}

/// Dialog allowing Platform Administrators to update a user's name or role.
///
/// Complies with C4 rules & security boundaries:
/// - Edits ONLY `full_name` and/or `platform_role`.
/// - Never sends email or password (read-only identity fields).
/// - Nullable legacy name handled cleanly (initial text empty if null).
/// - At least one changed field required; unchanged fields are omitted from PATCH JSON.
/// - Never sends null literals.
/// - Actor can rename self, but CANNOT select self-demotion to "user".
/// - Server 409 `self_admin_demotion_forbidden` handled atomically.
/// - Explicit confirmation checkbox required before granting or revoking Platform Admin.
/// - No optimistic authority: authority changes only take effect upon 200 OK.
/// - On success: refreshes user list, and if actor updated self, refreshes own permissions/profile.
/// - Admin endpoint 403 clears admin data/capabilities and retains session.
/// - Fenced by session/permission changes; disabled duplicate sends; unknown outcome warning.
class EditUserDialog extends ConsumerStatefulWidget {
  const EditUserDialog({super.key, required this.user});

  final UserSummary user;

  @override
  ConsumerState<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late String _selectedRole;

  bool _roleConfirmed = false;
  bool _isSubmitting = false;
  bool _unknownOutcome = false;
  Object? _error;

  int? _initialEpoch;
  String? _initialUserId;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.user.fullName ?? '',
    );
    _selectedRole = widget.user.platformRole;
    _initialEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    _initialUserId = ref.read(currentUserProvider)?.userId;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  bool _isSessionMismatch() {
    final currentEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final currentUserId = ref.read(currentUserProvider)?.userId;
    if (_initialEpoch != null && currentEpoch != _initialEpoch) return true;
    if (_initialUserId != null && currentUserId != _initialUserId) return true;
    return false;
  }

  bool _isSelf(String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) return false;
    return widget.user.id.trim().toLowerCase() ==
        currentUserId.trim().toLowerCase();
  }

  bool _hasNameChanged() {
    final currentTrimmed = _fullNameController.text.trim();
    final original = widget.user.fullName ?? '';
    return currentTrimmed != original;
  }

  bool _hasRoleChanged() {
    return _selectedRole != widget.user.platformRole;
  }

  bool _canSave(bool isSelf) {
    if (_isSubmitting || _unknownOutcome) return false;
    final nameChanged = _hasNameChanged();
    final roleChanged = _hasRoleChanged();
    if (!nameChanged && !roleChanged) return false;

    // Self cannot demote to user
    if (isSelf && _selectedRole == 'user') return false;

    // If role changed, explicit confirmation is mandatory
    if (roleChanged && !_roleConfirmed) return false;

    return true;
  }

  Future<void> _submit() async {
    final currentUserId = ref.read(currentUserProvider)?.userId;
    final isSelf = _isSelf(currentUserId);

    if (!_canSave(isSelf) || _isSessionMismatch()) {
      if (_isSessionMismatch()) Navigator.of(context).pop();
      return;
    }
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final nameChanged = _hasNameChanged();
    final roleChanged = _hasRoleChanged();

    // Guard self demotion client-side
    if (isSelf && _selectedRole == 'user') {
      setState(() {
        _error = const ApiException(
          statusCode: 409,
          code: 'self_admin_demotion_forbidden',
          message: 'Bạn không thể tự hạ quyền Quản trị viên của chính mình.',
        );
      });
      return;
    }

    final input = UpdateUserInput(
      fullName: nameChanged ? _fullNameController.text.trim() : null,
      platformRole: roleChanged ? _selectedRole : null,
    );

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ref.read(userRepositoryProvider);
      final updated = await repo.updateUser(widget.user.id, input);

      if (!mounted) return;
      if (_isSessionMismatch()) {
        Navigator.of(context).pop();
        return;
      }

      // On mutation success: refresh user list
      unawaited(ref.read(userListProvider.notifier).loadUsers());

      // If actor updated self: refresh permissions (no false Auth metadata sync)
      if (isSelf) {
        unawaited(ref.read(userPermissionsProvider.notifier).loadPermissions());
      }

      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_isSessionMismatch()) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _isSubmitting = false);

      if (e.statusCode == 403) {
        // Admin endpoint 403 clears admin capabilities while retaining session
        if (!_isSessionMismatch()) {
          ref
              .read(userPermissionsProvider.notifier)
              .invalidateAdminPermissions();
        }
        setState(() => _error = e);
      } else if (e.statusCode == 409 &&
          e.code == 'self_admin_demotion_forbidden') {
        // Rollback role selection on self-demotion conflict
        setState(() {
          _selectedRole = widget.user.platformRole;
          _roleConfirmed = false;
          _error = e;
        });
      } else if (e.statusCode == 503) {
        setState(() {
          _unknownOutcome = true;
          _error = e;
        });
      } else {
        setState(() => _error = e);
      }
    } on NetworkException catch (e) {
      if (!mounted) return;
      if (_isSessionMismatch()) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _isSubmitting = false;
        _unknownOutcome = true;
        _error = e;
      });
    } catch (e) {
      if (!mounted) return;
      if (_isSessionMismatch()) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Session and permission change fences: detect authenticated A -> B switch as well
    ref.listen(sessionProvider, (_, session) {
      if (!session.isAuthenticated || _isSessionMismatch()) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }
      }
    });
    ref.listen(userPermissionsProvider, (_, perms) {
      if (!perms.isPlatformAdmin && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
    });

    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);

    // Initial permission render barrier
    final permsState = ref.watch(userPermissionsProvider);
    if (permsState.isLoading) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(KiteSpace.xl),
          child: LoadingState(),
        ),
      );
    }
    if (!permsState.isPlatformAdmin || permsState.hasError) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(KiteSpace.xl),
          child: ErrorState(
            message: l.gatewayProvisionAccessDeniedMessage,
            onRetry: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    final currentUserId = ref.watch(currentUserProvider)?.userId;
    final isSelf = _isSelf(currentUserId);

    String? errorMessage;
    String? requestId;
    if (_error is ApiException) {
      final apiErr = _error as ApiException;
      requestId = apiErr.requestId;
      if (apiErr.statusCode == 409 &&
          apiErr.code == 'self_admin_demotion_forbidden') {
        errorMessage = l.adminUserSelfDemotionForbidden;
      } else {
        errorMessage = apiErr.message;
      }
    } else if (_error is NetworkException) {
      errorMessage = (_error as NetworkException).message;
    } else if (_error != null) {
      errorMessage = 'Đã xảy ra sự cố không xác định.';
    }

    final canSave = _canSave(isSelf);
    final roleChanged = _hasRoleChanged();

    return Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: KiteRadius.allMd,
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(KiteSpace.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l.adminUserEditTitle,
                        style: t.h4.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: KiteSpace.lg),
                const Divider(height: 1),
                const SizedBox(height: KiteSpace.lg),

                // Error alert box
                if (errorMessage != null && !_unknownOutcome) ...[
                  Container(
                    padding: const EdgeInsets.all(KiteSpace.md),
                    decoration: BoxDecoration(
                      color: c.destructive.withValues(alpha: 0.1),
                      borderRadius: KiteRadius.allSm,
                      border: Border.all(
                        color: c.destructive.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          errorMessage,
                          style: t.small.copyWith(color: c.destructive),
                        ),
                        if (requestId != null) ...[
                          const SizedBox(height: KiteSpace.xs),
                          Text(
                            'Request ID: $requestId',
                            style: t.muted.copyWith(
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: KiteSpace.md),
                ],

                // Unknown outcome warning banner
                if (_unknownOutcome) ...[
                  Container(
                    padding: const EdgeInsets.all(KiteSpace.md),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: KiteRadius.allSm,
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: KiteSpace.sm),
                            Expanded(
                              child: Text(
                                'Kết quả cập nhật chưa xác định',
                                style: t.small.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: KiteSpace.xs),
                        Text(
                          'Yêu cầu cập nhật có thể đã được thực thi nhưng phản hồi bị gián đoạn. Tuyệt đối không tự ý thử lại nhiều lần.',
                          style: t.small.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KiteSpace.md),
                ],

                // Read-only email and UUID
                Text('Email', style: t.muted),
                const SizedBox(height: KiteSpace.xs),
                SelectableText(
                  widget.user.email,
                  style: t.small.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: KiteSpace.sm),

                Text(
                  'UUID',
                  overflow: TextOverflow.ellipsis,
                  style: t.muted.copyWith(fontFamily: 'monospace'),
                ),
                Row(
                  children: [
                    Expanded(child: SelectableText(widget.user.id)),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.copy_outlined, size: 14),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.user.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép UUID vào bộ nhớ tạm'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: KiteSpace.md),

                // Full Name input field (editable)
                Text(
                  l.adminUserFullName,
                  style: t.small.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: KiteSpace.xs),
                TextFormField(
                  controller: _fullNameController,
                  enabled: !_isSubmitting,
                  onChanged: (_) => setState(() {}),
                  validator: validateFullName,
                  decoration: const InputDecoration(
                    hintText: 'Nhập họ và tên...',
                  ),
                ),
                const SizedBox(height: KiteSpace.lg),

                // Platform Role Selection
                Text(
                  l.adminUserRole,
                  style: t.small.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: KiteSpace.xs),

                RadioGroup<String>(
                  groupValue: _selectedRole,
                  onChanged: (val) {
                    if (_isSubmitting) return;
                    if (val != null) {
                      setState(() {
                        _selectedRole = val;
                        _roleConfirmed = false;
                      });
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: Text(l.adminUserRoleAdmin, style: t.small),
                        value: 'platform_admin',
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        title: Text(l.adminUserRoleUser, style: t.small),
                        subtitle: isSelf
                            ? Text(
                                l.adminUserSelfDemotionWarning,
                                style: t.muted.copyWith(
                                  color: c.destructive,
                                  fontSize: 11,
                                ),
                              )
                            : null,
                        value: 'user',
                        contentPadding: EdgeInsets.zero,
                        enabled: !_isSubmitting && !isSelf,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KiteSpace.sm),

                // Explicit Confirmation Checkbox for Role Change
                if (roleChanged && !isSelf) ...[
                  Container(
                    padding: const EdgeInsets.all(KiteSpace.sm),
                    decoration: BoxDecoration(
                      color: c.muted.withValues(alpha: 0.3),
                      borderRadius: KiteRadius.allSm,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        value: _roleConfirmed,
                        enabled: !_isSubmitting,
                        onChanged: (val) =>
                            setState(() => _roleConfirmed = val ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          _selectedRole == 'platform_admin'
                              ? l.adminUserRoleConfirmGrant
                              : l.adminUserRoleConfirmRevoke,
                          style: t.small.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: KiteSpace.md),
                ],

                const SizedBox(height: KiteSpace.lg),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    KiteButton.outline(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l.actionCancel),
                    ),
                    const SizedBox(width: KiteSpace.md),
                    KiteButton(
                      onPressed: canSave ? _submit : null,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l.adminUserEditSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
