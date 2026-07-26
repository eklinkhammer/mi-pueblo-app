class CategoryWatch {
  final String id;
  final String watchedUserId;
  final String? watchedUserName;
  final String category;
  final bool active;

  const CategoryWatch({
    required this.id,
    required this.watchedUserId,
    this.watchedUserName,
    required this.category,
    required this.active,
  });

  factory CategoryWatch.fromJson(Map<String, dynamic> json) {
    return CategoryWatch(
      id: json['id'] as String,
      watchedUserId: json['watched_user_id'] as String,
      watchedUserName: json['watched_user_name'] as String?,
      category: json['category'] as String,
      active: json['active'] as bool? ?? true,
    );
  }

  String get displayCategory {
    return category.replaceAll('_', ' ');
  }
}
