import 'package:flutter/widgets.dart';
import 'package:fence/l10n/app_localizations.dart';

String localizeApiError(BuildContext context, String code) {
  final l10n = AppLocalizations.of(context);
  return switch (code) {
    'unauthorized' => l10n.errorUnauthorized,
    'missing_fields' => l10n.errorMissingFields,
    'invalid_credentials' => l10n.errorInvalidCredentials,
    'invalid_refresh_token' => l10n.errorInvalidRefreshToken,
    'not_found' => l10n.errorNotFound,
    'forbidden' => l10n.errorForbidden,
    'invalid_invite_code' => l10n.errorInvalidInviteCode,
    'invite_code_expired' => l10n.errorInviteCodeExpired,
    'already_member' => l10n.errorAlreadyMember,
    'could_not_create_invite' => l10n.errorCouldNotCreateInvite,
    'already_opted_out' => l10n.errorAlreadyOptedOut,
    'geofence_not_found' => l10n.errorGeofenceNotFound,
    'geofence_expired' => l10n.errorGeofenceExpired,
    'not_group_member' => l10n.errorNotGroupMember,
    'opted_out' => l10n.errorOptedOut,
    'geocoding_unavailable' => l10n.errorGeocodingUnavailable,
    'missing_parameter' => l10n.errorMissingParameter,
    'validation_failed' => l10n.errorValidationFailed,
    _ => l10n.errorUnknown,
  };
}
