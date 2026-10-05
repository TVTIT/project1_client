import 'dart:io';

import 'package:kite/core/config/public_env.dart';

void main(List<String> args) {
  final output = File('assets/client.env');
  try {
    var input = '.env';
    var allowPlaceholder = false;
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--allow-placeholder') {
        allowPlaceholder = true;
      } else if (args[i] == '--input' && i + 1 < args.length) {
        input = args[++i];
      } else {
        throw const FormatException('Invalid arguments.');
      }
    }
    final env = validatePublicEnv(
      parsePublicEnv(File(input).readAsStringSync()),
      allowPlaceholder: allowPlaceholder,
    );
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(serializePublicEnv(env));
    stdout.writeln('Public client asset generated.');
  } catch (_) {
    if (output.existsSync()) output.deleteSync();
    stderr.writeln('Invalid public configuration. No asset generated.');
    exitCode = 1;
  }
}
