import 'package:flutter_test/flutter_test.dart';
import 'package:kite/features/gateways/data/gateway_dto.dart';
import 'package:kite_ui/kite_ui.dart';

void main() {
  group('GatewayRole', () {
    test('fromString parses valid roles correctly', () {
      expect(GatewayRole.fromString('owner'), GatewayRole.owner);
      expect(GatewayRole.fromString('OWNER'), GatewayRole.owner);
      expect(GatewayRole.fromString('operator'), GatewayRole.operator);
      expect(GatewayRole.fromString('OPERATOR'), GatewayRole.operator);
      expect(GatewayRole.fromString('viewer'), GatewayRole.viewer);
      expect(GatewayRole.fromString('VIEWER'), GatewayRole.viewer);
      expect(GatewayRole.fromString('unknown'), GatewayRole.viewer);
      expect(GatewayRole.fromString(null), GatewayRole.viewer);
    });

    test('provides human-readable Vietnamese labels and tones', () {
      expect(GatewayRole.owner.label, 'Chủ sở hữu');
      expect(GatewayRole.owner.tone, KiteTone.info);

      expect(GatewayRole.operator.label, 'Vận hành');
      expect(GatewayRole.operator.tone, KiteTone.success);

      expect(GatewayRole.viewer.label, 'Chỉ xem');
      expect(GatewayRole.viewer.tone, KiteTone.neutral);
    });
  });

  group('GatewayItem', () {
    test('parses full JSON with all fields', () {
      final json = {
        'gateway_id': 'gateway_001',
        'name': 'AM5728 Gateway 001',
        'description': 'Trạm quan trắc nhà kính số 1',
        'role': 'owner',
        'created_at': '2026-09-16T08:30:00Z',
      };

      final item = GatewayItem.fromJson(json);

      expect(item.gatewayId, 'gateway_001');
      expect(item.name, 'AM5728 Gateway 001');
      expect(item.description, 'Trạm quan trắc nhà kính số 1');
      expect(item.role, GatewayRole.owner);
      expect(item.createdAt, DateTime.parse('2026-09-16T08:30:00Z'));
    });

    test('parses JSON with nullable description and created_at', () {
      final json = {
        'gateway_id': 'gateway_002',
        'name': 'ESP32 Gateway 002',
        'description': null,
        'role': 'viewer',
        'created_at': null,
      };

      final item = GatewayItem.fromJson(json);

      expect(item.gatewayId, 'gateway_002');
      expect(item.name, 'ESP32 Gateway 002');
      expect(item.description, isNull);
      expect(item.role, GatewayRole.viewer);
      expect(item.createdAt, isNull);
    });

    test('supports equality and toJson', () {
      final item1 = GatewayItem(
        gatewayId: 'gw-1',
        name: 'GW 1',
        description: 'Desc',
        role: GatewayRole.operator,
        createdAt: DateTime.parse('2026-09-16T08:30:00Z'),
      );
      final item2 = GatewayItem(
        gatewayId: 'gw-1',
        name: 'GW 1',
        description: 'Desc',
        role: GatewayRole.operator,
        createdAt: DateTime.parse('2026-09-16T08:30:00Z'),
      );

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));

      final json = item1.toJson();
      expect(json['gateway_id'], 'gw-1');
      expect(json['role'], 'operator');
    });
  });

  group('GatewayListResponse', () {
    test('parses empty items list', () {
      final json = {'items': <dynamic>[]};
      final response = GatewayListResponse.fromJson(json);
      expect(response.items, isEmpty);
    });

    test('parses multiple items in response', () {
      final json = {
        'items': [
          {
            'gateway_id': 'gateway_001',
            'name': 'GW 001',
            'description': null,
            'role': 'owner',
            'created_at': '2026-09-16T08:30:00Z',
          },
          {
            'gateway_id': 'gateway_002',
            'name': 'GW 002',
            'description': 'Second gateway',
            'role': 'operator',
            'created_at': '2026-09-17T09:00:00Z',
          },
        ],
      };

      final response = GatewayListResponse.fromJson(json);
      expect(response.items.length, 2);
      expect(response.items[0].gatewayId, 'gateway_001');
      expect(response.items[1].gatewayId, 'gateway_002');
    });

    test('throws FormatException if items is missing or not a list', () {
      expect(() => GatewayListResponse.fromJson({}), throwsFormatException);
      expect(
        () => GatewayListResponse.fromJson({'items': 'not-a-list'}),
        throwsFormatException,
      );
    });
  });
}
