class GroupNotificationPreferences {
  final bool notifyHousehold;
  final bool notifyHomeActivity;

  const GroupNotificationPreferences({
    required this.notifyHousehold,
    required this.notifyHomeActivity,
  });

  factory GroupNotificationPreferences.fromJson(Map<String, dynamic> json) {
    return GroupNotificationPreferences(
      notifyHousehold: json['notify_household'] as bool,
      notifyHomeActivity: json['notify_home_activity'] as bool,
    );
  }
}
