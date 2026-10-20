// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class LVi extends L {
  LVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'SANSLAB IoT Server';

  @override
  String get navOverview => 'Tổng quan';

  @override
  String get navManage => 'Quản lý';

  @override
  String get navApps => 'Ứng dụng';

  @override
  String get navBuild => 'Xây dựng';

  @override
  String get navDashboard => 'Bảng điều khiển';

  @override
  String get navProjects => 'Dự án';

  @override
  String get navOrders => 'Đơn hàng';

  @override
  String get navCustomers => 'Khách hàng';

  @override
  String get navProducts => 'Sản phẩm';

  @override
  String get navInbox => 'Hộp thư';

  @override
  String get navBoard => 'Bảng';

  @override
  String get navCalendar => 'Lịch';

  @override
  String get navChat => 'Trò chuyện';

  @override
  String get navComponents => 'Thành phần';

  @override
  String get navForms => 'Biểu mẫu';

  @override
  String get navWizard => 'Trình hướng dẫn';

  @override
  String get navSettings => 'Cài đặt';

  @override
  String get navProfile => 'Hồ sơ';

  @override
  String get actionSave => 'Lưu';

  @override
  String get actionCancel => 'Hủy';

  @override
  String get actionDelete => 'Xóa';

  @override
  String get actionEdit => 'Chỉnh sửa';

  @override
  String get actionRefresh => 'Làm mới';

  @override
  String get actionExport => 'Xuất';

  @override
  String get actionSearch => 'Tìm kiếm';

  @override
  String get actionClear => 'Xóa';

  @override
  String get actionPrevious => 'Trước';

  @override
  String get actionNext => 'Tiếp';

  @override
  String get actionSignIn => 'Đăng nhập';

  @override
  String get actionSignOut => 'Đăng xuất';

  @override
  String get signInTitle => 'Đăng nhập';

  @override
  String get signInSubtitle => 'Nhập email và mật khẩu của bạn để tiếp tục.';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Mật khẩu';

  @override
  String get fieldName => 'Họ và tên';

  @override
  String get forgotPassword => 'Quên mật khẩu?';

  @override
  String get noAccount => 'Chưa có tài khoản? Tạo tài khoản';

  @override
  String get lightMode => 'Chế độ sáng';

  @override
  String get darkMode => 'Chế độ tối';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get theme => 'Giao diện';

  @override
  String get accent => 'Màu chủ đạo';

  @override
  String get emptyTitle => 'Không có kết quả phù hợp với bộ lọc';

  @override
  String get emptyMessage =>
      'Hãy thử xóa tìm kiếm hoặc chọn một trạng thái khác.';

  @override
  String get errorTitle => 'Đã xảy ra sự cố';

  @override
  String get errorRetry => 'Thử lại';

  @override
  String pageOf(int page, int pages) {
    return 'Trang $page trên $pages';
  }

  @override
  String rangeOfTotal(int first, int last, int total) {
    return '$first–$last trên $total';
  }

  @override
  String get accountInfo => 'Thông tin tài khoản';

  @override
  String get accountSubtitle =>
      'Xem thông tin định danh và phiên làm việc hiện tại của tài khoản.';

  @override
  String get accountIdentityTitle => 'Thông tin định danh';

  @override
  String get accountUserId => 'ID người dùng';

  @override
  String get accountEmail => 'Email tài khoản';

  @override
  String get accountFullName => 'Họ và tên';

  @override
  String get accountRole => 'Vai trò trạm (Gateway Role)';

  @override
  String get accountRoleUnassigned => 'Chưa gán vai trò trạm';

  @override
  String get accountRoleNote =>
      'Quyền truy cập các trạm Gateway (owner, operator, viewer) và quyền Quản trị nền tảng (platform_admins) được Go Backend thẩm định động trên từng truy vấn. Phiên định danh không ấn định hay suy diễn quyền hạn này.';

  @override
  String get accountSessionTitle => 'Phiên làm việc & Bảo mật';

  @override
  String get accountSessionStatus => 'Trạng thái phiên';

  @override
  String get accountStatusActive => 'Đang hoạt động (Active)';

  @override
  String get accountAuthMethod => 'Cơ chế xác thực';

  @override
  String get accountAuthMethodValue =>
      'Supabase Auth (GoTrue) · Xác thực cục bộ HS256 tại Go Backend';

  @override
  String get accountAdminNoteTitle => 'Chính sách quản lý tài khoản';

  @override
  String get accountAdminNote =>
      'Tài khoản được quản lý tập trung bởi Quản trị viên hệ thống. Người dùng không thể tự thay đổi thông tin định danh trực tiếp từ giao diện client. Quyền Platform Admin được quản lý độc lập tại bảng platform_admins.';

  @override
  String get accountCopyId => 'Sao chép ID';

  @override
  String get accountCopiedId => 'Đã sao chép mã người dùng vào bộ nhớ tạm';

  @override
  String get accountBackToDashboard => 'Quay lại Bảng điều khiển';

  @override
  String get navGateways => 'Quản lý Gateway';

  @override
  String get gatewayListTitle => 'Quản lý Gateway';

  @override
  String get gatewayListSubtitle =>
      'Danh sách các trạm kết nối được phân quyền truy cập.';

  @override
  String get gatewayId => 'Mã trạm (Gateway ID)';

  @override
  String get gatewayName => 'Tên trạm';

  @override
  String get gatewayDescription => 'Mô tả';

  @override
  String get gatewayRole => 'Vai trò';

  @override
  String get gatewayCreatedAt => 'Ngày tạo';

  @override
  String get gatewaySearchPlaceholder =>
      'Tìm theo mã trạm, tên hoặc mô tả trong danh sách đã tải...';

  @override
  String gatewayLoadedCount(int count) {
    return 'Đang hiển thị $count trạm đã tải (không phải tổng số)';
  }

  @override
  String gatewayLoadedCountFiltered(int filtered, int count) {
    return 'Đang hiển thị $filtered trên $count trạm đã tải (không phải tổng số)';
  }

  @override
  String get gatewaySensorReadDeniedMessage =>
      'Bạn không có quyền truy cập danh sách Sensor của Gateway này.';

  @override
  String get actionRetry => 'Thử lại';

  @override
  String get gatewayEmptyTitle => 'Chưa có trạm Gateway nào';

  @override
  String get gatewayEmptyMessage =>
      'Tài khoản của bạn hiện chưa được phân quyền truy cập trạm Gateway nào.';

  @override
  String get gatewaySearchEmptyTitle => 'Không tìm thấy kết quả';

  @override
  String get gatewaySearchEmptyMessage =>
      'Không có trạm Gateway nào khớp với từ khóa tìm kiếm.';

  @override
  String get gatewayRoleOwner => 'Chủ sở hữu';

  @override
  String get gatewayRoleOperator => 'Vận hành';

  @override
  String get gatewayRoleViewer => 'Chỉ xem';

  @override
  String get gatewayActionDetail => 'Chi tiết';

  @override
  String get gatewayDetailTitle => 'Chi tiết Gateway';

  @override
  String get gatewayDetailSubtitle =>
      'Thông tin cấu hình trạm kết nối và danh sách cảm biến trực thuộc.';

  @override
  String get gatewayNotFoundTitle => 'Không tìm thấy Gateway';

  @override
  String get gatewayNotFoundMessage =>
      'Trạm kết nối không tồn tại hoặc tài khoản của bạn chưa được cấp quyền truy cập.';

  @override
  String get gatewayInvalidIdMessage =>
      'Mã trạm Gateway không đúng định dạng hoặc chứa định danh hệ thống dành riêng.';

  @override
  String get gatewayBackToList => 'Quay lại danh sách Gateway';

  @override
  String get gatewaySectionMetadata => 'Thông tin Gateway';

  @override
  String get gatewaySectionSensors => 'Danh sách Cảm biến';

  @override
  String get sensorId => 'Mã cảm biến (Sensor ID)';

  @override
  String get sensorName => 'Tên cảm biến';

  @override
  String get sensorUnit => 'Đơn vị đo';

  @override
  String get sensorCreatedAt => 'Ngày tạo';

  @override
  String get sensorEmptyTitle => 'Chưa có cảm biến nào';

  @override
  String get sensorEmptyMessage =>
      'Trạm Gateway này hiện chưa được cấu hình cảm biến nào.';

  @override
  String get sensorSearchPlaceholder =>
      'Tìm cảm biến theo mã, tên hoặc đơn vị...';

  @override
  String get sensorSearchEmptyTitle => 'Không tìm thấy cảm biến';

  @override
  String get sensorSearchEmptyMessage =>
      'Không có cảm biến nào khớp với từ khóa tìm kiếm.';

  @override
  String get sensorErrorTitle => 'Không thể tải danh sách cảm biến';

  @override
  String get sensorErrorRetry => 'Thử tải lại cảm biến';

  @override
  String get gatewayReadOnlyNotice =>
      'Chế độ chỉ đọc (Giai đoạn 2). Tính năng điều khiển từ xa, lệnh downlink và đo từ xa thời gian thực chưa được kích hoạt.';

  @override
  String get accountPermissionsTitle => 'Cơ chế phân quyền trạm & quản trị';

  @override
  String get accountPlatformAdminStatus =>
      'Quyền Quản trị viên nền tảng (Platform Admin)';

  @override
  String get accountPlatformAdminTrue => 'Quản trị viên nền tảng (Đã xác thực)';

  @override
  String get accountPlatformAdminFalse =>
      'Người dùng tiêu chuẩn (Không có quyền Admin)';

  @override
  String get accountPlatformAdminChecking => 'Đang kiểm tra quyền quản trị...';

  @override
  String get gatewayAddButton => 'Thêm Gateway mới';

  @override
  String get gatewayProvisionTitle => 'Khởi tạo Gateway';

  @override
  String get gatewayProvisionSubtitle =>
      'Khởi tạo trạm Gateway mới và gán người sở hữu ban đầu (Dành cho Quản trị viên nền tảng).';

  @override
  String get gatewayProvisionSuccessCreated =>
      'Khởi tạo Gateway thành công (HTTP 201 Created)';

  @override
  String get gatewayProvisionSuccessReplayed =>
      'Trạm Gateway đã tồn tại với thông tin trùng khớp (HTTP 200 OK - Lặp lại an toàn)';

  @override
  String get gatewayProvisionNoticeAdmin =>
      'Lưu ý phân quyền: Quản trị viên nền tảng không tự động là thành viên danh mục trạm (user_gateways) trừ khi được phân quyền sở hữu. Trạm này có thể không xuất hiện trong danh mục cá nhân của bạn nếu bạn không phải là người sở hữu được gán.';

  @override
  String get gatewayProvisionCreateAnother => 'Khởi tạo thêm Gateway khác';

  @override
  String get gatewayProvisionSubmit => 'Khởi tạo Gateway';

  @override
  String get gatewayProvisionSubmitting => 'Đang khởi tạo...';

  @override
  String get gatewayProvisionFieldId => 'Gateway ID';

  @override
  String get gatewayProvisionFieldIdHint =>
      'Mã định danh của Gateway, không được trùng với các Gateway khác';

  @override
  String get gatewayProvisionFieldName => 'Tên trạm Gateway';

  @override
  String get gatewayProvisionFieldNameHint => 'Tên hiển thị trạm';

  @override
  String get gatewayProvisionFieldDesc => 'Mô tả trạm (Không bắt buộc)';

  @override
  String get gatewayProvisionFieldDescHint => 'Mô tả vị trí, chức năng trạm';

  @override
  String get gatewayProvisionFieldOwner =>
      'Mã người dùng sở hữu (owner_user_id)';

  @override
  String get gatewayProvisionFieldOwnerHint =>
      'ID người dùng sẽ sở hữu Gateway trong hệ thống';

  @override
  String get gatewayProvisionEntityId => 'Mã thực thể Digital Twin (Entity ID)';

  @override
  String get gatewayProvisionOwnerId => 'Người dùng sở hữu ban đầu';

  @override
  String get gatewayProvisionCreatedAt => 'Thời gian tạo';

  @override
  String get gatewayProvisionAccessDeniedTitle => 'Từ chối truy cập';

  @override
  String get gatewayProvisionAccessDeniedMessage =>
      'Bạn không có quyền Quản trị viên nền tảng (Platform Admin) để thực hiện thao tác này.';

  @override
  String get gatewayProvisionRetrySamePayload => 'Thử lại (Retry)';

  @override
  String get gatewayProvisionConflictError =>
      'Trạm Gateway đã tồn tại với thông tin khác biệt (HTTP 409 Conflict). Cơ chế khởi tạo không hỗ trợ cập nhật thay đổi dữ liệu.';

  @override
  String get gatewayProvisionNotFoundError =>
      'Không tìm thấy người dùng sở hữu trong hệ thống (HTTP 404 Not Found). Vui lòng kiểm tra lại UUID.';

  @override
  String get sensorAddButton => 'Thêm cảm biến mới';

  @override
  String get sensorCreateDialogTitle => 'Khởi tạo Cảm biến mới';

  @override
  String get sensorCreateDialogSubtitle =>
      'Thêm cảm biến mới trực thuộc trạm Gateway này.';

  @override
  String get sensorParentGateway => 'ID Gateway';

  @override
  String get sensorFieldId => 'Mã cảm biến (Sensor ID)';

  @override
  String get sensorFieldIdHint =>
      'Mã định danh của cảm biến, không được trùng với các cảm biến khác trong Gateway này';

  @override
  String get sensorFieldName => 'Tên cảm biến';

  @override
  String get sensorFieldNameHint => 'Tên hiển thị cảm biến';

  @override
  String get sensorFieldUnit => 'Đơn vị đo (Tùy chọn)';

  @override
  String get sensorFieldUnitHint => 'ví dụ: °C, %, ppm';

  @override
  String get sensorCreateSubmit => 'Khởi tạo Cảm biến';

  @override
  String get sensorCreateSubmitting => 'Đang khởi tạo...';

  @override
  String get sensorCreateSuccessCreated =>
      'Đã khởi tạo cảm biến thành công (HTTP 201 Created)';

  @override
  String get sensorCreateSuccessReplayed =>
      'Cảm biến đã tồn tại với thông tin trùng khớp (HTTP 200 OK - Lặp lại an toàn)';

  @override
  String get sensorProvisionConflictError =>
      'Cảm biến đã tồn tại với thông tin khác biệt (HTTP 409 Conflict). Cơ chế khởi tạo không hỗ trợ cập nhật thay đổi dữ liệu.';

  @override
  String get sensorProvisionNotFoundError =>
      'Trạm Gateway cha không tồn tại (HTTP 404 Not Found).';

  @override
  String get sensorProvisionForbiddenError =>
      'Từ chối truy cập. Bạn không có quyền Quản trị viên nền tảng.';

  @override
  String get navAdminUsers => 'Quản lý Người dùng';

  @override
  String get adminUserListTitle => 'Quản lý Người dùng';

  @override
  String get adminUserListSubtitle =>
      'Danh sách tất cả người dùng và vai trò trong hệ thống (Dành cho Quản trị viên nền tảng).';

  @override
  String get adminUserCreateButton => 'Thêm Người dùng';

  @override
  String get adminUserSearchPlaceholder => 'Tìm theo tên, email hoặc UUID...';

  @override
  String get adminUserCapacityExceeded =>
      'Dung lượng danh sách người dùng vượt quá giới hạn hệ thống (HTTP 409 Conflict). Vui lòng liên hệ quản trị viên cơ sở dữ liệu.';

  @override
  String get adminUserEmptyTitle => 'Chưa có người dùng nào';

  @override
  String get adminUserEmptyMessage =>
      'Hệ thống chưa có người dùng nào được tạo.';

  @override
  String get adminUserSearchEmptyTitle => 'Không tìm thấy người dùng';

  @override
  String get adminUserSearchEmptyMessage =>
      'Không có người dùng nào khớp với từ khóa tìm kiếm.';

  @override
  String get adminUserFullName => 'Họ và tên';

  @override
  String get adminUserEmail => 'Email';

  @override
  String get adminUserRole => 'Vai trò';

  @override
  String get adminUserMembershipCount => 'Số gateway quản lý';

  @override
  String get adminUserCreatedAt => 'Ngày tạo';

  @override
  String get adminUserUnassignedName => 'Chưa cập nhật';

  @override
  String get adminUserRoleAdmin => 'Platform Admin';

  @override
  String get adminUserRoleUser => 'User';

  @override
  String get adminUserCreateTitle => 'Tạo tài khoản người dùng mới';

  @override
  String get adminUserCreateSubtitle =>
      'Khởi tạo tài khoản người dùng tập trung qua Go Backend và Supabase Auth.';

  @override
  String get adminUserCreateFieldFullName => 'Họ và tên';

  @override
  String get adminUserCreateFieldEmail => 'Địa chỉ email';

  @override
  String get adminUserCreateFieldPassword => 'Mật khẩu ban đầu';

  @override
  String get adminUserCreateSubmit => 'Tạo tài khoản';

  @override
  String get adminUserCreateSubmitting => 'Đang tạo...';

  @override
  String get adminUserCreateSuccess =>
      'Tạo tài khoản người dùng thành công (HTTP 201 Created)';

  @override
  String get adminUserCreateConflictError =>
      'Email này đã tồn tại trong hệ thống (HTTP 409 Conflict). Vui lòng sử dụng địa chỉ email khác.';

  @override
  String get adminUserCreateUnknownOutcomeTitle =>
      'Kết quả tạo tài khoản chưa xác định';

  @override
  String get adminUserCreateUnknownOutcomeMessage =>
      'Yêu cầu tạo tài khoản có thể đã được tiếp nhận và xử lý trên máy chủ nhưng phản hồi bị gián đoạn. Tuyệt đối không tự động thử lại để tránh tạo trùng lặp.';

  @override
  String get adminUserReconcileButton => 'Đối soát danh sách';

  @override
  String adminUserReconcileFound(String email) {
    return 'Tài khoản $email đã được xác nhận tạo thành công trong danh sách!';
  }

  @override
  String get adminUserReconcileNotFound =>
      'Đã đối soát: Tài khoản chưa xuất hiện trong danh sách. Bạn có thể kiểm tra lại thông tin và thử lại.';

  @override
  String get adminUserReconcileFailed =>
      'Không thể tải danh sách để đối soát. Tuyệt đối không tự ý thử lại.';

  @override
  String get adminUserEditButton => 'Chỉnh sửa';

  @override
  String get adminUserEditTitle => 'Chỉnh sửa Người dùng';

  @override
  String get adminUserEditSubtitle =>
      'Cập nhật họ tên hoặc vai trò nền tảng cho tài khoản.';

  @override
  String get adminUserSelfDemotionWarning =>
      'Bạn không thể tự hạ quyền Quản trị viên của chính mình.';

  @override
  String get adminUserRoleConfirmGrant =>
      'Tôi xác nhận cấp quyền Quản trị viên nền tảng (Platform Admin) cho tài khoản này.';

  @override
  String get adminUserRoleConfirmRevoke =>
      'Tôi xác nhận thu hồi quyền Quản trị viên nền tảng (chuyển về User) của tài khoản này.';

  @override
  String get adminUserEditNoChanges => 'Không có thay đổi nào để lưu.';

  @override
  String get adminUserEditSave => 'Lưu thay đổi';

  @override
  String get adminUserEditSaving => 'Đang lưu...';

  @override
  String get adminUserEditSuccess =>
      'Cập nhật người dùng thành công (HTTP 200 OK)';

  @override
  String get adminUserSelfDemotionForbidden =>
      'Bạn không thể tự hạ quyền Quản trị viên của chính mình (HTTP 409 Conflict). Toàn bộ thay đổi đã được hoàn tác.';

  @override
  String get adminAssignRoleTitle => 'Gán vai trò thành viên Gateway';

  @override
  String get adminAssignRoleSubtitle =>
      'Phân quyền vận hành (Operator) hoặc chỉ xem (Viewer) cho tài khoản trên trạm.';

  @override
  String get adminAssignRoleButton => 'Phân quyền';

  @override
  String get adminAssignRoleSubmit => 'Lưu phân quyền';

  @override
  String get adminAssignRoleSubmitting => 'Đang lưu...';

  @override
  String get adminAssignRoleOperator => 'Vận hành (Operator)';

  @override
  String get adminAssignRoleViewer => 'Chỉ xem (Viewer)';

  @override
  String get adminAssignRoleOwnerHint =>
      'Để thay vai trò của chủ sở hữu, bạn hãy dùng tính năng chuyển quyền sở hữu.';

  @override
  String get adminAssignRoleOwnerConflict =>
      'Người dùng này hiện là chủ sở hữu của trạm. Để thay đổi vai trò của chủ sở hữu, vui lòng dùng chức năng Chuyển giao quyền sở hữu.';

  @override
  String get adminAssignRoleSuccess =>
      'Phân quyền thành viên trạm thành công (HTTP 200 OK)';

  @override
  String get adminTransferOwnerTitle => 'Chuyển giao quyền sở hữu Gateway';

  @override
  String get adminTransferOwnerSubtitle =>
      'Chuyển giao quyền chủ sở hữu (Owner) của trạm sang một người dùng khác.';

  @override
  String get adminTransferOwnerButton => 'Chuyển quyền sở hữu';

  @override
  String get adminTransferOwnerCurrentOwner => 'Chủ sở hữu hiện tại';

  @override
  String get adminTransferOwnerNewOwner => 'Chủ sở hữu mới (Người nhận)';

  @override
  String get adminTransferOwnerConfirm =>
      'Tôi xác nhận chuyển giao quyền sở hữu trạm cho người dùng này. Chủ sở hữu cũ sẽ chuyển thành Người xem (Viewer) và vẫn giữ quyền đọc trạm.';

  @override
  String adminTransferOwnerReplayNotice(Object id) {
    return 'Lưu ý: Sau khi chuyển quyền sở hữu, các yêu cầu khởi tạo trạm (PUT /v1/admin/gateways/$id) được lặp lại với mã người sở hữu cũ sẽ bị từ chối với mã 409 Conflict.';
  }

  @override
  String get adminTransferOwnerSubmit => 'Xác nhận chuyển giao';

  @override
  String get adminTransferOwnerSubmitting => 'Đang chuyển giao...';

  @override
  String get adminTransferOwnerSuccess =>
      'Chuyển giao quyền sở hữu Gateway thành công (HTTP 200 OK)';

  @override
  String get adminTransferOwnerInconsistentError =>
      'Dữ liệu chủ sở hữu trạm trên máy chủ không đồng nhất (HTTP 409 Conflict).';

  @override
  String get adminTransferOwnerZeroOwners =>
      'Không tìm thấy chủ sở hữu hiện tại trong danh sách. Không thể thực hiện chuyển giao.';

  @override
  String get adminTransferOwnerMultipleOwners =>
      'Tìm thấy nhiều hơn một chủ sở hữu trên trạm này. Dữ liệu không đồng nhất, không thể chuyển giao.';
}
