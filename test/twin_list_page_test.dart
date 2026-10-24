import 'package:flutter_test/flutter_test.dart';
import 'package:kite/core/network/api_client.dart';
import 'package:kite/features/digital_twin/data/twin_list_page.dart';

Map<String, dynamic> twinRow(String id, {String gateway = 'gw'}) => {
  'id': 'urn:ngsi-ld:Sensor:$gateway:$id',
  'type': 'Sensor',
  'name': 'Temperature $id',
  'gateway_id': gateway,
  'modifiedAt': '2026-10-23T00:00:00Z',
};

void main() {
  final uri = Uri.parse(
    'https://api.example/v1/digital-twins?format=simplified&type=Sensor&gateway_id=gw&limit=50',
  );
  ApiResponse response({dynamic body, String? link}) => ApiResponse(
    statusCode: 200,
    rawBody: body ?? [twinRow('s')],
    headers: {if (link != null) 'link': '<$link>; rel="next"'},
  );
  test('root array yields typed rows and no Link is terminal', () {
    final page = TwinListPage.parse(response(), uri);
    expect(page.items.single.name, 'Temperature s');
    expect(page.items.single.modifiedAt!.isUtc, isTrue);
    expect(page.nextCursor, isNull);
    expect(TwinListPage.parse(response(body: <dynamic>[]), uri).items, isEmpty);
    expect(
      () => TwinListPage.parse(response(body: {'items': <dynamic>[]}), uri),
      throwsFormatException,
    );
    expect(
      () => TwinListPage.parse(response(body: [<String, dynamic>{}]), uri),
      throwsFormatException,
    );
  });
  test(
    'query-only next resolves against actual request with preserved filters',
    () {
      final page = TwinListPage.parse(
        response(
          link: '?format=simplified&type=Sensor&gateway_id=gw&limit=50&cursor=v1.abc',
        ),
        uri,
      );
      expect(page.nextCursor, 'v1.abc');
    },
  );
  test('rejects external paths origins unsafe queries or changed filters', () {
    for (final link in [
      'https://evil.example/v1/digital-twins?cursor=x',
      '/v1/admin/gateways?cursor=x',
      '?format=simplified&type=Sensor&gateway_id=gw&cursor=x&user_id=u',
      '?format=simplified&type=Sensor&gateway_id=gw&cursor=x&after=x',
      '?format=simplified&type=Sensor&gateway_id=gw&cursor=x&cursor=y',
      '?type=Sensor&gateway_id=gw&cursor=x',
      '?format=simplified&type=Gateway&gateway_id=gw&cursor=x',
      '?format=simplified&type=Sensor&gateway_id=other&cursor=x',
      '?format=simplified&type=Sensor&gateway_id=gw&cursor=x&limit=200',
      '?format=simplified&type=Sensor&gateway_id=gw',
      'https://user@api.example/v1/digital-twins?cursor=x',
      '?format=simplified&type=Sensor&gateway_id=gw&cursor=x#fragment',
    ]) {
      expect(
        () => TwinListPage.parse(response(link: link), uri),
        throwsA(anything),
        reason: link,
      );
    }
  });
  test(
    'rejects row filter mismatch duplicate identities and oversized page',
    () {
      for (final body in [
        [twinRow('s', gateway: 'other')],
        [twinRow('s'), twinRow('s')],
        List.generate(51, (i) => twinRow('s$i')),
      ]) {
        expect(
          () => TwinListPage.parse(response(body: body), uri),
          throwsFormatException,
        );
      }
    },
  );
}
