import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/config/app_config.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/core/network/api_exception.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite/features/gateways/data/gateway_repository.dart';

import 'session_test.dart';

void main() {
  group('AdminGatewayItem DTO', () {
    test('parses full JSON with all fields without role or owner_user_id', () {
      final json = {
        'gateway_id': 'gw-station-alpha',
        'name': 'AM5728 Gateway 001',
        'description': 'Tram quan trac nha kinh so 1',
        'created_at': '2026-10-14T08:00:00Z',
      };

      final item = AdminGatewayItem.fromJson(json);

      expect(item.gatewayId, 'gw-station-alpha');
      expect(item.name, 'AM5728 Gateway 001');
      expect(item.description, 'Tram quan trac nha kinh so 1');
      expect(item.createdAt, DateTime.parse('2026-10-14T08:00:00Z').toUtc());

      // Verify toJson output adheres to inventory contract
      final outputJson = item.toJson();
      expect(outputJson['gateway_id'], 'gw-station-alpha');
      expect(outputJson['name'], 'AM5728 Gateway 001');
      expect(outputJson['description'], 'Tram quan trac nha kinh so 1');
      expect(outputJson['created_at'], '2026-10-14T08:00:00.000Z');
      expect(outputJson.containsKey('role'), isFalse);
      expect(outputJson.containsKey('owner_user_id'), isFalse);
      expect(outputJson.containsKey('password'), isFalse);
    });

    test('parses nullable description and nullable created_at', () {
      final json = {
        'gateway_id': 'gw-station-beta',
        'name': 'ESP32 Gateway 002',
        'description': null,
        'created_at': null,
      };

      final item = AdminGatewayItem.fromJson(json);

      expect(item.gatewayId, 'gw-station-beta');
      expect(item.name, 'ESP32 Gateway 002');
      expect(item.description, isNull);
      expect(item.createdAt, isNull);
    });

    test('throws FormatException when gateway_id is empty, whitespace, padded, reserved, invalid, or non-string', () {
      expect(
        () => AdminGatewayItem.fromJson({'gateway_id': '', 'name': 'GW'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AdminGatewayItem.fromJson({'gateway_id': '   ', 'name': 'GW'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AdminGatewayItem.fromJson({'gateway_id': ' gw-1 ', 'name': 'GW'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AdminGatewayItem.fromJson({
          'gateway_id': 'backend_service',
          'name': 'GW',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AdminGatewayItem.fromJson({
          'gateway_id': 'invalid/id#1',
          'name': 'GW',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AdminGatewayItem.fromJson({'gateway_id': 12345, 'name': 'GW'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AdminGatewayItem.fromJson({'name': 'GW'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AdminGatewayItem.fromJson({'gateway_id': 'gw-1'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('preserves exact casing of valid gateway_id without trimming', () {
      final item = AdminGatewayItem.fromJson({
        'gateway_id': 'GW_Alpha-001_Station',
        'name': 'Station Alpha',
      });
      expect(item.gatewayId, 'GW_Alpha-001_Station');
    });

    test('supports equality and hashCode', () {
      final item1 = AdminGatewayItem(
        gatewayId: 'gw-1',
        name: 'GW 1',
        description: 'Desc',
        createdAt: DateTime.parse('2026-10-14T08:00:00Z').toUtc(),
      );
      final item2 = AdminGatewayItem(
        gatewayId: 'gw-1',
        name: 'GW 1',
        description: 'Desc',
        createdAt: DateTime.parse('2026-10-14T08:00:00Z').toUtc(),
      );
      const item3 = AdminGatewayItem(gatewayId: 'gw-2', name: 'GW 2');

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
      expect(item1, isNot(equals(item3)));
    });
  });

  group('AdminGatewayInventoryResponse DTO', () {
    test('parses populated response with next_cursor', () {
      final json = {
        'items': [
          {
            'gateway_id': 'gw-station-alpha',
            'name': 'AM5728 Gateway 001',
            'description': 'Tram quan trac nha kinh so 1',
            'created_at': '2026-10-14T08:00:00Z',
          },
          {
            'gateway_id': 'gw-station-beta',
            'name': 'ESP32 Gateway 002',
            'description': null,
            'created_at': '2026-10-14T08:15:00Z',
          },
        ],
        'next_cursor': 'gw-station-beta',
      };

      final response = AdminGatewayInventoryResponse.fromJson(json);

      expect(response.items.length, 2);
      expect(response.items[0].gatewayId, 'gw-station-alpha');
      expect(response.items[1].gatewayId, 'gw-station-beta');
      expect(response.nextCursor, 'gw-station-beta');
      expect(response.hasMore, isTrue);

      final outJson = response.toJson();
      expect(outJson['items'], isA<List<dynamic>>());
      expect(outJson['next_cursor'], 'gw-station-beta');
      expect(outJson.containsKey('total'), isFalse);
      expect(outJson.containsKey('page'), isFalse);
    });

    test('keeps null next_cursor valid when null or omitted', () {
      final jsonExplicitNull = {'items': <dynamic>[], 'next_cursor': null};
      final response1 = AdminGatewayInventoryResponse.fromJson(
        jsonExplicitNull,
      );
      expect(response1.items, isEmpty);
      expect(response1.nextCursor, isNull);
      expect(response1.hasMore, isFalse);

      final jsonOmitted = {'items': <dynamic>[]};
      final response2 = AdminGatewayInventoryResponse.fromJson(jsonOmitted);
      expect(response2.items, isEmpty);
      expect(response2.nextCursor, isNull);
      expect(response2.hasMore, isFalse);
    });

    test('rejects empty, whitespace, padded, reserved, invalid, or non-string next_cursor with FormatException', () {
      // Empty string cursor
      expect(
        () => AdminGatewayInventoryResponse.fromJson({
          'items': <dynamic>[],
          'next_cursor': '',
        }),
        throwsA(isA<FormatException>()),
      );

      // Whitespace cursor
      expect(
        () => AdminGatewayInventoryResponse.fromJson({
          'items': <dynamic>[],
          'next_cursor': '   ',
        }),
        throwsA(isA<FormatException>()),
      );

      // Padded cursor
      expect(
        () => AdminGatewayInventoryResponse.fromJson({
          'items': <dynamic>[],
          'next_cursor': ' gw-station-beta ',
        }),
        throwsA(isA<FormatException>()),
      );

      // Reserved gateway ID as cursor
      expect(
        () => AdminGatewayInventoryResponse.fromJson({
          'items': <dynamic>[],
          'next_cursor': 'backend_service',
        }),
        throwsA(isA<FormatException>()),
      );

      // Invalid regex cursor
      expect(
        () => AdminGatewayInventoryResponse.fromJson({
          'items': <dynamic>[],
          'next_cursor': 'invalid/cursor#id',
        }),
        throwsA(isA<FormatException>()),
      );

      // Non-string cursor
      expect(
        () => AdminGatewayInventoryResponse.fromJson({
          'items': <dynamic>[],
          'next_cursor': 99999,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('preserves exact casing and characters of valid next_cursor without trimming', () {
      final response = AdminGatewayInventoryResponse.fromJson({
        'items': <dynamic>[],
        'next_cursor': 'GW_Station-BETA_02',
      });
      expect(response.nextCursor, 'GW_Station-BETA_02');
      expect(response.hasMore, isTrue);
    });

    test('throws FormatException when items is not a list', () {
      expect(
        () => AdminGatewayInventoryResponse.fromJson({'items': 'not-a-list'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('GatewayCatalogItem presentation model', () {
    test('fromUserGateway preserves all fields including non-null role', () {
      const userItem = GatewayItem(
        gatewayId: 'gw-user-1',
        name: 'User Gateway 1',
        description: 'Greenhouse',
        role: GatewayRole.owner,
      );

      final catalogItem = GatewayCatalogItem.fromUserGateway(userItem);

      expect(catalogItem.gatewayId, 'gw-user-1');
      expect(catalogItem.name, 'User Gateway 1');
      expect(catalogItem.description, 'Greenhouse');
      expect(catalogItem.role, GatewayRole.owner);
      expect(catalogItem.createdAt, isNull);
    });

    test(
      'fromAdminGateway preserves fields and sets role to null strictly',
      () {
        final now = DateTime.now().toUtc();
        final adminItem = AdminGatewayItem(
          gatewayId: 'gw-admin-1',
          name: 'Admin Gateway 1',
          description: 'Node cluster',
          createdAt: now,
        );

        final catalogItem = GatewayCatalogItem.fromAdminGateway(adminItem);

        expect(catalogItem.gatewayId, 'gw-admin-1');
        expect(catalogItem.name, 'Admin Gateway 1');
        expect(catalogItem.description, 'Node cluster');
        expect(catalogItem.role, isNull);
        expect(catalogItem.createdAt, now);
      },
    );

    test('supports value equality and hashCode', () {
      const itemA = GatewayCatalogItem(
        gatewayId: 'gw-1',
        name: 'Name',
        description: 'Desc',
        role: GatewayRole.viewer,
      );
      const itemB = GatewayCatalogItem(
        gatewayId: 'gw-1',
        name: 'Name',
        description: 'Desc',
        role: GatewayRole.viewer,
      );
      const itemC = GatewayCatalogItem(
        gatewayId: 'gw-1',
        name: 'Name',
        description: 'Desc',
        role: null,
      );

      expect(itemA, equals(itemB));
      expect(itemA.hashCode, equals(itemB.hashCode));
      expect(itemA, isNot(equals(itemC)));
    });
  });

  group('HttpGatewayRepository.getAdminGateways', () {
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

    test(
      'sends GET relative admin/gateways with Bearer token and headers',
      () async {
        await authRepo.signInWithPassword(
          email: 'admin@example.com',
          password: 'password',
        );

        late http.Request capturedRequest;
        final mockHttp = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'gateway_id': 'gw-001',
                  'name': 'Gateway 001',
                  'description': 'Description 001',
                  'created_at': '2026-10-14T08:00:00Z',
                },
              ],
              'next_cursor': null,
            }),
            200,
            headers: {
              'content-type': 'application/json',
              'cache-control': 'no-store',
              'pragma': 'no-cache',
              'x-request-id': 'req-test-123',
            },
          );
        });

        final client = ApiClient(
          authRepository: authRepo,
          httpClient: mockHttp,
          baseUrl: 'http://localhost/v1/',
        );
        final repo = HttpGatewayRepository(client);

        final result = await repo.getAdminGateways();

        expect(
          capturedRequest.url.toString(),
          'http://localhost/v1/admin/gateways',
        );
        expect(capturedRequest.method, 'GET');
        expect(
          capturedRequest.headers['Authorization'],
          'Bearer mock_jwt_token',
        );
        expect(capturedRequest.headers['Accept'], 'application/json');
        expect(capturedRequest.headers['X-Request-ID'], isNotNull);

        expect(result.items.length, 1);
        expect(result.items[0].gatewayId, 'gw-001');
        expect(result.items[0].name, 'Gateway 001');
        expect(result.items[0].description, 'Description 001');
        expect(result.nextCursor, isNull);
      },
    );

    test('passes limit and after query parameters correctly', () async {
      await authRepo.signInWithPassword(
        email: 'admin@example.com',
        password: 'password',
      );

      late http.Request capturedRequest;
      final mockHttp = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'items': <dynamic>[], 'next_cursor': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );
      final repo = HttpGatewayRepository(client);

      await repo.getAdminGateways(limit: 50, after: 'gw-alpha');

      expect(
        capturedRequest.url.toString(),
        'http://localhost/v1/admin/gateways?limit=50&after=gw-alpha',
      );
      expect(capturedRequest.url.queryParameters['limit'], '50');
      expect(capturedRequest.url.queryParameters['after'], 'gw-alpha');
      expect(
        capturedRequest.url.queryParameters.containsKey('user_id'),
        isFalse,
      );
    });

    test('client validates limit > 0 and throws 400 invalid_request before request', () async {
      final mockHttp = MockClient((request) async => http.Response('{}', 200));
      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );
      final repo = HttpGatewayRepository(client);

      expect(
        () => repo.getAdminGateways(limit: 0),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_request'),
        ),
      );

      expect(
        () => repo.getAdminGateways(limit: -5),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_request'),
        ),
      );
    });

    test('client validates after cursor and throws 400 invalid_request on empty, whitespace, padded, reserved, or invalid cursor', () async {
      final mockHttp = MockClient((request) async => http.Response('{}', 200));
      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );
      final repo = HttpGatewayRepository(client);

      // Empty cursor
      expect(
        () => repo.getAdminGateways(after: ''),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_request'),
        ),
      );

      // Whitespace cursor
      expect(
        () => repo.getAdminGateways(after: '   '),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_request'),
        ),
      );

      // Padded cursor
      expect(
        () => repo.getAdminGateways(after: ' gw-alpha '),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_request'),
        ),
      );

      // Reserved cursor
      expect(
        () => repo.getAdminGateways(after: 'backend_service'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_request'),
        ),
      );

      // Invalid regex cursor
      expect(
        () => repo.getAdminGateways(after: 'invalid/cursor'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'invalid_request'),
        ),
      );
    });

    test(
      'preserves exact case of valid after parameter without trimming',
      () async {
        await authRepo.signInWithPassword(
          email: 'admin@example.com',
          password: 'password',
        );

        late http.Request capturedRequest;
        final mockHttp = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({'items': <dynamic>[], 'next_cursor': null}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = ApiClient(
          authRepository: authRepo,
          httpClient: mockHttp,
          baseUrl: 'http://localhost/v1/',
        );
        final repo = HttpGatewayRepository(client);

        await repo.getAdminGateways(after: 'GW_Station-ALPHA_01');

        expect(
          capturedRequest.url.queryParameters['after'],
          'GW_Station-ALPHA_01',
        );
      },
    );

    test('throws 403 Forbidden when user is not a platform admin', () async {
      await authRepo.signInWithPassword(
        email: 'user@example.com',
        password: 'password',
      );

      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'forbidden',
              'message': 'insufficient permissions',
              'request_id': 'req-err-403',
            },
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        authRepository: authRepo,
        httpClient: mockHttp,
        baseUrl: 'http://localhost/v1/',
      );
      final repo = HttpGatewayRepository(client);

      expect(
        () => repo.getAdminGateways(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.code, 'code', 'forbidden')
              .having((e) => e.message, 'message', 'insufficient permissions')
              .having((e) => e.requestId, 'requestId', 'req-err-403'),
        ),
      );
    });
  });
}
