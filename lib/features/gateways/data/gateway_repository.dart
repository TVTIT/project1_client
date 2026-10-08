import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'gateway_dto.dart';
import 'mqtt_credential_dto.dart';

/// Contract for accessing Gateway resources.
abstract class GatewayRepository {
  Future<List<GatewayItem>> getGateways();
  Future<SensorListResponse> getGatewaySensors(String gatewayId);
  Future<ProvisionGatewayResult> provisionGateway(ProvisionGatewayInput input);
  Future<ProvisionSensorResult> provisionSensor(ProvisionSensorInput input);
  Future<MqttCredentialMetadata> getMqttCredential(String gatewayId);
  Future<Object> provisionMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  });
  Future<Object> rotateMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  });
  Future<MqttCredentialMutationResult> revokeMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  });
}

/// Concrete implementation of [GatewayRepository] using Go REST API (`/v1/*`).
class HttpGatewayRepository implements GatewayRepository {
  const HttpGatewayRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<GatewayItem>> getGateways() async {
    final json = await _client.get('gateways');
    final response = GatewayListResponse.fromJson(json);
    return response.items;
  }

  @override
  Future<SensorListResponse> getGatewaySensors(String gatewayId) async {
    if (!isValidGatewayId(gatewayId)) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Mã Gateway không hợp lệ hoặc chứa định danh dành riêng.',
      );
    }
    final json = await _client.get('gateways/$gatewayId/sensors');
    return SensorListResponse.fromJson(json, expectedGatewayId: gatewayId);
  }

  @override
  Future<ProvisionGatewayResult> provisionGateway(
    ProvisionGatewayInput input,
  ) async {
    final validationErr =
        validateProvisionGatewayId(input.gatewayId) ??
        validateProvisionName(input.name) ??
        validateProvisionDescription(input.description) ??
        validateProvisionOwnerUserId(input.ownerUserId);
    if (validationErr != null) {
      throw ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: validationErr,
      );
    }

    final response = await _client.put(
      'admin/gateways/${input.gatewayId.trim()}',
      body: input.toJson(),
    );

    return ProvisionGatewayResult.fromJson(
      response.data,
      statusCode: response.statusCode,
    );
  }

  @override
  Future<ProvisionSensorResult> provisionSensor(
    ProvisionSensorInput input,
  ) async {
    final validationErr =
        validateProvisionGatewayId(input.gatewayId) ??
        validateProvisionSensorId(input.sensorId) ??
        validateProvisionSensorName(input.name) ??
        validateProvisionSensorUnit(input.unit);
    if (validationErr != null) {
      throw ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: validationErr,
      );
    }

    final response = await _client.put(
      'admin/gateways/${input.gatewayId.trim()}/sensors/${input.sensorId.trim()}',
      body: input.toJson(),
    );

    return ProvisionSensorResult.fromJson(
      response.data,
      statusCode: response.statusCode,
    );
  }

  @override
  Future<MqttCredentialMetadata> getMqttCredential(String gatewayId) async {
    if (!isValidGatewayId(gatewayId)) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Mã Gateway không hợp lệ hoặc chứa định danh dành riêng.',
      );
    }

    final json = await _client.get(
      'admin/gateways/${gatewayId.trim()}/mqtt-credential',
    );
    return MqttCredentialMetadata.fromJson(json);
  }

  @override
  Future<Object> provisionMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  }) async {
    if (!isValidGatewayId(gatewayId)) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Mã Gateway không hợp lệ hoặc chứa định danh dành riêng.',
      );
    }

    final response = await _client.post(
      'admin/gateways/${gatewayId.trim()}/mqtt-credential',
      idempotencyKey: idempotencyKey,
    );

    if (response.data['secret_returned'] == true &&
        response.data['password'] != null) {
      return MqttCredentialSecretResult.fromJson(response.data);
    }
    return MqttCredentialMutationResult.fromJson(response.data);
  }

  @override
  Future<Object> rotateMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  }) async {
    if (!isValidGatewayId(gatewayId)) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Mã Gateway không hợp lệ hoặc chứa định danh dành riêng.',
      );
    }

    final response = await _client.post(
      'admin/gateways/${gatewayId.trim()}/mqtt-credential/rotate',
      idempotencyKey: idempotencyKey,
    );

    if (response.data['secret_returned'] == true &&
        response.data['password'] != null) {
      return MqttCredentialSecretResult.fromJson(response.data);
    }
    return MqttCredentialMutationResult.fromJson(response.data);
  }

  @override
  Future<MqttCredentialMutationResult> revokeMqttCredential(
    String gatewayId, {
    required String idempotencyKey,
  }) async {
    if (!isValidGatewayId(gatewayId)) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Mã Gateway không hợp lệ hoặc chứa định danh dành riêng.',
      );
    }

    final response = await _client.delete(
      'admin/gateways/${gatewayId.trim()}/mqtt-credential',
      idempotencyKey: idempotencyKey,
    );

    return MqttCredentialMutationResult.fromJson(response.data);
  }
}

final gatewayRepositoryProvider = Provider<GatewayRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HttpGatewayRepository(client);
});
