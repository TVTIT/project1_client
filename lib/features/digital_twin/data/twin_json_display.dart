import 'dart:convert';

/// Passive readable JSON with exact BigInt numeric tokens (not quoted strings).
/// This is display text, never HTML or a JSON-LD processor.
String formatTwinJson(Object? value, [int depth = 0]) {
  final indent = '  ' * depth;
  final childIndent = '  ' * (depth + 1);
  if (value is BigInt) return value.toString();
  if (value is Map) {
    if (value.isEmpty) return '{}';
    return '{\n${value.entries.map((e) => '$childIndent${jsonEncode(e.key)}: ${formatTwinJson(e.value, depth + 1)}').join(',\n')}\n$indent}';
  }
  if (value is List) {
    if (value.isEmpty) return '[]';
    return '[\n${value.map((v) => '$childIndent${formatTwinJson(v, depth + 1)}').join(',\n')}\n$indent]';
  }
  return jsonEncode(value);
}
