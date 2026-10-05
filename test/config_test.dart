import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/config/app_config.dart';
import 'package:kite/features/system/configuration_error_app.dart';

void main() {
  group('AppConfig parsing and validation', () {
    test('successfully parses valid environment variables', () {
      final env = {
        'BACKEND_API_BASE_URL': 'http://localhost/v1',
        'SUPABASE_URL': 'http://localhost',
        'SUPABASE_ANON_KEY': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.signature',
        'ENVIRONMENT': 'development',
        'BACKEND_WS_URL': 'ws://localhost/v1/ws',
      };

      final config = AppConfig.parse(env);
      expect(config.backendApiBaseUrl, 'http://localhost/v1/');
      expect(config.supabaseUrl, 'http://localhost');
      expect(config.supabaseAnonKey, contains('eyJhbGciOiJIUzI1NiI'));
      expect(config.environment, Environment.development);
      expect(config.backendWsUrl, 'ws://localhost/v1/ws');
    });

    test('rejects missing or empty required variables', () {
      final env = <String, String>{};
      expect(() => AppConfig.parse(env), throwsFormatException);
    });

    test('rejects unknown environment variables outside the 5 allowed', () {
      final env = {
        'BACKEND_API_BASE_URL': 'http://localhost/v1',
        'SUPABASE_URL': 'http://localhost',
        'SUPABASE_ANON_KEY': 'some_key',
        'ENVIRONMENT': 'development',
        'UNKNOWN_CUSTOM_VAR': 'malicious_injection',
      };
      expect(
        () => AppConfig.parse(env),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('không được phép'),
          ),
        ),
      );
    });

    test('rejects placeholder anon keys', () {
      final env = {
        'BACKEND_API_BASE_URL': 'http://localhost/v1',
        'SUPABASE_URL': 'http://localhost',
        'SUPABASE_ANON_KEY': 'replace_with_public_anon_key',
        'ENVIRONMENT': 'development',
      };
      expect(
        () => AppConfig.parse(env),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('placeholder'),
          ),
        ),
      );
    });

    test('rejects invalid or missing ENVIRONMENT without default fallback', () {
      final env = {
        'BACKEND_API_BASE_URL': 'http://localhost/v1',
        'SUPABASE_URL': 'http://localhost',
        'SUPABASE_ANON_KEY': 'sb_publishable_test',
        'ENVIRONMENT': 'local_test',
      };
      expect(
        () => AppConfig.parse(env),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('ENVIRONMENT không hợp lệ'),
          ),
        ),
      );
    });

    test('rejects Supabase URL containing /auth/v1 or /v1 path', () {
      final env = {
        'BACKEND_API_BASE_URL': 'http://localhost/v1',
        'SUPABASE_URL': 'http://localhost/auth/v1',
        'SUPABASE_ANON_KEY': 'sb_publishable_test',
        'ENVIRONMENT': 'development',
      };
      expect(
        () => AppConfig.parse(env),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('/auth/v1'),
          ),
        ),
      );
    });

    test(
      'rejects URLs with query, fragment, userinfo, or non-http/https schemes',
      () {
        final env = {
          'BACKEND_API_BASE_URL': 'ftp://localhost/v1',
          'SUPABASE_URL': 'http://user:pass@localhost?param=1#fragment',
          'SUPABASE_ANON_KEY': 'sb_publishable_test',
          'ENVIRONMENT': 'development',
        };
        expect(() => AppConfig.parse(env), throwsFormatException);
      },
    );

    test('rejects Backend API URL missing /v1 suffix', () {
      final env = {
        'BACKEND_API_BASE_URL': 'http://localhost/api',
        'SUPABASE_URL': 'http://localhost',
        'SUPABASE_ANON_KEY': 'sb_publishable_test',
        'ENVIRONMENT': 'development',
      };
      expect(
        () => AppConfig.parse(env),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('/v1'),
          ),
        ),
      );
    });

    test('rejects Android emulator 10.0.2.2 for web client', () {
      final env = {
        'BACKEND_API_BASE_URL': 'http://10.0.2.2/v1',
        'SUPABASE_URL': 'http://localhost',
        'SUPABASE_ANON_KEY': 'sb_publishable_test',
        'ENVIRONMENT': 'development',
      };
      expect(
        () => AppConfig.parse(env),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('10.0.2.2'),
          ),
        ),
      );
    });

    test('rejects server-side secrets, sb_secret_, or service_role keys', () {
      final env = {
        'BACKEND_API_BASE_URL': 'http://localhost/v1',
        'SUPABASE_URL': 'http://localhost',
        'SUPABASE_ANON_KEY': 'sb_secret_very_sensitive_key',
        'ENVIRONMENT': 'development',
      };
      expect(
        () => AppConfig.parse(env),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('sb_secret_'),
          ),
        ),
      );
    });

    test('rejects JWT with role other than anon', () {
      final env = {
        'BACKEND_API_BASE_URL': 'http://localhost/v1',
        'SUPABASE_URL': 'http://localhost',
        // {"role":"service_role"} base64url is eyJyb2xlIjoic2VydmljZV9yb2xlIn0
        'SUPABASE_ANON_KEY': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature',
        'ENVIRONMENT': 'development',
      };
      expect(
        () => AppConfig.parse(env),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('role "anon"'),
          ),
        ),
      );
    });

    test('enforces HTTPS in production environment', () {
      final env = {
        'BACKEND_API_BASE_URL': 'http://api.example.com/v1',
        'SUPABASE_URL': 'http://auth.example.com',
        'SUPABASE_ANON_KEY': 'sb_publishable_test',
        'ENVIRONMENT': 'production',
      };
      expect(
        () => AppConfig.parse(env),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('HTTPS'),
          ),
        ),
      );
    });
  });

  group('ConfigurationErrorApp startup fallback', () {
    testWidgets(
      'renders cleanly with ShadApp and shows friendly configuration error',
      (tester) async {
        await tester.pumpWidget(
          const ConfigurationErrorApp(
            message: 'SUPABASE_ANON_KEY đang sử dụng giá trị placeholder mẫu.',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cấu hình ứng dụng chưa sẵn sàng'), findsOneWidget);
        expect(
          find.text('SUPABASE_ANON_KEY đang sử dụng giá trị placeholder mẫu.'),
          findsOneWidget,
        );
        expect(find.text('Thử tải lại cấu hình'), findsNothing);
      },
    );
  });
}
