import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../data/gateway_dto.dart';
import '../providers/gateway_provision_provider.dart';

/// Screen allowing Platform Administrators to provision a new Gateway.
///
/// Complies with Stage 2 requirements:
/// - Form contains ONLY 4 fields: `gateway_id`, `name`, `description` (optional), `owner_user_id`.
/// - Strictly NO inline sensors.
/// - Protected: Only confirmed Platform Admins may access.
/// - Preserves 201 Created vs 200 OK replay semantics.
/// - Shows authoritative provisioning result in-page without blindly navigating to foreign gateway details.
/// - Offers approved same-payload retry on timeout/network failure without fake data.
class GatewayProvisionScreen extends ConsumerStatefulWidget {
  const GatewayProvisionScreen({super.key});

  @override
  ConsumerState<GatewayProvisionScreen> createState() =>
      _GatewayProvisionScreenState();
}

class _GatewayProvisionScreenState
    extends ConsumerState<GatewayProvisionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _gatewayIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _ownerUserIdController;

  @override
  void initState() {
    super.initState();
    _gatewayIdController = TextEditingController();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _ownerUserIdController = TextEditingController();
  }

  @override
  void dispose() {
    _gatewayIdController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _ownerUserIdController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _gatewayIdController.clear();
    _nameController.clear();
    _descriptionController.clear();
    _ownerUserIdController.clear();
    ref.read(gatewayProvisionProvider.notifier).reset();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    final input = ProvisionGatewayInput(
      gatewayId: _gatewayIdController.text.trim(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      ownerUserId: _ownerUserIdController.text.trim(),
    );

    await ref.read(gatewayProvisionProvider.notifier).submit(input);
  }

  Future<void> _retry() async {
    await ref.read(gatewayProvisionProvider.notifier).retryLastAttempt();
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

  @override
  Widget build(BuildContext context) {
    final isPlatformAdmin = ref.watch(isPlatformAdminProvider);
    final provisionState = ref.watch(gatewayProvisionProvider);
    final c = KiteColors.of(context);
    final t = KiteText.of(context);
    final l = L.of(context);
    final isMobile = KiteBreak.isMobile(context);

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KiteSpace.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Navigation Bar
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: KiteSpace.md,
                  runSpacing: KiteSpace.sm,
                  children: [
                    KiteButton.outline(
                      onPressed: () => context.go(R.gateways),
                      leading: const Icon(Icons.arrow_back, size: 16),
                      child: Text(isMobile ? 'Quay lại' : l.gatewayBackToList),
                    ),
                  ],
                ),
                const SizedBox(height: KiteSpace.lg),

                // Access check fail-closed barrier
                if (!isPlatformAdmin)
                  _buildAccessDeniedCard(context, c, t, l)
                else if (provisionState.isSuccess &&
                    provisionState.result != null)
                  _buildSuccessResultCard(
                    context,
                    provisionState.result!,
                    isMobile,
                    c,
                    t,
                    l,
                  )
                else
                  _buildProvisionFormCard(
                    context,
                    provisionState,
                    isMobile,
                    c,
                    t,
                    l,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessDeniedCard(
    BuildContext context,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return Container(
      padding: const EdgeInsets.all(KiteSpace.xxl),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: KiteRadius.allLg,
        border: Border.all(color: c.destructive.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 48, color: c.destructive),
          const SizedBox(height: KiteSpace.md),
          Text(l.gatewayProvisionAccessDeniedTitle, style: t.h3),
          const SizedBox(height: KiteSpace.sm),
          Text(
            l.gatewayProvisionAccessDeniedMessage,
            style: t.muted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KiteSpace.xl),
          KiteButton.outline(
            onPressed: () => context.go(R.gateways),
            child: Text(l.gatewayBackToList),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessResultCard(
    BuildContext context,
    ProvisionGatewayResult res,
    bool isMobile,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    const successColor = Color(0xFF16A34A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status Banner
        Container(
          padding: const EdgeInsets.all(KiteSpace.lg),
          decoration: BoxDecoration(
            color: res.isCreated
                ? successColor.withAlpha(25)
                : c.muted.withAlpha(80),
            borderRadius: KiteRadius.allMd,
            border: Border.all(color: res.isCreated ? successColor : c.border),
          ),
          child: Row(
            children: [
              Icon(
                res.isCreated ? Icons.check_circle : Icons.info_outline,
                color: res.isCreated ? successColor : c.foreground,
                size: 24,
              ),
              const SizedBox(width: KiteSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.isCreated
                          ? l.gatewayProvisionSuccessCreated
                          : l.gatewayProvisionSuccessReplayed,
                      style: t.p.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: KiteSpace.xs),
                    Text(
                      res.isCreated
                          ? 'Mã trạm: ${res.gatewayId} · Đã tạo mới thực thể Digital Twin.'
                          : 'Mã trạm: ${res.gatewayId} · Thông tin trùng khớp hoàn toàn với bản ghi đã lưu.',
                      style: t.small.copyWith(color: c.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KiteSpace.xl),

        // Metadata Card
        KiteCard(
          title: 'Thông tin kết quả khởi tạo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                label: l.gatewayProvisionFieldId,
                value: res.gatewayId,
                c: c,
                t: t,
              ),
              const SizedBox(height: KiteSpace.md),
              _buildDetailRow(
                label: l.gatewayProvisionFieldName,
                value: res.name,
                c: c,
                t: t,
              ),
              const SizedBox(height: KiteSpace.md),
              _buildDetailRow(
                label: l.gatewayProvisionFieldDesc,
                value: res.description ?? '—',
                c: c,
                t: t,
              ),
              const SizedBox(height: KiteSpace.md),
              _buildDetailRow(
                label: l.gatewayProvisionOwnerId,
                value: res.ownerUserId,
                isMonospace: true,
                c: c,
                t: t,
              ),
              const SizedBox(height: KiteSpace.md),
              _buildDetailRow(
                label: l.gatewayProvisionEntityId,
                value: res.entityId,
                isMonospace: true,
                c: c,
                t: t,
              ),
              const SizedBox(height: KiteSpace.md),
              _buildDetailRow(
                label: l.gatewayProvisionCreatedAt,
                value: _formatDate(res.createdAt),
                c: c,
                t: t,
              ),
              const SizedBox(height: KiteSpace.xl),

              // Authorization Warning / Notice
              Container(
                padding: const EdgeInsets.all(KiteSpace.md),
                decoration: BoxDecoration(
                  color: c.muted,
                  borderRadius: KiteRadius.allMd,
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: c.mutedForeground,
                    ),
                    const SizedBox(width: KiteSpace.sm),
                    Expanded(
                      child: Text(
                        l.gatewayProvisionNoticeAdmin,
                        style: t.small.copyWith(color: c.mutedForeground),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KiteSpace.xl),

              // Actions
              Wrap(
                spacing: KiteSpace.md,
                runSpacing: KiteSpace.sm,
                children: [
                  KiteButton(
                    onPressed: _resetForm,
                    leading: const Icon(Icons.add, size: 16),
                    child: Text(l.gatewayProvisionCreateAnother),
                  ),
                  KiteButton.outline(
                    onPressed: () => context.go(R.gateways),
                    leading: const Icon(Icons.list, size: 16),
                    child: Text(l.gatewayBackToList),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isMonospace = false,
    required KiteColors c,
    required KiteText t,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.muted.copyWith(fontSize: 13)),
        const SizedBox(height: KiteSpace.xs),
        Text(
          value,
          style: t.p.copyWith(
            fontWeight: FontWeight.w500,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildProvisionFormCard(
    BuildContext context,
    GatewayProvisionState state,
    bool isMobile,
    KiteColors c,
    KiteText t,
    L l,
  ) {
    return KiteCard(
      title: l.gatewayProvisionTitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.gatewayProvisionSubtitle, style: t.muted),
            const SizedBox(height: KiteSpace.lg),

            // Error banner if mutation failed
            if (state.hasError) ...[
              _buildErrorBanner(state.error!, c, t, l),
              const SizedBox(height: KiteSpace.lg),
            ],

            // 1. Gateway ID
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.gatewayProvisionFieldId,
                  style: t.p.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: KiteSpace.xs),
                Text(
                  l.gatewayProvisionFieldIdHint,
                  style: t.small.copyWith(color: c.mutedForeground),
                ),
                const SizedBox(height: KiteSpace.xs),
                TextFormField(
                  controller: _gatewayIdController,
                  enabled: !state.isSubmitting,
                  validator: validateProvisionGatewayId,
                  decoration: InputDecoration(
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

            // 2. Gateway Name
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.gatewayProvisionFieldName,
                  style: t.p.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: KiteSpace.xs),
                Text(
                  l.gatewayProvisionFieldNameHint,
                  style: t.small.copyWith(color: c.mutedForeground),
                ),
                const SizedBox(height: KiteSpace.xs),
                TextFormField(
                  controller: _nameController,
                  enabled: !state.isSubmitting,
                  validator: validateProvisionName,
                  decoration: InputDecoration(
                    hintText: 'ví dụ: Trạm Quan Trắc Alpha',
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

            // 3. Description (Optional)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.gatewayProvisionFieldDesc,
                  style: t.p.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: KiteSpace.xs),
                Text(
                  l.gatewayProvisionFieldDescHint,
                  style: t.small.copyWith(color: c.mutedForeground),
                ),
                const SizedBox(height: KiteSpace.xs),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !state.isSubmitting,
                  maxLines: 3,
                  validator: validateProvisionDescription,
                  decoration: InputDecoration(
                    hintText: 'ví dụ: Trạm đo thông số nhiệt độ và độ ẩm nhà màng khu A',
                    hintStyle: t.muted,
                    border: OutlineInputBorder(
                      borderRadius: KiteRadius.allMd,
                      borderSide: BorderSide(color: c.border),
                    ),
                    contentPadding: const EdgeInsets.all(KiteSpace.md),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KiteSpace.lg),

            // 4. Owner User ID (UUID)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.gatewayProvisionFieldOwner,
                  style: t.p.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: KiteSpace.xs),
                Text(
                  l.gatewayProvisionFieldOwnerHint,
                  style: t.small.copyWith(color: c.mutedForeground),
                ),
                const SizedBox(height: KiteSpace.xs),
                TextFormField(
                  controller: _ownerUserIdController,
                  enabled: !state.isSubmitting,
                  validator: validateProvisionOwnerUserId,
                  decoration: InputDecoration(
                    hintText: '00000000-0000-0000-0000-000000000002',
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

            // Submit Buttons
            Wrap(
              spacing: KiteSpace.md,
              runSpacing: KiteSpace.sm,
              children: [
                KiteButton(
                  onPressed: state.isSubmitting ? null : _submit,
                  leading: state.isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add, size: 16),
                  child: Text(
                    state.isSubmitting
                        ? l.gatewayProvisionSubmitting
                        : l.gatewayProvisionSubmit,
                  ),
                ),
                KiteButton.outline(
                  onPressed: state.isSubmitting
                      ? null
                      : () => context.go(R.gateways),
                  child: Text(l.actionCancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(Object error, KiteColors c, KiteText t, L l) {
    String message = 'Đã xảy ra lỗi khi khởi tạo Gateway.';
    String? requestId;
    bool isRetryable = false;

    if (error is ApiException) {
      requestId = error.requestId;
      if (error.statusCode == 409) {
        message = l.gatewayProvisionConflictError;
      } else if (error.statusCode == 404) {
        message = l.gatewayProvisionNotFoundError;
      } else if (error.statusCode == 403) {
        message = l.gatewayProvisionAccessDeniedMessage;
      } else if (error.message.isNotEmpty) {
        message = error.message;
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
              Icon(Icons.error_outline, size: 20, color: c.destructive),
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
