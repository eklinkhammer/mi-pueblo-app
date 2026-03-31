// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fence';

  @override
  String get appSubtitle => 'Family Location Sharing';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAnAccount => 'Create an account';

  @override
  String get createAccount => 'Create Account';

  @override
  String get displayName => 'Display Name';

  @override
  String get passwordHelperText => 'At least 8 characters';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get registrationFailed => 'Registration failed';

  @override
  String get invalidEmailOrPassword => 'Invalid email or password';

  @override
  String get map => 'Map';

  @override
  String get groups => 'Groups';

  @override
  String get settings => 'Settings';

  @override
  String get selectGroup => 'Select group';

  @override
  String get selectGroupToViewMap => 'Select a group to view the map';

  @override
  String get addGeofence => 'Add Geofence';

  @override
  String get createGeofence => 'Create Geofence';

  @override
  String get name => 'Name';

  @override
  String get radiusMeters => 'Radius (meters)';

  @override
  String get create => 'Create';

  @override
  String get geofenceCreated => 'Geofence created';

  @override
  String failedToCreateGeofence(String error) {
    return 'Failed to create geofence: $error';
  }

  @override
  String get locationPermissionDenied =>
      'Location permission denied. Enable it in Settings.';

  @override
  String get locationPermissionRequired =>
      'Location permission required to show your position.';

  @override
  String get nameIsRequired => 'Name is required';

  @override
  String get enterPositiveNumber => 'Enter a positive number';

  @override
  String get timeAgoJustNow => 'just now';

  @override
  String timeAgoMinutes(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeAgoHours(int hours) {
    return '${hours}h ago';
  }

  @override
  String timeAgoDays(int days) {
    return '${days}d ago';
  }

  @override
  String get joinGroup => 'Join Group';

  @override
  String get noGroupsYet => 'No groups yet';

  @override
  String get createAGroup => 'Create a Group';

  @override
  String get joinWithInviteCode => 'Join with Invite Code';

  @override
  String errorWithMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get group => 'Group';

  @override
  String get invite => 'Invite';

  @override
  String get members => 'Members';

  @override
  String get geofences => 'Geofences';

  @override
  String get noGeofencesYet => 'No geofences yet';

  @override
  String radiusWithValue(int radius) {
    return '${radius}m radius';
  }

  @override
  String get inviteCode => 'Invite Code';

  @override
  String get shareCodeWithFamily => 'Share this code with family members';

  @override
  String get copy => 'Copy';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get done => 'Done';

  @override
  String failedToCreateInvite(String error) {
    return 'Failed to create invite: $error';
  }

  @override
  String get createGroup => 'Create Group';

  @override
  String get groupName => 'Group Name';

  @override
  String get groupNameHint => 'e.g., The Smiths';

  @override
  String failedWithError(String error) {
    return 'Failed: $error';
  }

  @override
  String get enterInviteCodeInstructions =>
      'Enter the invite code shared by a group admin.';

  @override
  String get invalidOrExpiredInviteCode => 'Invalid or expired invite code';

  @override
  String get nameHint => 'e.g., Home, School, Office';

  @override
  String get searchAddress => 'Search address';

  @override
  String get searchAddressHint => 'e.g., 123 Main St';

  @override
  String get searchOrTapMap =>
      'Search for an address or tap the map to place the geofence center';

  @override
  String get setNameAndLocation => 'Please set a name and select a location';

  @override
  String get enterValidRadius => 'Please enter a valid radius';

  @override
  String get addressSearchFailed => 'Address search failed';

  @override
  String get geofenceNotFound => 'Geofence not found';

  @override
  String get radius => 'Radius';

  @override
  String radiusInMeters(int meters) {
    return '$meters meters';
  }

  @override
  String get description => 'Description';

  @override
  String get notifications => 'Notifications';

  @override
  String get notifyOnEntry => 'Notify on Entry';

  @override
  String get notifyOnExit => 'Notify on Exit';

  @override
  String get optOutOfGeofence => 'Opt out of this geofence';

  @override
  String get optOutSubtitle =>
      'Your location won\'t trigger notifications for this fence';

  @override
  String get deleteGeofence => 'Delete Geofence?';

  @override
  String get deleteCannotBeUndone => 'This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get optedOutSuccessfully => 'Opted out successfully';

  @override
  String get alreadyOptedOut => 'Already opted out';

  @override
  String get locationSharing => 'Location Sharing';

  @override
  String get locationSharingSubtitle =>
      'Share your location with group members';

  @override
  String get locationPermissions => 'Location Permissions';

  @override
  String get manageLocationAccess => 'Manage location access';

  @override
  String get locationPermissionGranted => 'Location permission granted';

  @override
  String get locationPermissionDeniedSettings =>
      'Location permission denied. Enable it in device Settings.';

  @override
  String get locationPermissionNotDetermined =>
      'Location permission not determined. Please try again.';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutConfirm => 'Sign Out?';

  @override
  String get unknown => 'Unknown';

  @override
  String get locationSharingNotificationTitle => 'Fence';

  @override
  String get locationSharingNotificationText => 'Location sharing active';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Spanish';

  @override
  String get errorUnauthorized => 'Unauthorized';

  @override
  String get errorMissingFields => 'Missing required fields';

  @override
  String get errorInvalidCredentials => 'Invalid email or password';

  @override
  String get errorInvalidRefreshToken => 'Invalid refresh token';

  @override
  String get errorNotFound => 'Not found';

  @override
  String get errorForbidden => 'Access denied';

  @override
  String get errorInvalidInviteCode => 'Invalid invite code';

  @override
  String get errorInviteCodeExpired => 'Invite code expired';

  @override
  String get errorAlreadyMember => 'Already a member';

  @override
  String get errorCouldNotCreateInvite => 'Could not create invite';

  @override
  String get errorAlreadyOptedOut => 'Already opted out';

  @override
  String get errorGeofenceNotFound => 'Geofence not found';

  @override
  String get errorGeofenceExpired => 'Geofence expired';

  @override
  String get errorNotGroupMember => 'Not a group member';

  @override
  String get errorOptedOut => 'Opted out of this geofence';

  @override
  String get errorGeocodingUnavailable => 'Geocoding service unavailable';

  @override
  String get errorMissingParameter => 'Missing required parameter';

  @override
  String get errorValidationFailed => 'Validation failed';

  @override
  String get errorUnknown => 'An unexpected error occurred';
}
