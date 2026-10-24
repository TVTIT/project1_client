import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signature for launching the metadata edit dialog across feature boundaries
/// without gateways directly importing digital_twin presentation internals.
typedef MetadataEditLauncher = Future<bool?> Function(
  BuildContext context, {
  required String entityUrn,
  String? initialName,
  String? initialDescription,
});

/// Shared provider for metadata edit launcher.
final metadataEditLauncherProvider = Provider<MetadataEditLauncher>((ref) {
  // The application composition root supplies the feature implementation.
  return (
    context, {
    required entityUrn,
    initialName,
    initialDescription,
  }) async => null;
});
