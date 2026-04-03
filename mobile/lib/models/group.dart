class Group {
  final String id;
  final String name;
  final DateTime insertedAt;
  final int sharingCount;

  const Group({
    required this.id,
    required this.name,
    required this.insertedAt,
    this.sharingCount = 0,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      insertedAt: DateTime.parse(json['inserted_at'] as String),
      sharingCount: (json['sharing_count'] as int?) ?? 0,
    );
  }
}

class GroupMember {
  final String id;
  final String displayName;
  final String? email;
  final String role;
  final DateTime joinedAt;

  const GroupMember({
    required this.id,
    required this.displayName,
    this.email,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      email: json['email'] as String?,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
