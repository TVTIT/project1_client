import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/network/web_safe_json.dart';

void main() {
  group('WebSafeJson Decoder', () {
    test('decodes basic objects, arrays, and primitives', () {
      const jsonStr = '''
      {
        "string": "hello world",
        "int": 42,
        "negative_int": -100,
        "double": 3.14159,
        "bool_true": true,
        "bool_false": false,
        "null_val": null,
        "list": [1, 2, "three", false, null],
        "nested": {
          "inner_key": "inner_val"
        }
      }
      ''';

      final decoded = webSafeJsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['string'], 'hello world');
      expect(decoded['int'], 42);
      expect(decoded['negative_int'], -100);
      expect(decoded['double'], 3.14159);
      expect(decoded['bool_true'], true);
      expect(decoded['bool_false'], false);
      expect(decoded['null_val'], isNull);
      expect(decoded['list'], [1, 2, 'three', false, null]);
      expect(decoded['nested'], {'inner_key': 'inner_val'});
    });

    test('decodes root JSON array', () {
      const jsonStr = '[{"id": "urn:1"}, {"id": "urn:2"}]';
      final decoded = webSafeJsonDecode(jsonStr) as List<dynamic>;
      expect(decoded.length, 2);
      expect(decoded[0]['id'], 'urn:1');
      expect(decoded[1]['id'], 'urn:2');
    });

    test('keeps version strings as exact strings', () {
      const jsonStr = '''
      {
        "reported_version": "1",
        "desired_version": "42"
      }
      ''';

      final decoded = webSafeJsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['reported_version'], isA<String>());
      expect(decoded['reported_version'], '1');
      expect(decoded['desired_version'], isA<String>());
      expect(decoded['desired_version'], '42');
    });

    test('preserves exact digits for integers beyond JS safe integer range (2^53 - 1)', () {
      // 2^53 - 1 = 9007199254740991 (safe int)
      // 9007199254740993 would be rounded to 9007199254740992 by normal JS jsonDecode
      // 9223372036854775807 is int64 max
      const jsonStr = '''
      {
        "safe_int": 9007199254740991,
        "safe_negative": -9007199254740991,
        "large_int_1": 9007199254740993,
        "large_int_2": 9223372036854775807,
        "large_negative": -9007199254740993
      }
      ''';

      final decoded = webSafeJsonDecode(jsonStr) as Map<String, dynamic>;

      // Safe integers fit in standard int
      expect(decoded['safe_int'], 9007199254740991);
      expect(decoded['safe_negative'], -9007199254740991);

      // Large integers outside safe range are preserved as BigInt without digit loss
      expect(decoded['large_int_1'], isA<BigInt>());
      expect(decoded['large_int_1'], BigInt.parse('9007199254740993'));
      expect(decoded['large_int_1'].toString(), '9007199254740993');

      expect(decoded['large_int_2'], isA<BigInt>());
      expect(decoded['large_int_2'], BigInt.parse('9223372036854775807'));
      expect(decoded['large_int_2'].toString(), '9223372036854775807');

      expect(decoded['large_negative'], isA<BigInt>());
      expect(decoded['large_negative'], BigInt.parse('-9007199254740993'));
      expect(decoded['large_negative'].toString(), '-9007199254740993');
    });

    test('does NOT convert all state numbers to strings (state numbers remain numeric)', () {
      const jsonStr = '''
      {
        "reported_state": {
          "temperature": 25.4,
          "sample_interval_us": 1000000,
          "counter": 42
        }
      }
      ''';

      final decoded = webSafeJsonDecode(jsonStr) as Map<String, dynamic>;
      final state = decoded['reported_state'] as Map<String, dynamic>;

      expect(state['temperature'], isA<num>());
      expect(state['temperature'], 25.4);
      expect(state['sample_interval_us'], isA<num>());
      expect(state['sample_interval_us'], 1000000);
      expect(state['counter'], isA<num>());
      expect(state['counter'], 42);

      // Verify they are NOT strings
      expect(state['temperature'], isNot(isA<String>()));
      expect(state['sample_interval_us'], isNot(isA<String>()));
      expect(state['counter'], isNot(isA<String>()));
    });

    test(
      'handles strings with escaped quotes, backslashes, and unicode safely',
      () {
        const jsonStr = '''
      {
        "url": "http://localhost:8080/v1/gateways/1234567890123456789",
        "escaped": "Quote: \\"Hello\\", backslash: \\\\, newline: \\n, tab: \\t",
        "unicode": "T\\u1ef7 l\\u1ec7 th\\u00e0nh c\\u00f4ng"
      }
      ''';

        final decoded = webSafeJsonDecode(jsonStr) as Map<String, dynamic>;
        expect(
          decoded['url'],
          'http://localhost:8080/v1/gateways/1234567890123456789',
        );
        expect(
          decoded['escaped'],
          'Quote: "Hello", backslash: \\, newline: \n, tab: \t',
        );
        expect(decoded['unicode'], 'Tỷ lệ thành công');
      },
    );

    test('throws FormatException on malformed JSON', () {
      expect(() => webSafeJsonDecode('{ invalid }'), throwsFormatException);
      expect(() => webSafeJsonDecode('[1, 2,'), throwsFormatException);
      expect(
        () => webSafeJsonDecode('{"key": "unterminated'),
        throwsFormatException,
      );
    });

    test('rejects excessive recursion depth to prevent stack overflow', () {
      final deeplyNested = '[' * 600 + ']' * 600;
      expect(() => webSafeJsonDecode(deeplyNested), throwsFormatException);
    });

    test(
      'rejects invalid JSON numbers (leading zeros, trailing dots/exponents)',
      () {
        // RFC 8259 forbids leading zero integers (e.g. 01), trailing dots (1.), and naked exponents (1e)
        expect(() => webSafeJsonDecode('{"val": 01}'), throwsFormatException);
        expect(() => webSafeJsonDecode('{"val": -01}'), throwsFormatException);
        expect(() => webSafeJsonDecode('{"val": 1.}'), throwsFormatException);
        expect(() => webSafeJsonDecode('{"val": 1e}'), throwsFormatException);
      },
    );

    test('rejects unterminated escape sequences at end of string', () {
      expect(() => webSafeJsonDecode('{"key": "val\\'), throwsFormatException);
    });
  });
}
