import 'package:flutter_test/flutter_test.dart';
import 'package:kite/features/users/data/user_dto.dart';

void main() {
  group('User DTO Validation & Serialization', () {
    test('validateFullName rejects blank or over 256 bytes UTF-8', () {
      expect(validateFullName(null), isNotNull);
      expect(validateFullName('   '), isNotNull);
      expect(validateFullName('Trần Vĩnh Trung'), isNull);

      final over256 = 'A' * 257;
      expect(validateFullName(over256), isNotNull);
    });

    test('validateEmail requires valid RFC 5322 format and trims outside whitespace only', () {
      expect(validateEmail(null), isNotNull);
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('invalid-email'), isNotNull);
      expect(validateEmail('user@'), isNotNull);
      expect(validateEmail('@domain.com'), isNotNull);
      expect(validateEmail('valid.user+test@domain.com'), isNull);
      expect(validateEmail('  spaced@domain.com  '), isNull);

      expect(
        normalizeEmail('  Admin.IoT@Example.COM  '),
        'Admin.IoT@Example.COM',
      );
    });

    test(
      'validatePassword enforces 6 runes to 72 bytes and NEVER normalizes',
      () {
        expect(validatePassword(null), isNotNull);
        expect(validatePassword(''), isNotNull);
        expect(validatePassword('12345'), isNotNull); // 5 chars
        expect(validatePassword('123456'), isNull); // 6 chars
        expect(
          validatePassword('  123456  '),
          isNull,
        ); // whitespace preserved, length > 6

        final over72 = 'A' * 73;
        expect(validatePassword(over72), isNotNull);

        // Verify CreateUserInput does not trim password
        const input = CreateUserInput(
          fullName: '  Test Admin  ',
          email: '  test@example.com  ',
          password: '  secret_pass_123  ',
        );
        final json = input.toJson();
        expect(json['full_name'], 'Test Admin');
        expect(json['email'], 'test@example.com');
        expect(
          json['password'],
          '  secret_pass_123  ',
        ); // Exact whitespace preserved!
      },
    );

    test('CreatedUser.fromJson parses fields correctly', () {
      final json = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'email': 'admin@example.com',
        'full_name': 'System Administrator',
        'platform_role': 'user',
        'created_at': '2026-10-19T08:00:00Z',
      };

      final user = CreatedUser.fromJson(json);
      expect(user.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(user.email, 'admin@example.com');
      expect(user.fullName, 'System Administrator');
      expect(user.platformRole, 'user');
      expect(user.createdAt, DateTime.parse('2026-10-19T08:00:00Z').toUtc());
    });

    test(
      'UpdateUserInput strictly omits null fields (never emits null literals)',
      () {
        const updateRoleOnly = UpdateUserInput(platformRole: 'platform_admin');
        expect(updateRoleOnly.toJson(), {'platform_role': 'platform_admin'});
        expect(updateRoleOnly.toJson().containsKey('full_name'), isFalse);

        const updateNameOnly = UpdateUserInput(fullName: 'New Name');
        expect(updateNameOnly.toJson(), {'full_name': 'New Name'});
        expect(updateNameOnly.toJson().containsKey('platform_role'), isFalse);

        const updateBoth = UpdateUserInput(
          fullName: 'New Name',
          platformRole: 'user',
        );
        expect(updateBoth.toJson(), {
          'full_name': 'New Name',
          'platform_role': 'user',
        });
      },
    );

    test('UserSummary.fromJson supports nullable full_name and parses gateway_roles', () {
      final json = {
        'id': '00000000-0000-4000-8000-000000000001',
        'email': 'legacy@example.com',
        'full_name': null,
        'platform_role': 'platform_admin',
        'created_at': '2026-08-24T00:00:00Z',
        'gateway_roles': [
          {'gateway_id': 'gw-001', 'role': 'owner'},
          {'gateway_id': 'gw-002', 'role': 'viewer'},
        ],
      };

      final summary = UserSummary.fromJson(json);
      expect(summary.id, '00000000-0000-4000-8000-000000000001');
      expect(summary.email, 'legacy@example.com');
      expect(summary.fullName, isNull);
      expect(summary.platformRole, 'platform_admin');
      expect(summary.isPlatformAdmin, isTrue);
      expect(summary.gatewayRoles.length, 2);
      expect(summary.gatewayRoles[0].gatewayId, 'gw-001');
      expect(summary.gatewayRoles[0].role, 'owner');
    });

    test('UserListResponse.fromJson parses full bounded array', () {
      final json = {
        'items': [
          {
            'id': 'u-1',
            'email': 'u1@example.com',
            'full_name': 'User One',
            'platform_role': 'user',
            'created_at': '2026-09-01T00:00:00Z',
            'gateway_roles': <dynamic>[],
          },
        ],
      };

      final resp = UserListResponse.fromJson(json);
      expect(resp.items.length, 1);
      expect(resp.items[0].email, 'u1@example.com');
    });

    test(
      'AssignGatewayUserResult and TransferGatewayOwnerResult parse correctly',
      () {
        final assign = AssignGatewayUserResult.fromJson({
          'gateway_id': 'gw-1',
          'user_id': 'u-1',
          'role': 'operator',
        });
        expect(assign.gatewayId, 'gw-1');
        expect(assign.userId, 'u-1');
        expect(assign.role, 'operator');

        final transfer = TransferGatewayOwnerResult.fromJson({
          'gateway_id': 'gw-1',
          'owner_user_id': 'u-target',
        });
        expect(transfer.gatewayId, 'gw-1');
        expect(transfer.ownerUserId, 'u-target');
      },
    );
  });
}
