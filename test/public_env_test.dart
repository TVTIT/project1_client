import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/config/public_env.dart';

const valid =
    'BACKEND_API_BASE_URL=http://localhost/v1/\n'
    'SUPABASE_URL=http://localhost\nSUPABASE_ANON_KEY=sb_publishable_test\n'
    'ENVIRONMENT=development\n';

void main() {
  final packages = File('.dart_tool/package_config.json').absolute;
  final config =
      jsonDecode(packages.readAsStringSync()) as Map<String, dynamic>;
  final flutter = (config['packages'] as List).firstWhere(
    (p) => p['name'] == 'flutter',
  );
  final flutterRoot = packages.uri
      .resolve(flutter['rootUri'] as String)
      .resolve('../');
  final dart = flutterRoot.resolve('bin/cache/dart-sdk/bin/dart').toFilePath();
  test(
    'strict subset rejects malformed, duplicate and unknown assignments',
    () {
      for (final line in [
        'SUPABASE_ANON_KEY=sb_secret_private',
        'UNKNOWN=secret',
        'export ENVIRONMENT=development',
        'broken',
        'BACKEND_WS_URL="unclosed',
        r'BACKEND_WS_URL=$SECRET',
        'BACKEND_WS_URL=ws://localhost #comment',
        'BACKEND_WS_URL=ws://localhost\x00',
      ]) {
        expect(() => parsePublicEnv('$valid$line\n'), throwsFormatException);
      }
      expect(
        () => parsePublicEnv('SUPABASE_ANON_KEY=sb_secret_private\n$valid'),
        throwsFormatException,
      );
    },
  );
  test('key formats and host are fail closed', () {
    for (final key in [
      'unknown',
      'sb_secret_private',
      'sb_publishable_',
      'abc.bad.signature',
      'e30.e30.signature',
      'e30.eyJyb2xlIjoiYXV0aGVudGljYXRlZCJ9.signature',
    ]) {
      expect(
        () => validatePublicEnv({
          ...parsePublicEnv(valid),
          'SUPABASE_ANON_KEY': key,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => validatePublicEnv({
        ...parsePublicEnv(valid),
        'SUPABASE_URL': 'http:///',
      }),
      throwsFormatException,
    );
  });
  test(
    'sanitization removes comments and runtime disallows CI placeholder',
    () {
      final env = parsePublicEnv('# sensitive comment never shipped\n$valid');
      expect(serializePublicEnv(validatePublicEnv(env)), valid);
      env['SUPABASE_ANON_KEY'] = 'replace_with_public_anon_key';
      expect(() => validatePublicEnv(env), throwsFormatException);
      expect(validatePublicEnv(env, allowPlaceholder: true), env);
    },
  );
  test('standalone generator rejects duplicate privileged first without asset or key output', () async {
    final dir = await Directory.systemTemp.createTemp('public-env-test-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final input = File('${dir.path}/input.env')
      ..writeAsStringSync('SUPABASE_ANON_KEY=sb_secret_private\n$valid');
    final script = File('scripts/validate_client_env.dart').absolute.path;
    // Flutter test runs with flutter_tester, not dart. Use the SDK's dart.
    final result = await Process.run(dart, [
      '--packages=${packages.path}',
      script,
      '--input',
      input.path,
    ], workingDirectory: dir.path);
    expect(result.exitCode, 1);
    expect(File('${dir.path}/assets/client.env').existsSync(), false);
    expect(
      '${result.stdout}${result.stderr}',
      isNot(contains('sb_secret_private')),
    );
    input.writeAsStringSync('# secret comment\n$valid');
    final success = await Process.run(dart, [
      '--packages=${packages.path}',
      script,
      '--input',
      input.path,
    ], workingDirectory: dir.path);
    expect(success.exitCode, 0);
    expect(File('${dir.path}/assets/client.env').readAsStringSync(), valid);
  });
}
