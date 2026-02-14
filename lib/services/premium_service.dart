import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat configuration constants
class RevenueCatConfig {
  static const String apiKey = 'test_HJkJTgplbAzOatkthKPMCNjXHDk';
  static const String entitlementId = 'Project Launcher Pro';

  /// Product identifiers configured in RevenueCat
  static const String monthlyProductId = 'monthly';
  static const String yearlyProductId = 'yearly';
  static const String lifetimeProductId = 'lifetime';
}

class PremiumService {
  static bool _isConfigured = false;

  /// Initialize RevenueCat SDK. Call once at app startup.
  static Future<void> configure() async {
    if (_isConfigured) return;

    await Purchases.setLogLevel(LogLevel.debug);

    final configuration = PurchasesConfiguration(RevenueCatConfig.apiKey);
    await Purchases.configure(configuration);

    _isConfigured = true;
    log('RevenueCat SDK configured');
  }

  /// Check if the user has an active Pro entitlement
  static Future<bool> isPro() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[RevenueCatConfig.entitlementId]?.isActive ?? false;
    } on PlatformException catch (e) {
      log('Error checking pro status: $e');
      return false;
    }
  }

  /// Get current customer info
  static Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } on PlatformException catch (e) {
      log('Error getting customer info: $e');
      return null;
    }
  }

  /// Get available offerings (product packages)
  static Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        return offerings;
      }
      return null;
    } on PlatformException catch (e) {
      log('Error fetching offerings: $e');
      return null;
    }
  }

  /// Purchase a package and return whether the Pro entitlement is now active
  static Future<PremiumResult> purchase(Package package) async {
    try {
      final purchaseParams = PurchaseParams.package(package);
      final result = await Purchases.purchase(purchaseParams);
      final isActive = result.customerInfo.entitlements.all[RevenueCatConfig.entitlementId]?.isActive ?? false;

      if (isActive) {
        return const PremiumResult(
          success: true,
          message: 'Welcome to Pro! All premium features are now unlocked.',
        );
      } else {
        return const PremiumResult(
          success: false,
          message: 'Purchase completed but entitlement not active. Please contact support.',
        );
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return const PremiumResult(
          success: false,
          message: 'Purchase cancelled.',
        );
      }
      return PremiumResult(
        success: false,
        message: 'Purchase failed: ${e.message ?? 'Unknown error'}',
      );
    }
  }

  /// Restore previous purchases
  static Future<PremiumResult> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isActive = customerInfo.entitlements.all[RevenueCatConfig.entitlementId]?.isActive ?? false;

      if (isActive) {
        return const PremiumResult(
          success: true,
          message: 'Purchases restored! Pro features are now active.',
        );
      } else {
        return const PremiumResult(
          success: false,
          message: 'No active Pro subscription found to restore.',
        );
      }
    } on PlatformException catch (e) {
      return PremiumResult(
        success: false,
        message: 'Restore failed: ${e.message ?? 'Unknown error'}',
      );
    }
  }

  /// Listen for customer info changes (e.g. subscription renewal/expiry)
  static void addCustomerInfoListener(void Function(CustomerInfo) listener) {
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  /// Get the active subscription details if any
  static Future<SubscriptionStatus> getSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.all[RevenueCatConfig.entitlementId];

      if (entitlement == null || !entitlement.isActive) {
        return const SubscriptionStatus(isActive: false);
      }

      return SubscriptionStatus(
        isActive: true,
        productIdentifier: entitlement.productIdentifier,
        expirationDate: entitlement.expirationDate != null
            ? DateTime.tryParse(entitlement.expirationDate!)
            : null,
        willRenew: entitlement.willRenew,
        periodType: entitlement.periodType,
      );
    } on PlatformException catch (e) {
      log('Error getting subscription status: $e');
      return const SubscriptionStatus(isActive: false);
    }
  }
}

/// Result of a purchase or restore attempt
class PremiumResult {
  final bool success;
  final String message;

  const PremiumResult({
    required this.success,
    required this.message,
  });
}

/// Current subscription status details
class SubscriptionStatus {
  final bool isActive;
  final String? productIdentifier;
  final DateTime? expirationDate;
  final bool? willRenew;
  final PeriodType? periodType;

  const SubscriptionStatus({
    required this.isActive,
    this.productIdentifier,
    this.expirationDate,
    this.willRenew,
    this.periodType,
  });

  String get planName {
    if (!isActive) return 'Free';
    switch (productIdentifier) {
      case RevenueCatConfig.monthlyProductId:
        return 'Pro Monthly';
      case RevenueCatConfig.yearlyProductId:
        return 'Pro Yearly';
      case RevenueCatConfig.lifetimeProductId:
        return 'Pro Lifetime';
      default:
        return 'Pro';
    }
  }

  bool get isLifetime => productIdentifier == RevenueCatConfig.lifetimeProductId;
}
