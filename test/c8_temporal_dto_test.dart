import 'package:flutter_test/flutter_test.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';

void main() {
  group('C8 Temporal DTO & Empty Aggregate Mode', () {
    test('empty aggregate payload must retain isAggregated == true', () {
      final json = {
        'id': 'urn:ngsi-ld:Sensor:gw1:sensor1',
        'type': 'Sensor',
        'measurement': {
          'type': 'Property',
          'avg': <dynamic>[],
          'min': <dynamic>[],
          'max': <dynamic>[],
          'totalCount': <dynamic>[],
        },
      };

      final response = TwinTemporalResponse.fromJson(
        json,
        attrName: 'measurement',
      );

      expect(response.isAggregated, isTrue);
      expect(response.isRaw, isFalse);
    });

    test('raw mode payload correctly sets isAggregated == false', () {
      final json = {
        'id': 'urn:ngsi-ld:Sensor:gw1:sensor1',
        'type': 'Sensor',
        'measurement': {
          'type': 'Property',
          'values': [
            [24.5, '2026-10-23T10:00:00.000000Z'],
            [24.8, '2026-10-23T10:00:01.000000Z'],
          ],
        },
      };

      final response = TwinTemporalResponse.fromJson(
        json,
        attrName: 'measurement',
      );
      expect(response.isAggregated, isFalse);
      expect(response.isRaw, isTrue);
      expect(response.rawPoints.length, 2);
      expect(response.rawPoints[0].value, 24.5);
      expect(response.rawPoints[1].value, 24.8);
    });

    test('raw mode preserves duplicate timestamps', () {
      final json = {
        'id': 'urn:ngsi-ld:Sensor:gw1:sensor1',
        'type': 'Sensor',
        'measurement': {
          'type': 'Property',
          'values': [
            [10.0, '2026-10-23T10:00:00.000000Z'],
            [12.0, '2026-10-23T10:00:00.000000Z'],
          ],
        },
      };

      final response = TwinTemporalResponse.fromJson(
        json,
        attrName: 'measurement',
      );
      expect(response.rawPoints.length, 2);
      expect(
        response.rawPoints[0].observedAt,
        response.rawPoints[1].observedAt,
      );
      expect(response.rawPoints[0].value, 10.0);
      expect(response.rawPoints[1].value, 12.0);
    });

    test('totalCount parses exact integer BigInt without precision loss', () {
      final triple = [
        '9007199254740993', // 2^53 + 1, larger than double safe integer
        '2026-10-23T10:00:00.000000Z',
        '2026-10-23T10:05:00.000000Z',
      ];

      final point = TemporalBucketPoint.countTriple(triple);
      expect(point.value, BigInt.parse('9007199254740993'));
      expect(point.value.toString(), '9007199254740993');
    });

    test(
      'strict numeric validation rejects NaN and Infinity in raw points',
      () {
        final nanTuple = [double.nan, '2026-10-23T10:00:00Z'];
        expect(
          () => TemporalRawPoint.fromTuple(nanTuple),
          throwsA(isA<FormatException>()),
        );

        final infTuple = [double.infinity, '2026-10-23T10:00:00Z'];
        expect(
          () => TemporalRawPoint.fromTuple(infTuple),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('TemporalStats Calculations', () {
    test('raw mode calculates arithmetic mean, min, max and count', () {
      final response = TwinTemporalResponse(
        id: 'urn:ngsi-ld:Sensor:gw1:s1',
        type: 'Sensor',
        attrName: 'measurement',
        isAggregated: false,
        rawPoints: [
          TemporalRawPoint(
            value: 20.0,
            observedAt: DateTime.parse('2026-10-23T10:00:00Z'),
          ),
          TemporalRawPoint(
            value: 30.0,
            observedAt: DateTime.parse('2026-10-23T10:00:05Z'),
          ),
        ],
      );

      final stats = TemporalStats.calculate(response);
      expect(stats, isNotNull);
      expect(stats!.min, 20.0);
      expect(stats.max, 30.0);
      expect(stats.avg, 25.0);
      expect(stats.count, BigInt.from(2));
      expect(stats.isRaw, isTrue);
    });

    test('aggregated mode calculates weighted mean sum(avg*count)/sum(count), not average of averages', () {
      // Bucket 1: avg = 10.0, count = 100
      // Bucket 2: avg = 20.0, count = 10
      // Simple average of averages would be (10 + 20) / 2 = 15.0
      // Weighted mean is (10*100 + 20*10) / (100 + 10) = 1200 / 110 = 10.9090909...
      final response = TwinTemporalResponse(
        id: 'urn:ngsi-ld:Sensor:gw1:s1',
        type: 'Sensor',
        attrName: 'measurement',
        isAggregated: true,
        avgBuckets: [
          TemporalBucketPoint(
            value: 10.0,
            bucketStart: DateTime.parse('2026-10-23T10:00:00Z'),
            bucketEnd: DateTime.parse('2026-10-23T10:05:00Z'),
          ),
          TemporalBucketPoint(
            value: 20.0,
            bucketStart: DateTime.parse('2026-10-23T10:05:00Z'),
            bucketEnd: DateTime.parse('2026-10-23T10:10:00Z'),
          ),
        ],
        minBuckets: [
          TemporalBucketPoint(
            value: 5.0,
            bucketStart: DateTime.parse('2026-10-23T10:00:00Z'),
            bucketEnd: DateTime.parse('2026-10-23T10:05:00Z'),
          ),
          TemporalBucketPoint(
            value: 15.0,
            bucketStart: DateTime.parse('2026-10-23T10:05:00Z'),
            bucketEnd: DateTime.parse('2026-10-23T10:10:00Z'),
          ),
        ],
        maxBuckets: [
          TemporalBucketPoint(
            value: 12.0,
            bucketStart: DateTime.parse('2026-10-23T10:00:00Z'),
            bucketEnd: DateTime.parse('2026-10-23T10:05:00Z'),
          ),
          TemporalBucketPoint(
            value: 25.0,
            bucketStart: DateTime.parse('2026-10-23T10:05:00Z'),
            bucketEnd: DateTime.parse('2026-10-23T10:10:00Z'),
          ),
        ],
        totalCountBuckets: [
          TemporalBucketPoint(
            value: BigInt.from(100),
            bucketStart: DateTime.parse('2026-10-23T10:00:00Z'),
            bucketEnd: DateTime.parse('2026-10-23T10:05:00Z'),
          ),
          TemporalBucketPoint(
            value: BigInt.from(10),
            bucketStart: DateTime.parse('2026-10-23T10:05:00Z'),
            bucketEnd: DateTime.parse('2026-10-23T10:10:00Z'),
          ),
        ],
      );

      final stats = TemporalStats.calculate(response);
      expect(stats, isNotNull);
      expect(stats!.min, 5.0);
      expect(stats.max, 25.0);
      expect(stats.count, BigInt.from(110));
      expect(stats.avg, closeTo(10.90909, 0.0001));
      expect(stats.isRaw, isFalse);
    });

    test('aggregated stats returns null when bucket methods are incomplete or empty', () {
      const response = TwinTemporalResponse(
        id: 'urn:ngsi-ld:Sensor:gw1:s1',
        type: 'Sensor',
        attrName: 'measurement',
        isAggregated: true,
        avgBuckets: [],
        minBuckets: [],
        maxBuckets: [],
        totalCountBuckets: [],
      );

      final stats = TemporalStats.calculate(response);
      expect(stats, isNull);
    });
  });

  group('TemporalQueryParameters Bounds Validation', () {
    test('raw mode rejects range > 10 seconds', () {
      final start = DateTime.parse('2026-10-23T10:00:00Z');
      final end = DateTime.parse('2026-10-23T10:00:11Z'); // 11s > 10s

      final params = TemporalQueryParameters(
        timeAt: start,
        endTimeAt: end,
        mode: TemporalQueryMode.raw,
      );

      expect(() => params.validate(), throwsA(isA<FormatException>()));
    });

    test('raw mode allows range <= 10 seconds', () {
      final start = DateTime.parse('2026-10-23T10:00:00Z');
      final end = DateTime.parse('2026-10-23T10:00:10Z'); // 10s

      final params = TemporalQueryParameters(
        timeAt: start,
        endTimeAt: end,
        mode: TemporalQueryMode.raw,
      );

      expect(() => params.validate(), returnsNormally);
    });

    test('rejects range > 744 hours (31 days)', () {
      final start = DateTime.parse('2026-10-01T00:00:00Z');
      final end = DateTime.parse('2026-11-02T00:00:00Z'); // 32 days > 31 days

      final params = TemporalQueryParameters(
        timeAt: start,
        endTimeAt: end,
        mode: TemporalQueryMode.aggregated,
        aggrPeriodDuration: 'P1D',
      );

      expect(() => params.validate(), throwsA(isA<FormatException>()));
    });

    test('rejects non-canonical aggregation duration', () {
      final start = DateTime.parse('2026-10-23T00:00:00Z');
      final end = DateTime.parse('2026-10-23T12:00:00Z');

      final params = TemporalQueryParameters(
        timeAt: start,
        endTimeAt: end,
        mode: TemporalQueryMode.aggregated,
        aggrPeriodDuration: 'PT2M', // Not in 9 canonical durations!
      );

      expect(() => params.validate(), throwsA(isA<FormatException>()));
    });

    test('accepts all 9 canonical aggregation durations', () {
      final start = DateTime.parse('2026-10-23T00:00:00Z');
      final end = DateTime.parse('2026-10-23T12:00:00Z');

      for (final d in TemporalQueryParameters.canonicalDurations) {
        final params = TemporalQueryParameters(
          timeAt: start,
          endTimeAt: end,
          mode: TemporalQueryMode.aggregated,
          aggrPeriodDuration: d,
        );
        expect(() => params.validate(), returnsNormally);
      }
    });

    test('validates maxPoints bounds 100..2000', () {
      final start = DateTime.parse('2026-10-23T00:00:00Z');
      final end = DateTime.parse('2026-10-23T12:00:00Z');

      expect(
        () => TemporalQueryParameters(
          timeAt: start,
          endTimeAt: end,
          maxPoints: 99,
        ).validate(),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TemporalQueryParameters(
          timeAt: start,
          endTimeAt: end,
          maxPoints: 2001,
        ).validate(),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => TemporalQueryParameters(
          timeAt: start,
          endTimeAt: end,
          maxPoints: 1000,
        ).validate(),
        returnsNormally,
      );
    });
  });
}
