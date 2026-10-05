import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/auth/session.dart';
import 'core/config/app_config.dart';
import 'features/system/configuration_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean paths instead of Flutter's default hash URLs
  usePathUrlStrategy();

  AppConfig? config;
  String? configError;

  try {
    config = await AppConfig.load();
  } catch (_) {
    configError = 'Cấu hình công khai không hợp lệ hoặc chưa được tạo.';
  }

  // If configuration failed or contains placeholders, show friendly error screen with full ShadTheme
  if (config == null || configError != null) {
    runApp(
      ConfigurationErrorApp(
        message: configError ?? 'Không thể tải tệp cấu hình môi trường .env',
      ),
    );
    return;
  }

  // Initialize Supabase Auth SDK only (no Realtime / storage / MQTT)
  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: config.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
  } catch (_) {
    // Graceful stop on Supabase initialization failure
    runApp(
      const ConfigurationErrorApp(
        message:
            'Không thể khởi tạo dịch vụ xác thực. Vui lòng kiểm tra cấu hình.',
      ),
    );
    return;
  }

  final container = ProviderContainer();
  // Trigger initial session restoration after initialization
  unawaited(container.read(sessionProvider.notifier).restoreSession());

  runApp(
    UncontrolledProviderScope(container: container, child: const KiteApp()),
  );
}
