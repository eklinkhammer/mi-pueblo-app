import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:fence/models/subscription.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/services/revenuecat_service.dart';

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, UserSubscription?>(
        SubscriptionNotifier.new);

class SubscriptionNotifier extends AsyncNotifier<UserSubscription?> {
  @override
  Future<UserSubscription?> build() async {
    final auth = ref.watch(authProvider);
    if (auth.status != AuthStatus.authenticated) return null;
    return _fetch();
  }

  Future<UserSubscription?> _fetch() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.getSubscription_();
    return UserSubscription.fromJson(response.data!);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

final subscriptionLimitsProvider =
    FutureProvider<List<TierInfo>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.getSubscriptionLimits();
  final data = response.data!;
  return (data['tiers'] as List<dynamic>)
      .map((t) => TierInfo.fromJson(t as Map<String, dynamic>))
      .toList();
});

final offeringsProvider = FutureProvider<Offerings?>((ref) async {
  return RevenueCatService.getOfferings();
});

final canCreateGroupProvider = Provider<bool>((ref) {
  final sub = ref.watch(subscriptionProvider).valueOrNull;
  return sub?.canCreateGroup ?? true;
});
