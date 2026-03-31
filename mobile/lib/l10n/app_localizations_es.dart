// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Fence';

  @override
  String get appSubtitle => 'Ubicación familiar compartida';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get createAnAccount => 'Crear una cuenta';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get displayName => 'Nombre';

  @override
  String get passwordHelperText => 'Al menos 8 caracteres';

  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta? Inicia sesión';

  @override
  String get registrationFailed => 'Error en el registro';

  @override
  String get invalidEmailOrPassword => 'Correo o contraseña inválidos';

  @override
  String get map => 'Mapa';

  @override
  String get groups => 'Grupos';

  @override
  String get settings => 'Ajustes';

  @override
  String get selectGroup => 'Seleccionar grupo';

  @override
  String get selectGroupToViewMap => 'Selecciona un grupo para ver el mapa';

  @override
  String get addGeofence => 'Agregar geocerca';

  @override
  String get createGeofence => 'Crear geocerca';

  @override
  String get name => 'Nombre';

  @override
  String get radiusMeters => 'Radio (metros)';

  @override
  String get create => 'Crear';

  @override
  String get geofenceCreated => 'Geocerca creada';

  @override
  String failedToCreateGeofence(String error) {
    return 'Error al crear geocerca: $error';
  }

  @override
  String get locationPermissionDenied =>
      'Permiso de ubicación denegado. Actívalo en Ajustes.';

  @override
  String get locationPermissionRequired =>
      'Se requiere permiso de ubicación para mostrar tu posición.';

  @override
  String get nameIsRequired => 'El nombre es obligatorio';

  @override
  String get enterPositiveNumber => 'Ingresa un número positivo';

  @override
  String get timeAgoJustNow => 'ahora';

  @override
  String timeAgoMinutes(int minutes) {
    return 'hace ${minutes}m';
  }

  @override
  String timeAgoHours(int hours) {
    return 'hace ${hours}h';
  }

  @override
  String timeAgoDays(int days) {
    return 'hace ${days}d';
  }

  @override
  String get joinGroup => 'Unirse a grupo';

  @override
  String get noGroupsYet => 'Aún no hay grupos';

  @override
  String get createAGroup => 'Crear un grupo';

  @override
  String get joinWithInviteCode => 'Unirse con código de invitación';

  @override
  String errorWithMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get group => 'Grupo';

  @override
  String get invite => 'Invitar';

  @override
  String get members => 'Miembros';

  @override
  String get geofences => 'Geocercas';

  @override
  String get noGeofencesYet => 'Aún no hay geocercas';

  @override
  String radiusWithValue(int radius) {
    return 'Radio de ${radius}m';
  }

  @override
  String get inviteCode => 'Código de invitación';

  @override
  String get shareCodeWithFamily =>
      'Comparte este código con los miembros de tu familia';

  @override
  String get copy => 'Copiar';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get done => 'Listo';

  @override
  String failedToCreateInvite(String error) {
    return 'Error al crear invitación: $error';
  }

  @override
  String get createGroup => 'Crear grupo';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String get groupNameHint => 'ej., Los García';

  @override
  String failedWithError(String error) {
    return 'Error: $error';
  }

  @override
  String get enterInviteCodeInstructions =>
      'Ingresa el código de invitación compartido por un administrador del grupo.';

  @override
  String get invalidOrExpiredInviteCode =>
      'Código de invitación inválido o expirado';

  @override
  String get nameHint => 'ej., Casa, Escuela, Oficina';

  @override
  String get searchAddress => 'Buscar dirección';

  @override
  String get searchAddressHint => 'ej., Av. Principal 123';

  @override
  String get searchOrTapMap =>
      'Busca una dirección o toca el mapa para colocar el centro de la geocerca';

  @override
  String get setNameAndLocation =>
      'Ingresa un nombre y selecciona una ubicación';

  @override
  String get enterValidRadius => 'Ingresa un radio válido';

  @override
  String get addressSearchFailed => 'Error en la búsqueda de dirección';

  @override
  String get geofenceNotFound => 'Geocerca no encontrada';

  @override
  String get radius => 'Radio';

  @override
  String radiusInMeters(int meters) {
    return '$meters metros';
  }

  @override
  String get description => 'Descripción';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get notifyOnEntry => 'Notificar al entrar';

  @override
  String get notifyOnExit => 'Notificar al salir';

  @override
  String get optOutOfGeofence => 'Excluirse de esta geocerca';

  @override
  String get optOutSubtitle =>
      'Tu ubicación no activará notificaciones para esta geocerca';

  @override
  String get deleteGeofence => '¿Eliminar geocerca?';

  @override
  String get deleteCannotBeUndone => 'Esta acción no se puede deshacer.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get optedOutSuccessfully => 'Exclusión exitosa';

  @override
  String get alreadyOptedOut => 'Ya estás excluido';

  @override
  String get locationSharing => 'Compartir ubicación';

  @override
  String get locationSharingSubtitle =>
      'Comparte tu ubicación con los miembros del grupo';

  @override
  String get locationPermissions => 'Permisos de ubicación';

  @override
  String get manageLocationAccess => 'Administrar acceso a ubicación';

  @override
  String get locationPermissionGranted => 'Permiso de ubicación concedido';

  @override
  String get locationPermissionDeniedSettings =>
      'Permiso de ubicación denegado. Actívalo en Ajustes del dispositivo.';

  @override
  String get locationPermissionNotDetermined =>
      'Permiso de ubicación no determinado. Intenta de nuevo.';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signOutConfirm => '¿Cerrar sesión?';

  @override
  String get unknown => 'Desconocido';

  @override
  String get locationSharingNotificationTitle => 'Fence';

  @override
  String get locationSharingNotificationText => 'Ubicación compartida activa';

  @override
  String get language => 'Idioma';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Español';

  @override
  String get errorUnauthorized => 'No autorizado';

  @override
  String get errorMissingFields => 'Faltan campos obligatorios';

  @override
  String get errorInvalidCredentials => 'Correo o contraseña inválidos';

  @override
  String get errorInvalidRefreshToken => 'Token de actualización inválido';

  @override
  String get errorNotFound => 'No encontrado';

  @override
  String get errorForbidden => 'Acceso denegado';

  @override
  String get errorInvalidInviteCode => 'Código de invitación inválido';

  @override
  String get errorInviteCodeExpired => 'Código de invitación expirado';

  @override
  String get errorAlreadyMember => 'Ya eres miembro';

  @override
  String get errorCouldNotCreateInvite => 'No se pudo crear la invitación';

  @override
  String get errorAlreadyOptedOut => 'Ya estás excluido';

  @override
  String get errorGeofenceNotFound => 'Geocerca no encontrada';

  @override
  String get errorGeofenceExpired => 'Geocerca expirada';

  @override
  String get errorNotGroupMember => 'No eres miembro del grupo';

  @override
  String get errorOptedOut => 'Estás excluido de esta geocerca';

  @override
  String get errorGeocodingUnavailable =>
      'Servicio de geocodificación no disponible';

  @override
  String get errorMissingParameter => 'Falta un parámetro obligatorio';

  @override
  String get errorValidationFailed => 'Error de validación';

  @override
  String get errorUnknown => 'Ocurrió un error inesperado';
}
