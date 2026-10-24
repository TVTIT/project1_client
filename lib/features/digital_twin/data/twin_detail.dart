import '../../../core/network/api_client.dart';
import '../../../core/network/link_header.dart';
import 'digital_twin_dto.dart';

/// A passive Property. JSON-LD context is deliberately ignored, never resolved.
class TwinProperty<T> {
  const TwinProperty(
    this.value, {
    this.modifiedAt,
    this.observedAt,
    this.unitCode,
  });
  final T value;
  final DateTime? modifiedAt;
  final DateTime? observedAt;
  final String? unitCode;

  static TwinProperty<T>? parse<T>(Object? raw, bool Function(Object?) valid) {
    if (raw == null) return null;
    if (raw is! Map || raw['type'] != 'Property' || !valid(raw['value'])) {
      throw const FormatException('Invalid normalized Property');
    }
    DateTime? date(Object? value) {
      if (value == null) return null;
      return parseTwinUtc(value);
    }

    final code = raw['unitCode'];
    if (code != null && code is! String) {
      throw const FormatException('Invalid unitCode');
    }
    return TwinProperty<T>(
      raw['value'] as T,
      modifiedAt: date(raw['modifiedAt']),
      observedAt: date(raw['observedAt']),
      unitCode: code as String?,
    );
  }
}

class TwinDetail {
  const TwinDetail({
    required this.entity,
    this.name,
    this.description,
    this.measurement,
    this.sampleInterval,
    this.measurementUnit,
    this.hostedBy,
    this.sensors = const [],
  });
  final EntityUrn entity;
  final TwinProperty<String>? name, description, measurementUnit;
  final TwinProperty<Object>? measurement, sampleInterval;
  final EntityUrn? hostedBy;
  final List<EntityUrn> sensors;

  String? get displayUnit => switch (measurement?.unitCode) {
    'CEL' => '°C',
    'C81' => 'rad',
    'P1' => '%',
    final String code => measurementUnit?.value ?? code,
    null => measurementUnit?.value,
  };

  factory TwinDetail.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String) throw const FormatException('Missing identity');
    final entity = EntityUrn.parse(json['id'] as String);
    if (json['type'] != entity.type.value) {
      throw const FormatException('Invalid entity type');
    }
    final sensors = <EntityUrn>[];
    final relationship = json['hasSensor'];
    if (relationship != null) {
      if (entity.type != EntityType.gateway ||
          relationship is! Map ||
          relationship['type'] != 'Relationship' ||
          relationship['objectType'] != 'Sensor' ||
          relationship['object'] is! List) {
        throw const FormatException('Invalid hasSensor relationship');
      }
      for (final target in relationship['object'] as List) {
        if (target is! String) {
          throw const FormatException('Invalid relationship target');
        }
        final sensor = EntityUrn.parse(target);
        if (sensor.type != EntityType.sensor ||
            sensor.gatewayId != entity.gatewayId ||
            sensors.any((s) => s.urn == target)) {
          throw const FormatException('Invalid Sensor relationship');
        }
        sensors.add(sensor);
      }
    }
    EntityUrn? hostedBy;
    final hosted = json['isHostedBy'];
    if (hosted != null) {
      if (entity.type != EntityType.sensor ||
          hosted is! Map ||
          hosted['type'] != 'Relationship' ||
          hosted['object'] is! String) {
        throw const FormatException('Invalid isHostedBy relationship');
      }
      hostedBy = EntityUrn.parse(hosted['object'] as String);
      if (hostedBy.type != EntityType.gateway ||
          hostedBy.gatewayId != entity.gatewayId) {
        throw const FormatException('Invalid hosting Gateway');
      }
    }
    bool string(Object? v) => v is String;
    bool number(Object? v) => v is num || v is BigInt;
    return TwinDetail(
      entity: entity,
      name: TwinProperty.parse<String>(json['name'], string),
      description: TwinProperty.parse<String>(json['description'], string),
      measurementUnit: TwinProperty.parse<String>(
        json['measurementUnit'],
        string,
      ),
      measurement: TwinProperty.parse<Object>(json['measurement'], number),
      sampleInterval: TwinProperty.parse<Object>(
        json['sample_interval_us'],
        number,
      ),
      hostedBy: hostedBy,
      sensors: List.unmodifiable(sensors),
    );
  }
}

class TwinDetailPage {
  const TwinDetailPage(this.detail, this.nextCursor);
  final TwinDetail detail;
  final String? nextCursor;

  factory TwinDetailPage.parse(
    ApiResponse response,
    Uri requestUri,
    String entityId,
  ) {
    final detail = TwinDetail.fromJson(response.asMap);
    if (detail.entity.urn != entityId) {
      throw const FormatException('Wrong detail identity');
    }
    final limit = requestUri.queryParameters['relationship_limit'] ?? '20';
    if (detail.sensors.length > int.parse(limit)) {
      throw const FormatException('Relationship page too large');
    }
    // Compare exactly one decoded, validated URN segment. Go PathEscape retains
    // colons, whereas Dart encodeComponent does not. Neither permits path escapes.
    String canonical(String path) {
      final parts = path.split('/');
      if (parts.length != 4 ||
          parts[0] != '' ||
          parts[1] != 'v1' ||
          parts[2] != 'digital-twins') {
        throw const FormatException('Invalid entity path');
      }
      return '/v1/digital-twins/${EntityUrn.parse(Uri.decodeComponent(parts[3])).urn}';
    }

    final next = SafeLinkParser.resolveAndValidateNextLink(
      rawLinkHeader: response.link,
      requestUri: requestUri,
      baseUri: requestUri,
      expectedPath: requestUri.path,
      canonicalizePath: canonical,
      allowedQueryParams: const {'relationship_limit', 'relationship_after'},
    );
    if (next == null) return TwinDetailPage(detail, null);
    final q = next.queryParameters;
    if (detail.entity.type != EntityType.gateway ||
        (q['relationship_limit'] ?? '20') != limit ||
        q['relationship_after'] == null ||
        q['relationship_after']!.isEmpty ||
        q['relationship_after']!.length > 768) {
      throw const FormatException('Invalid relationship cursor or size');
    }
    return TwinDetailPage(detail, q['relationship_after']);
  }
}
