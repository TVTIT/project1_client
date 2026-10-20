import 'package:flutter_test/flutter_test.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';

void main() {
  group('Digital Twin DTOs & Validation', () {
    test('EntityUrn parses and single-encodes Gateway and Sensor URNs', () {
      final gw = EntityUrn.parse('urn:ngsi-ld:Gateway:gw-001');
      expect(gw.type, EntityType.gateway);
      expect(gw.gatewayId, 'gw-001');
      expect(gw.sensorId, isNull);
      expect(gw.encoded, 'urn%3Angsi-ld%3AGateway%3Agw-001');

      final sensor = EntityUrn.parse('urn:ngsi-ld:Sensor:gw-001:temp-01');
      expect(sensor.type, EntityType.sensor);
      expect(sensor.gatewayId, 'gw-001');
      expect(sensor.sensorId, 'temp-01');
      expect(sensor.encoded, 'urn%3Angsi-ld%3ASensor%3Agw-001%3Atemp-01');

      expect(
        () => EntityUrn.parse('invalid-prefix:Gateway:gw-1'),
        throwsFormatException,
      );
      expect(
        () => EntityUrn.parse('urn:ngsi-ld:UnknownType:gw-1'),
        throwsFormatException,
      );
    });

    test(
      'TwinSummaryItem parses both simplified and normalized summary items',
      () {
        // Simplified flat summary item
        final simplifiedJson = {
          'id': 'urn:ngsi-ld:Gateway:gw-1',
          'type': 'Gateway',
          'name': 'Greenhouse Station',
          'gateway_id': 'gw-1',
          'modifiedAt': '2026-10-15T12:00:00Z',
        };
        final item1 = TwinSummaryItem.fromJson(simplifiedJson);
        expect(item1.id, 'urn:ngsi-ld:Gateway:gw-1');
        expect(item1.name, 'Greenhouse Station');
        expect(item1.gatewayId, 'gw-1');

        // Normalized summary item with PropertyDTO wrapper
        final normalizedJson = {
          'id': 'urn:ngsi-ld:Gateway:gw-1',
          'type': 'Gateway',
          'name': {
            'type': 'Property',
            'value': 'Greenhouse Station Normalized',
          },
          'gateway_id': {'type': 'Property', 'value': 'gw-1'},
          'modifiedAt': '2026-10-15T12:00:00Z',
        };
        final item2 = TwinSummaryItem.fromJson(normalizedJson);
        expect(item2.name, 'Greenhouse Station Normalized');
        expect(item2.gatewayId, 'gw-1');
      },
    );

    test('TwinStateResponse preserves exact version strings and JSONB numeric state', () {
      final stateJson = {
        'id': 'urn:ngsi-ld:Sensor:gw-1:s-1',
        'type': 'Sensor',
        'gateway_id': 'gw-1',
        'reported_state': {
          'temperature': 25.5,
          'sample_interval_us': 1000000,
          'counter': 9007199254740993, // Large integer
        },
        'desired_state': {'sample_interval_us': 2000000},
        'reported_version': '1',
        'desired_version': '42',
        'updated_at': '2026-10-19T08:30:00Z',
      };

      final state = TwinStateResponse.fromJson(stateJson);
      expect(state.reportedVersion, isA<String>());
      expect(state.reportedVersion, '1');
      expect(state.desiredVersion, isA<String>());
      expect(state.desiredVersion, '42');

      expect(state.reportedState['temperature'], 25.5);
      expect(state.reportedState['sample_interval_us'], 1000000);
      expect(state.reportedState['counter'], 9007199254740993);
      expect(state.desiredState['sample_interval_us'], 2000000);
    });

    test('TwinTemporalResponse parses raw temporal values', () {
      final rawJson = {
        'id': 'urn:ngsi-ld:Sensor:gw-1:temp-1',
        'type': 'Sensor',
        'measurement': {
          'type': 'Property',
          'values': [
            [25.4, '2026-10-19T08:00:00.000000Z'],
            [25.6, '2026-10-19T08:01:00.000000Z'],
          ],
        },
      };

      final resp = TwinTemporalResponse.fromJson(
        rawJson,
        attrName: 'measurement',
      );
      expect(resp.isAggregated, isFalse);
      expect(resp.rawPoints.length, 2);
      expect(resp.rawPoints[0].value, 25.4);
      expect(
        resp.rawPoints[0].observedAt,
        DateTime.parse('2026-10-19T08:00:00Z').toUtc(),
      );
    });

    test('TwinTemporalResponse parses aggregated bucket values and keeps totalCount BigInt exact', () {
      final aggrJson = {
        'id': 'urn:ngsi-ld:Sensor:gw-1:temp-1',
        'type': 'Sensor',
        'measurement': {
          'type': 'Property',
          'avg': [
            [25.5, '2026-10-19T08:00:00Z', '2026-10-19T09:00:00Z'],
          ],
          'min': [
            [24.0, '2026-10-19T08:00:00Z', '2026-10-19T09:00:00Z'],
          ],
          'max': [
            [27.0, '2026-10-19T08:00:00Z', '2026-10-19T09:00:00Z'],
          ],
          'totalCount': [
            [
              BigInt.parse('9007199254740993'),
              '2026-10-19T08:00:00Z',
              '2026-10-19T09:00:00Z',
            ],
          ],
        },
      };

      final resp = TwinTemporalResponse.fromJson(
        aggrJson,
        attrName: 'measurement',
      );
      expect(resp.isAggregated, isTrue);
      expect(resp.avgBuckets[0].value, 25.5);
      expect(resp.minBuckets[0].value, 24.0);
      expect(resp.maxBuckets[0].value, 27.0);

      // totalCount must be exact BigInt
      expect(resp.totalCountBuckets[0].value, isA<BigInt>());
      expect(resp.totalCountBuckets[0].value, BigInt.parse('9007199254740993'));
      expect(resp.totalCountBuckets[0].value.toString(), '9007199254740993');
    });

    test('PatchTwinAttrsInput generates Normalized Property Fragment with ternary description', () {
      // 1. Name only (description unchanged / omitted)
      const input1 = PatchTwinAttrsInput(name: 'Updated Sensor');
      expect(input1.toJson(), {
        'name': {'type': 'Property', 'value': 'Updated Sensor'},
      });

      // 2. Name with new text description
      const input2 = PatchTwinAttrsInput(
        name: 'Updated Gateway',
        description: 'New Description Text',
      );
      expect(input2.toJson(), {
        'name': {'type': 'Property', 'value': 'Updated Gateway'},
        'description': {'type': 'Property', 'value': 'New Description Text'},
      });

      // 3. Name with clear description (urn:ngsi-ld:null)
      const input3 = PatchTwinAttrsInput(
        name: 'Cleared Gateway',
        clearDescription: true,
      );
      expect(input3.toJson(), {
        'name': {'type': 'Property', 'value': 'Cleared Gateway'},
        'description': {'type': 'Property', 'value': 'urn:ngsi-ld:null'},
      });
    });

    test(
      'PostTwinEntityInput serializes Gateway and Sensor creation payloads',
      () {
        const gwInput = PostTwinEntityInput(
          entityType: EntityType.gateway,
          gatewayId: 'gw-001',
          name: 'Main Gateway',
          description: 'Station 1',
          ownerUserId: '550e8400-e29b-41d4-a716-446655440000',
        );
        expect(gwInput.toJson(), {
          'entity_type': 'Gateway',
          'gateway_id': 'gw-001',
          'name': 'Main Gateway',
          'description': 'Station 1',
          'owner_user_id': '550e8400-e29b-41d4-a716-446655440000',
        });

        const sensorInput = PostTwinEntityInput(
          entityType: EntityType.sensor,
          gatewayId: 'gw-001',
          sensorId: 'temp-01',
          name: 'Temperature Sensor',
          unit: '°C',
        );
        expect(sensorInput.toJson(), {
          'entity_type': 'Sensor',
          'gateway_id': 'gw-001',
          'name': 'Temperature Sensor',
          'sensor_id': 'temp-01',
          'unit': '°C',
        });
      },
    );
  });
}
