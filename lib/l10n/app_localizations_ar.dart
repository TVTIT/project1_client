// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class LAr extends L {
  LAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'SANSLAB IoT Server';

  @override
  String get navOverview => 'نظرة عامة';

  @override
  String get navManage => 'الإدارة';

  @override
  String get navApps => 'التطبيقات';

  @override
  String get navBuild => 'البناء';

  @override
  String get navDashboard => 'لوحة التحكم';

  @override
  String get navProjects => 'المشاريع';

  @override
  String get navOrders => 'الطلبات';

  @override
  String get navCustomers => 'العملاء';

  @override
  String get navProducts => 'المنتجات';

  @override
  String get navInbox => 'البريد';

  @override
  String get navBoard => 'اللوحة';

  @override
  String get navCalendar => 'التقويم';

  @override
  String get navChat => 'المحادثة';

  @override
  String get navComponents => 'المكوّنات';

  @override
  String get navForms => 'النماذج';

  @override
  String get navWizard => 'المعالج';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionRefresh => 'تحديث';

  @override
  String get actionExport => 'تصدير';

  @override
  String get actionSearch => 'بحث';

  @override
  String get actionClear => 'مسح';

  @override
  String get actionPrevious => 'السابق';

  @override
  String get actionNext => 'التالي';

  @override
  String get actionSignIn => 'تسجيل الدخول';

  @override
  String get actionSignOut => 'تسجيل الخروج';

  @override
  String get signInTitle => 'تسجيل الدخول';

  @override
  String get signInSubtitle => 'أي بريد إلكتروني يعمل — هذا مزوّد تجريبي.';

  @override
  String get fieldEmail => 'البريد الإلكتروني';

  @override
  String get fieldPassword => 'كلمة المرور';

  @override
  String get fieldName => 'الاسم';

  @override
  String get forgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get noAccount => 'ليس لديك حساب؟ أنشئ واحدًا';

  @override
  String get lightMode => 'الوضع الفاتح';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'المظهر';

  @override
  String get accent => 'اللون';

  @override
  String get emptyTitle => 'لا شيء يطابق عوامل التصفية';

  @override
  String get emptyMessage => 'جرّب مسح البحث أو اختيار حالة مختلفة.';

  @override
  String get errorTitle => 'حدث خطأ ما';

  @override
  String get errorRetry => 'إعادة المحاولة';

  @override
  String pageOf(int page, int pages) {
    return 'صفحة $page من $pages';
  }

  @override
  String rangeOfTotal(int first, int last, int total) {
    return '$first–$last من $total';
  }

  @override
  String get accountInfo => 'معلومات الحساب';

  @override
  String get accountSubtitle =>
      'عرض تفاصيل الهوية والجلسة الحالية لهذا الحساب.';

  @override
  String get accountIdentityTitle => 'معلومات الهوية';

  @override
  String get accountUserId => 'معرف المستخدم (UUID)';

  @override
  String get accountEmail => 'البريد الإلكتروني';

  @override
  String get accountFullName => 'الاسم الكامل';

  @override
  String get accountRole => 'دور البوابة';

  @override
  String get accountRoleUnassigned => 'لم يتم تعيين دور';

  @override
  String get accountRoleNote =>
      'يتم التحقق من الصلاحيات ديناميكيًا لكل بوابة في الخادم الخلفي.';

  @override
  String get accountSessionTitle => 'الجلسة والأمان';

  @override
  String get accountSessionStatus => 'حالة الجلسة';

  @override
  String get accountStatusActive => 'نشط';

  @override
  String get accountAuthMethod => 'طريقة المصادقة';

  @override
  String get accountAuthMethodValue => 'Supabase Auth (GoTrue) · Local HS256';

  @override
  String get accountAdminNoteTitle => 'سياسة إدارة الحسابات';

  @override
  String get accountAdminNote =>
      'تتم إدارة الحسابات مركزيًا بواسطة مديري النظام.';

  @override
  String get accountCopyId => 'نسخ المعرف';

  @override
  String get accountCopiedId => 'تم نسخ معرف المستخدم';

  @override
  String get accountBackToDashboard => 'العودة إلى لوحة التحكم';

  @override
  String get navGateways => 'البوابات';

  @override
  String get gatewayListTitle => 'البوابات';

  @override
  String get gatewayListSubtitle => 'قائمة البوابات المتاحة في المنصة.';

  @override
  String get gatewayId => 'معرف البوابة';

  @override
  String get gatewayName => 'الاسم';

  @override
  String get gatewayDescription => 'الوصف';

  @override
  String get gatewayRole => 'الدور';

  @override
  String get gatewayCreatedAt => 'تاريخ الإنشاء';

  @override
  String get gatewaySearchPlaceholder => 'البحث بالمعرف أو الاسم...';

  @override
  String get gatewayEmptyTitle => 'لا توجد بوابات';

  @override
  String get gatewayEmptyMessage => 'لم يتم تعيين أي بوابات لحسابك بعد.';

  @override
  String get gatewaySearchEmptyTitle => 'لا توجد نتائج مطابقة';

  @override
  String get gatewaySearchEmptyMessage => 'لا توجد بوابات تطابق بحثك.';

  @override
  String get gatewayRoleOwner => 'مالك';

  @override
  String get gatewayRoleOperator => 'مشغل';

  @override
  String get gatewayRoleViewer => 'مشاهد';

  @override
  String get gatewayActionDetail => 'تفاصيل';

  @override
  String get gatewayDetailTitle => 'تفاصيل البوابة';

  @override
  String get gatewayDetailSubtitle =>
      'نظرة عامة على تكوين المحطة وأجهزة الاستشعار المرتبطة بها.';

  @override
  String get gatewayNotFoundTitle => 'لم يتم العثور على البوابة';

  @override
  String get gatewayNotFoundMessage =>
      'لم يتم العثور على البوابة المطلوبة أو ليس لديك إذن بالوصول.';

  @override
  String get gatewayInvalidIdMessage => 'معرف البوابة غير صالح أو محجوز.';

  @override
  String get gatewayBackToList => 'العودة إلى البوابات';

  @override
  String get gatewaySectionMetadata => 'معلومات البوابة';

  @override
  String get gatewaySectionSensors => 'كتالوج أجهزة الاستشعار';

  @override
  String get sensorId => 'معرف الحساس';

  @override
  String get sensorName => 'اسم الحساس';

  @override
  String get sensorUnit => 'الوحدة';

  @override
  String get sensorCreatedAt => 'تاريخ الإنشاء';

  @override
  String get sensorEmptyTitle => 'لا توجد أجهزة استشعار';

  @override
  String get sensorEmptyMessage =>
      'لم تتم إضافة أي أجهزة استشعار إلى هذه المحطة بعد.';

  @override
  String get sensorSearchPlaceholder => 'البحث بالمعرف أو الاسم أو الوحدة...';

  @override
  String get sensorSearchEmptyTitle => 'لا توجد نتائج مطابقة';

  @override
  String get sensorSearchEmptyMessage => 'لا توجد أجهزة استشعار تطابق بحثك.';

  @override
  String get sensorErrorTitle => 'فشل تحميل أجهزة الاستشعار';

  @override
  String get sensorErrorRetry => 'إعادة المحاولة';

  @override
  String get gatewayReadOnlyNotice =>
      'وضع القراءة فقط (المرحلة 2). التحكم عن بعد غير مفعل.';
}
