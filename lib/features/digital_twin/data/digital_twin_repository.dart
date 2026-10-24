import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'digital_twin_dto.dart';
import 'twin_detail.dart';

/// Contract for accessing Stage 4 ETSI GS CIM 009 V1.9.1 Digital Twin APIs.
abstract class DigitalTwinRepository {
  Future<TwinDetailPage> getTwinDetail(
    String entityId, {
    int relationshipLimit = 20,
    String? relationshipAfter,
  });

  /// Queries membership-scoped Digital Twin entity list.
  Future<ApiResponse> listTwins({
    EntityType? type,
    String? gatewayId,
    int? limit,
    String? cursor,
    bool simplified = true,
  });

  /// Reads flat state view of an entity from `GET /v1/digital-twins/{entity_id}?format=simplified`.
  Future<TwinStateResponse> getTwinState(String entityId);

  /// Queries temporal observation history from `GET /v1/digital-twins/{entity_id}/temporal`.
  Future<TwinTemporalResponse> getSensorTemporal(
    String entityId, {
    required String attrs,
    required DateTime timeAt,
    required DateTime endTimeAt,
    String? aggrPeriodDuration,
    String? aggrMethods,
    int? maxPoints,
  });

  /// Creates or exact-replays Digital Twin entity via `POST /v1/digital-twins`.
  Future<ApiResponse> createTwin(PostTwinEntityInput input);

  /// Mutates entity metadata Property fragment via `PATCH /v1/digital-twins/{entity_id}/attrs`.
  Future<PatchTwinResponseDto> patchTwinAttrs(
    String entityId,
    PatchTwinAttrsInput input,
  );
}

/// Concrete implementation of [DigitalTwinRepository] using Go REST API (`/v1/*`).
class HttpDigitalTwinRepository implements DigitalTwinRepository {
  const HttpDigitalTwinRepository(this._client);

  final ApiClient _client;

  @override
  Future<TwinDetailPage> getTwinDetail(
    String entityId, {
    int relationshipLimit = 20,
    String? relationshipAfter,
  }) async {
    final entity = EntityUrn.parse(entityId);
    if (relationshipLimit < 1 || relationshipLimit > 200) {
      throw const FormatException('Invalid relationship limit');
    }
    final path = 'digital-twins/${entity.encoded}';
    final query = <String, String>{
      'relationship_limit': '$relationshipLimit',
      'relationship_after': ?relationshipAfter,
    };
    final response = await _client.getEnvelope(
      path,
      queryParams: query,
      accept: 'application/ld+json',
    );
    return TwinDetailPage.parse(
      response,
      _client.buildUri(path, query),
      entityId,
    );
  }

  @override
  Future<ApiResponse> listTwins({
    EntityType? type,
    String? gatewayId,
    int? limit,
    String? cursor,
    bool simplified = true,
  }) async {
    final queryParams = <String, String>{};
    if (type != null) {
      queryParams['type'] = type == EntityType.gateway ? 'Gateway' : 'Sensor';
    }
    if (gatewayId != null && gatewayId.isNotEmpty) {
      queryParams['gateway_id'] = gatewayId;
    }
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }
    if (simplified) {
      queryParams['format'] = 'simplified';
    }

    return _client.getEnvelope(
      'digital-twins',
      queryParams: queryParams.isEmpty ? null : queryParams,
      accept: simplified ? 'application/json' : 'application/ld+json',
    );
  }

  @override
  Future<TwinStateResponse> getTwinState(String entityId) async {
    final parsed = EntityUrn.parse(entityId);
    final json = await _client.get(
      'digital-twins/${parsed.encoded}',
      queryParams: {'format': 'simplified'},
      accept: 'application/json',
    );
    return TwinStateResponse.fromJson(json);
  }

  @override
  Future<TwinTemporalResponse> getSensorTemporal(
    String entityId, {
    required String attrs,
    required DateTime timeAt,
    required DateTime endTimeAt,
    String? aggrPeriodDuration,
    String? aggrMethods,
    int? maxPoints,
  }) async {
    final parsed = EntityUrn.parse(entityId);
    if (parsed.type != EntityType.sensor) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Lịch sử temporal chỉ hỗ trợ cho thực thể cảm biến (Sensor).',
      );
    }

    final isRaw = aggrPeriodDuration == null || aggrPeriodDuration.isEmpty;
    final queryParamsObj = TemporalQueryParameters(
      attrs: attrs,
      timeAt: timeAt,
      endTimeAt: endTimeAt,
      mode: isRaw ? TemporalQueryMode.raw : TemporalQueryMode.aggregated,
      aggrPeriodDuration: isRaw ? null : aggrPeriodDuration,
      aggrMethods: aggrMethods,
      maxPoints: maxPoints ?? 1000,
    );

    try {
      queryParamsObj.validate();
    } on FormatException catch (e) {
      throw ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: e.message,
      );
    }

    final queryParams = <String, String>{
      'attrs': attrs,
      'timerel': 'between',
      'timeAt': timeAt.toUtc().toIso8601String(),
      'endTimeAt': endTimeAt.toUtc().toIso8601String(),
    };

    if (!isRaw) {
      queryParams['aggrPeriodDuration'] = aggrPeriodDuration;
      if (aggrMethods != null && aggrMethods.isNotEmpty) {
        queryParams['aggrMethods'] = aggrMethods;
      }
    }
    if (maxPoints != null) {
      queryParams['max_points'] = maxPoints.toString();
    }

    final json = await _client.get(
      'digital-twins/${parsed.encoded}/temporal',
      queryParams: queryParams,
      accept: 'application/ld+json',
    );

    final res = TwinTemporalResponse.fromJson(json, attrName: attrs);
    if (res.id.isNotEmpty && (res.id != parsed.urn || res.type != 'Sensor')) {
      throw const FormatException(
        'Sensor URN identity or type mismatch in temporal response',
      );
    }
    res.validateFor(entityId, queryParamsObj);
    return res;
  }

  @override
  Future<ApiResponse> createTwin(PostTwinEntityInput input) async {
    return _client.post('digital-twins', body: input.toJson());
  }

  @override
  Future<PatchTwinResponseDto> patchTwinAttrs(
    String entityId,
    PatchTwinAttrsInput input,
  ) async {
    final parsed = EntityUrn.parse(entityId);
    final res = await _client.patch(
      'digital-twins/${parsed.encoded}/attrs',
      body: input.toJson(),
    );
    final dto = PatchTwinResponseDto.fromJson(res.data);
    if (dto.id != entityId) {
      throw const FormatException('Wrong mutation identity');
    }
    return dto;
  }
}

final digitalTwinRepositoryProvider = Provider<DigitalTwinRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HttpDigitalTwinRepository(client);
});
