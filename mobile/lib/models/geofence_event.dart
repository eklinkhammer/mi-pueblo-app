class GeofenceEvent {
  final String id;
  final String event;
  final String geofenceId;
  final String geofenceName;
  final DateTime insertedAt;

  const GeofenceEvent({
    required this.id,
    required this.event,
    required this.geofenceId,
    required this.geofenceName,
    required this.insertedAt,
  });

  factory GeofenceEvent.fromJson(Map<String, dynamic> json) {
    return GeofenceEvent(
      id: json['id'] as String,
      event: json['event'] as String,
      geofenceId: json['geofence_id'] as String,
      geofenceName: json['geofence_name'] as String,
      insertedAt: DateTime.parse(json['inserted_at'] as String),
    );
  }
}
