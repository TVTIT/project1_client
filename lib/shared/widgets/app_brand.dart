import 'package:flutter/material.dart';
import 'package:kite_ui/kite_ui.dart';

import '../../l10n/app_localizations.dart';
import 'app_logo.dart';

/// The standard brand identity widget composing [AppLogo] and the localized
/// application name.
///
/// Ensures consistent visual identity across screens while handling:
/// - Responsive constraints: prevents unbounded [Flexible] runtime issues by
///   adapting flex layout based on incoming constraints.
/// - Text truncation: gracefully applies ellipsis when space is constrained.
/// - Accessibility: excludes the decorative logo from the semantics tree to
///   prevent duplicate image announcements alongside the app name text.
/// - Modularity: bundles no background styling or navigation actions.
class AppBrand extends StatelessWidget {
  const AppBrand({
    super.key,
    this.logoSize = 20.0,
    this.spacing,
    this.textStyle,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize,
    this.overflow = TextOverflow.ellipsis,
    this.maxLines = 1,
    this.appName,
  });

  /// The dimension (width and height) of the [AppLogo]. Defaults to 20.0.
  final double logoSize;

  /// Horizontal spacing between the logo and brand text.
  ///
  /// Defaults to [KiteSpace.sm] (8.0).
  final double? spacing;

  /// Custom typography for the brand name text.
  ///
  /// Defaults to [KiteText.of(context).h4].
  final TextStyle? textStyle;

  /// How children are placed along the horizontal main axis.
  ///
  /// Defaults to [MainAxisAlignment.start].
  final MainAxisAlignment mainAxisAlignment;

  /// How children are aligned along the vertical cross axis.
  ///
  /// Defaults to [CrossAxisAlignment.center].
  final CrossAxisAlignment crossAxisAlignment;

  /// How much horizontal space the row should occupy.
  ///
  /// When not specified, defaults to [MainAxisSize.max] in bounded layouts
  /// and [MainAxisSize.min] in unbounded horizontal layouts to prevent layout crashes.
  final MainAxisSize? mainAxisSize;

  /// Overflow handling for the brand text.
  ///
  /// Defaults to [TextOverflow.ellipsis].
  final TextOverflow overflow;

  /// Maximum line count for the brand text. Defaults to 1.
  final int? maxLines;

  /// Optional override for the application name.
  ///
  /// When null, defaults to [L.of(context).appName], falling back safely to
  /// `'SANSLAB IoT Server'` when localizations are unavailable (e.g. in bare tests).
  final String? appName;

  @override
  Widget build(BuildContext context) {
    final effectiveSpacing = spacing ?? KiteSpace.sm;
    final effectiveTextStyle = textStyle ?? KiteText.of(context).h4;
    final displayName =
        appName ??
        (Localizations.of<L>(context, L)?.appName ?? 'SANSLAB IoT Server');

    final textWidget = Text(
      displayName,
      style: effectiveTextStyle,
      overflow: overflow,
      maxLines: maxLines,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isBounded = constraints.hasBoundedWidth;
        final effectiveMainAxisSize =
            mainAxisSize ?? (isBounded ? MainAxisSize.max : MainAxisSize.min);

        return Row(
          mainAxisSize: isBounded ? effectiveMainAxisSize : MainAxisSize.min,
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: [
            AppLogo(size: logoSize, excludeFromSemantics: true),
            SizedBox(width: effectiveSpacing),
            if (isBounded) Flexible(child: textWidget) else textWidget,
          ],
        );
      },
    );
  }
}
