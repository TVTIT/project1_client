import 'package:flutter/widgets.dart';
import 'package:kite_ui/shadcn.dart';

import '../../l10n/app_localizations.dart';
import 'configuration_error_screen.dart';

/// Error app mounted when configuration validation fails or Supabase initialization fails.
/// Provides ShadTheme, localizations, and Kite tokens without entering the auth/protected router.
class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      onGenerateTitle: (context) =>
          '${L.of(context).appName} — Configuration Error',
      supportedLocales: L.supportedLocales,
      localizationsDelegates: L.localizationsDelegates,
      home: ConfigurationErrorScreen(message: message),
    );
  }
}
