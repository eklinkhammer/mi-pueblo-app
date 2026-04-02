import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Fence'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Family Location Sharing'**
  String get appSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @createAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAnAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @passwordHelperText.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHelperText;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registrationFailed;

  /// No description provided for @invalidEmailOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalidEmailOrPassword;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed'**
  String get googleSignInFailed;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @selectGroup.
  ///
  /// In en, this message translates to:
  /// **'Select group'**
  String get selectGroup;

  /// No description provided for @selectGroupToViewMap.
  ///
  /// In en, this message translates to:
  /// **'Select a group to view the map'**
  String get selectGroupToViewMap;

  /// No description provided for @addGeofence.
  ///
  /// In en, this message translates to:
  /// **'Add Geofence'**
  String get addGeofence;

  /// No description provided for @createGeofence.
  ///
  /// In en, this message translates to:
  /// **'Create Geofence'**
  String get createGeofence;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @radiusMeters.
  ///
  /// In en, this message translates to:
  /// **'Radius (meters)'**
  String get radiusMeters;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @geofenceCreated.
  ///
  /// In en, this message translates to:
  /// **'Geofence created'**
  String get geofenceCreated;

  /// No description provided for @failedToCreateGeofence.
  ///
  /// In en, this message translates to:
  /// **'Failed to create geofence: {error}'**
  String failedToCreateGeofence(String error);

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Enable it in Settings.'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission required to show your position.'**
  String get locationPermissionRequired;

  /// No description provided for @nameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameIsRequired;

  /// No description provided for @enterPositiveNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number'**
  String get enterPositiveNumber;

  /// No description provided for @timeAgoJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeAgoJustNow;

  /// No description provided for @timeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeAgoMinutes(int minutes);

  /// No description provided for @timeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeAgoHours(int hours);

  /// No description provided for @timeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeAgoDays(int days);

  /// No description provided for @joinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get joinGroup;

  /// No description provided for @noGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get noGroupsYet;

  /// No description provided for @createAGroup.
  ///
  /// In en, this message translates to:
  /// **'Create a Group'**
  String get createAGroup;

  /// No description provided for @joinWithInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Join with Invite Code'**
  String get joinWithInviteCode;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithMessage(String error);

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @geofences.
  ///
  /// In en, this message translates to:
  /// **'Geofences'**
  String get geofences;

  /// No description provided for @noGeofencesYet.
  ///
  /// In en, this message translates to:
  /// **'No geofences yet'**
  String get noGeofencesYet;

  /// No description provided for @radiusWithValue.
  ///
  /// In en, this message translates to:
  /// **'{radius}m radius'**
  String radiusWithValue(int radius);

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get inviteCode;

  /// No description provided for @shareCodeWithFamily.
  ///
  /// In en, this message translates to:
  /// **'Share this code with family members'**
  String get shareCodeWithFamily;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @failedToCreateInvite.
  ///
  /// In en, this message translates to:
  /// **'Failed to create invite: {error}'**
  String failedToCreateInvite(String error);

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupName;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., The Smiths'**
  String get groupNameHint;

  /// No description provided for @failedWithError.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String failedWithError(String error);

  /// No description provided for @enterInviteCodeInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code shared by a group admin.'**
  String get enterInviteCodeInstructions;

  /// No description provided for @invalidOrExpiredInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired invite code'**
  String get invalidOrExpiredInviteCode;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Home, School, Office'**
  String get nameHint;

  /// No description provided for @searchAddress.
  ///
  /// In en, this message translates to:
  /// **'Search address'**
  String get searchAddress;

  /// No description provided for @searchAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 123 Main St'**
  String get searchAddressHint;

  /// No description provided for @searchOrTapMap.
  ///
  /// In en, this message translates to:
  /// **'Search for an address or tap the map to place the geofence center'**
  String get searchOrTapMap;

  /// No description provided for @setNameAndLocation.
  ///
  /// In en, this message translates to:
  /// **'Please set a name and select a location'**
  String get setNameAndLocation;

  /// No description provided for @enterValidRadius.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid radius'**
  String get enterValidRadius;

  /// No description provided for @addressSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Address search failed'**
  String get addressSearchFailed;

  /// No description provided for @geofenceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Geofence not found'**
  String get geofenceNotFound;

  /// No description provided for @radius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get radius;

  /// No description provided for @radiusInMeters.
  ///
  /// In en, this message translates to:
  /// **'{meters} meters'**
  String radiusInMeters(int meters);

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notifyOnEntry.
  ///
  /// In en, this message translates to:
  /// **'Notify on Entry'**
  String get notifyOnEntry;

  /// No description provided for @notifyOnExit.
  ///
  /// In en, this message translates to:
  /// **'Notify on Exit'**
  String get notifyOnExit;

  /// No description provided for @optOutOfGeofence.
  ///
  /// In en, this message translates to:
  /// **'Opt out of this geofence'**
  String get optOutOfGeofence;

  /// No description provided for @optOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your location won\'t trigger notifications for this fence'**
  String get optOutSubtitle;

  /// No description provided for @deleteGeofence.
  ///
  /// In en, this message translates to:
  /// **'Delete Geofence?'**
  String get deleteGeofence;

  /// No description provided for @deleteCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteCannotBeUndone;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @optedOutSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Opted out successfully'**
  String get optedOutSuccessfully;

  /// No description provided for @alreadyOptedOut.
  ///
  /// In en, this message translates to:
  /// **'Already opted out'**
  String get alreadyOptedOut;

  /// No description provided for @locationSharing.
  ///
  /// In en, this message translates to:
  /// **'Location Sharing'**
  String get locationSharing;

  /// No description provided for @locationSharingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your location with group members'**
  String get locationSharingSubtitle;

  /// No description provided for @locationPermissions.
  ///
  /// In en, this message translates to:
  /// **'Location Permissions'**
  String get locationPermissions;

  /// No description provided for @manageLocationAccess.
  ///
  /// In en, this message translates to:
  /// **'Manage location access'**
  String get manageLocationAccess;

  /// No description provided for @locationPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Location permission granted'**
  String get locationPermissionGranted;

  /// No description provided for @locationPermissionDeniedSettings.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Enable it in device Settings.'**
  String get locationPermissionDeniedSettings;

  /// No description provided for @locationPermissionNotDetermined.
  ///
  /// In en, this message translates to:
  /// **'Location permission not determined. Please try again.'**
  String get locationPermissionNotDetermined;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get signOutConfirm;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @locationSharingNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Fence'**
  String get locationSharingNotificationTitle;

  /// No description provided for @locationSharingNotificationText.
  ///
  /// In en, this message translates to:
  /// **'Location sharing active'**
  String get locationSharingNotificationText;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @residents.
  ///
  /// In en, this message translates to:
  /// **'Residents'**
  String get residents;

  /// No description provided for @noResidents.
  ///
  /// In en, this message translates to:
  /// **'No one has claimed this as home'**
  String get noResidents;

  /// No description provided for @claimAsHome.
  ///
  /// In en, this message translates to:
  /// **'Claim as Home'**
  String get claimAsHome;

  /// No description provided for @unclaimHome.
  ///
  /// In en, this message translates to:
  /// **'Unclaim Home'**
  String get unclaimHome;

  /// No description provided for @claimedAsHome.
  ///
  /// In en, this message translates to:
  /// **'Claimed as home'**
  String get claimedAsHome;

  /// No description provided for @homeUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'Home unclaimed'**
  String get homeUnclaimed;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized'**
  String get errorUnauthorized;

  /// No description provided for @errorMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Missing required fields'**
  String get errorMissingFields;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get errorInvalidCredentials;

  /// No description provided for @errorInvalidRefreshToken.
  ///
  /// In en, this message translates to:
  /// **'Invalid refresh token'**
  String get errorInvalidRefreshToken;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFound;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get errorForbidden;

  /// No description provided for @errorInvalidInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid invite code'**
  String get errorInvalidInviteCode;

  /// No description provided for @errorInviteCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'Invite code expired'**
  String get errorInviteCodeExpired;

  /// No description provided for @errorAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'Already a member'**
  String get errorAlreadyMember;

  /// No description provided for @errorCouldNotCreateInvite.
  ///
  /// In en, this message translates to:
  /// **'Could not create invite'**
  String get errorCouldNotCreateInvite;

  /// No description provided for @errorAlreadyOptedOut.
  ///
  /// In en, this message translates to:
  /// **'Already opted out'**
  String get errorAlreadyOptedOut;

  /// No description provided for @errorGeofenceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Geofence not found'**
  String get errorGeofenceNotFound;

  /// No description provided for @errorGeofenceExpired.
  ///
  /// In en, this message translates to:
  /// **'Geofence expired'**
  String get errorGeofenceExpired;

  /// No description provided for @errorNotGroupMember.
  ///
  /// In en, this message translates to:
  /// **'Not a group member'**
  String get errorNotGroupMember;

  /// No description provided for @errorOptedOut.
  ///
  /// In en, this message translates to:
  /// **'Opted out of this geofence'**
  String get errorOptedOut;

  /// No description provided for @errorGeocodingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Geocoding service unavailable'**
  String get errorGeocodingUnavailable;

  /// No description provided for @errorMissingParameter.
  ///
  /// In en, this message translates to:
  /// **'Missing required parameter'**
  String get errorMissingParameter;

  /// No description provided for @errorValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Validation failed'**
  String get errorValidationFailed;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get errorUnknown;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @silenceAllNotifications.
  ///
  /// In en, this message translates to:
  /// **'Silence All Notifications'**
  String get silenceAllNotifications;

  /// No description provided for @silenceAllNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stop all notifications from this group'**
  String get silenceAllNotificationsSubtitle;

  /// No description provided for @silenceHomeNotifications.
  ///
  /// In en, this message translates to:
  /// **'Silence Home Notifications'**
  String get silenceHomeNotifications;

  /// No description provided for @silenceHomeNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stop notifications when members enter or leave their home'**
  String get silenceHomeNotificationsSubtitle;

  /// No description provided for @notifyHousehold.
  ///
  /// In en, this message translates to:
  /// **'Always Notify Household'**
  String get notifyHousehold;

  /// No description provided for @notifyHouseholdSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Override silence settings for members who share your home geofence'**
  String get notifyHouseholdSubtitle;

  /// No description provided for @memberNotifications.
  ///
  /// In en, this message translates to:
  /// **'Per-Member Notifications'**
  String get memberNotifications;

  /// No description provided for @homeNotifications.
  ///
  /// In en, this message translates to:
  /// **'Home Notifications'**
  String get homeNotifications;

  /// No description provided for @whoCanSeeMe.
  ///
  /// In en, this message translates to:
  /// **'Who Can See Me?'**
  String get whoCanSeeMe;

  /// No description provided for @pendingVisibility.
  ///
  /// In en, this message translates to:
  /// **'Pending Requests'**
  String get pendingVisibility;

  /// No description provided for @visibleMembers.
  ///
  /// In en, this message translates to:
  /// **'Visible Members'**
  String get visibleMembers;

  /// No description provided for @grant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get grant;

  /// No description provided for @noVisibilityPairsYet.
  ///
  /// In en, this message translates to:
  /// **'No group members yet. Invite someone to get started.'**
  String get noVisibilityPairsYet;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
