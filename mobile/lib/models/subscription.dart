enum SubscriptionTier {
  villageMember,
  villageElder,
  villageLeader;

  static SubscriptionTier fromString(String value) {
    switch (value) {
      case 'village_elder':
        return SubscriptionTier.villageElder;
      case 'village_leader':
        return SubscriptionTier.villageLeader;
      default:
        return SubscriptionTier.villageMember;
    }
  }

  String get apiValue {
    switch (this) {
      case SubscriptionTier.villageMember:
        return 'village_member';
      case SubscriptionTier.villageElder:
        return 'village_elder';
      case SubscriptionTier.villageLeader:
        return 'village_leader';
    }
  }
}

class TierLimits {
  final int maxGroups; // -1 = unlimited
  final int maxMembers;
  final int maxGeofences; // -1 = unlimited
  final int historyDays;

  const TierLimits({
    required this.maxGroups,
    required this.maxMembers,
    required this.maxGeofences,
    required this.historyDays,
  });

  bool get unlimitedGroups => maxGroups == -1;
  bool get unlimitedGeofences => maxGeofences == -1;

  factory TierLimits.fromJson(Map<String, dynamic> json) {
    return TierLimits(
      maxGroups: json['max_groups'] as int,
      maxMembers: json['max_members'] as int,
      maxGeofences: json['max_geofences'] as int,
      historyDays: json['history_days'] as int,
    );
  }
}

class UserSubscription {
  final SubscriptionTier tier;
  final String status;
  final String? store;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? expiresAt;
  final TierLimits limits;
  final int groupsCreated;

  const UserSubscription({
    required this.tier,
    required this.status,
    this.store,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.expiresAt,
    required this.limits,
    required this.groupsCreated,
  });

  bool get isActive => status == 'active' || status == 'grace_period';
  bool get isFree => tier == SubscriptionTier.villageMember;

  bool get canCreateGroup {
    if (limits.unlimitedGroups) return true;
    return groupsCreated < limits.maxGroups;
  }

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'] as Map<String, dynamic>;
    final limits = json['limits'] as Map<String, dynamic>;
    final usage = json['usage'] as Map<String, dynamic>;

    return UserSubscription(
      tier: SubscriptionTier.fromString(sub['tier'] as String),
      status: sub['status'] as String,
      store: sub['store'] as String?,
      currentPeriodStart: sub['current_period_start'] != null
          ? DateTime.parse(sub['current_period_start'] as String)
          : null,
      currentPeriodEnd: sub['current_period_end'] != null
          ? DateTime.parse(sub['current_period_end'] as String)
          : null,
      expiresAt: sub['expires_at'] != null
          ? DateTime.parse(sub['expires_at'] as String)
          : null,
      limits: TierLimits.fromJson(limits),
      groupsCreated: usage['groups_created'] as int,
    );
  }
}

class TierInfo {
  final String tier;
  final TierLimits limits;

  const TierInfo({required this.tier, required this.limits});

  factory TierInfo.fromJson(Map<String, dynamic> json) {
    return TierInfo(
      tier: json['tier'] as String,
      limits: TierLimits.fromJson(json['limits'] as Map<String, dynamic>),
    );
  }
}
