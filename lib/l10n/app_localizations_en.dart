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

  @override
  String get accountPermissionsTitle => 'Cơ chế phân quyền trạm & quản trị';

  @override
  String get accountPlatformAdminStatus => 'Platform Admin Status';

  @override
  String get accountPlatformAdminTrue => 'Platform Admin (Confirmed)';

  @override
  String get accountPlatformAdminFalse => 'Standard User (No Admin privileges)';

  @override
  String get accountPlatformAdminChecking => 'Checking admin permissions...';

  @override
  String get gatewayAddButton => 'Thêm Gateway mới';

  @override
  String get gatewayProvisionTitle => 'Provision Gateway';

  @override
  String get gatewayProvisionSubtitle =>
      'Provision a new Gateway station and assign initial owner (Platform Admin only).';

  @override
  String get gatewayProvisionSuccessCreated =>
      'Gateway provisioned successfully (HTTP 201 Created)';

  @override
  String get gatewayProvisionSuccessReplayed =>
      'Gateway already exists with identical payload (HTTP 200 OK - Idempotent Replay)';

  @override
  String get gatewayProvisionNoticeAdmin =>
      'Authorization notice: Platform Admin accounts are not automatically catalog members (user_gateways) unless assigned ownership. This gateway may not appear in your personal catalog unless you are the assigned owner.';

  @override
  String get gatewayProvisionCreateAnother => 'Provision another Gateway';

  @override
  String get gatewayProvisionSubmit => 'Provision Gateway';

  @override
  String get gatewayProvisionSubmitting => 'Provisioning...';

  @override
  String get gatewayProvisionFieldId => 'Gateway ID';

  @override
  String get gatewayProvisionFieldIdHint =>
      '1–64 ASCII chars [A-Za-z0-9_-], backend_service forbidden';

  @override
  String get gatewayProvisionFieldName => 'Gateway Name';

  @override
  String get gatewayProvisionFieldNameHint =>
      'Gateway display name (max 256 UTF-8 bytes)';

  @override
  String get gatewayProvisionFieldDesc => 'Description (Optional)';

  @override
  String get gatewayProvisionFieldDescHint =>
      'Location or function description (max 4096 UTF-8 bytes)';

  @override
  String get gatewayProvisionFieldOwner => 'Owner User ID (owner_user_id)';

  @override
  String get gatewayProvisionFieldOwnerHint =>
      'UUID of the owner user in the system (no nil UUID)';

  @override
  String get gatewayProvisionEntityId => 'Digital Twin Entity ID';

  @override
  String get gatewayProvisionOwnerId => 'Initial Owner User ID';

  @override
  String get gatewayProvisionCreatedAt => 'Created At';

  @override
  String get gatewayProvisionAccessDeniedTitle => 'Access Denied';

  @override
  String get gatewayProvisionAccessDeniedMessage =>
      'You do not have Platform Admin privileges to perform this action.';

  @override
  String get gatewayProvisionRetrySamePayload => 'Retry with same payload';

  @override
  String get gatewayProvisionConflictError =>
      'Gateway already exists with different payload (HTTP 409 Conflict). Provisioning endpoint does not support updating existing metadata.';

  @override
  String get gatewayProvisionNotFoundError =>
      'Owner user ID not found in system (HTTP 404 Not Found). Please verify UUID.';

  @override
  String get sensorAddButton => 'Thêm cảm biến mới';

  @override
  String get sensorCreateDialogTitle => 'Create New Sensor';

  @override
  String get sensorCreateDialogSubtitle =>
      'Add a new sensor associated with this Gateway station (Platform Admin only).';

  @override
  String get sensorParentGateway => 'Parent Gateway ID (Fixed, read-only)';

  @override
  String get sensorFieldId => 'Sensor ID';

  @override
  String get sensorFieldIdHint =>
      '1–64 ASCII chars [A-Za-z0-9_-], backend_service allowed';

  @override
  String get sensorFieldName => 'Sensor Name';

  @override
  String get sensorFieldNameHint => 'Sensor display name (max 256 UTF-8 bytes)';

  @override
  String get sensorFieldUnit => 'Measurement Unit (Optional)';

  @override
  String get sensorFieldUnitHint => 'e.g. °C, %, ppm (max 64 UTF-8 bytes)';

  @override
  String get sensorCreateSubmit => 'Create Sensor';

  @override
  String get sensorCreateSubmitting => 'Creating...';

  @override
  String get sensorCreateSuccessCreated =>
      'Sensor created successfully (HTTP 201 Created)';

  @override
  String get sensorCreateSuccessReplayed =>
      'Sensor already exists with identical payload (HTTP 200 OK - Idempotent Replay)';

  @override
  String get sensorProvisionConflictError =>
      'Sensor already exists with different payload (HTTP 409 Conflict). Provisioning endpoint does not support updating existing metadata.';

  @override
  String get sensorProvisionNotFoundError =>
      'Parent Gateway not found (HTTP 404 Not Found).';

  @override
  String get sensorProvisionForbiddenError =>
      'Access denied. You do not have Platform Admin privileges.';
}
