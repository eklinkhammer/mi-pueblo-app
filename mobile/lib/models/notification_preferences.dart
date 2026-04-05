class GroupNotificationPreferences {
  final bool silenceAllNotifications;
  final bool silenceHomeNotifications;
  final bool notifyHousehold;

  const GroupNotificationPreferences({
    required this.silenceAllNotifications,
    required this.silenceHomeNotifications,
    required this.notifyHousehold,
  });

  factory GroupNotificationPreferences.fromJson(Map<String, dynamic> json) {
    return GroupNotificationPreferences(
      silenceAllNotifications: json['silence_all_notifications'] as bool,
      silenceHomeNotifications: json['silence_home_notifications'] as bool,
      notifyHousehold: json['notify_household'] as bool,
    );
  }
}
