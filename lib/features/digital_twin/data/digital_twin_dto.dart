import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Reject calendar normalization, offsets and sub-microsecond precision.
DateTime parseTwinUtc(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$')
          .hasMatch(value)) {
    throw const FormatException('Invalid UTC timestamp');
  }
  final date = DateTime.tryParse(value);
  if (date == null ||
      date.year < 1 ||
      date.toIso8601String().substring(0, 19) != value.substring(0, 19)) {
    throw const FormatException('Invalid UTC calendar date');
  }
  return date;
}

/// Supported NGSI-LD Entity Types.
enum EntityType {
  gateway('Gateway'),
  sensor('Sensor');

  const EntityType(this.value);
  final String value;

  static EntityType fromString(String val) => switch (val.toLowerCase()) {
    'gateway' => EntityType.gateway,
    'sensor' => EntityType.sensor,
    _ => throw FormatException('Unsupported entity type: $val'),
  };
}

/// Parsed NGSI-LD entity URN.
@immutable
class EntityUrn {
  const EntityUrn({
    required this.urn,
    required this.type,
    required this.gatewayId,
    this.sensorId,
  });

  final String urn;
  final EntityType type;
  final String gatewayId;
  final String? sensorId;

  /// Returns single-URL-encoded URN component for use in URL paths.
  ///
  /// Strictly encodes once (e.g. `urn%3Angsi-ld%3ASensor%3Agw%3As1`) without double-encoding.
  String get encoded => Uri.encodeComponent(urn);

  static EntityUrn parse(String rawUrn) {
    if (!rawUrn.startsWith('urn:ngsi-ld:')) {
      throw FormatException('Invalid URN prefix: $rawUrn');
    }
    final parts = rawUrn.split(':');
    final idPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');
    bool validId(String id) => idPattern.stringMatch(id) == id && id.isNotEmpty;
    if (parts.length < 4 ||
        !validId(parts[3]) ||
        parts[3] == 'backend_service' ||
        (parts.length == 5 && !validId(parts[4]))) {
      throw const FormatException('Invalid entity identifiers');
    }
    if (parts.length == 4 && parts[2] == 'Gateway') {
      return EntityUrn(
        urn: rawUrn,
        type: EntityType.gateway,
        gatewayId: parts[3],
      );
    }
    if (parts.length == 5 && parts[2] == 'Sensor') {
      return EntityUrn(
        urn: rawUrn,
        type: EntityType.sensor,
        gatewayId: parts[3],
        sensorId: parts[4],
      );
    }
    throw FormatException('Invalid entity URN format: $rawUrn');
  }

  static String gateway(String gatewayId) => 'urn:ngsi-ld:Gateway:$gatewayId';

  static String sensor(String gatewayId, String sensorId) =>
      'urn:ngsi-ld:Sensor:$gatewayId:$sensorId';
}

/// Summary item from `GET /v1/digital-twins` (supports simplified or normalized).
@immutable
class TwinSummaryItem {
  const TwinSummaryItem({
    required this.id,
    required this.type,
    this.name,
    required this.gatewayId,
    this.modifiedAt,
  });

  final String id;
  final String type;
  final String? name;
  final String gatewayId;
  final DateTime? modifiedAt;

  factory TwinSummaryItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawType = json['type'];
    if (rawId is! String || rawType is! String) {
      throw const FormatException('Missing summary identity');
    }
    final urn = EntityUrn.parse(rawId);
    if (rawType != urn.type.value) {
      throw const FormatException('Summary type does not match URN');
    }

    // Handle name: simplified flat string OR normalized Property object {"type": "Property", "value": "..."}
    String? parsedName;
    if (json['name'] is String) {
      parsedName = json['name'] as String;
    } else if (json['name'] is Map) {
      final property = json['name'] as Map;
      if (property['type'] == 'Property' && property['value'] is String) {
        parsedName = property['value'] as String;
      }
    }
    if (json['name'] != null && parsedName == null) {
      throw const FormatException('Invalid summary name');
    }

    // Handle gateway_id: simplified string OR normalized Property object
    String parsedGwId = '';
    if (json['gateway_id'] is String) {
      parsedGwId = json['gateway_id'] as String;
    } else if (json['gateway_id'] is Map) {
      final property = json['gateway_id'] as Map;
      if (property['type'] == 'Property' && property['value'] is String) {
        parsedGwId = property['value'] as String;
      }
    }
    if (parsedGwId != urn.gatewayId) {
      throw const FormatException('Summary gateway does not match URN');
    }

    final modified = json['modifiedAt'];
    if (modified is! String ||
        !modified.endsWith('Z') ||
        DateTime.tryParse(modified) == null) {
      throw const FormatException('Invalid summary modifiedAt');
    }
    final parsedModified = parseTwinUtc(modified);

    return TwinSummaryItem(
      id: rawId,
      type: rawType,
      name: parsedName,
      gatewayId: parsedGwId,
      modifiedAt: parsedModified,
    );
  }
}

/// Flat state response from `GET /v1/digital-twins/{entity_id}?format=simplified`.
@immutable
class TwinStateResponse {
  const TwinStateResponse({
    required this.id,
    required this.type,
    required this.gatewayId,
    required this.reportedState,
    required this.desiredState,
    required this.reportedVersion,
    required this.desiredVersion,
    this.lastReportedAt,
    this.lastDesiredAt,
    this.updatedAt,
  });

  final String id;
  final String type;
  final String gatewayId;

  /// Raw reported JSONB state. Numbers inside are numeric (not forced to strings).
  final Map<String, dynamic> reportedState;

  /// Raw desired JSONB state. Numbers inside are numeric (not forced to strings).
  final Map<String, dynamic> desiredState;

  /// Exact version string (e.g. "1", "42").
  final String reportedVersion;

  /// Exact version string.
  final String desiredVersion;

  final DateTime? lastReportedAt;
  final DateTime? lastDesiredAt;
  final DateTime? updatedAt;

  factory TwinStateResponse.fromJson(Map<String, dynamic> json) {
    return TwinStateResponse(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      gatewayId: json['gateway_id'] as String? ?? '',
      reportedState: json['reported_state'] is Map
          ? Map<String, dynamic>.from(json['reported_state'] as Map)
          : const <String, dynamic>{},
      desiredState: json['desired_state'] is Map
          ? Map<String, dynamic>.from(json['desired_state'] as Map)
          : const <String, dynamic>{},
      reportedVersion: json['reported_version']?.toString() ?? '0',
      desiredVersion: json['desired_version']?.toString() ?? '0',
      lastReportedAt: json['last_reported_at'] != null
          ? DateTime.tryParse(json['last_reported_at'].toString())?.toUtc()
          : null,
      lastDesiredAt: json['last_desired_at'] != null
          ? DateTime.tryParse(json['last_desired_at'].toString())?.toUtc()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())?.toUtc()
          : null,
    );
  }
}

/// A raw temporal observation point: tuple `[value, observedAt]`.
@immutable
class TemporalRawPoint {
  const TemporalRawPoint({required this.value, required this.observedAt});

  final double value;
  final DateTime observedAt;

  factory TemporalRawPoint.fromTuple(List<dynamic> tuple) {
    if (tuple.length != 2) {
      throw const FormatException(
        'Expected exactly 2-element tuple for raw temporal point',
      );
    }
    final rawVal = tuple[0];
    if (rawVal is! num) {
      throw const FormatException(
        'Expected strictly numeric value in raw temporal point',
      );
    }
    final doubleVal = rawVal.toDouble();
    if (!doubleVal.isFinite) {
      throw const FormatException('Value in raw temporal point must be finite');
    }
    final dt = parseTwinUtc(tuple[1]);
    return TemporalRawPoint(value: doubleVal, observedAt: dt);
  }
}

/// An aggregated temporal bucket point: triple `[value, bucketStart, bucketEnd]`.
@immutable
class TemporalBucketPoint<T> {
  const TemporalBucketPoint({
    required this.value,
    required this.bucketStart,
    required this.bucketEnd,
  });

  final T value;
  final DateTime bucketStart;
  final DateTime bucketEnd;

  static TemporalBucketPoint<double> doubleTriple(List<dynamic> triple) {
    if (triple.length != 3) {
      throw const FormatException(
        'Expected 3-element triple for aggregated bucket point',
      );
    }
    final rawVal = triple[0];
    if (rawVal is! num) {
      throw const FormatException('Expected numeric value in bucket point');
    }
    final d = rawVal.toDouble();
    if (!d.isFinite) {
      throw const FormatException(
        'Value in aggregated bucket point must be finite',
      );
    }
    final start = parseTwinUtc(triple[1]);
    final end = parseTwinUtc(triple[2]);
    if (!start.isBefore(end)) {
      throw const FormatException(
        'bucketStart must be strictly before bucketEnd',
      );
    }
    return TemporalBucketPoint(value: d, bucketStart: start, bucketEnd: end);
  }

  static TemporalBucketPoint<BigInt> countTriple(List<dynamic> triple) {
    if (triple.length != 3) {
      throw const FormatException(
        'Expected exactly 3-element triple for totalCount bucket point',
      );
    }
    final rawVal = triple[0];
    final BigInt bi;
    if (rawVal is BigInt) {
      bi = rawVal;
    } else if (rawVal is int) {
      bi = BigInt.from(rawVal);
    } else if (rawVal is String) {
      bi = BigInt.parse(rawVal);
    } else {
      throw const FormatException('Expected integer count in bucket point');
    }
    if (bi < BigInt.zero) {
      throw const FormatException(
        'Count in totalCount bucket must be non-negative',
      );
    }
    final start = parseTwinUtc(triple[1]);
    final end = parseTwinUtc(triple[2]);
    if (!start.isBefore(end)) {
      throw const FormatException(
        'bucketStart must be strictly before bucketEnd',
      );
    }
    return TemporalBucketPoint(value: bi, bucketStart: start, bucketEnd: end);
  }
}

/// Response payload from temporal history `GET /v1/digital-twins/{entity_id}/temporal`.
@immutable
class TwinTemporalResponse {
  const TwinTemporalResponse({
    required this.id,
    required this.type,
    required this.attrName,
    this.rawPoints = const [],
    this.avgBuckets = const [],
    this.minBuckets = const [],
    this.maxBuckets = const [],
    this.totalCountBuckets = const [],
    this.methods,
    bool? isAggregated,
  }) : isAggregated =
           isAggregated ??
           (avgBuckets.length > 0 ||
               minBuckets.length > 0 ||
               maxBuckets.length > 0 ||
               totalCountBuckets.length > 0);

  final String id;
  final String type;
  final String attrName;
  final List<TemporalRawPoint> rawPoints;
  final List<TemporalBucketPoint<double>> avgBuckets;
  final List<TemporalBucketPoint<double>> minBuckets;
  final List<TemporalBucketPoint<double>> maxBuckets;
  final List<TemporalBucketPoint<BigInt>> totalCountBuckets;
  final bool isAggregated;
  final Set<String>? methods;

  bool get isRaw => !isAggregated;

  /// Bind a parsed (or typed adapter) response to the applied request.
  void validateFor(String entityId, TemporalQueryParameters query) {
    if (id != entityId ||
        type != 'Sensor' ||
        attrName != query.attrs ||
        isRaw != query.isRaw) {
      throw const FormatException('Temporal response does not match query');
    }
    if (!isRaw &&
        methods != null &&
        !setEquals(methods, query.effectiveAggrMethods!.split(',').toSet())) {
      throw const FormatException('Temporal methods do not match query');
    }
    DateTime? previous;
    for (final point in rawPoints) {
      if (!point.value.isFinite ||
          point.observedAt.isBefore(query.timeAt) ||
          !point.observedAt.isBefore(query.endTimeAt) ||
          (previous != null && point.observedAt.isBefore(previous))) {
        throw const FormatException('Invalid raw point order or range');
      }
      previous = point.observedAt; // duplicates are distinct samples
    }
    if (rawPoints.length > query.maxPoints) {
      throw const FormatException('Temporal response exceeds cap');
    }
    void buckets<T>(List<TemporalBucketPoint<T>> points) {
      if (points.length > query.maxPoints) {
        throw const FormatException('Temporal response exceeds cap');
      }
      DateTime? lastEnd;
      for (final point in points) {
        // Partial edge buckets may straddle the requested window.
        if (!point.bucketStart.isBefore(point.bucketEnd) ||
            !point.bucketStart.isBefore(query.endTimeAt) ||
            !point.bucketEnd.isAfter(query.timeAt) ||
            (lastEnd != null && point.bucketStart.isBefore(lastEnd))) {
          throw const FormatException('Invalid bucket order or range');
        }
        if (point.value is double && !(point.value as double).isFinite) {
          throw const FormatException('Nonfinite bucket');
        }
        if (point.value is BigInt && (point.value as BigInt) < BigInt.zero) {
          throw const FormatException('Negative count');
        }
        lastEnd = point.bucketEnd;
      }
    }

    buckets(avgBuckets);
    buckets(minBuckets);
    buckets(maxBuckets);
    buckets(totalCountBuckets);
    if (isRaw &&
        (avgBuckets.isNotEmpty ||
            minBuckets.isNotEmpty ||
            maxBuckets.isNotEmpty ||
            totalCountBuckets.isNotEmpty)) {
      throw const FormatException('Mixed temporal modes');
    }
    if (!isRaw && rawPoints.isNotEmpty) {
      throw const FormatException('Mixed temporal modes');
    }
  }

  factory TwinTemporalResponse.fromJson(
    Map<String, dynamic> json, {
    String attrName = 'measurement',
  }) {
    final id = json['id'] as String? ?? '';
    final type = json['type'] as String? ?? '';
    if (EntityUrn.parse(id).type != EntityType.sensor ||
        type != 'Sensor' ||
        (attrName != 'measurement' && attrName != 'sample_interval_us')) {
      throw const FormatException('Invalid temporal identity or attribute');
    }

    // Property attribute object
    final attrObj = json[attrName] is Map
        ? json[attrName] as Map<String, dynamic>
        : null;
    if (attrObj == null) {
      throw const FormatException('Missing temporal Property');
    }
    if (attrObj['type'] != 'Property') {
      throw const FormatException('Invalid temporal Property');
    }
    for (final key in ['values', 'avg', 'min', 'max', 'totalCount']) {
      if (attrObj.containsKey(key) && attrObj[key] is! List) {
        throw const FormatException('Invalid temporal values');
      }
    }

    final hasRawKey = attrObj.containsKey('values');
    final hasAggrKeys =
        attrObj.containsKey('avg') ||
        attrObj.containsKey('min') ||
        attrObj.containsKey('max') ||
        attrObj.containsKey('totalCount');

    if (hasRawKey && hasAggrKeys) {
      throw const FormatException('Mixed raw and aggregated temporal payload');
    }
    if (!hasRawKey && !hasAggrKeys) {
      throw const FormatException('Missing temporal values');
    }

    // Raw mode: values: [[val, observedAt], ...]
    if (hasRawKey && attrObj['values'] is List) {
      final rawList = attrObj['values'] as List;
      final pts = rawList.map((e) {
        if (e is! List) throw const FormatException('Invalid temporal tuple');
        return TemporalRawPoint.fromTuple(e);
      }).toList();
      return TwinTemporalResponse(
        id: id,
        type: type,
        attrName: attrName,
        rawPoints: pts,
        isAggregated: false,
      );
    }

    List<TemporalBucketPoint<double>> avgs = [];
    List<TemporalBucketPoint<double>> mins = [];
    List<TemporalBucketPoint<double>> maxs = [];
    List<TemporalBucketPoint<BigInt>> counts = [];

    if (attrObj['avg'] is List) {
      avgs = (attrObj['avg'] as List)
          .map((e) => TemporalBucketPoint.doubleTriple(e as List))
          .toList();
    }
    if (attrObj['min'] is List) {
      mins = (attrObj['min'] as List)
          .map((e) => TemporalBucketPoint.doubleTriple(e as List))
          .toList();
    }
    if (attrObj['max'] is List) {
      maxs = (attrObj['max'] as List)
          .map((e) => TemporalBucketPoint.doubleTriple(e as List))
          .toList();
    }
    if (attrObj['totalCount'] is List) {
      counts = (attrObj['totalCount'] as List)
          .map((e) => TemporalBucketPoint.countTriple(e as List))
          .toList();
    }

    return TwinTemporalResponse(
      id: id,
      type: type,
      attrName: attrName,
      avgBuckets: avgs,
      minBuckets: mins,
      maxBuckets: maxs,
      totalCountBuckets: counts,
      methods: attrObj.keys
          .where(TemporalQueryParameters.allowedAggregationMethods.contains)
          .toSet(),
      isAggregated:
          hasAggrKeys ||
          avgs.isNotEmpty ||
          mins.isNotEmpty ||
          maxs.isNotEmpty ||
          counts.isNotEmpty,
    );
  }
}

/// Statistics calculated over the returned temporal response.
@immutable
class TemporalStats {
  const TemporalStats({
    required this.min,
    required this.max,
    required this.count,
    required this.avg,
    required this.isRaw,
  });

  final double min;
  final double max;
  final BigInt count;
  final double avg;
  final bool isRaw;

  static TemporalStats? calculate(TwinTemporalResponse response) {
    if (response.isRaw) {
      if (response.rawPoints.isEmpty) return null;
      double minVal = double.infinity;
      double maxVal = -double.infinity;
      double sum = 0.0;
      for (final pt in response.rawPoints) {
        if (pt.value < minVal) minVal = pt.value;
        if (pt.value > maxVal) maxVal = pt.value;
        if (!pt.value.isFinite) return null;
        sum += pt.value / response.rawPoints.length;
      }
      if (!sum.isFinite) return null;
      return TemporalStats(
        min: minVal,
        max: maxVal,
        count: BigInt.from(response.rawPoints.length),
        avg: sum,
        isRaw: true,
      );
    } else {
      if (response.avgBuckets.isEmpty ||
          response.minBuckets.isEmpty ||
          response.maxBuckets.isEmpty ||
          response.totalCountBuckets.isEmpty) {
        return null;
      }

      String bucketKey(DateTime start, DateTime end) =>
          '${start.toIso8601String()}_${end.toIso8601String()}';

      final avgMap = {
        for (final ab in response.avgBuckets)
          bucketKey(ab.bucketStart, ab.bucketEnd): ab.value,
      };
      final minMap = {
        for (final mb in response.minBuckets)
          bucketKey(mb.bucketStart, mb.bucketEnd): mb.value,
      };
      final maxMap = {
        for (final mb in response.maxBuckets)
          bucketKey(mb.bucketStart, mb.bucketEnd): mb.value,
      };
      final countMap = {
        for (final cb in response.totalCountBuckets)
          bucketKey(cb.bucketStart, cb.bucketEnd): cb.value,
      };

      // Strict requirement: all bucket keys (start + end) must match completely across all 4 methods!
      final avgKeys = avgMap.keys.toSet();
      if (avgMap.length != response.avgBuckets.length ||
          minMap.length != response.minBuckets.length ||
          maxMap.length != response.maxBuckets.length ||
          countMap.length != response.totalCountBuckets.length ||
          !setEquals(avgKeys, minMap.keys.toSet()) ||
          !setEquals(avgKeys, maxMap.keys.toSet()) ||
          !setEquals(avgKeys, countMap.keys.toSet())) {
        return null;
      }

      double minVal = double.infinity;
      double maxVal = -double.infinity;
      double weightedSum = 0.0;
      BigInt totalCountSum = BigInt.zero;

      for (final count in countMap.values) {
        totalCountSum += count;
      }
      if (totalCountSum <= BigInt.zero || !totalCountSum.toDouble().isFinite) {
        return null;
      }
      for (final key in avgKeys) {
        final avgV = avgMap[key]!;
        final minV = minMap[key]!;
        final maxV = maxMap[key]!;
        final countV = countMap[key]!;
        if (countV == BigInt.zero) continue;

        if (minV < minVal) minVal = minV;
        if (maxV > maxVal) maxVal = maxV;

        if (!avgV.isFinite ||
            !minV.isFinite ||
            !maxV.isFinite ||
            countV < BigInt.zero) {
          return null;
        }
        weightedSum += avgV * (countV.toDouble() / totalCountSum.toDouble());
      }

      if (!weightedSum.isFinite ||
          totalCountSum == BigInt.zero ||
          minVal == double.infinity ||
          maxVal == -double.infinity) {
        return null;
      }

      return TemporalStats(
        min: minVal,
        max: maxVal,
        count: totalCountSum,
        avg: weightedSum,
        isRaw: false,
      );
    }
  }
}

enum TemporalQueryMode { raw, aggregated }

/// Canonical query parameters for `GET /v1/digital-twins/{entity_id}/temporal`.
@immutable
class TemporalQueryParameters {
  const TemporalQueryParameters({
    this.attrs = 'measurement',
    required this.timeAt,
    required this.endTimeAt,
    this.mode = TemporalQueryMode.aggregated,
    this.aggrPeriodDuration,
    this.aggrMethods,
    this.maxPoints = 1000,
  });

  final String attrs;
  final DateTime timeAt;
  final DateTime endTimeAt;
  final TemporalQueryMode mode;
  final String? aggrPeriodDuration;
  final String? aggrMethods;
  final int maxPoints;

  Duration get range => endTimeAt.difference(timeAt);
  bool get isRaw => mode == TemporalQueryMode.raw;

  String? get effectiveAggrPeriodDuration =>
      isRaw ? null : (aggrPeriodDuration ?? 'PT5M');
  String? get effectiveAggrMethods =>
      isRaw ? null : (aggrMethods ?? 'avg,min,max,totalCount');

  static const canonicalDurations = {
    'PT0.1S',
    'PT1S',
    'PT10S',
    'PT1M',
    'PT5M',
    'PT15M',
    'PT1H',
    'PT6H',
    'P1D',
  };

  static const allowedAggregationMethods = {'avg', 'min', 'max', 'totalCount'};

  void validate() {
    if (attrs != 'measurement' && attrs != 'sample_interval_us') {
      throw const FormatException(
        'attrs must be measurement or sample_interval_us',
      );
    }
    if (!timeAt.isBefore(endTimeAt)) {
      throw const FormatException('timeAt must be strictly before endTimeAt');
    }
    if (range > const Duration(hours: 744)) {
      throw const FormatException(
        'Query range cannot exceed 744 hours (31 days)',
      );
    }
    if (isRaw) {
      if (range > const Duration(seconds: 10)) {
        throw const FormatException('Raw mode range cannot exceed 10 seconds');
      }
      if (aggrPeriodDuration != null && aggrPeriodDuration!.isNotEmpty) {
        throw const FormatException(
          'aggrPeriodDuration is forbidden in raw mode',
        );
      }
      if (aggrMethods != null && aggrMethods!.isNotEmpty) {
        throw const FormatException('aggrMethods is forbidden in raw mode');
      }
    } else {
      final duration = aggrPeriodDuration ?? 'PT5M';
      if (!canonicalDurations.contains(duration)) {
        throw FormatException(
          'Invalid aggrPeriodDuration: $aggrPeriodDuration',
        );
      }
      if (aggrMethods != null && aggrMethods!.isNotEmpty) {
        final methods = aggrMethods!.split(',').map((m) => m.trim()).toList();
        final seen = <String>{};
        for (final m in methods) {
          if (!allowedAggregationMethods.contains(m)) {
            throw FormatException('Disallowed aggregation method: $m');
          }
          if (!seen.add(m)) {
            throw FormatException('Duplicate aggregation method: $m');
          }
        }
      }
    }
    if (maxPoints < 100 || maxPoints > 2000) {
      throw const FormatException('maxPoints must be between 100 and 2000');
    }
  }
}

/// Input fragment for `PATCH /v1/digital-twins/{entity_id}/attrs`.
///
/// Discrepancy note: HTTP parser in backend (`patch_entity_request.go:385`) enforces
/// `len(frag.Value) <= 512` for description, whereas domain/docs state 4096.
/// Client validation enforces 512 bytes to avoid 400 Bad Request from backend.
@immutable
class PatchTwinAttrsInput {
  const PatchTwinAttrsInput({
    this.name,
    this.description,
    this.clearDescription = false,
  });

  final String? name;
  final String? description;
  final bool clearDescription;

  /// Validates the patch input fields according to Stage 4 ETSI GS CIM 009 contract.
  void validate() {
    if (name == null && description == null && !clearDescription) {
      throw const FormatException(
        'At least one field must be modified in PATCH',
      );
    }
    if (description != null && clearDescription) {
      throw const FormatException(
        'Cannot simultaneously set description and clearDescription',
      );
    }

    if (name != null) {
      if (name!.trim().isEmpty) {
        throw const FormatException('Name cannot be blank');
      }
      final nameBytes = utf8.encode(name!).length;
      if (nameBytes < 1 || nameBytes > 256) {
        throw const FormatException(
          'Name must be between 1 and 256 UTF-8 bytes',
        );
      }
      if (name!.contains('\u0000')) {
        throw const FormatException('Name cannot contain NUL byte');
      }
    }

    if (description != null) {
      final descBytes = utf8.encode(description!).length;
      if (descBytes > 512) {
        throw const FormatException(
          'Description cannot exceed 512 UTF-8 bytes (backend HTTP parser limit)',
        );
      }
      if (description!.contains('\u0000')) {
        throw const FormatException('Description cannot contain NUL byte');
      }
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    final map = <String, dynamic>{};

    if (name != null) {
      map['name'] = {'type': 'Property', 'value': name!};
    }

    if (clearDescription) {
      map['description'] = {'type': 'Property', 'value': 'urn:ngsi-ld:null'};
    } else if (description != null) {
      map['description'] = {'type': 'Property', 'value': description!};
    }

    return map;
  }
}

/// Canonical flat response returned by `PATCH /v1/digital-twins/{entity_id}/attrs`.
@immutable
class PatchTwinResponseDto {
  const PatchTwinResponseDto({
    required this.id,
    required this.type,
    required this.gatewayId,
    this.sensorId,
    required this.name,
    this.description,
    this.unit,
    required this.updatedAt,
  });

  final String id;
  final EntityType type;
  final String gatewayId;
  final String? sensorId;
  final String name;
  final String? description;
  final String? unit;
  final String updatedAt;

  factory PatchTwinResponseDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final rawType = json['type'] as String? ?? '';
    final entity = EntityUrn.parse(id);
    final type = entity.type;
    final gatewayId = json['gateway_id'] as String? ?? '';
    final sensorId = json['sensor_id'] as String?;
    final name = json['name'] as String? ?? '';
    final description = json['description'] as String?;
    final unit = json['unit'] as String?;
    final updatedAt = json['updated_at'] as String? ?? '';
    if (rawType != type.value ||
        gatewayId != entity.gatewayId ||
        sensorId != entity.sensorId ||
        name.trim().isEmpty) {
      throw const FormatException('Invalid PATCH response identity');
    }
    parseTwinUtc(updatedAt);

    return PatchTwinResponseDto(
      id: id,
      type: type,
      gatewayId: gatewayId,
      sensorId: sensorId,
      name: name,
      description: description,
      unit: unit,
      updatedAt: updatedAt,
    );
  }
}

/// Input payload for creating or exact-replaying Digital Twin via `POST /v1/digital-twins`.
@immutable
class PostTwinEntityInput {
  const PostTwinEntityInput({
    required this.entityType,
    required this.gatewayId,
    required this.name,
    this.description,
    this.ownerUserId,
    this.sensorId,
    this.unit,
  });

  final EntityType entityType;
  final String gatewayId;
  final String name;
  final String? description;
  final String? ownerUserId;
  final String? sensorId;
  final String? unit;

  Map<String, dynamic> toJson() {
    return {
      'entity_type': entityType == EntityType.gateway ? 'Gateway' : 'Sensor',
      'gateway_id': gatewayId.trim(),
      'name': name.trim(),
      if (entityType == EntityType.gateway) ...{
        if (description != null) 'description': description!.trim(),
        if (ownerUserId != null) 'owner_user_id': ownerUserId!.trim(),
      },
      if (entityType == EntityType.sensor) ...{
        if (sensorId != null) 'sensor_id': sensorId!.trim(),
        if (unit != null) 'unit': unit!.trim(),
      },
    };
  }
}
