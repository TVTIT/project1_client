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

/// Opens the dialog to assign an operator or viewer role on a gateway to a user.
Future<AssignGatewayUserResult?> showAssignGatewayUserDialog(
  BuildContext context, {
  required String gatewayId,
  String? preselectedUserId,
}) {
  return showDialog<AssignGatewayUserResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AssignGatewayUserDialog(
      gatewayId: gatewayId,
      preselectedUserId: preselectedUserId,
    ),
  );
}

/// Dialog allowing Platform Administrators to assign gateway membership.
///
/// Complies with C5 boundaries & security requirements:
/// - Belongs to `gateways/presentation` domain.
/// - Assigns operator/viewer or revokes membership; owners require ownership transfer.
/// - User selection comes from full bounded admin user directory with local search.
/// - Handles 409 `owner_transfer_required` if target user is current owner.
/// - Unknown outcome locks resend for the lifetime of this dialog (no blind retry).
/// - 403 invalidates admin capabilities while retaining session for the same actor only.
/// - Fenced by session epoch and actor identity captured at creation and mutation completion.
/// - Fails closed with permission render barrier.
class AssignGatewayUserDialog extends ConsumerStatefulWidget {
  const AssignGatewayUserDialog({
    super.key,
    required this.gatewayId,
    this.preselectedUserId,
  });

  final String gatewayId;
  final String? preselectedUserId;

  @override
  ConsumerState<AssignGatewayUserDialog> createState() =>
      _AssignGatewayUserDialogState();
}

class _AssignGatewayUserDialogState
    extends ConsumerState<AssignGatewayUserDialog> {
  final _searchController = TextEditingController();

  String? _selectedUserId;
  String _selectedRole = 'none';
  String? _roleUserId;
  String? _roleSnapshot;

  bool _isSubmitting = false;
  bool _unknownOutcome = false;
  Object? _error;

  int? _initialEpoch;
  String? _initialUserId;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.preselectedUserId;
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

  String _gatewayRole(UserSummary user) {
    for (final membership in user.gatewayRoles) {
      if (membership.gatewayId == widget.gatewayId) return membership.role;
    }
    return 'none';
  }

  UserSummary? _selectedUser(List<UserSummary> users) {
    for (final user in users) {
      if (user.id == _selectedUserId) return user;
    }
    return null;
  }

  void _syncRole(UserSummary user) {
    final role = _gatewayRole(user);
    // Rebuilds/search must not overwrite an unsaved choice for the same user.
    if (_roleUserId != user.id || _roleSnapshot != role) {
      _roleUserId = user.id;
      _roleSnapshot = role;
      _selectedRole = role;
    }
  }

  Future<void> _submit() async {
    final userId = _selectedUserId;
    if (userId == null || userId.isEmpty || _isSubmitting || _unknownOutcome) {
      return;
    }

    if (_isSessionMismatch()) {
      Navigator.of(context).pop();
      return;
    }

    final usersState = ref.read(userListProvider);
    final user = _selectedUser(usersState.users);
    if (usersState.isLoading ||
        usersState.hasError ||
        user == null ||
        _gatewayRole(user) == 'owner') {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(userRepositoryProvider);
      AssignGatewayUserResult? result;

      if (_selectedRole == 'none') {
        // DELETE /v1/admin/gateways/{gateway_id}/users/{user_id}
        await repo.revokeGatewayUser(
          gatewayId: widget.gatewayId,
          userId: userId,
        );
      } else {
        // PUT /v1/admin/gateways/{gateway_id}/users/{user_id}
        result = await repo.assignGatewayUser(
          gatewayId: widget.gatewayId,
          userId: userId,
          role: _selectedRole,
        );
      }

      if (!mounted) return;

      // Discard response if session changed while in flight
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
      if (userId == currentUserId) {
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

    final usersState = ref.watch(userListProvider);
    final filteredUsers = _filterUsers(usersState.users);

    if (_selectedUserId == null && filteredUsers.isNotEmpty) {
      _selectedUserId = filteredUsers.first.id;
    }

    final selectedUser = _selectedUser(usersState.users);
    if (selectedUser != null) _syncRole(selectedUser);
    final isOwner =
        selectedUser != null && _gatewayRole(selectedUser) == 'owner';
    final rolesEnabled =
        selectedUser != null &&
        !isOwner &&
        !_isSubmitting &&
        !_unknownOutcome &&
        !usersState.isLoading &&
        !usersState.hasError;

    final canSubmit = rolesEnabled;

    String? errorMessage;
    String? requestId;
    if (_error is ApiException) {
      final apiErr = _error as ApiException;
      requestId = apiErr.requestId;
      if (apiErr.statusCode == 409 &&
          apiErr.code == 'owner_transfer_required') {
        errorMessage = l.adminAssignRoleOwnerConflict;
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
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
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
                          l.adminAssignRoleTitle,
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

              Text(
                l.navCustomers,
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

              if (usersState.isLoading)
                const Padding(
                  padding: EdgeInsets.all(KiteSpace.md),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (filteredUsers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(KiteSpace.md),
                  child: Text(l.adminUserSearchEmptyTitle, style: t.muted),
                )
              else
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: KiteRadius.allSm,
                  ),
                  child: ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (ctx, idx) {
                      final u = filteredUsers[idx];
                      final isSelected = u.id == _selectedUserId;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: c.accent,
                        title: Text(
                          u.fullName ?? u.email,
                          style: t.small.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          u.email,
                          style: t.muted.copyWith(fontSize: 11),
                        ),
                        trailing: _gatewayRole(u) == 'owner'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  KiteBadge(
                                    l.gatewayRoleOwner,
                                    tone: KiteTone.info,
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: KiteSpace.xs),
                                    Icon(
                                      Icons.check,
                                      size: 16,
                                      color: c.primary,
                                    ),
                                  ],
                                ],
                              )
                            : isSelected
                            ? Icon(Icons.check, size: 16, color: c.primary)
                            : null,
                        onTap: _isSubmitting
                            ? null
                            : () => setState(() {
                                _selectedUserId = u.id;
                                _syncRole(u);
                              }),
                      );
                    },
                  ),
                ),
              const SizedBox(height: KiteSpace.lg),

              Text(
                l.gatewayRole,
                style: t.small.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: KiteSpace.xs),

              RadioGroup<String>(
                groupValue: _selectedRole,
                onChanged: (val) {
                  if (!rolesEnabled) return;
                  if (val != null) setState(() => _selectedRole = val);
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(l.adminAssignRoleOperator, style: t.small),
                      value: 'operator',
                      enabled: rolesEnabled,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: Text(l.adminAssignRoleViewer, style: t.small),
                      value: 'viewer',
                      enabled: rolesEnabled,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: Text('Không có quyền', style: t.small),
                      value: 'none',
                      enabled: rolesEnabled,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: KiteSpace.xs),
                Text(
                  l.adminAssignRoleOwnerHint,
                  style: t.small.copyWith(color: c.destructive),
                ),
              ],
              const SizedBox(height: KiteSpace.xl),

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
                    onPressed: canSubmit ? _submit : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l.adminAssignRoleSubmit),
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
