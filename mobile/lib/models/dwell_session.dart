class DwellSession {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final double latitude;
  final double longitude;
  final String? displayName;
  final String? category;
  final int? pointCount;

  const DwellSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    required this.latitude,
    required this.longitude,
    this.displayName,
    this.category,
    this.pointCount,
  });

  factory DwellSession.fromJson(Map<String, dynamic> json) {
    return DwellSession(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      displayName: json['display_name'] as String?,
      category: json['category'] as String?,
      pointCount: json['point_count'] as int?,
    );
  }

  String get formattedDuration {
    if (durationSeconds == null) return '';
    final d = Duration(seconds: durationSeconds!);
    if (d.inMinutes < 1) return '<1m';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  String get displayCategory {
    if (category == null) return '';
    return category!.replaceAll('_', ' ');
  }
}
