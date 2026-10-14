import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'SANSLAB IoT Server'**
  String get appName;

  /// No description provided for @navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// No description provided for @navManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get navManage;

  /// No description provided for @navApps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get navApps;

  /// No description provided for @navBuild.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get navBuild;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navOrders;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get navProducts;

  /// No description provided for @navInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get navInbox;

  /// No description provided for @navBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get navBoard;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navComponents.
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get navComponents;

  /// No description provided for @navForms.
  ///
  /// In en, this message translates to:
  /// **'Forms'**
  String get navForms;

  /// No description provided for @navWizard.
  ///
  /// In en, this message translates to:
  /// **'Wizard'**
  String get navWizard;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get actionExport;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get actionPrevious;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Type your email and password to continue'**
  String get signInSubtitle;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'No account? Create one'**
  String get noAccount;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @accent.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get accent;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches those filters'**
  String get emptyTitle;

  /// No description provided for @emptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Try clearing the search or choosing a different status.'**
  String get emptyMessage;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @errorRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get errorRetry;

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String pageOf(int page, int pages);

  /// No description provided for @rangeOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{first}–{last} of {total}'**
  String rangeOfTotal(int first, int last, int total);

  /// No description provided for @accountInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get accountInfo;

  /// No description provided for @accountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View identity and active session details for this account.'**
  String get accountSubtitle;

  /// No description provided for @accountIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity Information'**
  String get accountIdentityTitle;

  /// No description provided for @accountUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get accountUserId;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Account Email'**
  String get accountEmail;

  /// No description provided for @accountFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get accountFullName;

  /// No description provided for @accountRole.
  ///
  /// In en, this message translates to:
  /// **'Gateway Role'**
  String get accountRole;

  /// No description provided for @accountRoleUnassigned.
  ///
  /// In en, this message translates to:
  /// **'No gateway role assigned'**
  String get accountRoleUnassigned;

  /// No description provided for @accountRoleNote.
  ///
  /// In en, this message translates to:
  /// **'Gateway permissions (owner, operator, viewer) and Platform Admin privileges are evaluated dynamically per request on Go Backend. Identity session does not assert or infer permissions.'**
  String get accountRoleNote;

  /// No description provided for @accountSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session & Security'**
  String get accountSessionTitle;

  /// No description provided for @accountSessionStatus.
  ///
  /// In en, this message translates to:
  /// **'Session Status'**
  String get accountSessionStatus;

  /// No description provided for @accountStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get accountStatusActive;

  /// No description provided for @accountAuthMethod.
  ///
  /// In en, this message translates to:
  /// **'Authentication Method'**
  String get accountAuthMethod;

  /// No description provided for @accountAuthMethodValue.
  ///
  /// In en, this message translates to:
  /// **'Supabase Auth (GoTrue) · Local HS256 JWT Verification on Go Backend'**
  String get accountAuthMethodValue;

  /// No description provided for @accountAdminNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Management Policy'**
  String get accountAdminNoteTitle;

  /// No description provided for @accountAdminNote.
  ///
  /// In en, this message translates to:
  /// **'Accounts are managed centrally by Platform Administrators. Direct self-modification from client UI is disabled. Platform Admin privileges are maintained separately in public.platform_admins.'**
  String get accountAdminNote;

  /// No description provided for @accountCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy ID'**
  String get accountCopyId;

  /// No description provided for @accountCopiedId.
  ///
  /// In en, this message translates to:
  /// **'Copied User ID to clipboard'**
  String get accountCopiedId;

  /// No description provided for @accountBackToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to Dashboard'**
  String get accountBackToDashboard;

  /// No description provided for @navGateways.
  ///
  /// In en, this message translates to:
  /// **'Gateways'**
  String get navGateways;

  /// No description provided for @gatewayListTitle.
  ///
  /// In en, this message translates to:
  /// **'Gateways'**
  String get gatewayListTitle;

  /// No description provided for @gatewayListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'List of accessible gateway devices in the platform.'**
  String get gatewayListSubtitle;

  /// No description provided for @gatewayId.
  ///
  /// In en, this message translates to:
  /// **'Gateway ID'**
  String get gatewayId;

  /// No description provided for @gatewayName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get gatewayName;

  /// No description provided for @gatewayDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get gatewayDescription;

  /// No description provided for @gatewayRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get gatewayRole;

  /// No description provided for @gatewayCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created At'**
  String get gatewayCreatedAt;

  /// No description provided for @gatewaySearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search by ID, name or description...'**
  String get gatewaySearchPlaceholder;

  /// No description provided for @gatewayEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No gateways found'**
  String get gatewayEmptyTitle;

  /// No description provided for @gatewayEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has not been assigned access to any gateways yet.'**
  String get gatewayEmptyMessage;

  /// No description provided for @gatewaySearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching gateways'**
  String get gatewaySearchEmptyTitle;

  /// No description provided for @gatewaySearchEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No gateways match your search query.'**
  String get gatewaySearchEmptyMessage;

  /// No description provided for @gatewayRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get gatewayRoleOwner;

  /// No description provided for @gatewayRoleOperator.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get gatewayRoleOperator;

  /// No description provided for @gatewayRoleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get gatewayRoleViewer;

  /// No description provided for @gatewayActionDetail.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get gatewayActionDetail;

  /// No description provided for @gatewayDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Gateway Details'**
  String get gatewayDetailTitle;

  /// No description provided for @gatewayDetailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Overview of station configuration and associated sensors.'**
  String get gatewayDetailSubtitle;

  /// No description provided for @gatewayNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Gateway not found'**
  String get gatewayNotFoundTitle;

  /// No description provided for @gatewayNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'The requested gateway was not found or your account does not have access permission.'**
  String get gatewayNotFoundMessage;

  /// No description provided for @gatewayInvalidIdMessage.
  ///
  /// In en, this message translates to:
  /// **'Invalid gateway identifier or reserved identifier.'**
  String get gatewayInvalidIdMessage;

  /// No description provided for @gatewayBackToList.
  ///
  /// In en, this message translates to:
  /// **'Back to Gateways'**
  String get gatewayBackToList;

  /// No description provided for @gatewaySectionMetadata.
  ///
  /// In en, this message translates to:
  /// **'Gateway Information'**
  String get gatewaySectionMetadata;

  /// No description provided for @gatewaySectionSensors.
  ///
  /// In en, this message translates to:
  /// **'Sensor Catalog'**
  String get gatewaySectionSensors;

  /// No description provided for @sensorId.
  ///
  /// In en, this message translates to:
  /// **'Sensor ID'**
  String get sensorId;

  /// No description provided for @sensorName.
  ///
  /// In en, this message translates to:
  /// **'Sensor Name'**
  String get sensorName;

  /// No description provided for @sensorUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get sensorUnit;

  /// No description provided for @sensorCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created At'**
  String get sensorCreatedAt;

  /// No description provided for @sensorEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sensors configured'**
  String get sensorEmptyTitle;

  /// No description provided for @sensorEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No sensors have been added to this gateway station yet.'**
  String get sensorEmptyMessage;

  /// No description provided for @sensorSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search sensors by ID, name or unit...'**
  String get sensorSearchPlaceholder;

  /// No description provided for @sensorSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching sensors'**
  String get sensorSearchEmptyTitle;

  /// No description provided for @sensorSearchEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No sensors match your search query.'**
  String get sensorSearchEmptyMessage;

  /// No description provided for @sensorErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sensors'**
  String get sensorErrorTitle;

  /// No description provided for @sensorErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry loading sensors'**
  String get sensorErrorRetry;

  /// No description provided for @gatewayReadOnlyNotice.
  ///
  /// In en, this message translates to:
  /// **'Read-only mode (Stage 2). Remote control, downlink commands, and real-time telemetry streaming are not active.'**
  String get gatewayReadOnlyNotice;

  /// No description provided for @accountPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cơ chế phân quyền trạm & quản trị'**
  String get accountPermissionsTitle;

  /// No description provided for @accountPlatformAdminStatus.
  ///
  /// In en, this message translates to:
  /// **'Platform Admin Status'**
  String get accountPlatformAdminStatus;

  /// No description provided for @accountPlatformAdminTrue.
  ///
  /// In en, this message translates to:
  /// **'Platform Admin (Confirmed)'**
  String get accountPlatformAdminTrue;

  /// No description provided for @accountPlatformAdminFalse.
  ///
  /// In en, this message translates to:
  /// **'Standard User (No Admin privileges)'**
  String get accountPlatformAdminFalse;

  /// No description provided for @accountPlatformAdminChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking admin permissions...'**
  String get accountPlatformAdminChecking;

  /// No description provided for @gatewayAddButton.
  ///
  /// In en, this message translates to:
  /// **'Thêm Gateway mới'**
  String get gatewayAddButton;

  /// No description provided for @gatewayProvisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Provision Gateway'**
  String get gatewayProvisionTitle;

  /// No description provided for @gatewayProvisionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Provision a new Gateway station and assign initial owner (Platform Admin only).'**
  String get gatewayProvisionSubtitle;

  /// No description provided for @gatewayProvisionSuccessCreated.
  ///
  /// In en, this message translates to:
  /// **'Gateway provisioned successfully (HTTP 201 Created)'**
  String get gatewayProvisionSuccessCreated;

  /// No description provided for @gatewayProvisionSuccessReplayed.
  ///
  /// In en, this message translates to:
  /// **'Gateway already exists with identical payload (HTTP 200 OK - Idempotent Replay)'**
  String get gatewayProvisionSuccessReplayed;

  /// No description provided for @gatewayProvisionNoticeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Authorization notice: Platform Admin accounts are not automatically catalog members (user_gateways) unless assigned ownership. This gateway may not appear in your personal catalog unless you are the assigned owner.'**
  String get gatewayProvisionNoticeAdmin;

  /// No description provided for @gatewayProvisionCreateAnother.
  ///
  /// In en, this message translates to:
  /// **'Provision another Gateway'**
  String get gatewayProvisionCreateAnother;

  /// No description provided for @gatewayProvisionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Provision Gateway'**
  String get gatewayProvisionSubmit;

  /// No description provided for @gatewayProvisionSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Provisioning...'**
  String get gatewayProvisionSubmitting;

  /// No description provided for @gatewayProvisionFieldId.
  ///
  /// In en, this message translates to:
  /// **'Gateway ID'**
  String get gatewayProvisionFieldId;

  /// No description provided for @gatewayProvisionFieldIdHint.
  ///
  /// In en, this message translates to:
  /// **'Gateway\'s identification, must not be a duplicate of other gateways'**
  String get gatewayProvisionFieldIdHint;

  /// No description provided for @gatewayProvisionFieldName.
  ///
  /// In en, this message translates to:
  /// **'Gateway Name'**
  String get gatewayProvisionFieldName;

  /// No description provided for @gatewayProvisionFieldNameHint.
  ///
  /// In en, this message translates to:
  /// **'Gateway display name'**
  String get gatewayProvisionFieldNameHint;

  /// No description provided for @gatewayProvisionFieldDesc.
  ///
  /// In en, this message translates to:
  /// **'Description (Optional)'**
  String get gatewayProvisionFieldDesc;

  /// No description provided for @gatewayProvisionFieldDescHint.
  ///
  /// In en, this message translates to:
  /// **'Location or function description'**
  String get gatewayProvisionFieldDescHint;

  /// No description provided for @gatewayProvisionFieldOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner User ID (owner_user_id)'**
  String get gatewayProvisionFieldOwner;

  /// No description provided for @gatewayProvisionFieldOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'UUID of the owner user in the system'**
  String get gatewayProvisionFieldOwnerHint;

  /// No description provided for @gatewayProvisionEntityId.
  ///
  /// In en, this message translates to:
  /// **'Digital Twin Entity ID'**
  String get gatewayProvisionEntityId;

  /// No description provided for @gatewayProvisionOwnerId.
  ///
  /// In en, this message translates to:
  /// **'Initial Owner User ID'**
  String get gatewayProvisionOwnerId;

  /// No description provided for @gatewayProvisionCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created At'**
  String get gatewayProvisionCreatedAt;

  /// No description provided for @gatewayProvisionAccessDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get gatewayProvisionAccessDeniedTitle;

  /// No description provided for @gatewayProvisionAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'You do not have Platform Admin privileges to perform this action.'**
  String get gatewayProvisionAccessDeniedMessage;

  /// No description provided for @gatewayProvisionRetrySamePayload.
  ///
  /// In en, this message translates to:
  /// **'Retry with same payload'**
  String get gatewayProvisionRetrySamePayload;

  /// No description provided for @gatewayProvisionConflictError.
  ///
  /// In en, this message translates to:
  /// **'Gateway already exists with different payload (HTTP 409 Conflict). Provisioning endpoint does not support updating existing metadata.'**
  String get gatewayProvisionConflictError;

  /// No description provided for @gatewayProvisionNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'Owner user ID not found in system (HTTP 404 Not Found). Please verify UUID.'**
  String get gatewayProvisionNotFoundError;

  /// No description provided for @sensorAddButton.
  ///
  /// In en, this message translates to:
  /// **'Thêm cảm biến mới'**
  String get sensorAddButton;

  /// No description provided for @sensorCreateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New Sensor'**
  String get sensorCreateDialogTitle;

  /// No description provided for @sensorCreateDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a new sensor associated with this Gateway station'**
  String get sensorCreateDialogSubtitle;

  /// No description provided for @sensorParentGateway.
  ///
  /// In en, this message translates to:
  /// **'Parent Gateway ID'**
  String get sensorParentGateway;

  /// No description provided for @sensorFieldId.
  ///
  /// In en, this message translates to:
  /// **'Sensor ID'**
  String get sensorFieldId;

  /// No description provided for @sensorFieldIdHint.
  ///
  /// In en, this message translates to:
  /// **'Sensor\'s identification, must not be a duplicate of other sensors inside this Gateway'**
  String get sensorFieldIdHint;

  /// No description provided for @sensorFieldName.
  ///
  /// In en, this message translates to:
  /// **'Sensor Name'**
  String get sensorFieldName;

  /// No description provided for @sensorFieldNameHint.
  ///
  /// In en, this message translates to:
  /// **'Sensor display name'**
  String get sensorFieldNameHint;

  /// No description provided for @sensorFieldUnit.
  ///
  /// In en, this message translates to:
  /// **'Measurement Unit (Optional)'**
  String get sensorFieldUnit;

  /// No description provided for @sensorFieldUnitHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. °C, %, ppm'**
  String get sensorFieldUnitHint;

  /// No description provided for @sensorCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create Sensor'**
  String get sensorCreateSubmit;

  /// No description provided for @sensorCreateSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get sensorCreateSubmitting;

  /// No description provided for @sensorCreateSuccessCreated.
  ///
  /// In en, this message translates to:
  /// **'Sensor created successfully (HTTP 201 Created)'**
  String get sensorCreateSuccessCreated;

  /// No description provided for @sensorCreateSuccessReplayed.
  ///
  /// In en, this message translates to:
  /// **'Sensor already exists with identical payload (HTTP 200 OK - Idempotent Replay)'**
  String get sensorCreateSuccessReplayed;

  /// No description provided for @sensorProvisionConflictError.
  ///
  /// In en, this message translates to:
  /// **'Sensor already exists with different payload (HTTP 409 Conflict). Provisioning endpoint does not support updating existing metadata.'**
  String get sensorProvisionConflictError;

  /// No description provided for @sensorProvisionNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'Parent Gateway not found (HTTP 404 Not Found).'**
  String get sensorProvisionNotFoundError;

  /// No description provided for @sensorProvisionForbiddenError.
  ///
  /// In en, this message translates to:
  /// **'Access denied. You do not have Platform Admin privileges.'**
  String get sensorProvisionForbiddenError;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'vi':
      return LVi();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
