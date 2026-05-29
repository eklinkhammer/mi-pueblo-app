import 'dart:async';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static bool _initialized = false;

  static Future<void> initialize(String userId) async {
    if (_initialized) return;

    // TODO: Replace with actual RevenueCat API keys from dashboard
    const apiKey = String.fromEnvironment(
      'REVENUECAT_API_KEY',
      defaultValue: '',
    );

    if (apiKey.isEmpty) return;

    final configuration = PurchasesConfiguration(apiKey)..appUserID = userId;
    await Purchases.configure(configuration);
    _initialized = true;
  }

  static Future<Offerings?> getOfferings() async {
    if (!_initialized) return null;
    try {
      return Purchases.getOfferings();
    } on Exception {
      return null;
    }
  }

  static Future<CustomerInfo?> purchase(Package package) async {
    if (!_initialized) return null;
    return Purchases.purchasePackage(package);
  }

  static Future<CustomerInfo?> restorePurchases() async {
    if (!_initialized) return null;
    return Purchases.restorePurchases();
  }
}
