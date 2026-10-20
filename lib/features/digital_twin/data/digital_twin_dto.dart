import 'package:flutter/foundation.dart';

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
    final rawId = json['id'] as String? ?? '';
    final rawType = json['type'] as String? ?? '';

    // Handle name: simplified flat string OR normalized Property object {"type": "Property", "value": "..."}
    String? parsedName;
    if (json['name'] is String) {
      parsedName = json['name'] as String;
    } else if (json['name'] is Map) {
      parsedName = (json['name'] as Map)['value']?.toString();
    }

    // Handle gateway_id: simplified string OR normalized Property object
    String parsedGwId = '';
    if (json['gateway_id'] is String) {
      parsedGwId = json['gateway_id'] as String;
    } else if (json['gateway_id'] is Map) {
      parsedGwId = (json['gateway_id'] as Map)['value']?.toString() ?? '';
    }

    DateTime? parsedModified;
    if (json['modifiedAt'] != null) {
      parsedModified = DateTime.tryParse(json['modifiedAt'].toString())
          ?.toUtc();
    }

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
    if (tuple.length < 2) {
      throw const FormatException(
        'Expected 2-element tuple for raw temporal point',
      );
    }
    final rawVal = tuple[0];
    final doubleVal = rawVal is num
        ? rawVal.toDouble()
        : double.parse(rawVal.toString());
    final dt = DateTime.parse(tuple[1].toString()).toUtc();
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
    if (triple.length < 3) {
      throw const FormatException(
        'Expected 3-element triple for aggregated bucket point',
      );
    }
    final rawVal = triple[0];
    final d = rawVal is num
        ? rawVal.toDouble()
        : double.parse(rawVal.toString());
    return TemporalBucketPoint(
      value: d,
      bucketStart: DateTime.parse(triple[1].toString()).toUtc(),
      bucketEnd: DateTime.parse(triple[2].toString()).toUtc(),
    );
  }

  static TemporalBucketPoint<BigInt> countTriple(List<dynamic> triple) {
    if (triple.length < 3) {
      throw const FormatException(
        'Expected 3-element triple for totalCount bucket point',
      );
    }
    final rawVal = triple[0];
    final BigInt bi = rawVal is BigInt
        ? rawVal
        : (rawVal is int
              ? BigInt.from(rawVal)
              : BigInt.parse(rawVal.toString()));
    return TemporalBucketPoint(
      value: bi,
      bucketStart: DateTime.parse(triple[1].toString()).toUtc(),
      bucketEnd: DateTime.parse(triple[2].toString()).toUtc(),
    );
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
  });

  final String id;
  final String type;
  final String attrName;
  final List<TemporalRawPoint> rawPoints;
  final List<TemporalBucketPoint<double>> avgBuckets;
  final List<TemporalBucketPoint<double>> minBuckets;
  final List<TemporalBucketPoint<double>> maxBuckets;
  final List<TemporalBucketPoint<BigInt>> totalCountBuckets;

  bool get isAggregated =>
      avgBuckets.isNotEmpty ||
      minBuckets.isNotEmpty ||
      maxBuckets.isNotEmpty ||
      totalCountBuckets.isNotEmpty;

  factory TwinTemporalResponse.fromJson(
    Map<String, dynamic> json, {
    String attrName = 'measurement',
  }) {
    final id = json['id'] as String? ?? '';
    final type = json['type'] as String? ?? '';

    // Property attribute object
    final attrObj = json[attrName] is Map
        ? json[attrName] as Map<String, dynamic>
        : null;
    if (attrObj == null) {
      return TwinTemporalResponse(id: id, type: type, attrName: attrName);
    }

    // Raw mode: values: [[val, observedAt], ...]
    if (attrObj.containsKey('values') && attrObj['values'] is List) {
      final rawList = attrObj['values'] as List;
      final pts = rawList
          .map((e) => TemporalRawPoint.fromTuple(e as List))
          .toList();
      return TwinTemporalResponse(
        id: id,
        type: type,
        attrName: attrName,
        rawPoints: pts,
      );
    }

    // Aggregated mode: methods e.g. avg, min, max, totalCount
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
    );
  }
}

/// Input fragment for `PATCH /v1/digital-twins/{entity_id}/attrs`.
@immutable
class PatchTwinAttrsInput {
  const PatchTwinAttrsInput({
    required this.name,
    this.description,
    this.clearDescription = false,
  });

  final String name;
  final String? description;
  final bool clearDescription;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': {'type': 'Property', 'value': name.trim()},
    };

    if (clearDescription) {
      map['description'] = {'type': 'Property', 'value': 'urn:ngsi-ld:null'};
    } else if (description != null) {
      map['description'] = {'type': 'Property', 'value': description!.trim()};
    }

    return map;
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
