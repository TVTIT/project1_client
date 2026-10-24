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
    test('temporal HTTP binds root identity, mode, UTC range and exact count to request', () async {
      await authRepo.signInWithPassword(
        email: 'fixture@example.com',
        password: 'fixture',
      );
      const id = 'urn:ngsi-ld:Sensor:gw:s';
      var body =
          '{"id":"$id","type":"Sensor","measurement":{"type":"Property","avg":[],"min":[],"max":[],"totalCount":[[9007199254740993,"2026-10-23T00:00:00.000000Z","2026-10-23T00:01:00.000000Z"]]}}';
      final client = ApiClient(
        authRepository: authRepo,
        baseUrl: 'http://localhost/v1/',
        httpClient: MockClient((request) async {
          expect(request.headers['Accept'], 'application/ld+json');
          expect(request.headers['Authorization'], isNotEmpty);
          expect(
            request.url.queryParameters['timeAt'],
            '2026-10-23T00:00:00.000Z',
          );
          expect(request.url.queryParameters.containsKey('user_id'), isFalse);
          return http.Response(
            body,
            200,
            headers: {'content-type': 'application/ld+json'},
          );
        }),
      );
      final repo = HttpDigitalTwinRepository(client);
      Future<TwinTemporalResponse> fetch() => repo.getSensorTemporal(
        id,
        attrs: 'measurement',
        timeAt: DateTime.utc(2026, 10, 23),
        endTimeAt: DateTime.utc(2026, 10, 23, 0, 1),
        aggrPeriodDuration: 'PT1M',
      );
      expect(
        (await fetch()).totalCountBuckets.single.value.toString(),
        '9007199254740993',
      );
      body = body.replaceFirst('"type":"Sensor"', '"type":"Gateway"');
      await expectLater(fetch(), throwsFormatException);
    });
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
              'id': 'urn:ngsi-ld:Gateway:gw-01',
              'type': 'Gateway',
              'gateway_id': 'gw-01',
              'name': 'New Gateway Name',
              'updated_at': '2026-10-23T12:00:00.000000Z',
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

        expect(res.name, 'New Gateway Name');
        expect(res.id, 'urn:ngsi-ld:Gateway:gw-01');
        expect(capturedRequest.method, 'PATCH');
        expect(
          capturedRequest.url.path,
          '/v1/digital-twins/urn%3Angsi-ld%3AGateway%3Agw-01/attrs',
        );
      },
    );
  });
}
