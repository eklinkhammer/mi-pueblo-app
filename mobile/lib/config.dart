class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000/api/v1',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://10.0.2.2:4000/socket/websocket',
  );

  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static const Duration locationInterval = Duration(minutes: 5);
  static final int locationIntervalMs = locationInterval.inMilliseconds;
  static const int locationDistanceFilter = 50; // meters

  /// If no location update arrives within this duration, the position stream
  /// is assumed stalled and will be restarted. Set to 2× the location interval.
  static const Duration locationWatchdogTimeout = Duration(minutes: 10);
}
