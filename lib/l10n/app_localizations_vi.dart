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
  String get accountUserId => 'Mã định danh người dùng (UUID)';

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
  String get gatewaySearchPlaceholder => 'Tìm theo mã trạm, tên hoặc mô tả...';

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
}
