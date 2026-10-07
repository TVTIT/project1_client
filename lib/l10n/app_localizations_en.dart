// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'SANSLAB IoT Server';

  @override
  String get navOverview => 'Overview';

  @override
  String get navManage => 'Manage';

  @override
  String get navApps => 'Apps';

  @override
  String get navBuild => 'Build';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navProjects => 'Projects';

  @override
  String get navOrders => 'Orders';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navProducts => 'Products';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navBoard => 'Board';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navChat => 'Chat';

  @override
  String get navComponents => 'Components';

  @override
  String get navForms => 'Forms';

  @override
  String get navWizard => 'Wizard';

  @override
  String get navSettings => 'Settings';

  @override
  String get navProfile => 'Profile';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionExport => 'Export';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionPrevious => 'Previous';

  @override
  String get actionNext => 'Next';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubtitle => 'Any email works — this is the mock provider.';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldName => 'Name';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get noAccount => 'No account? Create one';

  @override
  String get lightMode => 'Light mode';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get accent => 'Accent';

  @override
  String get emptyTitle => 'Nothing matches those filters';

  @override
  String get emptyMessage =>
      'Try clearing the search or choosing a different status.';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get errorRetry => 'Try again';

  @override
  String pageOf(int page, int pages) {
    return 'Page $page of $pages';
  }

  @override
  String rangeOfTotal(int first, int last, int total) {
    return '$first–$last of $total';
  }

  @override
  String get accountInfo => 'Account Information';

  @override
  String get accountSubtitle =>
      'View identity and active session details for this account.';

  @override
  String get accountIdentityTitle => 'Identity Information';

  @override
  String get accountUserId => 'User ID (UUID)';

  @override
  String get accountEmail => 'Account Email';

  @override
  String get accountFullName => 'Full Name';

  @override
  String get accountRole => 'Gateway Role';

  @override
  String get accountRoleUnassigned => 'No gateway role assigned';

  @override
  String get accountRoleNote =>
      'Gateway permissions (owner, operator, viewer) and Platform Admin privileges are evaluated dynamically per request on Go Backend. Identity session does not assert or infer permissions.';

  @override
  String get accountSessionTitle => 'Session & Security';

  @override
  String get accountSessionStatus => 'Session Status';

  @override
  String get accountStatusActive => 'Active';

  @override
  String get accountAuthMethod => 'Authentication Method';

  @override
  String get accountAuthMethodValue =>
      'Supabase Auth (GoTrue) · Local HS256 JWT Verification on Go Backend';

  @override
  String get accountAdminNoteTitle => 'Account Management Policy';

  @override
  String get accountAdminNote =>
      'Accounts are managed centrally by Platform Administrators. Direct self-modification from client UI is disabled. Platform Admin privileges are maintained separately in public.platform_admins.';

  @override
  String get accountCopyId => 'Copy ID';

  @override
  String get accountCopiedId => 'Copied User ID to clipboard';

  @override
  String get accountBackToDashboard => 'Back to Dashboard';

  @override
  String get navGateways => 'Gateways';

  @override
  String get gatewayListTitle => 'Gateways';

  @override
  String get gatewayListSubtitle =>
      'List of accessible gateway devices in the platform.';

  @override
  String get gatewayId => 'Gateway ID';

  @override
  String get gatewayName => 'Name';

  @override
  String get gatewayDescription => 'Description';

  @override
  String get gatewayRole => 'Role';

  @override
  String get gatewayCreatedAt => 'Created At';

  @override
  String get gatewaySearchPlaceholder => 'Search by ID, name or description...';

  @override
  String get gatewayEmptyTitle => 'No gateways found';

  @override
  String get gatewayEmptyMessage =>
      'Your account has not been assigned access to any gateways yet.';

  @override
  String get gatewaySearchEmptyTitle => 'No matching gateways';

  @override
  String get gatewaySearchEmptyMessage =>
      'No gateways match your search query.';

  @override
  String get gatewayRoleOwner => 'Owner';

  @override
  String get gatewayRoleOperator => 'Operator';

  @override
  String get gatewayRoleViewer => 'Viewer';

  @override
  String get gatewayActionDetail => 'Details';

  @override
  String get gatewayDetailTitle => 'Gateway Details';

  @override
  String get gatewayDetailSubtitle =>
      'Overview of station configuration and associated sensors.';

  @override
  String get gatewayNotFoundTitle => 'Gateway not found';

  @override
  String get gatewayNotFoundMessage =>
      'The requested gateway was not found or your account does not have access permission.';

  @override
  String get gatewayInvalidIdMessage =>
      'Invalid gateway identifier or reserved identifier.';

  @override
  String get gatewayBackToList => 'Back to Gateways';

  @override
  String get gatewaySectionMetadata => 'Gateway Information';

  @override
  String get gatewaySectionSensors => 'Sensor Catalog';

  @override
  String get sensorId => 'Sensor ID';

  @override
  String get sensorName => 'Sensor Name';

  @override
  String get sensorUnit => 'Unit';

  @override
  String get sensorCreatedAt => 'Created At';

  @override
  String get sensorEmptyTitle => 'No sensors configured';

  @override
  String get sensorEmptyMessage =>
      'No sensors have been added to this gateway station yet.';

  @override
  String get sensorSearchPlaceholder => 'Search sensors by ID, name or unit...';

  @override
  String get sensorSearchEmptyTitle => 'No matching sensors';

  @override
  String get sensorSearchEmptyMessage => 'No sensors match your search query.';

  @override
  String get sensorErrorTitle => 'Failed to load sensors';

  @override
  String get sensorErrorRetry => 'Retry loading sensors';

  @override
  String get gatewayReadOnlyNotice =>
      'Read-only mode (Stage 2). Remote control, downlink commands, and real-time telemetry streaming are not active.';
}
