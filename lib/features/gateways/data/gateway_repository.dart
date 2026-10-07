import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'gateway_dto.dart';

/// Contract for accessing Gateway resources.
abstract class GatewayRepository {
  Future<List<GatewayItem>> getGateways();
  Future<SensorListResponse> getGatewaySensors(String gatewayId);
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
}

final gatewayRepositoryProvider = Provider<GatewayRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HttpGatewayRepository(client);
});
