import 'dart:async';

import 'package:flutter/material.dart';
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

/// Opens the dialog to provision a new user account.
Future<CreatedUser?> showCreateUserDialog(BuildContext context) {
  return showDialog<CreatedUser>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const CreateUserDialog(),
  );
}

/// Dialog allowing Platform Administrators to centrally provision a user account.
///
/// Complies with security & C3 requirements:
/// - Fields: `full_name`, `email`, `password`.
/// - Uses C2 validation functions for length and format bounds.
/// - Obscured password input with toggle button.
/// - Ephemeral password controller only; NEVER cached, toasted, logged, or serialized to URL.
/// - Disposed immediately on dialog close, session change, or admin permission revocation.
/// - Disabled inputs and button while request is in-flight (prevents duplicate submission).
/// - Known conflict (409 user_already_exists) displays clear guidance and preserves inputs.
/// - Unknown outcome (503 / NetworkException / Timeout) displays explicit warning with NO blind retry.
/// - Reconcile list button queries full list; never infers absent account if list load fails or overflows.
class CreateUserDialog extends ConsumerStatefulWidget {
  const CreateUserDialog({super.key});

  @override
  ConsumerState<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isReconciling = false;
  bool _unknownOutcome = false;
  String? _reconciliationMessage;
  Object? _error;

  int? _initialEpoch;
  String? _initialUserId;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _initialEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    _initialUserId = ref.read(currentUserProvider)?.userId;
  }

  @override
  void dispose() {
    // Ephemeral controllers securely disposed; password is never leaked or retained in memory
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isSessionMismatch() {
    final currentEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final currentUserId = ref.read(currentUserProvider)?.userId;
    if (_initialEpoch != null && currentEpoch != _initialEpoch) return true;
    if (_initialUserId != null && currentUserId != _initialUserId) return true;
    return false;
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isReconciling || _unknownOutcome) return;
    if (_isSessionMismatch()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _error = null;
      _reconciliationMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final fullName = _fullNameController.text.trim();
    final email = normalizeEmail(_emailController.text);
    final password = _passwordController.text;

    setState(() {
      _isSubmitting = true;
    });

    final input = CreateUserInput(
      fullName: fullName,
      email: email,
      password: password,
    );

    try {
      final repo = ref.read(userRepositoryProvider);
      final created = await repo.createUser(input);

      if (!mounted) return;
      if (_isSessionMismatch()) {
        Navigator.of(context).pop();
        return;
      }

      // On creation success: clear ephemeral form controllers and refresh user list
      _fullNameController.clear();
      _emailController.clear();
      _passwordController.clear();

      unawaited(ref.read(userListProvider.notifier).loadUsers());
      Navigator.of(context).pop(created);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_isSessionMismatch()) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _isSubmitting = false);

      if (e.statusCode == 503) {
        // Unknown outcome on 503: server might have completed account creation.
        // Password must be cleared immediately since no resend is permitted.
        _passwordController.clear();
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
      // Network failure / timeout: unknown outcome on server.
      // Password must be cleared immediately since no resend is permitted.
      _passwordController.clear();
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

  Future<void> _reconcileList() async {
    final targetEmail = _emailController.text;
    if (targetEmail.trim().isEmpty) return;

    setState(() {
      _isReconciling = true;
      _reconciliationMessage = null;
    });

    try {
      await ref.read(userListProvider.notifier).loadUsers();
      if (!mounted) return;

      final listState = ref.read(userListProvider);
      if (listState.hasError) {
        // Reconciliation failed or capacity overflowed (409):
        // NEVER infer absent account if reconciliation fails or capacity overflows!
        setState(() {
          _isReconciling = false;
          _reconciliationMessage = 'Không thể tải danh sách để đối soát. Tuyệt đối không tự ý thử lại.';
        });
        return;
      }

      final normalized = normalizeEmail(targetEmail).toLowerCase();
      final exists = listState.users.any(
        (u) => u.email.trim().toLowerCase() == normalized,
      );

      if (exists) {
        // Finding email proves account exists, NOT that this timed-out request created it.
        // Never claim exact request success or password validity, do not retry or overwrite.
        _passwordController.clear();
        setState(() {
          _isReconciling = false;
          _reconciliationMessage = 'Đã đối soát: Tài khoản với email này đã tồn tại trên hệ thống. Vui lòng kiểm tra lại thông tin chi tiết của người dùng trong danh sách.';
        });
      } else {
        setState(() {
          _isReconciling = false;
          _unknownOutcome = false;
          _reconciliationMessage = 'Đã đối soát: Tài khoản chưa xuất hiện trong danh sách. Bạn có thể kiểm tra lại thông tin và thử lại.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isReconciling = false;
        _reconciliationMessage = 'Lỗi trong quá trình đối soát danh sách.';
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

    String? errorMessage;
    String? requestId;
    if (_error is ApiException) {
      final apiErr = _error as ApiException;
      requestId = apiErr.requestId;
      if (apiErr.statusCode == 409 && apiErr.code == 'user_already_exists') {
        errorMessage = 'Email này đã tồn tại trong hệ thống (HTTP 409 Conflict). Vui lòng sử dụng địa chỉ email khác.';
      } else {
        errorMessage = apiErr.message;
      }
    } else if (_error is NetworkException) {
      errorMessage = (_error as NetworkException).message;
    } else if (_error != null) {
      errorMessage = 'Đã xảy ra lỗi không xác định.';
    }

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
                        l.adminUserCreateTitle,
                        style: t.h4.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _isSubmitting || _isReconciling
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
                                l.adminUserCreateUnknownOutcomeTitle,
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
                          l.adminUserCreateUnknownOutcomeMessage,
                          style: t.small.copyWith(fontSize: 12),
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
                        const SizedBox(height: KiteSpace.md),
                        SizedBox(
                          width: double.infinity,
                          child: KiteButton.outline(
                            onPressed: _isReconciling ? null : _reconcileList,
                            child: _isReconciling
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(l.adminUserReconcileButton),
                          ),
                        ),
                        if (_reconciliationMessage != null) ...[
                          const SizedBox(height: KiteSpace.xs),
                          Text(
                            _reconciliationMessage!,
                            style: t.small.copyWith(
                              color: Colors.amber[900],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: KiteSpace.md),
                ],

                // Form Fields
                Text(
                  l.adminUserCreateFieldFullName,
                  style: t.small.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: KiteSpace.xs),
                TextFormField(
                  controller: _fullNameController,
                  enabled: !_isSubmitting && !_isReconciling,
                  validator: validateFullName,
                  decoration: const InputDecoration(
                    hintText: 'Nhập họ và tên...',
                  ),
                ),
                const SizedBox(height: KiteSpace.md),

                Text(
                  l.adminUserCreateFieldEmail,
                  style: t.small.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: KiteSpace.xs),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isSubmitting && !_isReconciling,
                  validator: validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'user@example.com',
                  ),
                ),
                const SizedBox(height: KiteSpace.md),

                Text(
                  l.adminUserCreateFieldPassword,
                  style: t.small.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: KiteSpace.xs),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isSubmitting && !_isReconciling,
                  obscureText: _obscurePassword,
                  validator: validatePassword,
                  decoration: InputDecoration(
                    hintText: 'Tối thiểu 6 ký tự...',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: KiteSpace.xl),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    KiteButton.outline(
                      onPressed: _isSubmitting || _isReconciling
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l.actionCancel),
                    ),
                    const SizedBox(width: KiteSpace.md),
                    KiteButton(
                      onPressed:
                          _isSubmitting || _isReconciling || _unknownOutcome
                          ? null
                          : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l.adminUserCreateSubmit),
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
