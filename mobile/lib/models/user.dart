class User {
  final String id;
  final String? email;
  final String displayName;
  final bool isAnonymous;
  final String? avatarUrl;
  final DateTime insertedAt;

  const User({
    required this.id,
    this.email,
    required this.displayName,
    this.isAnonymous = false,
    this.avatarUrl,
    required this.insertedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      avatarUrl: json['avatar_url'] as String?,
      insertedAt: DateTime.parse(json['inserted_at'] as String),
    );
  }
}
