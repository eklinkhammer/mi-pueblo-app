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
  String get groupCodePrompt => 'Código de grupo';

  @override
  String get yourName => 'Tu nombre';

  @override
  String get joinButton => 'Unirse';

  @override
  String get joinFamilyRequiresCode => 'Únete a tu familia (requiere código)';

  @override
  String get anonymousJoinFailed => 'Error al unirse al grupo';

  @override
  String get anonymousCreateFailed => 'Error al crear el grupo';

  @override
  String get haveInviteCode =>
      '¿Tienes un código de invitación? Únete a un grupo';

  @override
  String get createNewGroup => 'Crear un grupo nuevo';

  @override
  String get anonymousAccount => 'Cuenta anónima';

  @override
  String get signOutAnonymousWarning =>
      'Tienes una cuenta anónima. Cerrar sesión perderá permanentemente el acceso a esta cuenta.';

  @override
  String get registrationFailed => 'Error en el registro';

  @override
  String get invalidEmailOrPassword => 'Correo o contraseña inválidos';

  @override
  String get signInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get googleSignInFailed => 'Error al iniciar sesión con Google';

  @override
  String get or => 'o';

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
  String get color => 'Color';

  @override
  String get language => 'Idioma';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Español';

  @override
  String get recentActivity => 'Actividad reciente';

  @override
  String get noRecentActivity => 'Sin actividad reciente';

  @override
  String enteredAt(String userName) {
    return '$userName entró';
  }

  @override
  String exitedAt(String userName) {
    return '$userName salió';
  }

  @override
  String get residents => 'Residentes';

  @override
  String get noResidents => 'Nadie ha marcado esto como hogar';

  @override
  String get claimAsHome => 'Marcar como hogar';

  @override
  String get unclaimHome => 'Desmarcar hogar';

  @override
  String get claimedAsHome => 'Marcado como hogar';

  @override
  String get homeUnclaimed => 'Hogar desmarcado';

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

  @override
  String get notificationSettings => 'Ajustes de notificaciones';

  @override
  String get notifyHousehold => 'Siempre ver mi hogar';

  @override
  String get notifyHouseholdSubtitle =>
      'Recibir notificaciones cuando los miembros del hogar entren o salgan de tu hogar compartido';

  @override
  String get notifyHomeActivity => 'Ver actividad del hogar';

  @override
  String get notifyHomeActivitySubtitle =>
      'Recibir notificaciones cuando los miembros del grupo entren o salgan de su hogar';

  @override
  String get whoCanSeeMe => '¿Quién puede verme?';

  @override
  String get pendingVisibility => 'Solicitudes pendientes';

  @override
  String get visibleMembers => 'Miembros visibles';

  @override
  String get share => 'Compartir';

  @override
  String get noVisibilityPairsYet =>
      'Aún no hay miembros en el grupo. Invita a alguien para comenzar.';

  @override
  String sharingWithCount(int count) {
    return 'Compartiendo con $count personas';
  }

  @override
  String get deleteGroup => '¿Eliminar grupo?';

  @override
  String get locationSharingMode =>
      '¿Cómo comparto mi ubicación con este grupo?';

  @override
  String get live => 'En vivo';

  @override
  String get geofencesOnly => 'Geocercas';

  @override
  String get leaveGroup => '¿Salir del grupo?';

  @override
  String get leaveGroupConfirmation =>
      'Ya no verás los miembros ni las geocercas de este grupo.';

  @override
  String get leave => 'Salir';

  @override
  String get stats => 'Estadísticas';

  @override
  String get noStatsYet => 'Marca un hogar para ver estadísticas';

  @override
  String get homeVisits => 'Visitas al hogar';

  @override
  String get totalVisits => 'Visitas totales';

  @override
  String get yourTopPlaces => 'Tus lugares frecuentes';

  @override
  String get housemateTopPlaces => 'Lugares frecuentes de compañeros';

  @override
  String get allTime => 'Desde siempre';

  @override
  String visitsCount(int count) {
    return '$count visitas';
  }

  @override
  String get noVisitsYet => 'Sin visitas aún';

  @override
  String get history => 'Historial';

  @override
  String get noHistoryYet => 'Sin historial aún';

  @override
  String get entered => 'Entró';

  @override
  String get exited => 'Salió';

  @override
  String arrivedAndSpent(String place, String duration) {
    return 'Llegó a $place y estuvo $duration';
  }

  @override
  String get subscription => 'Suscripción';

  @override
  String get villageMember => 'Miembro del Pueblo';

  @override
  String get villageElder => 'Anciano del Pueblo';

  @override
  String get villageLeader => 'Líder del Pueblo';

  @override
  String get currentPlan => 'Plan Actual';

  @override
  String get freeTier => 'Gratis';

  @override
  String get perMonth => '/mes';

  @override
  String get upgrade => 'Mejorar';

  @override
  String get subscribe => 'Suscribirse';

  @override
  String get restorePurchases => 'Restaurar Compras';

  @override
  String get restorePurchasesSuccess => 'Compras restauradas';

  @override
  String get groupLimitReached =>
      'Has alcanzado el límite de grupos. Mejora tu plan para crear más.';

  @override
  String get geofenceLimitReached =>
      'Este grupo ha alcanzado su límite de geocercas. El creador del grupo puede mejorar su plan.';

  @override
  String get memberLimitReached =>
      'Este grupo ha alcanzado su límite de miembros.';

  @override
  String get groupsYouCanCreate => 'Grupos que puedes crear';

  @override
  String get groupsYouCanJoin => 'Grupos a los que puedes unirte';

  @override
  String get membersPerGroup => 'Miembros por grupo';

  @override
  String get geofencesPerGroup => 'Geocercas por grupo';

  @override
  String get historyRetention => 'Historial';

  @override
  String get days => 'días';

  @override
  String get unlimited => 'Ilimitado';

  @override
  String get renewsOn => 'Se renueva el';

  @override
  String get errorGroupLimitReached => 'Mejora tu plan para crear más grupos';

  @override
  String get errorGeofenceLimitReached =>
      'Límite de geocercas alcanzado para este grupo';

  @override
  String get errorMemberLimitReached =>
      'Límite de miembros del grupo alcanzado';

  @override
  String get currentLocation => 'Ubicación actual';

  @override
  String get lastUpdated => 'Última actualización';

  @override
  String get arrivedAt => 'Llegó';

  @override
  String get close => 'Cerrar';

  @override
  String get share => 'Compartir';

  @override
  String inviteShareMessage(String url) {
    return '¡Únete a mi familia en Mi Pueblo! Toca este enlace: $url';
  }

  @override
  String get home => 'Hogar';

  @override
  String replaceHomeWarning(String currentHome) {
    return 'Ya tienes un hogar ($currentHome). Reclamar esta geocerca lo reemplazará.';
  }

  @override
  String get replaceHome => 'Reemplazar hogar';

  @override
  String get currentlyAtHome => 'Actualmente en casa';
}
