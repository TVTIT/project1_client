import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../../core/auth/permissions.dart';
import '../../../core/auth/session.dart';
import '../../../l10n/app_localizations.dart';
import '../../gateways/providers/gateway_detail_provider.dart';
import '../data/digital_twin_dto.dart';
import '../providers/metadata_edit_provider.dart';

/// Modal dialog for editing Gateway and Sensor metadata.
class EditMetadataDialog extends ConsumerStatefulWidget {
  const EditMetadataDialog({
    super.key,
    required this.entityUrn,
    this.initialName,
    this.initialDescription,
  });

  final String entityUrn;
  final String? initialName;
  final String? initialDescription;

  @override
  ConsumerState<EditMetadataDialog> createState() => _EditMetadataDialogState();
}

class _EditMetadataDialogState extends ConsumerState<EditMetadataDialog> {
  late final EntityUrn _parsedUrn;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _clearDescription = false;
  bool _forceClosing = false;

  int? _initialEpoch;
  String? _initialUserId;

  @override
  void initState() {
    super.initState();
    _parsedUrn = EntityUrn.parse(widget.entityUrn);
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descController = TextEditingController(
      text: widget.initialDescription ?? '',
    );

    _initialEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    _initialUserId = ref.read(sessionProvider).user?.userId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _forceClose() {
    if (!_forceClosing && mounted) {
      _forceClosing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  bool get _hasChanges {
    final origName = widget.initialName ?? '';
    final nameChanged = _nameController.text != origName;

    if (_parsedUrn.type == EntityType.gateway) {
      final origDesc = widget.initialDescription;
      if (_clearDescription) {
        return nameChanged || origDesc != null;
      }
      final descChanged = _descController.text != (origDesc ?? '');
      return nameChanged || descChanged;
    }

    return nameChanged;
  }

  Future<void> _submit(MetadataEditAuthority authority) async {
    if (_formKey.currentState?.validate() != true) return;
    if (!_hasChanges) return;

    final origName = widget.initialName ?? '';
    final String? nameToSend = _nameController.text != origName
        ? _nameController.text
        : null;

    String? descToSend;
    bool clearDesc = false;

    if (_parsedUrn.type == EntityType.gateway) {
      if (_clearDescription) {
        clearDesc = widget.initialDescription != null;
      } else if (_descController.text != (widget.initialDescription ?? '')) {
        descToSend = _descController.text;
      }
    }

    final success = await ref
        .read(metadataEditProvider(widget.entityUrn).notifier)
        .submit(
          entityUrn: _parsedUrn,
          name: nameToSend,
          description: descToSend,
          clearDescription: clearDesc,
          authority: authority,
        );

    if (success && mounted) {
      _forceClosing = true;
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final isGateway = _parsedUrn.type == EntityType.gateway;

    // Listen to session changes:
    ref.listen(sessionProvider, (_, session) {
      if (!session.isAuthenticated ||
          session.user?.userId != _initialUserId ||
          ref.read(sessionProvider.notifier).sessionEpoch != _initialEpoch) {
        _forceClose();
      }
    });

    // Listen to permissions changes (revocation while open):
    ref.listen(userPermissionsProvider, (_, perms) {
      final role = ref
          .read(gatewayDetailProvider(_parsedUrn.gatewayId))
          .membershipRole;
      final auth = resolveMetadataEditAuthority(
        permissionsState: perms,
        entityType: _parsedUrn.type,
        membershipRole: role,
      );
      if (auth == null) {
        _forceClose();
      }
    });

    final permissionsState = ref.watch(userPermissionsProvider);
    final gatewayDetailState = ref.watch(
      gatewayDetailProvider(_parsedUrn.gatewayId),
    );
    final authority = resolveMetadataEditAuthority(
      permissionsState: permissionsState,
      entityType: _parsedUrn.type,
      membershipRole: gatewayDetailState.membershipRole,
    );

    if (authority == null) {
      _forceClose();
      return const SizedBox.shrink();
    }

    final editState = ref.watch(metadataEditProvider(widget.entityUrn));
    ref.listen(metadataEditProvider(widget.entityUrn), (_, next) {
      if (next.isSuccess) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_forceClosing) {
            _forceClosing = true;
            Navigator.of(context).pop(true);
          }
        });
      }
    });
    final notifier = ref.read(metadataEditProvider(widget.entityUrn).notifier);

    return Dialog(
      backgroundColor: KiteColors.of(context).card,
      shape: const RoundedRectangleBorder(borderRadius: KiteRadius.allMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
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
                        '${l.twinEditMetadataTitle} (${isGateway ? "Gateway" : "Sensor"})',
                        style: KiteText.of(context).h4,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: editState.isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SelectableText(
                  widget.entityUrn,
                  style: KiteText.of(context).muted,
                ),
                const SizedBox(height: KiteSpace.md),

                // Database metadata notice banner:
                Container(
                  padding: const EdgeInsets.all(KiteSpace.md),
                  decoration: BoxDecoration(
                    color: KiteColors.of(context).muted,
                    borderRadius: KiteRadius.allSm,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: KiteSpace.sm),
                      Expanded(
                        child: Text(
                          l.twinEditMetadataNotice,
                          style: KiteText.of(context).small,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KiteSpace.lg),

                // Name field:
                Text(l.twinEditNameLabel, style: KiteText.of(context).small),
                const SizedBox(height: KiteSpace.xs),
                TextFormField(
                  key: const ValueKey('metadata-edit-name-field'),
                  controller: _nameController,
                  enabled:
                      !editState.isSubmitting && !editState.isUnknownOutcome,
                  onChanged: (_) => setState(() {}),
                  validator: (val) {
                    if (val == (widget.initialName ?? '')) return null;
                    if (val == null || val.trim().isEmpty) {
                      return l.twinEditNameRequired;
                    }
                    if (utf8.encode(val).length > 256) {
                      return l.twinEditNameTooLong;
                    }
                    if (val.contains('\u0000')) {
                      return l.twinEditInvalidText;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: KiteSpace.md),

                // Gateway: Description field and Clear Description checkbox:
                if (isGateway) ...[
                  Text(
                    l.twinEditDescriptionLabel,
                    style: KiteText.of(context).small,
                  ),
                  const SizedBox(height: KiteSpace.xs),
                  TextFormField(
                    key: const ValueKey('metadata-edit-desc-field'),
                    controller: _descController,
                    enabled:
                        !_clearDescription &&
                        !editState.isSubmitting &&
                        !editState.isUnknownOutcome,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      if (_clearDescription ||
                          val == (widget.initialDescription ?? '')) {
                        return null;
                      }
                      if (val != null) {
                        if (utf8.encode(val).length > 512) {
                          return l.twinEditDescriptionTooLong;
                        }
                        if (val.contains('\u0000')) {
                          return l.twinEditInvalidText;
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: KiteSpace.sm),
                  CheckboxListTile(
                    key: const ValueKey('metadata-edit-clear-desc-check'),
                    title: Text(
                      l.twinEditClearDescription,
                      style: KiteText.of(context).small,
                    ),
                    value: _clearDescription,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged:
                        editState.isSubmitting || editState.isUnknownOutcome
                        ? null
                        : (val) {
                            setState(() {
                              _clearDescription = val ?? false;
                            });
                          },
                  ),
                  const SizedBox(height: KiteSpace.md),
                ],

                // Unknown outcome warning banner & reconcile:
                if (editState.isUnknownOutcome) ...[
                  Container(
                    padding: const EdgeInsets.all(KiteSpace.md),
                    decoration: BoxDecoration(
                      color: KiteColors.of(context).muted,
                      borderRadius: KiteRadius.allSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.twinEditUnknownOutcomeNotice,
                          style: KiteText.of(context).small.copyWith(
                            color: KiteColors.of(context).foreground,
                          ),
                        ),
                        if (editState.requestId != null) ...[
                          const SizedBox(height: KiteSpace.xs),
                          Text(
                            'Request ID: ${editState.requestId}',
                            style: KiteText.of(context).small.copyWith(
                              color: KiteColors.of(context).foreground,
                            ),
                          ),
                        ],
                        const SizedBox(height: KiteSpace.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: KiteButton.outline(
                            key: const ValueKey('metadata-edit-reconcile-btn'),
                            onPressed: editState.isReconciling
                                ? null
                                : () => notifier.reconcile(_parsedUrn),
                            child: Text(
                              editState.isReconciling
                                  ? l.twinEditReconciling
                                  : l.twinEditReconcileAction,
                            ),
                          ),
                        ),
                        if (editState.reconcileStatus ==
                                MetadataReconcileStatus.mismatch ||
                            editState.reconcileStatus ==
                                MetadataReconcileStatus.cannotVerify) ...[
                          const SizedBox(height: KiteSpace.xs),
                          Text(
                            editState.reconcileStatus ==
                                    MetadataReconcileStatus.mismatch
                                ? l.twinEditReconcileMismatch
                                : l.twinEditReconcileUnavailable,
                            style: KiteText.of(context).small.copyWith(
                              color: KiteColors.of(context).foreground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: KiteSpace.md),
                ],

                // Error message banner:
                if (editState.status == MetadataEditStatus.error) ...[
                  Container(
                    padding: const EdgeInsets.all(KiteSpace.md),
                    decoration: BoxDecoration(
                      color: KiteColors.of(context).muted,
                      borderRadius: KiteRadius.allSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.twinEditFailed,
                          style: KiteText.of(context).small.copyWith(
                            color: KiteColors.of(context).destructive,
                          ),
                        ),
                        if (editState.requestId != null) ...[
                          const SizedBox(height: KiteSpace.xs),
                          Text(
                            'Request ID: ${editState.requestId}',
                            style: KiteText.of(context).small.copyWith(
                              color: KiteColors.of(context).foreground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: KiteSpace.md),
                ],

                // Action buttons:
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: editState.isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l.actionCancel),
                    ),
                    const SizedBox(width: KiteSpace.sm),
                    KiteButton(
                      key: const ValueKey('metadata-edit-submit-btn'),
                      onPressed:
                          !_hasChanges ||
                              editState.isSubmitting ||
                              editState.isUnknownOutcome
                          ? null
                          : () => _submit(authority),
                      child: editState.isSubmitting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: KiteColors.of(context).primaryForeground,
                              ),
                            )
                          : Text(l.actionSave),
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

/// Helper function to show the [EditMetadataDialog].
Future<bool?> showEditMetadataDialog(
  BuildContext context, {
  required String entityUrn,
  String? initialName,
  String? initialDescription,
}) async {
  final container = ProviderScope.containerOf(context);
  final session = container.read(sessionProvider);
  final epoch = container.read(sessionProvider.notifier).sessionEpoch;
  final entity = EntityUrn.parse(entityUrn);
  await container.read(userPermissionsProvider.notifier).loadPermissions();
  if (entity.type == EntityType.sensor) {
    await container
        .read(gatewayDetailProvider(entity.gatewayId).notifier)
        .load();
  }
  if (!context.mounted ||
      !container.read(sessionProvider).isAuthenticated ||
      epoch != container.read(sessionProvider.notifier).sessionEpoch ||
      session.user?.userId != container.read(sessionProvider).user?.userId) {
    return null;
  }
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => EditMetadataDialog(
      entityUrn: entityUrn,
      initialName: initialName,
      initialDescription: initialDescription,
    ),
  );
}
