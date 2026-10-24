import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/digital_twin/data/digital_twin_repository.dart';

import 'session_test.dart';

const gatewayUrn = 'urn:ngsi-ld:Gateway:gw';
Map<String, dynamic> detailFixture({bool sensor = false}) => {
  '@context': ['https://must-not-fetch.example/context'],
  'id': sensor ? 'urn:ngsi-ld:Sensor:gw:s1' : gatewayUrn,
  'type': sensor ? 'Sensor' : 'Gateway',
  'name': {
    'type': 'Property',
    'value': '<script>plain text</script>',
    'modifiedAt': '2026-10-23T00:00:00Z',
  },
  if (sensor) 'isHostedBy': {'type': 'Relationship', 'object': gatewayUrn},
  if (!sensor)
    'hasSensor': {
      'type': 'Relationship',
      'object': ['urn:ngsi-ld:Sensor:gw:s1'],
      'objectType': 'Sensor',
    },
};

void main() {
  late FakeAuthRepository auth;
  late ApiClient client;
  late dynamic repository;
  final requests = <http.Request>[];
  late Map<String, dynamic> body;
  String? link;
  setUp(() async {
    auth = FakeAuthRepository();
    await auth.signInWithPassword(email: 'member@example.com', password: 'pwd');
    requests.clear();
    body = detailFixture();
    link = null;
    client = ApiClient(
      authRepository: auth,
      baseUrl: 'https://api.example/v1/',
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(
          jsonEncode(body),
          200,
          headers: {
            'content-type': 'application/ld+json',
            if (link != null) 'link': link!,
          },
        );
      }),
    );
    repository = HttpDigitalTwinRepository(client);
  });
  tearDown(() {
    auth.dispose();
  });
  // Dynamic invocation deliberately permits a runtime RED before the API exists.
  test('normalized detail derives Gateway from URN, preserves properties and relationships', () async {
    final dynamic page = await repository.getTwinDetail(gatewayUrn);
    expect(page.detail.entity.gatewayId, 'gw');
    expect(page.detail.name.value, '<script>plain text</script>');
    expect(page.detail.name.modifiedAt, DateTime.utc(2026, 10, 23));
    expect(page.detail.sensors.single.urn, 'urn:ngsi-ld:Sensor:gw:s1');
    expect(page.nextCursor, isNull);
    expect(requests, hasLength(1));
    expect(
      requests.single.url.toString(),
      'https://api.example/v1/digital-twins/urn%3Angsi-ld%3AGateway%3Agw?relationship_limit=20',
    );
    expect(requests.single.headers['Accept'], 'application/ld+json');
    expect(requests.single.headers['Authorization'], startsWith('Bearer '));
  });
  test('optional properties and omitted empty hasSensor accepted; hostedBy needs no objectType', () async {
    body = {'id': gatewayUrn, 'type': 'Gateway'};
    dynamic page = await repository.getTwinDetail(gatewayUrn);
    expect(page.detail.sensors, isEmpty);
    expect(page.detail.name, isNull);
    body = detailFixture(sensor: true);
    page = await repository.getTwinDetail('urn:ngsi-ld:Sensor:gw:s1');
    expect(page.detail.hostedBy.urn, gatewayUrn);
  });
  for (final mutation in [
    'identity',
    'relationship',
    'property',
    'timestamp',
  ]) {
    test('malformed $mutation fails closed', () async {
      switch (mutation) {
        case 'identity':
          body['id'] = 'urn:ngsi-ld:Gateway:other';
        case 'relationship':
          body['hasSensor'] = {
            'type': 'Relationship',
            'object': ['urn:ngsi-ld:Sensor:foreign:s1'],
            'objectType': 'Sensor',
          };
        case 'property':
          body['name'] = 'flat';
        case 'timestamp':
          (body['name'] as Map)['modifiedAt'] = 'yesterday';
      }
      await expectLater(
        repository.getTwinDetail(gatewayUrn),
        throwsFormatException,
      );
    });
  }
  for (final path in [
    'urn:ngsi-ld:Gateway:gw',
    'urn%3Angsi-ld%3AGateway%3Agw',
  ]) {
    test('relationship Link accepts canonical entity path $path', () async {
      link =
          '</v1/digital-twins/$path?relationship_limit=20&relationship_after=c1>; rel="next"';
      final dynamic page = await repository.getTwinDetail(gatewayUrn);
      expect(page.nextCursor, 'c1');
    });
  }
  for (final target in [
    'https://evil.example/v1/digital-twins/$gatewayUrn?relationship_after=c1',
    '/v1/digital-twins/urn:ngsi-ld:Gateway:other?relationship_after=c1',
    '/v1/digital-twins/urn%253Angsi-ld%253AGateway%253Agw?relationship_after=c1',
    '/v1/digital-twins/urn:ngsi-ld:Gateway:gw%2Fescape?relationship_after=c1',
    '/v1/digital-twins/$gatewayUrn?relationship_after=c1&format=simplified',
    '?relationship_after=c1&relationship_limit=21',
    '?relationship_after=c1&relationship_after=c2',
    '?user_id=u1',
    '?relationship_limit=20',
    '/v1/digital-twins/x/../$gatewayUrn?relationship_after=c1',
  ]) {
    test('unsafe relationship Link rejected: $target', () async {
      link = '<$target>; rel="next"';
      await expectLater(
        repository.getTwinDetail(gatewayUrn),
        throwsA(anything),
      );
    });
  }
  test('invalid URN rejects before HTTP', () async {
    await expectLater(
      repository.getTwinDetail('urn%3Angsi-ld%3AGateway%3Agw'),
      throwsFormatException,
    );
    expect(requests, isEmpty);
  });
}
