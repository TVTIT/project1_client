// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get twinEditInvalidText => 'Text contains an invalid character.';

  @override
  String get twinEditFailed =>
      'Unable to update metadata. Check your permissions and input.';

  @override
  String get twinEditReconcileUnavailable =>
      'Cannot verify this update. Resubmission remains blocked.';

  @override
  String get temporalRawRange =>
      'Raw history is limited to 10 seconds. Narrow the range or use aggregation.';

  @override
  String get temporalFailed =>
      'Unable to load history. Previously displayed data may be stale.';

  @override
  String get temporalShowing => 'Showing';

  @override
  String get temporalPresets => 'Presets:';

  @override
  String get navDigitalTwins => 'Digital Twins';

  @override
  String get twinInformation => 'Information';

  @override
  String get twinState => 'State';

  @override
  String get twinBackToList => 'Back to Digital Twins';

  @override
  String get twinNotFound => 'Entity not found or access unavailable.';

  @override
  String get twinNoData => 'No data';

  @override
  String get twinStale => 'Unable to refresh. Displayed data may be stale.';

  @override
  String get twinDescription => 'Description';

  @override
  String get twinMeasurement => 'Latest measurement';

  @override
  String get twinUnit => 'Unit';

  @override
  String get twinObservedAt => 'Observed (UTC)';

  @override
  String get twinRelationships => 'Sensors';

  @override
  String get twinRelationshipCapacity =>
      'Relationship limit reached (400 Sensors).';

  @override
  String get twinReadOnly =>
      'Read-only backend state. No device commands are sent.';

  @override
  String get twinVersion => 'Version';

  @override
  String get twinReportedAt => 'Last reported (UTC)';

  @override
  String get twinDesiredAt => 'Last desired (UTC)';

  @override
  String get twinTypeFilter => 'Entity type';

  @override
  String get twinGatewayFilter => 'Assigned Gateway';

  @override
  String get twinAll => 'All';

  @override
  String get twinName => 'Name';

  @override
  String get twinType => 'Type';

  @override
  String get twinModifiedAt => 'Modified (UTC)';

  @override
  String get twinEmpty => 'No assigned Digital Twins match these filters.';

  @override
  String get twinLoadMore => 'Load next page';

  @override
  String get twinCapacity =>
      'Showing up to 1000 entities (20 pages). Narrow the filters to continue.';

  @override
  String get twinLoadError =>
      'Unable to load Digital Twins. Refresh or retry the page.';

  @override
  String get twinGatewayError => 'Unable to load assigned Gateways.';

  @override
  String get twinOpen => 'Open Digital Twin';

  @override
  String get twinHistory => 'History';

  @override
  String get twinEditMetadata => 'Edit metadata';

  @override
  String get twinEditMetadataTitle => 'Edit metadata';

  @override
  String get twinEditMetadataNotice =>
      'Metadata is updated in the server database (this does not execute commands on hardware devices).';

  @override
  String get twinEditNameLabel => 'Name';

  @override
  String get twinEditDescriptionLabel => 'Description';

  @override
  String get twinEditClearDescription => 'Clear description (set to null)';

  @override
  String get twinEditNoChanges => 'No fields have been changed.';

  @override
  String get twinEditNameRequired => 'Name is required and cannot be blank.';

  @override
  String get twinEditNameTooLong => 'Name must not exceed 256 UTF-8 bytes.';

  @override
  String get twinEditDescriptionTooLong =>
      'Description must not exceed 512 UTF-8 bytes (server HTTP parser limit).';

  @override
  String get twinEditUnknownOutcomeNotice =>
      'Update request timed out or server unavailable (503). Outcome is unknown. Automatic resubmit is blocked to avoid conflicts. Please reconcile metadata.';

  @override
  String get twinEditReconcileAction => 'Reconcile metadata';

  @override
  String get twinEditReconciling => 'Checking server status...';

  @override
  String get twinEditReconcileConfirmed =>
      'Reconciliation confirmed: Metadata was successfully updated on server.';

  @override
  String get twinEditReconcileMismatch =>
      'Reconciliation mismatch: Current server values differ from requested changes.';

  @override
  String get twinEditReconcileCannotVerify =>
      'Cannot verify status because read access is not available (404).';

  @override
  String get twinEditSuccess =>
      'Metadata updated successfully in server database.';

  @override
  String get actionEditMetadata => 'Edit metadata';

  @override
  String get twinUrn => 'URN';

  @override
  String get twinGatewayId => 'Gateway ID';

  @override
  String get twinSensorId => 'Sensor ID';

  @override
  String get twinHostedBy => 'Hosted by Gateway';

  @override
  String twinLoadedCount(int count) {
    return 'Showing $count loaded entities (not total)';
  }

  @override
  String get temporalHistoryTitle => 'Telemetry History';

  @override
  String get temporalMode => 'Mode';

  @override
  String get temporalModeRaw => 'Raw (max 10s)';

  @override
  String get temporalModeAggregated => 'Aggregated';

  @override
  String get temporalDuration => 'Duration';

  @override
  String get temporalAttribute => 'Attribute';

  @override
  String get temporalAttrMeasurement => 'Measurement';

  @override
  String get temporalAttrSampleInterval => 'Sample Interval (µs)';

  @override
  String get temporalStartTime => 'Start';

  @override
  String get temporalEndTime => 'End';

  @override
  String get temporalPickDateTime => 'Pick date and time';

  @override
  String get temporalApply => 'Apply';

  @override
  String get temporalPreset10s => '10s (Raw)';

  @override
  String get temporalPreset15m => '15m';

  @override
  String get temporalPreset1h => '1h';

  @override
  String get temporalPreset24h => '24h';

  @override
  String get temporalPreset7d => '7d';

  @override
  String get temporalPreset30d => '30d';

  @override
  String get temporalStatsMin => 'Min';

  @override
  String get temporalStatsMax => 'Max';

  @override
  String get temporalStatsAvg => 'Weighted Mean';

  @override
  String get temporalStatsRawAvg => 'Average';

  @override
  String get temporalStatsCount => 'Total Samples';

  @override
  String get temporalNoData =>
      'No temporal telemetry data for this time range.';

  @override
  String get temporalStaleWarning =>
      'Unable to refresh. Displayed temporal history may be stale.';

  @override
  String get temporalInspectTable => 'Detailed Data Inspection';

  @override
  String get temporalTimestamp => 'Timestamp';

  @override
  String get temporalValue => 'Value';

  @override
  String get temporalSamples => 'Samples';

  @override
  String get temporalMaxPoints => 'Max Points';

  @override
  String get temporalGuidanceRawLimit =>
      'Raw telemetry points exceeded capacity. Please narrow the time range or select aggregated mode.';

  @override
  String get temporalGuidanceResolution =>
      'Resolution is too fine for this range. Please select a coarser aggregation duration.';

  @override
  String get temporalGuidanceRange =>
      'Query range exceeds maximum limit of 31 days (744 hours).';

  @override
  String get temporalGuidanceInvalidDate =>
      'Invalid calendar date or format. Please verify year, month, and day.';

  @override
  String get gatewayTabTelemetryHistory => 'Telemetry history';

  @override
  String get gatewayTabSensors => 'Sensor catalog';

  @override
  String get gatewaySelectSensor => 'Sensor:';

  @override
  String get gatewayNoSensorsForHistory =>
      'No sensors available to display telemetry history.';

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
  String get signInSubtitle => 'Type your email and password to continue';

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
  String get accountUserId => 'User ID';

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
  String get gatewaySearchPlaceholder =>
      'Search loaded gateways by ID, name or description...';

  @override
  String gatewayLoadedCount(int count) {
    return 'Showing $count loaded gateways (not total)';
  }

  @override
  String gatewayLoadedCountFiltered(int filtered, int count) {
    return 'Showing $filtered of $count loaded gateways (not total)';
  }

  @override
  String get gatewaySensorReadDeniedMessage =>
      'You do not have permission to access the Sensor list for this Gateway.';

  @override
  String get actionRetry => 'Retry';

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
      'Gateway\'s identification, must not be a duplicate of other gateways';

  @override
  String get gatewayProvisionFieldName => 'Gateway Name';

  @override
  String get gatewayProvisionFieldNameHint => 'Gateway display name';

  @override
  String get gatewayProvisionFieldDesc => 'Description (Optional)';

  @override
  String get gatewayProvisionFieldDescHint =>
      'Location or function description';

  @override
  String get gatewayProvisionFieldOwner => 'Owner User ID (owner_user_id)';

  @override
  String get gatewayProvisionFieldOwnerHint =>
      'UUID of the owner user in the system';

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
      'Add a new sensor associated with this Gateway station';

  @override
  String get sensorParentGateway => 'Parent Gateway ID';

  @override
  String get sensorFieldId => 'Sensor ID';

  @override
  String get sensorFieldIdHint =>
      'Sensor\'s identification, must not be a duplicate of other sensors inside this Gateway';

  @override
  String get sensorFieldName => 'Sensor Name';

  @override
  String get sensorFieldNameHint => 'Sensor display name';

  @override
  String get sensorFieldUnit => 'Measurement Unit (Optional)';

  @override
  String get sensorFieldUnitHint => 'e.g. °C, %, ppm';

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

  @override
  String get navAdminUsers => 'User Management';

  @override
  String get adminUserListTitle => 'User Management';

  @override
  String get adminUserListSubtitle =>
      'All users and roles across the system (Platform Admin only).';

  @override
  String get adminUserCreateButton => 'Add User';

  @override
  String get adminUserSearchPlaceholder => 'Search by name, email or UUID...';

  @override
  String get adminUserCapacityExceeded =>
      'User list capacity exceeded limit (HTTP 409 Conflict). Please contact the database administrator.';

  @override
  String get adminUserEmptyTitle => 'No users found';

  @override
  String get adminUserEmptyMessage =>
      'No users have been created in the system.';

  @override
  String get adminUserSearchEmptyTitle => 'No matching users';

  @override
  String get adminUserSearchEmptyMessage => 'No users match your search term.';

  @override
  String get adminUserFullName => 'Full Name';

  @override
  String get adminUserEmail => 'Email';

  @override
  String get adminUserRole => 'Platform Role';

  @override
  String get adminUserMembershipCount => 'Gateways';

  @override
  String get adminUserCreatedAt => 'Created At';

  @override
  String get adminUserUnassignedName => 'Not set';

  @override
  String get adminUserRoleAdmin => 'Platform Admin';

  @override
  String get adminUserRoleUser => 'User';

  @override
  String get adminUserCreateTitle => 'Create New User Account';

  @override
  String get adminUserCreateSubtitle =>
      'Provision a user account centrally via Go Backend and Supabase Auth.';

  @override
  String get adminUserCreateFieldFullName => 'Full Name';

  @override
  String get adminUserCreateFieldEmail => 'Email Address';

  @override
  String get adminUserCreateFieldPassword => 'Initial Password';

  @override
  String get adminUserCreateSubmit => 'Create Account';

  @override
  String get adminUserCreateSubmitting => 'Creating...';

  @override
  String get adminUserCreateSuccess =>
      'User account created successfully (HTTP 201 Created)';

  @override
  String get adminUserCreateConflictError =>
      'This email already exists (HTTP 409 Conflict). Please use another email.';

  @override
  String get adminUserCreateUnknownOutcomeTitle =>
      'Uncertain Account Creation Result';

  @override
  String get adminUserCreateUnknownOutcomeMessage =>
      'Request may have completed on the server, but the response was interrupted. Do not blind retry. Please reconcile the user list.';

  @override
  String get adminUserReconcileButton => 'Reconcile List';

  @override
  String adminUserReconcileFound(String email) {
    return 'Account $email confirmed created in user list!';
  }

  @override
  String get adminUserReconcileNotFound =>
      'Reconciled: Account not found in list yet. You may verify and retry.';

  @override
  String get adminUserReconcileFailed =>
      'Unable to reconcile list. Please check later.';

  @override
  String get adminUserEditButton => 'Edit';

  @override
  String get adminUserEditTitle => 'Edit User';

  @override
  String get adminUserEditSubtitle =>
      'Update full name or platform role for this account.';

  @override
  String get adminUserSelfDemotionWarning =>
      'You cannot demote your own Platform Admin role.';

  @override
  String get adminUserRoleConfirmGrant =>
      'I confirm granting Platform Admin role to this account.';

  @override
  String get adminUserRoleConfirmRevoke =>
      'I confirm revoking Platform Admin role from this account.';

  @override
  String get adminUserEditNoChanges => 'No changes to save.';

  @override
  String get adminUserEditSave => 'Save Changes';

  @override
  String get adminUserEditSaving => 'Saving...';

  @override
  String get adminUserEditSuccess => 'User updated successfully (HTTP 200 OK)';

  @override
  String get adminUserSelfDemotionForbidden =>
      'Self admin demotion forbidden (HTTP 409 Conflict). Changes have been rolled back.';

  @override
  String get adminAssignRoleTitle => 'Assign Gateway Membership Role';

  @override
  String get adminAssignRoleSubtitle =>
      'Assign operator or viewer role on this gateway to a user.';

  @override
  String get adminAssignRoleButton => 'Assign Role';

  @override
  String get adminAssignRoleSubmit => 'Save Membership';

  @override
  String get adminAssignRoleSubmitting => 'Saving...';

  @override
  String get adminAssignRoleOperator => 'Operator';

  @override
  String get adminAssignRoleViewer => 'Viewer';

  @override
  String get adminAssignRoleOwnerHint =>
      'To change the owner\'s role, please use the ownership transfer feature.';

  @override
  String get adminAssignRoleOwnerConflict =>
      'This user is currently the owner of the gateway. To change an owner\'s role, please use Transfer Ownership.';

  @override
  String get adminAssignRoleSuccess =>
      'Gateway membership role assigned successfully (HTTP 200 OK)';

  @override
  String get adminTransferOwnerTitle => 'Transfer Gateway Ownership';

  @override
  String get adminTransferOwnerSubtitle =>
      'Transfer the owner role of this gateway to another user.';

  @override
  String get adminTransferOwnerButton => 'Transfer Ownership';

  @override
  String get adminTransferOwnerCurrentOwner => 'Current Owner';

  @override
  String get adminTransferOwnerNewOwner => 'New Owner (Recipient)';

  @override
  String get adminTransferOwnerConfirm =>
      'I confirm transferring gateway ownership to this user. The previous owner will become a Viewer and retain read access.';

  @override
  String adminTransferOwnerReplayNotice(Object id) {
    return 'Notice: After transferring ownership, replaying initial gateway provisioning (PUT /v1/admin/gateways/$id) with the previous owner ID will conflict with 409 Conflict.';
  }

  @override
  String get adminTransferOwnerSubmit => 'Confirm Transfer';

  @override
  String get adminTransferOwnerSubmitting => 'Transferring...';

  @override
  String get adminTransferOwnerSuccess =>
      'Gateway ownership transferred successfully (HTTP 200 OK)';

  @override
  String get adminTransferOwnerInconsistentError =>
      'Gateway owner state on the server is inconsistent (HTTP 409 Conflict).';

  @override
  String get adminTransferOwnerZeroOwners =>
      'No current owner found in the directory for this gateway. Transfer is blocked.';

  @override
  String get adminTransferOwnerMultipleOwners =>
      'Multiple owners found on this gateway. Inconsistent state, transfer is blocked.';
}
