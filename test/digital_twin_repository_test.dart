import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/config/app_config.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';

import 'session_test.dart';

void main() {
  late FakeAuthRepository authRepo;

  setUp(() {
    authRepo = FakeAuthRepository();
    AppConfig.currentForTesting = const AppConfig(
      backendApiBaseUrl: 'http://localhost/v1/',
      supabaseUrl: 'http://localhost',
      supabaseAnonKey: 'anon-key',
      environment: Environment.development,
    );
  });

  tearDown(() {
    authRepo.dispose();
    AppConfig.currentForTesting = null;
  });

  group('DigitalTwinRepository Tests', () {
    test(
      'listTwins passes simplified query and application/json Accept header',
      () async {
        await authRepo.signInWithPassword(
          email: 'admin@example.com',
          password: 'pwd',
        );

        late http.Request capturedRequest;
        final mockHttp = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode([
              {
                'id': 'urn:ngsi-ld:Gateway:gw-01',
                'type': 'Gateway',
                'name': 'Station 1',
                'gateway_id': 'gw-01',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = ApiClient(
          authRepository: authRepo,
          httpClient: mockHttp,
          baseUrl: 'http://localhost/v1/',
        );

        final repo = HttpDigitalTwinRepository(client);
        final res = await repo.listTwins(simplified: true);

        expect(res.statusCode, 200);
        expect(capturedRequest.url.queryParameters['format'], 'simplified');
        expect(capturedRequest.headers['Accept'], 'application/json');
      },
    );

    test(
      'getTwinState calls single-encoded URN path with format=simplified',
      () async {
        await authRepo.signInWithPassword(
          email: 'admin@example.com',
          password: 'pwd',
        );

        late http.Request capturedRequest;
        final mockHttp = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'id': 'urn:ngsi-ld:Sensor:gw-1:temp-1',
              'type': 'Sensor',
              'gateway_id': 'gw-1',
              'reported_state': {'temperature': 25.0},
              'desired_state': <String, dynamic>{},
              'reported_version': '1',
              'desired_version': '1',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = ApiClient(
          authRepository: authRepo,
          httpClient: mockHttp,
          baseUrl: 'http://localhost/v1/',
        );

        final repo = HttpDigitalTwinRepository(client);
        final state = await repo.getTwinState('urn:ngsi-ld:Sensor:gw-1:temp-1');

        expect(state.id, 'urn:ngsi-ld:Sensor:gw-1:temp-1');
        expect(state.reportedState['temperature'], 25.0);
        expect(
          capturedRequest.url.path,
          '/v1/digital-twins/urn%3Angsi-ld%3ASensor%3Agw-1%3Atemp-1',
        );
        expect(capturedRequest.url.queryParameters['format'], 'simplified');
      },
    );

    test(
      'getSensorTemporal rejects Gateway URN and validates time range',
      () async {
        await authRepo.signInWithPassword(
          email: 'admin@example.com',
          password: 'pwd',
        );

        final client = ApiClient(
          authRepository: authRepo,
          baseUrl: 'http://localhost/v1/',
        );
        final repo = HttpDigitalTwinRepository(client);

        // Rejects Gateway URN
        expect(
          () => repo.getSensorTemporal(
            'urn:ngsi-ld:Gateway:gw-1',
            attrs: 'measurement',
            timeAt: DateTime.parse('2026-10-19T08:00:00Z'),
            endTimeAt: DateTime.parse('2026-10-19T09:00:00Z'),
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.code, 'code', 'invalid_request'),
          ),
        );

        // Rejects timeAt >= endTimeAt
        expect(
          () => repo.getSensorTemporal(
            'urn:ngsi-ld:Sensor:gw-1:temp-1',
            attrs: 'measurement',
            timeAt: DateTime.parse('2026-10-19T10:00:00Z'),
            endTimeAt: DateTime.parse('2026-10-19T09:00:00Z'),
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.code, 'code', 'invalid_request'),
          ),
        );
      },
    );

    test(
      'patchTwinAttrs calls PATCH digital-twins/{encoded_urn}/attrs',
      () async {
        await authRepo.signInWithPassword(
          email: 'admin@example.com',
          password: 'pwd',
        );

        late http.Request capturedRequest;
        final mockHttp = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'name': {'type': 'Property', 'value': 'New Gateway Name'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = ApiClient(
          authRepository: authRepo,
          httpClient: mockHttp,
          baseUrl: 'http://localhost/v1/',
        );

        final repo = HttpDigitalTwinRepository(client);
        final res = await repo.patchTwinAttrs(
          'urn:ngsi-ld:Gateway:gw-01',
          const PatchTwinAttrsInput(name: 'New Gateway Name'),
        );

        expect(res.statusCode, 200);
        expect(capturedRequest.method, 'PATCH');
        expect(
          capturedRequest.url.path,
          '/v1/digital-twins/urn%3Angsi-ld%3AGateway%3Agw-01/attrs',
        );
      },
    );
  });
}
