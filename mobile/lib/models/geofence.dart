class Geofence {
  final String id;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final DateTime expiresAt;
  final String groupId;
  final DateTime insertedAt;

  const Geofence({
    required this.id,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.expiresAt,
    required this.groupId,
    required this.insertedAt,
  });

  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      groupId: json['group_id'] as String,
      insertedAt: DateTime.parse(json['inserted_at'] as String),
    );
  }
}

class Resident {
  final String id;
  final String displayName;

  const Resident({required this.id, required this.displayName});

  factory Resident.fromJson(Map<String, dynamic> json) {
    return Resident(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
    );
  }
}

class GeofenceSubscription {
  final String id;
  final String geofenceId;
  final bool notifyOnEntry;
  final bool notifyOnExit;
  final List<String> blacklistedUserIds;
  final int throttleSeconds;

  const GeofenceSubscription({
    required this.id,
    required this.geofenceId,
    required this.notifyOnEntry,
    required this.notifyOnExit,
    required this.blacklistedUserIds,
    required this.throttleSeconds,
  });

  factory GeofenceSubscription.fromJson(Map<String, dynamic> json) {
    return GeofenceSubscription(
      id: json['id'] as String,
      geofenceId: json['geofence_id'] as String,
      notifyOnEntry: json['notify_on_entry'] as bool,
      notifyOnExit: json['notify_on_exit'] as bool,
      blacklistedUserIds: (json['blacklisted_user_ids'] as List)
          .map((e) => e as String)
          .toList(),
      throttleSeconds: json['throttle_seconds'] as int,
    );
  }
}
