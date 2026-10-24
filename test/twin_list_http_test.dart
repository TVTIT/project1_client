import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/digital_twin/data/digital_twin_dto.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';
import 'package:kite/features/digital_twin/data/twin_list_page.dart';

import 'session_test.dart';
import 'twin_list_page_test.dart' show twinRow;

void main() {
  test(
    'real transport decodes root arrays and follows only validated list cursor',
    () async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      await auth.signInWithPassword(
        email: 'member@example.com',
        password: 'fixture-only',
      );
      final requests = <http.Request>[];
      final transport = MockClient((request) async {
        requests.add(request);
        expect(request.url.path, '/v1/digital-twins');
        expect(request.url.queryParameters['format'], 'simplified');
        expect(request.url.queryParameters['type'], 'Sensor');
        expect(request.url.queryParameters['gateway_id'], 'gw');
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], startsWith('Bearer '));
        final more = requests.length == 1;
        return http.Response(
          jsonEncode([twinRow(more ? 'one' : 'two')]),
          200,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            if (more) 'link': '<?format=simplified&type=Sensor&gateway_id=gw&limit=50&cursor=v1.next>; rel="next"',
          },
        );
      });
      addTearDown(transport.close);
      final client = ApiClient(
        authRepository: auth,
        httpClient: transport,
        baseUrl: 'https://api.example/v1/',
      );
      final repo = HttpDigitalTwinRepository(client);
      final first = await repo.listTwins(
        type: EntityType.sensor,
        gatewayId: 'gw',
        limit: 50,
      );
      final page = TwinListPage.parse(first, requests.last.url);
      expect(page.items.single.id, 'urn:ngsi-ld:Sensor:gw:one');
      expect(requests, hasLength(1));
      final second = await repo.listTwins(
        type: EntityType.sensor,
        gatewayId: 'gw',
        limit: 50,
        cursor: page.nextCursor,
      );
      expect(requests.last.url.queryParameters['cursor'], 'v1.next');
      expect(TwinListPage.parse(second, requests.last.url).nextCursor, isNull);
      expect(requests, hasLength(2));
    },
  );
}
