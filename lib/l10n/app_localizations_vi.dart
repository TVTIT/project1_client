// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class LVi extends L {
  LVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'Kite';

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
}
