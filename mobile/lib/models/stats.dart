class GeofenceVisitStat {
  final String geofenceId;
  final String geofenceName;
  final int visitCount;

  const GeofenceVisitStat({
    required this.geofenceId,
    required this.geofenceName,
    required this.visitCount,
  });

  factory GeofenceVisitStat.fromJson(Map<String, dynamic> json) {
    return GeofenceVisitStat(
      geofenceId: json['geofence_id'] as String,
      geofenceName: json['geofence_name'] as String,
      visitCount: json['visit_count'] as int,
    );
  }
}

class CurrentGeofence {
  final String name;
  final double? latitude;
  final double? longitude;

  const CurrentGeofence({required this.name, this.latitude, this.longitude});

  factory CurrentGeofence.fromJson(Map<String, dynamic> json) {
    return CurrentGeofence(
      name: json['name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class HousemateStat {
  final String displayName;
  final List<CurrentGeofence> currentGeofences;
  final List<GeofenceVisitStat> topGeofences;

  const HousemateStat({
    required this.displayName,
    required this.currentGeofences,
    required this.topGeofences,
  });

  factory HousemateStat.fromJson(Map<String, dynamic> json) {
    return HousemateStat(
      displayName: json['display_name'] as String,
      currentGeofences: (json['current_geofences'] as List?)
              ?.map((e) => CurrentGeofence.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topGeofences: (json['top_geofences'] as List)
          .map((e) => GeofenceVisitStat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GroupStats {
  final String groupId;
  final String groupName;
  final String homeGeofenceName;
  final double? homeLatitude;
  final double? homeLongitude;
  final int homeVisitCount;
  final List<HousemateStat> housemates;
  final List<GeofenceVisitStat> yourTopGeofences;

  const GroupStats({
    required this.groupId,
    required this.groupName,
    required this.homeGeofenceName,
    this.homeLatitude,
    this.homeLongitude,
    required this.homeVisitCount,
    required this.housemates,
    required this.yourTopGeofences,
  });

  factory GroupStats.fromJson(Map<String, dynamic> json) {
    return GroupStats(
      groupId: json['group_id'] as String,
      groupName: json['group_name'] as String,
      homeGeofenceName: json['home_geofence_name'] as String,
      homeLatitude: (json['home_latitude'] as num?)?.toDouble(),
      homeLongitude: (json['home_longitude'] as num?)?.toDouble(),
      homeVisitCount: json['home_visit_count'] as int,
      housemates: (json['housemates'] as List)
          .map((e) => HousemateStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      yourTopGeofences: (json['your_top_geofences'] as List)
          .map((e) => GeofenceVisitStat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
