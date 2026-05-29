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
  String get groupCodePrompt => 'Group Code';

  @override
  String get yourName => 'Your Name';

  @override
  String get joinButton => 'Join';

  @override
  String get joinFamilyRequiresCode => 'Join your family (requires code)';

  @override
  String get anonymousJoinFailed => 'Failed to join group';

  @override
  String get anonymousCreateFailed => 'Failed to create group';

  @override
  String get haveInviteCode => 'Have an invite code? Join a group';

  @override
  String get createNewGroup => 'Create a new group';

  @override
  String get anonymousAccount => 'Anonymous account';

  @override
  String get signOutAnonymousWarning =>
      'You have an anonymous account. Signing out will permanently lose access to this account.';

  @override
  String get registrationFailed => 'Registration failed';

  @override
  String get invalidEmailOrPassword => 'Invalid email or password';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get googleSignInFailed => 'Google sign-in failed';

  @override
  String get or => 'or';

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
  String get recentActivity => 'Recent Activity';

  @override
  String get noRecentActivity => 'No recent activity';

  @override
  String enteredAt(String userName) {
    return '$userName entered';
  }

  @override
  String exitedAt(String userName) {
    return '$userName exited';
  }

  @override
  String get residents => 'Residents';

  @override
  String get noResidents => 'No one has claimed this as home';

  @override
  String get claimAsHome => 'Claim as Home';

  @override
  String get unclaimHome => 'Unclaim Home';

  @override
  String get claimedAsHome => 'Claimed as home';

  @override
  String get homeUnclaimed => 'Home unclaimed';

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

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get notifyHousehold => 'Always See My Household';

  @override
  String get notifyHouseholdSubtitle =>
      'Get notifications when household members enter or leave your shared home';

  @override
  String get notifyHomeActivity => 'See Home Activity';

  @override
  String get notifyHomeActivitySubtitle =>
      'Get notified when group members enter or leave their claimed home';

  @override
  String get whoCanSeeMe => 'Who Can See Me?';

  @override
  String get pendingVisibility => 'Pending Requests';

  @override
  String get visibleMembers => 'Visible Members';

  @override
  String get grant => 'Grant';

  @override
  String get noVisibilityPairsYet =>
      'No group members yet. Invite someone to get started.';

  @override
  String sharingWithCount(int count) {
    return 'Sharing with $count people';
  }

  @override
  String get deleteGroup => 'Delete Group?';

  @override
  String get locationSharingMode =>
      'How do I share my location with this group?';

  @override
  String get live => 'Live';

  @override
  String get geofencesOnly => 'Geofences';

  @override
  String get leaveGroup => 'Leave Group?';

  @override
  String get leaveGroupConfirmation =>
      'You will no longer see this group\'s members or geofences.';

  @override
  String get leave => 'Leave';

  @override
  String get history => 'History';

  @override
  String get noHistoryYet => 'No history yet';

  @override
  String get entered => 'Entered';

  @override
  String get exited => 'Exited';

  @override
  String get close => 'Close';

  @override
  String get share => 'Share';

  @override
  String inviteShareMessage(String url) {
    return 'Join my family on Mi Pueblo! Tap this link: $url';
  }
}
