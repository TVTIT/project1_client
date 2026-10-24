import 'package:flutter_test/flutter_test.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/twin_detail.dart';

void main() {
  test('normalized Property rejects impossible UTC calendar dates', () {
    expect(
      () => TwinProperty.parse<String>({
        'type': 'Property',
        'value': 'Name',
        'modifiedAt': '2026-02-30T12:00:00Z',
      }, (v) => v is String),
      throwsFormatException,
    );
  });
  test('zero-count buckets do not influence extrema; large finite averages do not overflow', () {
    final start = DateTime.utc(2026, 10, 23);
    final middle = start.add(const Duration(minutes: 1));
    final end = middle.add(const Duration(minutes: 1));
    List<TemporalBucketPoint<double>> values(double empty, double real) => [
      TemporalBucketPoint(value: empty, bucketStart: start, bucketEnd: middle),
      TemporalBucketPoint(value: real, bucketStart: middle, bucketEnd: end),
    ];
    final response = TwinTemporalResponse(
      id: 'urn:ngsi-ld:Sensor:gw:s',
      type: 'Sensor',
      attrName: 'measurement',
      avgBuckets: values(0, 1e308),
      minBuckets: values(-100, 1e308),
      maxBuckets: values(0, 1e308),
      totalCountBuckets: [
        TemporalBucketPoint(
          value: BigInt.zero,
          bucketStart: start,
          bucketEnd: middle,
        ),
        TemporalBucketPoint(
          value: BigInt.from(1000),
          bucketStart: middle,
          bucketEnd: end,
        ),
      ],
    );
    final stats = TemporalStats.calculate(response)!;
    expect(stats.min, 1e308);
    expect(stats.max, 1e308);
    expect(stats.avg, 1e308);
    expect(stats.count, BigInt.from(1000));
  });
  test('raw large finite mean stays finite and invalid values never become zero stats', () {
    final start = DateTime.utc(2026);
    TwinTemporalResponse raw(List<double> values) => TwinTemporalResponse(
      id: 'urn:ngsi-ld:Sensor:gw:s',
      type: 'Sensor',
      attrName: 'measurement',
      rawPoints: [
        for (final value in values)
          TemporalRawPoint(value: value, observedAt: start),
      ],
    );
    expect(TemporalStats.calculate(raw([1e308, 1e308]))!.avg, 1e308);
    expect(TemporalStats.calculate(raw([double.nan])), isNull);
    expect(TemporalStats.calculate(raw([double.infinity])), isNull);
  });
}
