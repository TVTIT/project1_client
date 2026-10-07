import 'package:flutter_test/flutter_test.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';

void main() {
  group('isValidGatewayId', () {
    test('accepts valid 1-64 character ASCII identifiers', () {
      expect(isValidGatewayId('gateway_001'), isTrue);
      expect(isValidGatewayId('GW-AM5728-alpha'), isTrue);
      expect(isValidGatewayId('a'), isTrue);
      expect(isValidGatewayId('1'), isTrue);
      expect(isValidGatewayId('a' * 64), isTrue);
      expect(isValidGatewayId('Node_123-ABC'), isTrue);
    });

    test('strictly forbids reserved backend_service identifier', () {
      expect(isValidGatewayId('backend_service'), isFalse);
      expect(isValidGatewayId(kReservedGatewayId), isFalse);
    });

    test('rejects empty, overlong, or invalid characters', () {
      expect(isValidGatewayId(''), isFalse);
      expect(isValidGatewayId('a' * 65), isFalse);
      expect(isValidGatewayId('-leading-hyphen'), isFalse);
      expect(isValidGatewayId('_leading_underscore'), isFalse);
      expect(isValidGatewayId('has space'), isFalse);
      expect(isValidGatewayId('gw/with/slash'), isFalse);
      expect(isValidGatewayId('gw@domain'), isFalse);
      expect(isValidGatewayId('gw#hash'), isFalse);
    });

    test('preserves casing for ID without mutations', () {
      const mixedCase = 'Gw_AM5728_Station';
      expect(isValidGatewayId(mixedCase), isTrue);
      expect(mixedCase, 'Gw_AM5728_Station');
    });
  });

  group('SensorItem', () {
    test('parses full JSON with all fields', () {
      final json = {
        'sensor_id': 'sensor_001',
        'name': 'Ambient Temperature',
        'unit': '°C',
        'created_at': '2026-09-16T08:30:00Z',
      };

      final item = SensorItem.fromJson(json);

      expect(item.sensorId, 'sensor_001');
      expect(item.name, 'Ambient Temperature');
      expect(item.unit, '°C');
      expect(item.createdAt, DateTime.parse('2026-09-16T08:30:00Z'));
    });

    test('parses JSON with nullable unit and created_at', () {
      final json = {
        'sensor_id': 'sensor_002',
        'name': 'Digital Switch',
        'unit': null,
        'created_at': null,
      };

      final item = SensorItem.fromJson(json);

      expect(item.sensorId, 'sensor_002');
      expect(item.name, 'Digital Switch');
      expect(item.unit, isNull);
      expect(item.createdAt, isNull);
    });

    test('distinguishes null from empty string or 0 in unit', () {
      final itemZero = SensorItem.fromJson({
        'sensor_id': 's_zero',
        'name': 'Zero Unit',
        'unit': '0',
      });
      expect(itemZero.unit, '0');

      final itemEmpty = SensorItem.fromJson({
        'sensor_id': 's_empty',
        'name': 'Empty Unit',
        'unit': '',
      });
      expect(itemEmpty.unit, '');

      final itemNull = SensorItem.fromJson({
        'sensor_id': 's_null',
        'name': 'Null Unit',
        'unit': null,
      });
      expect(itemNull.unit, isNull);
    });

    test('throws FormatException on missing or empty sensor_id', () {
      expect(
        () => SensorItem.fromJson({'sensor_id': '', 'name': 'Sensor'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SensorItem.fromJson({'name': 'Sensor'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on missing or invalid name', () {
      expect(
        () => SensorItem.fromJson({'sensor_id': 's1', 'name': 123}),
        throwsA(isA<FormatException>()),
      );
    });

    test('supports equality and toJson', () {
      final item1 = SensorItem(
        sensorId: 's1',
        name: 'Temp',
        unit: 'K',
        createdAt: DateTime.parse('2026-09-16T08:30:00Z'),
      );
      final item2 = SensorItem(
        sensorId: 's1',
        name: 'Temp',
        unit: 'K',
        createdAt: DateTime.parse('2026-09-16T08:30:00Z'),
      );

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));

      final json = item1.toJson();
      expect(json['sensor_id'], 's1');
      expect(json['name'], 'Temp');
      expect(json['unit'], 'K');
    });
  });

  group('SensorListResponse', () {
    test('parses valid empty sensor list', () {
      final json = {'gateway_id': 'gw_001', 'items': <dynamic>[]};

      final response = SensorListResponse.fromJson(json);

      expect(response.gatewayId, 'gw_001');
      expect(response.items, isEmpty);
    });

    test('parses multiple sensor items and matches expectedGatewayId', () {
      final json = {
        'gateway_id': 'gateway_alpha',
        'items': [
          {
            'sensor_id': 'sensor_01',
            'name': 'Humidity',
            'unit': '%',
            'created_at': '2026-09-16T08:30:00Z',
          },
          {
            'sensor_id': 'sensor_02',
            'name': 'Pressure',
            'unit': 'hPa',
            'created_at': null,
          },
        ],
      };

      final response = SensorListResponse.fromJson(
        json,
        expectedGatewayId: 'gateway_alpha',
      );

      expect(response.gatewayId, 'gateway_alpha');
      expect(response.items.length, 2);
      expect(response.items[0].sensorId, 'sensor_01');
      expect(response.items[0].unit, '%');
      expect(response.items[1].sensorId, 'sensor_02');
      expect(response.items[1].unit, 'hPa');
    });

    test('throws FormatException when response gateway_id mismatches expectedGatewayId', () {
      final json = {'gateway_id': 'gateway_foreign', 'items': <dynamic>[]};

      expect(
        () => SensorListResponse.fromJson(
          json,
          expectedGatewayId: 'gateway_target',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('does not match expected'),
          ),
        ),
      );
    });

    test('throws FormatException on malformed response structure', () {
      expect(
        () => SensorListResponse.fromJson({'items': <dynamic>[]}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SensorListResponse.fromJson({'gateway_id': 'gw-1'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
