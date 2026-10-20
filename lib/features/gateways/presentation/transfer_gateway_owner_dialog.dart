import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/states.dart';
import '../../users/data/user_dto.dart';
import '../../users/data/user_repository.dart';
import '../../users/providers/user_providers.dart';
import '../providers/gateway_detail_provider.dart';
import '../providers/gateway_list_provider.dart';

/// Opens the dialog to transfer gateway ownership to another user.
Future<TransferGatewayOwnerResult?> showTransferGatewayOwnerDialog(
  BuildContext context, {
  required String gatewayId,
}) {
  return showDialog<TransferGatewayOwnerResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => TransferGatewayOwnerDialog(gatewayId: gatewayId),
  );
}

/// Dialog allowing Platform Administrators to transfer gateway ownership.
///
/// Complies with C5 boundaries & security requirements:
/// - Belongs to `gateways/presentation` domain.
/// - Determines actual current owner from full users' `gateway_roles`.
/// - If 0, multiple, or list unavailable/capacity overflow: BLOCKS transfer and offers list refresh.
/// - Recipient selected from user directory with local search.
/// - Same owner is supported as safe no-op.
/// - If different owner, requires explicit confirmation that old owner becomes Viewer retaining read rights.
/// - Shows informative notice about PUT provisioning replay conflicts after owner transfer.
/// - Resend is permanently blocked for the lifetime of this dialog upon unknown mutation outcome (no blind retry).
/// - Fenced by session epoch and actor identity captured at creation and mutation completion.
/// - Fails closed with permission render barrier.
class TransferGatewayOwnerDialog extends ConsumerStatefulWidget {
  const TransferGatewayOwnerDialog({super.key, required this.gatewayId});

  final String gatewayId;

  @override
  ConsumerState<TransferGatewayOwnerDialog> createState() =>
      _TransferGatewayOwnerDialogState();
}

class _TransferGatewayOwnerDialogState
    extends ConsumerState<TransferGatewayOwnerDialog> {
  final _searchController = TextEditingController();

  String? _selectedUserId;
  bool _confirmed = false;
  bool _isSubmitting = false;
  bool _unknownOutcome = false;
  Object? _error;

  int? _initialEpoch;
  String? _initialUserId;

  @override
  void initState() {
    super.initState();
    _initialEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    _initialUserId = ref.read(currentUserProvider)?.userId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final perms = ref.read(userPermissionsProvider);
        if (perms.isPlatformAdmin) {
          final usersState = ref.read(userListProvider);
          if (usersState.users.isEmpty && !usersState.isLoading) {
            ref.read(userListProvider.notifier).loadUsers();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isSessionMismatch() {
    final currentEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final currentUserId = ref.read(currentUserProvider)?.userId;
    if (_initialEpoch != null && currentEpoch != _initialEpoch) return true;
    if (_initialUserId != null && currentUserId != _initialUserId) return true;
    return false;
  }

  List<UserSummary> _filterUsers(List<UserSummary> users) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return users;
    return users.where((u) {
      final name = u.fullName?.toLowerCase() ?? '';
      final email = u.email.toLowerCase();
      final id = u.id.toLowerCase();
      return name.contains(q) || email.contains(q) || id.contains(q);
    }).toList();
  }

  Future<void> _submit(UserSummary? currentOwner) async {
    final targetId = _selectedUserId;
    if (targetId == null ||
        targetId.isEmpty ||
        _isSubmitting ||
        _unknownOutcome) {
      return;
    }

    if (_isSessionMismatch()) {
      Navigator.of(context).pop();
      return;
    }

    final isSameOwner = currentOwner != null && currentOwner.id == targetId;
    if (!isSameOwner && !_confirmed) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(userRepositoryProvider);
      final result = await repo.transferGatewayOwner(
        gatewayId: widget.gatewayId,
        targetUserId: targetId,
      );

      if (!mounted) return;

      if (_isSessionMismatch()) {
        Navigator.of(context).pop();
        return;
      }

      // On mutation success: refresh user list and gateway detail
      unawaited(ref.read(userListProvider.notifier).loadUsers());
      unawaited(
        ref.read(gatewayDetailProvider(widget.gatewayId).notifier).load(),
      );

      final currentUserId = ref.read(currentUserProvider)?.userId;
      if (currentOwner?.id == currentUserId || targetId == currentUserId) {
        unawaited(ref.read(gatewayListProvider.notifier).loadGateways());
      }

      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_isSessionMismatch()) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _isSubmitting = false);

      if (e.statusCode == 403) {
        ref.read(userPermissionsProvider.notifier).invalidateAdminPermissions();
        setState(() => _error = e);
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

    final usersState = ref.watch(userListProvider);
    final filteredUsers = _filterUsers(usersState.users);

    final owners = usersState.users.where((u) {
      return u.gatewayRoles.any(
        (r) => r.gatewayId == widget.gatewayId && r.role == 'owner',
      );
    }).toList();

    UserSummary? currentOwner;
    String? ownerInconsistencyWarning;
    if (usersState.hasError) {
      ownerInconsistencyWarning = 'Không thể tải danh sách người dùng để xác định chủ sở hữu. Vui lòng tải lại danh sách.';
    } else if (!usersState.isLoading && usersState.users.isNotEmpty) {
      if (owners.isEmpty) {
        ownerInconsistencyWarning = l.adminTransferOwnerZeroOwners;
      } else if (owners.length > 1) {
        ownerInconsistencyWarning = l.adminTransferOwnerMultipleOwners;
      } else {
        currentOwner = owners.first;
      }
    }

    if (_selectedUserId == null && filteredUsers.isNotEmpty) {
      final nonOwner = filteredUsers.where((u) => u.id != currentOwner?.id);
      _selectedUserId = nonOwner.isNotEmpty
          ? nonOwner.first.id
          : filteredUsers.first.id;
    }

    final isSameOwner =
        currentOwner != null && currentOwner.id == _selectedUserId;
    final canSubmit =
        currentOwner != null &&
        ownerInconsistencyWarning == null &&
        _selectedUserId != null &&
        !_unknownOutcome &&
        !usersState.isLoading &&
        !_isSubmitting &&
        (isSameOwner || _confirmed);

    String? errorMessage;
    String? requestId;
    if (_error is ApiException) {
      final apiErr = _error as ApiException;
      requestId = apiErr.requestId;
      if (apiErr.statusCode == 409 &&
          apiErr.code == 'gateway_owner_inconsistent') {
        errorMessage = l.adminTransferOwnerInconsistentError;
      } else {
        errorMessage = apiErr.message;
      }
    } else if (_error is NetworkException) {
      errorMessage = (_error as NetworkException).message;
    } else if (_error != null) {
      errorMessage = l.errorTitle;
    }

    return Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: KiteRadius.allMd,
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KiteSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.adminTransferOwnerTitle,
                          style: t.h4.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: KiteSpace.xs),
                        Text(
                          '${l.gatewayId}: ${widget.gatewayId}',
                          style: t.muted.copyWith(fontSize: 12),
                        ),
                      ],
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
                    ],
                  ),
                ),
                const SizedBox(height: KiteSpace.md),
              ],

              if (usersState.isLoading)
                const Padding(
                  padding: EdgeInsets.all(KiteSpace.md),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (ownerInconsistencyWarning != null) ...[
                Container(
                  padding: const EdgeInsets.all(KiteSpace.md),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: KiteRadius.allSm,
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          const SizedBox(width: KiteSpace.sm),
                          Expanded(
                            child: Text(
                              ownerInconsistencyWarning,
                              style: t.small.copyWith(color: Colors.red[900]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KiteSpace.sm),
                      KiteButton.outline(
                        onPressed: () =>
                            ref.read(userListProvider.notifier).loadUsers(),
                        child: Text(l.actionRefresh),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KiteSpace.md),
              ] else if (currentOwner != null) ...[
                Container(
                  padding: const EdgeInsets.all(KiteSpace.md),
                  decoration: BoxDecoration(
                    color: c.muted.withValues(alpha: 0.25),
                    borderRadius: KiteRadius.allSm,
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.adminTransferOwnerCurrentOwner,
                        style: t.muted.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: KiteSpace.xs),
                      Text(
                        currentOwner.fullName ?? currentOwner.email,
                        style: t.small.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(currentOwner.email, style: t.small),
                      Text(
                        'UUID: ${currentOwner.id}',
                        style: t.muted.copyWith(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KiteSpace.md),
              ],

              Text(
                l.adminTransferOwnerNewOwner,
                style: t.small.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: KiteSpace.xs),

              TextField(
                controller: _searchController,
                enabled: !_isSubmitting,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l.adminUserSearchPlaceholder,
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
              ),
              const SizedBox(height: KiteSpace.sm),

              if (filteredUsers.isNotEmpty)
                Container(
                  height: 130,
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: KiteRadius.allSm,
                  ),
                  child: ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (ctx, idx) {
                      final u = filteredUsers[idx];
                      final isSelected = u.id == _selectedUserId;
                      final isCurrent = u.id == currentOwner?.id;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: c.accent,
                        title: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: KiteSpace.xs,
                          children: [
                            Text(
                              u.fullName ?? u.email,
                              style: t.small.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isCurrent)
                              const KiteBadge('Hiện tại', tone: KiteTone.info),
                          ],
                        ),
                        subtitle: Text(
                          u.email,
                          style: t.muted.copyWith(fontSize: 11),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check, size: 16, color: c.primary)
                            : null,
                        onTap: _isSubmitting
                            ? null
                            : () => setState(() => _selectedUserId = u.id),
                      );
                    },
                  ),
                ),
              const SizedBox(height: KiteSpace.md),

              Container(
                padding: const EdgeInsets.all(KiteSpace.sm),
                decoration: BoxDecoration(
                  color: c.muted.withValues(alpha: 0.2),
                  borderRadius: KiteRadius.allSm,
                ),
                child: Text(
                  l.adminTransferOwnerReplayNotice(widget.gatewayId),
                  style: t.muted.copyWith(fontSize: 11),
                ),
              ),
              const SizedBox(height: KiteSpace.md),

              if (currentOwner != null && !isSameOwner) ...[
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    value: _confirmed,
                    enabled: !_isSubmitting,
                    onChanged: (val) =>
                        setState(() => _confirmed = val ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      l.adminTransferOwnerConfirm,
                      style: t.small.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KiteSpace.md),
              ],

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
                    onPressed: canSubmit ? () => _submit(currentOwner) : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Chuyển giao'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
