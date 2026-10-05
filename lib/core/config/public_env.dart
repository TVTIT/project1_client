import 'dart:convert';

const publicEnvKeys = {
  'BACKEND_API_BASE_URL',
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'ENVIRONMENT',
  'BACKEND_WS_URL',
};

/// Single-line subset: KEY=value, optional paired quotes, blank/full comments.
/// No export, interpolation, escapes, inline comments or multiline values.
Map<String, String> parsePublicEnv(String source) {
  final values = <String, String>{};
  for (final raw in source.split('\n')) {
    final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
    if (RegExp(r'[\x00-\x08\x0b-\x1f\x7f]').hasMatch(line)) {
      throw const FormatException('Cấu hình chứa ký tự không được phép.');
    }
    final text = line.trim();
    if (text.isEmpty || text.startsWith('#')) continue;
    final match = RegExp(r'^([A-Z][A-Z0-9_]*)\s*=\s*(.*)$').firstMatch(text);
    if (match == null) {
      throw const FormatException('Dòng cấu hình không hợp lệ.');
    }
    final key = match[1]!;
    if (!publicEnvKeys.contains(key) || values.containsKey(key)) {
      throw const FormatException('Biến trùng hoặc không được phép.');
    }
    var value = match[2]!;
    if (value.startsWith('"') || value.startsWith("'")) {
      if (value.length < 2 || !value.endsWith(value[0])) {
        throw const FormatException('Dấu nháy cấu hình không hợp lệ.');
      }
      value = value.substring(1, value.length - 1);
    }
    if (RegExp(r'''[\s$\\#"']''').hasMatch(value)) {
      throw const FormatException('Giá trị cấu hình không hợp lệ.');
    }
    values[key] = value;
  }
  return values;
}

Map<String, String> validatePublicEnv(
  Map<String, String> input, {
  bool allowPlaceholder = false,
}) {
  if (input.keys.any((key) => !publicEnvKeys.contains(key))) {
    throw const FormatException('Biến môi trường không được phép.');
  }
  final env = Map<String, String>.from(input);
  if (env.values.any(
    (value) => RegExp(r'''[\s$\\#"'\x00-\x1f\x7f]''').hasMatch(value),
  )) {
    throw const FormatException('Giá trị cấu hình không hợp lệ.');
  }
  for (final key in publicEnvKeys.where((key) => key != 'BACKEND_WS_URL')) {
    if (env[key] == null || env[key]!.isEmpty) {
      throw const FormatException('Thiếu cấu hình bắt buộc.');
    }
  }
  if (!{'development', 'staging', 'production'}.contains(env['ENVIRONMENT'])) {
    throw const FormatException('ENVIRONMENT không hợp lệ.');
  }
  final key = env['SUPABASE_ANON_KEY']!;
  if (key == 'replace_with_public_anon_key') {
    if (!allowPlaceholder) {
      throw const FormatException('Không chấp nhận placeholder.');
    }
  } else if (!RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(key)) {
    try {
      final parts = key.split('.');
      if (parts.length != 3 ||
          parts.any((p) => !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(p))) {
        throw const FormatException();
      }
      final header = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
      );
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (header is! Map || payload is! Map || payload['role'] != 'anon') {
        throw const FormatException();
      }
    } catch (_) {
      throw const FormatException(
        'Khóa không hợp lệ: chỉ public key hoặc JWT role "anon"; không sb_secret_.',
      );
    }
  }
  for (final name in [
    'BACKEND_API_BASE_URL',
    'SUPABASE_URL',
    'BACKEND_WS_URL',
  ]) {
    final value = env[name];
    if (name == 'BACKEND_WS_URL' && (value == null || value.isEmpty)) continue;
    final uri = Uri.tryParse(value!);
    final ws = name == 'BACKEND_WS_URL';
    if (uri == null ||
        uri.host.isEmpty ||
        !uri.hasAuthority ||
        !(ws ? {'ws', 'wss'} : {'http', 'https'}).contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        RegExp(r'\s').hasMatch(value)) {
      throw const FormatException('URL cấu hình không hợp lệ.');
    }
    if (uri.host == '10.0.2.2') {
      throw const FormatException('Không sử dụng 10.0.2.2.');
    }
    if (env['ENVIRONMENT'] == 'production' &&
        uri.scheme != (ws ? 'wss' : 'https')) {
      throw const FormatException('Production yêu cầu HTTPS/WSS.');
    }
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (name == 'BACKEND_API_BASE_URL' && !path.endsWith('/v1')) {
      throw const FormatException('Backend phải kết thúc /v1.');
    }
    if (name == 'SUPABASE_URL' && path.isNotEmpty) {
      throw const FormatException('Supabase phải là root, không /auth/v1.');
    }
  }
  return env;
}

String serializePublicEnv(Map<String, String> env) => publicEnvKeys
    .where(env.containsKey)
    .map((key) => '$key=${env[key]}\n')
    .join();
