class GeofenceVisitStat {
  final String geofenceName;
  final int visitCount;

  const GeofenceVisitStat({required this.geofenceName, required this.visitCount});

  factory GeofenceVisitStat.fromJson(Map<String, dynamic> json) {
    return GeofenceVisitStat(
      geofenceName: json['geofence_name'] as String,
      visitCount: json['visit_count'] as int,
    );
  }
}

class HousemateStat {
  final String displayName;
  final List<GeofenceVisitStat> topGeofences;

  const HousemateStat({required this.displayName, required this.topGeofences});

  factory HousemateStat.fromJson(Map<String, dynamic> json) {
    return HousemateStat(
      displayName: json['display_name'] as String,
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
  final int homeVisitCount;
  final List<HousemateStat> housemates;
  final List<GeofenceVisitStat> yourTopGeofences;

  const GroupStats({
    required this.groupId,
    required this.groupName,
    required this.homeGeofenceName,
    required this.homeVisitCount,
    required this.housemates,
    required this.yourTopGeofences,
  });

  factory GroupStats.fromJson(Map<String, dynamic> json) {
    return GroupStats(
      groupId: json['group_id'] as String,
      groupName: json['group_name'] as String,
      homeGeofenceName: json['home_geofence_name'] as String,
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
