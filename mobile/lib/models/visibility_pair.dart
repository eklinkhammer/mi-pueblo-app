class VisibilityPair {
  final String id;
  final String otherUserId;
  final String otherDisplayName;
  final String status;
  final String? grantedById;
  final DateTime? grantedAt;

  const VisibilityPair({
    required this.id,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.status,
    this.grantedById,
    this.grantedAt,
  });

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';

  factory VisibilityPair.fromJson(Map<String, dynamic> json) {
    return VisibilityPair(
      id: json['id'] as String,
      otherUserId: json['other_user_id'] as String,
      otherDisplayName: json['other_display_name'] as String,
      status: json['status'] as String,
      grantedById: json['granted_by_id'] as String?,
      grantedAt: json['granted_at'] != null
          ? DateTime.parse(json['granted_at'] as String)
          : null,
    );
  }
}
