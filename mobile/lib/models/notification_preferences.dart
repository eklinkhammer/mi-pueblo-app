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

class MemberNotificationPreference {
  final String subjectId;
  final bool notify;
  final bool notifyHome;

  const MemberNotificationPreference({
    required this.subjectId,
    required this.notify,
    required this.notifyHome,
  });

  factory MemberNotificationPreference.fromJson(Map<String, dynamic> json) {
    return MemberNotificationPreference(
      subjectId: json['subject_id'] as String,
      notify: json['notify'] as bool,
      notifyHome: json['notify_home'] as bool,
    );
  }
}
