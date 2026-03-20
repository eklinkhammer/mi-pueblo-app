class User {
  final String id;
  final String email;
  final String displayName;
  final DateTime insertedAt;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.insertedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      insertedAt: DateTime.parse(json['inserted_at'] as String),
    );
  }
}
