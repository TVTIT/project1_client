import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/router/routes.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';

void main() {
  test('summary accepts omitted optional name from backend flat DTO', () {
    final summary = TwinSummaryItem.fromJson({
      'id': 'urn:ngsi-ld:Gateway:gw',
      'type': 'Gateway',
      'gateway_id': 'gw',
      'modifiedAt': '2026-10-23T00:00:00Z',
    });
    expect(summary.name, isNull);
  });
  test('summary rejects missing required modifiedAt from backend flat DTO', () {
    expect(
      () => TwinSummaryItem.fromJson({
        'id': 'urn:ngsi-ld:Gateway:gw',
        'type': 'Gateway',
        'gateway_id': 'gw',
        'name': 'Station',
      }),
      throwsFormatException,
    );
  });
  test('EntityUrn rejects invalid IDs and reserved gateway', () {
    for (final id in [
      '',
      '_bad',
      'a/b',
      'a b',
      'é',
      'a' * 65,
      'backend_service',
      'good\n',
    ]) {
      expect(
        () => EntityUrn.parse('urn:ngsi-ld:Gateway:$id'),
        throwsFormatException,
        reason: id,
      );
      expect(
        () => EntityUrn.parse('urn:ngsi-ld:Sensor:$id:s'),
        throwsFormatException,
        reason: id,
      );
    }
    expect(
      EntityUrn.parse('urn:ngsi-ld:Sensor:gw:backend_service').sensorId,
      'backend_service',
    );
    expect(
      () => EntityUrn.parse('urn:ngsi-ld:Sensor:gw:_bad'),
      throwsFormatException,
    );
  });

  test('summary rejects malformed data instead of defaulting fields', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {
        'id': 'urn:ngsi-ld:Gateway:gw',
        'type': 'Sensor',
        'gateway_id': 'gw',
        'name': 'X',
      },
      {
        'id': 'urn:ngsi-ld:Gateway:gw',
        'type': 'Gateway',
        'gateway_id': 'other',
        'name': 'X',
      },
      {
        'id': 'urn:ngsi-ld:Gateway:gw',
        'type': 'Gateway',
        'gateway_id': 'gw',
        'name': 42,
      },
      {
        'id': 'urn:ngsi-ld:Gateway:gw',
        'type': 'Gateway',
        'gateway_id': 'gw',
        'name': 'X',
        'modifiedAt': 'bad',
      },
    ]) {
      expect(() => TwinSummaryItem.fromJson(json), throwsFormatException);
    }
  });

  test('authenticated navigation includes non-admin Digital Twins', () {
    expect(
      kNav.where((n) => n.path == '/digital-twins' && !n.adminOnly),
      hasLength(1),
    );
  });
}
