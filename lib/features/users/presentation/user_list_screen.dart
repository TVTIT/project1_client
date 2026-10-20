import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/states.dart';
import '../data/user_dto.dart';
import '../providers/user_providers.dart';
import 'create_user_dialog.dart';
import 'edit_user_dialog.dart';

export 'create_user_dialog.dart' show showCreateUserDialog, CreateUserDialog;
export 'edit_user_dialog.dart' show showEditUserDialog, EditUserDialog;

/// Screen presenting system-wide user directory for Platform Administrators.
///
/// Features:
/// - True fail-closed render barrier during permissions loading or permission denial.
/// - Loads full bounded list via `GET /v1/admin/users` with strictly NO query parameters.
/// - Local client-side search filtering by name, email, or UUID.
/// - Local client-side pagination.
/// - Honest capacity limit error handling (HTTP 409 `user_list_capacity_exceeded`).
/// - Displays nullable profile name, email, UUID, platform role badge, and gateway count.
/// - Responsive card view for mobile (<640px) and data table for desktop/tablet (>=640px).
class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  late final TextEditingController _searchController;
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final perms = ref.read(userPermissionsProvider);
        if (perms.isPlatformAdmin) {
          ref.read(userListProvider.notifier).loadUsers();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserSummary> _filterUsers(List<UserSummary> allUsers, String query) {
    if (query.trim().isEmpty) return allUsers;
    final q = query.trim().toLowerCase();
    return allUsers.where((u) {
      final name = u.fullName?.toLowerCase() ?? '';
      final email = u.email.toLowerCase();
      final id = u.id.toLowerCase();
      return name.contains(q) || email.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final permsState = ref.watch(userPermissionsProvider);
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);
    final mobile = KiteBreak.isMobile(context);

    // 1. True fail-closed render barrier during permissions loading
    if (permsState.isLoading) {
      return const Scaffold(body: LoadingState());
    }

    // 2. True fail-closed render barrier when permission is denied or errored
    if (!permsState.isPlatformAdmin || permsState.hasError) {
      return Scaffold(
        backgroundColor: c.background,
        body: const ErrorState(
          message: 'Bạn không có quyền Quản trị viên nền tảng để truy cập trang này.',
        ),
      );
    }

    final userState = ref.watch(userListProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(mobile ? KiteSpace.md : KiteSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header title and actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.adminUserListTitle,
                          style: t.h3.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: KiteSpace.xs),
                        Text(
                          l.adminUserListSubtitle,
                          style: t.muted.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  KiteButton(
                    onPressed: () => showCreateUserDialog(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_outlined, size: 18),
                        const SizedBox(width: KiteSpace.sm),
                        Text(l.adminUserCreateButton),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KiteSpace.lg),

              // Search bar (strictly local search)
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() => _currentPage = 1),
                decoration: InputDecoration(
                  hintText: l.adminUserSearchPlaceholder,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _currentPage = 1);
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: KiteSpace.md),

              // Body content
              Expanded(child: _buildBody(userState, c, t, l, mobile)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    UserListState userState,
    KiteColors c,
    KiteText t,
    L l,
    bool mobile,
  ) {
    if (userState.isLoading) {
      return const LoadingState();
    }

    if (userState.hasError) {
      final err = userState.error;
      if (err is ApiException &&
          err.statusCode == 409 &&
          err.code == 'user_list_capacity_exceeded') {
        return ErrorState(
          message: 'Dung lượng danh sách người dùng vượt quá giới hạn hệ thống (HTTP 409 Conflict). Vui lòng liên hệ quản trị viên cơ sở dữ liệu.',
          onRetry: () => ref.read(userListProvider.notifier).loadUsers(),
        );
      }
      return ErrorState(
        message: err is ApiException
            ? err.message
            : 'Không thể tải danh sách người dùng. Vui lòng thử lại.',
        onRetry: () => ref.read(userListProvider.notifier).loadUsers(),
      );
    }

    final allUsers = userState.users;
    if (allUsers.isEmpty) {
      return EmptyState(
        title: l.adminUserEmptyTitle,
        message: l.adminUserEmptyMessage,
        actionLabel: l.adminUserCreateButton,
        onAction: () => showCreateUserDialog(context),
      );
    }

    final filtered = _filterUsers(allUsers, _searchController.text);
    if (filtered.isEmpty) {
      return EmptyState(
        title: l.adminUserSearchEmptyTitle,
        message: l.adminUserSearchEmptyMessage,
        actionLabel: l.actionClear,
        onAction: () {
          _searchController.clear();
          setState(() => _currentPage = 1);
        },
      );
    }

    // Local pagination slicing
    final totalItems = filtered.length;
    final totalPages = (totalItems / _pageSize).ceil();
    final validPage = _currentPage > totalPages ? totalPages : _currentPage;
    final startIndex = (validPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize > totalItems)
        ? totalItems
        : startIndex + _pageSize;
    final pageUsers = filtered.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: mobile
              ? _buildMobileCards(pageUsers, c, t, l)
              : _buildDesktopTable(pageUsers, c, t, l),
        ),
        const SizedBox(height: KiteSpace.sm),
        _buildPaginationBar(validPage, totalPages, totalItems, c, t, l),
      ],
    );
  }

  Widget _buildDesktopTable(
    List<UserSummary> users,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return SelectionArea(
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: KiteRadius.allMd,
          border: Border.all(color: c.border),
        ),
        child: ClipRRect(
          borderRadius: KiteRadius.allMd,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth < 900
                        ? 900
                        : constraints.maxWidth,
                  ),
                  child: DataTable(
                    horizontalMargin: KiteSpace.xl,
                    columnSpacing: KiteSpace.xl,
                    headingRowColor: WidgetStateProperty.all(
                      c.muted.withValues(alpha: 0.3),
                    ),
                    columns: [
                      DataColumn(
                        label: Text(l.adminUserFullName, style: t.small),
                      ),
                      DataColumn(label: Text(l.adminUserEmail, style: t.small)),
                      DataColumn(label: Text('UUID', style: t.small)),
                      DataColumn(label: Text(l.adminUserRole, style: t.small)),
                      DataColumn(
                        label: Text(l.adminUserMembershipCount, style: t.small),
                      ),
                      DataColumn(
                        label: Text(l.adminUserCreatedAt, style: t.small),
                      ),
                      DataColumn(
                        label: Text(l.adminUserEditButton, style: t.small),
                      ),
                    ],
                    rows: [
                      for (final u in users)
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                u.fullName ?? l.adminUserUnassignedName,
                                style: u.fullName == null
                                    ? t.muted.copyWith(
                                        fontStyle: FontStyle.italic,
                                      )
                                    : t.small.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                              ),
                            ),
                            DataCell(Text(u.email, style: t.small)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    u.id.length > 8
                                        ? '${u.id.substring(0, 8)}...'
                                        : u.id,
                                    style: t.muted.copyWith(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy_outlined,
                                      size: 14,
                                    ),
                                    tooltip: 'Sao chép UUID',
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: u.id),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Đã sao chép UUID vào bộ nhớ tạm',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              KiteBadge(
                                u.isPlatformAdmin
                                    ? l.adminUserRoleAdmin
                                    : l.adminUserRoleUser,
                                tone: u.isPlatformAdmin
                                    ? KiteTone.info
                                    : KiteTone.neutral,
                              ),
                            ),
                            DataCell(
                              Text(
                                '${u.gatewayRoles.length} trạm',
                                style: t.small,
                              ),
                            ),
                            DataCell(
                              Text(
                                DateFormat('yyyy-MM-dd HH:mm')
                                    .format(u.createdAt),
                                style: t.muted.copyWith(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: l.adminUserEditButton,
                                onPressed: () =>
                                    showEditUserDialog(context, user: u),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCards(
    List<UserSummary> users,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: KiteSpace.sm),
      itemBuilder: (ctx, idx) {
        final u = users[idx];
        return SelectionArea(
          child: Container(
            padding: const EdgeInsets.all(KiteSpace.md),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: KiteRadius.allMd,
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        u.fullName ?? l.adminUserUnassignedName,
                        style: u.fullName == null
                            ? t.muted.copyWith(fontStyle: FontStyle.italic)
                            : t.h4.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    KiteBadge(
                      u.isPlatformAdmin
                          ? l.adminUserRoleAdmin
                          : l.adminUserRoleUser,
                      tone: u.isPlatformAdmin ? KiteTone.info : KiteTone.neutral,
                    ),
                    const SizedBox(width: KiteSpace.xs),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: l.adminUserEditButton,
                      onPressed: () => showEditUserDialog(context, user: u),
                    ),
                  ],
                ),
                const SizedBox(height: KiteSpace.xs),
                Text(u.email, style: t.small),
                const SizedBox(height: KiteSpace.xs),
                Row(
                  children: [
                    Text(
                      'UUID: ${u.id.substring(0, 8)}...',
                      style: t.muted.copyWith(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 14),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: u.id));
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
                const Divider(height: KiteSpace.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l.adminUserMembershipCount}: ${u.gatewayRoles.length}',
                      style: t.muted.copyWith(fontSize: 12),
                    ),
                    Text(
                      DateFormat('yyyy-MM-dd').format(u.createdAt),
                      style: t.muted.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationBar(
    int page,
    int totalPages,
    int totalItems,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Trang $page trên $totalPages (Tổng $totalItems)',
          style: t.muted.copyWith(fontSize: 12),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: page > 1
                  ? () => setState(() => _currentPage = page - 1)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: page < totalPages
                  ? () => setState(() => _currentPage = page + 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
