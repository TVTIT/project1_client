import 'package:flutter/material.dart';

/// The official SANSLAB logo widget.
///
/// Loads the high-resolution logo from assets/images/sanslab_logo.png with
/// [BoxFit.contain] and no color tint.
///
/// Accessibility:
/// When paired with adjacent brand text (e.g. app name), screen readers
/// should not make duplicate brand announcements. By default, when
/// [semanticLabel] is null, [excludeFromSemantics] defaults to `true` to omit
/// the logo from the semantics tree. When used standalone, supply [semanticLabel]
/// to make it accessible to assistive technologies.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    this.excludeFromSemantics,
  });

  /// Path to the SANSLAB logo asset.
  static const String assetPath = 'assets/images/sanslab_logo.png';

  /// Equal width and height dimension shortcut.
  final double? size;

  /// Custom width. Takes precedence over [size].
  final double? width;

  /// Custom height. Takes precedence over [size].
  final double? height;

  /// How to fit the image into the allocated space.
  final BoxFit fit;

  /// Optional accessibility label for assistive technologies.
  final String? semanticLabel;

  /// Whether to exclude this logo from the semantics tree.
  ///
  /// Defaults to `true` when [semanticLabel] is null to avoid duplicate
  /// brand announcements when paired with adjacent brand text.
  final bool? excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;
    final isExcluded = excludeFromSemantics ?? (semanticLabel == null);

    return Image.asset(
      assetPath,
      width: effectiveWidth,
      height: effectiveHeight,
      fit: fit,
      semanticLabel: isExcluded ? null : semanticLabel,
      excludeFromSemantics: isExcluded,
    );
  }
}
