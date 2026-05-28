class GeofencePresence {
  final String userId;
  final String displayName;
  final String sharingMode;
  final String geofenceId;
  final String geofenceName;
  final double? geofenceLatitude;
  final double? geofenceLongitude;
  final DateTime enteredAt;

  const GeofencePresence({
    required this.userId,
    required this.displayName,
    required this.sharingMode,
    required this.geofenceId,
    required this.geofenceName,
    required this.geofenceLatitude,
    required this.geofenceLongitude,
    required this.enteredAt,
  });

  factory GeofencePresence.fromJson(Map<String, dynamic> json) {
    return GeofencePresence(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      sharingMode: json['sharing_mode'] as String,
      geofenceId: json['geofence_id'] as String,
      geofenceName: json['geofence_name'] as String,
      geofenceLatitude: (json['geofence_latitude'] as num?)?.toDouble(),
      geofenceLongitude: (json['geofence_longitude'] as num?)?.toDouble(),
      enteredAt: DateTime.parse(json['entered_at'] as String),
    );
  }
}
