import 'dart:convert';

/// Decodes a JSON string while preserving exact 64-bit integer precision.
///
/// On Flutter Web compiled to JavaScript, standard `jsonDecode` delegates to
/// native `JSON.parse`, which rounds integers outside `[-2^53 + 1, 2^53 - 1]`
/// (`[-9007199254740991, 9007199254740991]`) to IEEE-754 64-bit floats,
/// permanently losing digits.
///
/// This decoder:
/// - Preserves integers within the safe range as `int`.
/// - Preserves large integers exceeding the safe range as `BigInt`.
/// - Preserves floating-point numbers (with `.` or `e`/`E`) as `double`.
/// - Preserves version strings and string literals as `String`.
/// - Never converts non-string numbers to strings.
/// - Operates directly on character tokens without regex JSON rewriting.
dynamic webSafeJsonDecode(String source) {
  return _WebSafeJsonDecoder(source).decode();
}

class _WebSafeJsonDecoder {
  _WebSafeJsonDecoder(this.src);

  final String src;
  int pos = 0;
  int depth = 0;

  static const int maxDepth = 512;
  static final BigInt _maxSafe = BigInt.from(9007199254740991);
  static final BigInt _minSafe = BigInt.from(-9007199254740991);

  dynamic decode() {
    _skipWhitespace();
    if (pos >= src.length) {
      throw const FormatException('Empty JSON input');
    }
    final result = _parseValue();
    _skipWhitespace();
    if (pos < src.length) {
      throw FormatException(
        'Unexpected trailing character at position $pos: "${src[pos]}"',
        src,
        pos,
      );
    }
    return result;
  }

  void _skipWhitespace() {
    while (pos < src.length) {
      final c = src.codeUnitAt(pos);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        pos++;
      } else {
        break;
      }
    }
  }

  dynamic _parseValue() {
    _skipWhitespace();
    if (pos >= src.length) {
      throw FormatException('Unexpected end of JSON input at $pos', src, pos);
    }
    final c = src.codeUnitAt(pos);
    if (c == 0x7B) return _parseObject(); // '{'
    if (c == 0x5B) return _parseArray(); // '['
    if (c == 0x22) return _parseString(); // '"'
    if (c == 0x74) return _parseLiteral('true', true);
    if (c == 0x66) return _parseLiteral('false', false);
    if (c == 0x6E) return _parseLiteral('null', null);
    if (c == 0x2D || (c >= 0x30 && c <= 0x39)) return _parseNumber();

    throw FormatException(
      'Unexpected character at position $pos: "${src[pos]}"',
      src,
      pos,
    );
  }

  Map<String, dynamic> _parseObject() {
    if (++depth > maxDepth) {
      throw FormatException(
        'JSON nesting depth exceeded maximum limit of $maxDepth',
        src,
        pos,
      );
    }
    pos++; // skip '{'
    final map = <String, dynamic>{};
    _skipWhitespace();
    if (pos < src.length && src.codeUnitAt(pos) == 0x7D) {
      pos++; // skip '}'
      depth--;
      return map;
    }

    try {
      while (pos < src.length) {
        _skipWhitespace();
        if (pos >= src.length || src.codeUnitAt(pos) != 0x22) {
          throw FormatException(
            'Expected string key in object at $pos',
            src,
            pos,
          );
        }
        final key = _parseString();
        _skipWhitespace();
        if (pos >= src.length || src.codeUnitAt(pos) != 0x3A) {
          // ':'
          throw FormatException(
            'Expected ":" after key in object at $pos',
            src,
            pos,
          );
        }
        pos++; // skip ':'
        _skipWhitespace();
        final value = _parseValue();
        map[key] = value;
        _skipWhitespace();
        if (pos >= src.length) {
          throw FormatException('Unterminated object in JSON input', src, pos);
        }
        final next = src.codeUnitAt(pos);
        if (next == 0x7D) {
          // '}'
          pos++;
          return map;
        }
        if (next == 0x2C) {
          // ','
          pos++;
          continue;
        }
        throw FormatException(
          'Expected "," or "}" in object at $pos, got "${src[pos]}"',
          src,
          pos,
        );
      }
      throw FormatException('Unterminated object in JSON input', src, pos);
    } finally {
      depth--;
    }
  }

  List<dynamic> _parseArray() {
    if (++depth > maxDepth) {
      throw FormatException(
        'JSON nesting depth exceeded maximum limit of $maxDepth',
        src,
        pos,
      );
    }
    pos++; // skip '['
    final list = <dynamic>[];
    _skipWhitespace();
    if (pos < src.length && src.codeUnitAt(pos) == 0x5D) {
      // ']'
      pos++;
      depth--;
      return list;
    }

    try {
      while (pos < src.length) {
        _skipWhitespace();
        final value = _parseValue();
        list.add(value);
        _skipWhitespace();
        if (pos >= src.length) {
          throw FormatException('Unterminated array in JSON input', src, pos);
        }
        final next = src.codeUnitAt(pos);
        if (next == 0x5D) {
          // ']'
          pos++;
          return list;
        }
        if (next == 0x2C) {
          // ','
          pos++;
          continue;
        }
        throw FormatException(
          'Expected "," or "]" in array at $pos, got "${src[pos]}"',
          src,
          pos,
        );
      }
      throw FormatException('Unterminated array in JSON input', src, pos);
    } finally {
      depth--;
    }
  }

  String _parseString() {
    pos++; // skip opening '"'
    final start = pos;
    var hasEscape = false;
    while (pos < src.length) {
      final c = src.codeUnitAt(pos);
      if (c == 0x5C) {
        // '\'
        if (pos + 1 >= src.length) {
          throw FormatException(
            'Unterminated escape sequence at end of string',
            src,
            pos,
          );
        }
        hasEscape = true;
        pos += 2; // skip escape character
        continue;
      }
      if (c == 0x22) {
        // '"'
        break;
      }
      pos++;
    }
    if (pos >= src.length) {
      throw FormatException('Unterminated string in JSON input', src, pos);
    }
    final raw = src.substring(start, pos);
    pos++; // skip closing '"'

    if (!hasEscape) return raw;
    // Safely delegate escaped string to jsonDecode to handle standard escapes and unicode
    return jsonDecode('"$raw"') as String;
  }

  dynamic _parseLiteral(String expected, dynamic value) {
    if (src.startsWith(expected, pos)) {
      pos += expected.length;
      return value;
    }
    throw FormatException(
      'Invalid literal at $pos (expected $expected)',
      src,
      pos,
    );
  }

  dynamic _parseNumber() {
    final start = pos;
    if (src.codeUnitAt(pos) == 0x2D) pos++; // '-'
    while (pos < src.length) {
      final c = src.codeUnitAt(pos);
      if ((c >= 0x30 && c <= 0x39) ||
          c == 0x2E ||
          c == 0x65 ||
          c == 0x45 ||
          c == 0x2B ||
          c == 0x2D) {
        pos++;
      } else {
        break;
      }
    }
    final numStr = src.substring(start, pos);

    // RFC 8259 number syntax validation
    final checkStr = numStr.startsWith('-') ? numStr.substring(1) : numStr;
    if (checkStr.isEmpty) {
      throw FormatException('Invalid number format: $numStr', src, start);
    }
    if (checkStr.length > 1 &&
        checkStr.startsWith('0') &&
        checkStr.codeUnitAt(1) >= 0x30 &&
        checkStr.codeUnitAt(1) <= 0x39) {
      throw FormatException(
        'Leading zero is forbidden in JSON numbers: $numStr',
        src,
        start,
      );
    }
    if (numStr.endsWith('.') ||
        numStr.endsWith('e') ||
        numStr.endsWith('E') ||
        numStr.endsWith('+') ||
        numStr.endsWith('-')) {
      throw FormatException(
        'Incomplete JSON number format: $numStr',
        src,
        start,
      );
    }
    if (numStr.contains('.')) {
      final dotIdx = numStr.indexOf('.');
      if (dotIdx + 1 >= numStr.length ||
          numStr.codeUnitAt(dotIdx + 1) < 0x30 ||
          numStr.codeUnitAt(dotIdx + 1) > 0x39) {
        throw FormatException(
          'Decimal point must be followed by digits: $numStr',
          src,
          start,
        );
      }
    }

    if (numStr.contains('.') || numStr.contains('e') || numStr.contains('E')) {
      final d = double.tryParse(numStr);
      if (d == null) {
        throw FormatException('Invalid number format: $numStr', src, start);
      }
      return d;
    }

    final bi = BigInt.tryParse(numStr);
    if (bi == null) {
      throw FormatException('Invalid integer format: $numStr', src, start);
    }

    if (bi >= _minSafe && bi <= _maxSafe) {
      return bi.toInt();
    }
    return bi;
  }
}
