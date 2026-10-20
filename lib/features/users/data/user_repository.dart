import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'user_dto.dart';

/// Contract for Platform Admin User Management and Gateway Membership.
abstract class UserRepository {
  /// Fetches the full bounded user list from `GET /v1/admin/users`.
  Future<List<UserSummary>> listUsers();

  /// Creates a new user via `POST /v1/admin/users`.
  Future<CreatedUser> createUser(CreateUserInput input);

  /// Updates user full_name and/or platform_role via `PATCH /v1/admin/users/{user_id}`.
  Future<UpdatedUser> updateUser(String userId, UpdateUserInput input);

  /// Assigns operator or viewer role on a gateway via `PUT /v1/admin/gateways/{gateway_id}/users/{user_id}`.
  Future<AssignGatewayUserResult> assignGatewayUser({
    required String gatewayId,
    required String userId,
    required String role,
  });

  /// Revokes user membership from a gateway via `DELETE /v1/admin/gateways/{gateway_id}/users/{user_id}`.
  Future<void> revokeGatewayUser({
    required String gatewayId,
    required String userId,
  });

  /// Transfers gateway ownership via `PUT /v1/admin/gateways/{gateway_id}/owner`.
  Future<TransferGatewayOwnerResult> transferGatewayOwner({
    required String gatewayId,
    required String targetUserId,
  });
}

/// Concrete implementation of [UserRepository] using Go REST API (`/v1/admin/*`).
class HttpUserRepository implements UserRepository {
  const HttpUserRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<UserSummary>> listUsers() async {
    // Strictly NO query parameters allowed on /v1/admin/users
    final json = await _client.get('admin/users');
    final response = UserListResponse.fromJson(json);
    return response.items;
  }

  @override
  Future<CreatedUser> createUser(CreateUserInput input) async {
    final nameErr = validateFullName(input.fullName);
    if (nameErr != null) {
      throw ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: nameErr,
      );
    }
    final emailErr = validateEmail(input.email);
    if (emailErr != null) {
      throw ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: emailErr,
      );
    }
    final pwdErr = validatePassword(input.password);
    if (pwdErr != null) {
      throw ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: pwdErr,
      );
    }

    final response = await _client.post('admin/users', body: input.toJson());

    return CreatedUser.fromJson(response.data);
  }

  @override
  Future<UpdatedUser> updateUser(String userId, UpdateUserInput input) async {
    final trimmedId = userId.trim();
    if (!kUuidRegex.hasMatch(trimmedId) ||
        trimmedId.toLowerCase() == kNilUuid) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Mã người dùng (user_id) không đúng định dạng UUID.',
      );
    }

    if (input.fullName == null && input.platformRole == null) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Cần cung cấp ít nhất một trường để cập nhật.',
      );
    }

    if (input.fullName != null) {
      final nameErr = validateFullName(input.fullName);
      if (nameErr != null) {
        throw ApiException(
          statusCode: 400,
          code: 'invalid_request',
          message: nameErr,
        );
      }
    }

    if (input.platformRole != null) {
      final role = input.platformRole!;
      if (role != 'platform_admin' && role != 'user') {
        throw const ApiException(
          statusCode: 400,
          code: 'invalid_request',
          message: 'Vai trò hệ thống phải là platform_admin hoặc user.',
        );
      }
    }

    final response = await _client.patch(
      'admin/users/$trimmedId',
      body: input.toJson(),
    );

    return UpdatedUser.fromJson(response.data);
  }

  @override
  Future<AssignGatewayUserResult> assignGatewayUser({
    required String gatewayId,
    required String userId,
    required String role,
  }) async {
    final trimmedGw = gatewayId.trim();
    final trimmedUser = userId.trim();
    final trimmedRole = role.trim().toLowerCase();

    if (trimmedRole == 'owner') {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_role',
        message: 'Không thể gán vai trò owner qua endpoint này. Vui lòng dùng chức năng chuyển giao quyền sở hữu.',
      );
    }

    if (trimmedRole != 'operator' && trimmedRole != 'viewer') {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_role',
        message: 'Vai trò thành viên chỉ có thể là operator hoặc viewer.',
      );
    }

    if (!kUuidRegex.hasMatch(trimmedUser) ||
        trimmedUser.toLowerCase() == kNilUuid) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Mã người dùng không hợp lệ.',
      );
    }

    final response = await _client.put(
      'admin/gateways/$trimmedGw/users/$trimmedUser',
      body: {'role': trimmedRole},
    );

    return AssignGatewayUserResult.fromJson(response.data);
  }

  @override
  Future<void> revokeGatewayUser({
    required String gatewayId,
    required String userId,
  }) async {
    final trimmedGw = gatewayId.trim();
    final trimmedUser = userId.trim();

    if (!kUuidRegex.hasMatch(trimmedUser) ||
        trimmedUser.toLowerCase() == kNilUuid) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Mã người dùng không hợp lệ.',
      );
    }

    // Endpoint DELETE /v1/admin/gateways/{id}/users/{id} returns 204 No Content with empty body.
    await _client.delete('admin/gateways/$trimmedGw/users/$trimmedUser');
  }

  @override
  Future<TransferGatewayOwnerResult> transferGatewayOwner({
    required String gatewayId,
    required String targetUserId,
  }) async {
    final trimmedGw = gatewayId.trim();
    final trimmedTarget = targetUserId.trim();

    if (!kUuidRegex.hasMatch(trimmedTarget) ||
        trimmedTarget.toLowerCase() == kNilUuid) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_request',
        message: 'Mã người dùng nhận quyền sở hữu không hợp lệ.',
      );
    }

    final response = await _client.put(
      'admin/gateways/$trimmedGw/owner',
      body: {'user_id': trimmedTarget},
    );

    return TransferGatewayOwnerResult.fromJson(response.data);
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HttpUserRepository(client);
});
