class MemberLocation {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? speed;
  final double? batteryLevel;
  final DateTime updatedAt;

  const MemberLocation({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.speed,
    this.batteryLevel,
    required this.updatedAt,
  });

  factory MemberLocation.fromJson(Map<String, dynamic> json) {
    return MemberLocation(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      batteryLevel: (json['battery_level'] as num?)?.toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
