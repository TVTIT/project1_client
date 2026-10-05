import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'public_env.dart';

enum Environment { development, staging, production }

@immutable
class AppConfig {
  const AppConfig({
    required this.backendApiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.environment,
    this.backendWsUrl,
  });
  final String backendApiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final Environment environment;
  final String? backendWsUrl;
  static AppConfig? _current;
  static AppConfig get current =>
      _current ?? (throw StateError('Configuration not initialized.'));
  @visibleForTesting
  static set currentForTesting(AppConfig? config) => _current = config;
  static AppConfig parse(Map<String, String> input) {
    final env = validatePublicEnv(input);
    final backend = env['BACKEND_API_BASE_URL']!;
    return AppConfig(
      backendApiBaseUrl: backend.endsWith('/') ? backend : '$backend/',
      supabaseUrl: env['SUPABASE_URL']!.replaceAll(RegExp(r'/+$'), ''),
      supabaseAnonKey: env['SUPABASE_ANON_KEY']!,
      environment: Environment.values.byName(env['ENVIRONMENT']!),
      backendWsUrl: env['BACKEND_WS_URL'],
    );
  }

  static Future<AppConfig> load({String fileName = 'assets/client.env'}) async {
    final source = await rootBundle.loadString(fileName);
    final env = validatePublicEnv(parsePublicEnv(source));
    // dotenv only sees normalized, validated assignments, never the raw input.
    dotenv.testLoad(fileInput: serializePublicEnv(env));
    return _current = parse(env);
  }
}
