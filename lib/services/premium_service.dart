import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Paddle Billing configuration
class PaddleConfig {
  // ── API (injected via --dart-define from .env) ──
  static const String apiKey = String.fromEnvironment('PADDLE_API_KEY');
  static const bool isSandbox =
      String.fromEnvironment('PADDLE_IS_SANDBOX', defaultValue: 'true') == 'true';

  static String get apiBaseUrl =>
      isSandbox ? 'https://sandbox-api.paddle.com' : 'https://api.paddle.com';

  // ── Price ID ──
  static const String monthlyPriceId = 'pri_01kk4w25sv27phfgq2tzwm802d';

  // ── URLs ──
  // Hosted checkout page with Paddle.js that reads price_id from URL params
  static const String checkoutBaseUrl =
      'https://projectbrowser.web.app';

  static const String billingPortalUrl =
      'https://projectbrowser.web.app/portal.html';
}

class PremiumService {
  static String? _appUserId;
  static String? _paddleCustomerId;
  static SubscriptionStatus? _cachedStatus;
  static final _statusController = StreamController<bool>.broadcast();

  /// Stream of pro status changes
  static Stream<bool> get proStatusStream => _statusController.stream;

  /// Get or create a persistent app user ID
  static Future<String> getAppUserId() async {
    if (_appUserId != null) return _appUserId!;

    final prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString('app_user_id');
    if (userId == null) {
      userId = 'plr_${const Uuid().v4()}';
      await prefs.setString('app_user_id', userId);
      log('Created new app user ID: $userId');
    }
    _appUserId = userId;
    return userId;
  }

  static Future<String?> _getPaddleCustomerId() async {
    if (_paddleCustomerId != null) return _paddleCustomerId;
    final prefs = await SharedPreferences.getInstance();
    _paddleCustomerId = prefs.getString('paddle_customer_id');
    return _paddleCustomerId;
  }

  static Future<void> _savePaddleCustomerId(String customerId) async {
    _paddleCustomerId = customerId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('paddle_customer_id', customerId);
  }

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer ${PaddleConfig.apiKey}',
        'Content-Type': 'application/json',
      };

  /// Initialize service. Call once at app startup.
  static Future<void> configure() async {
    await getAppUserId();
    await _getPaddleCustomerId();
    log('Paddle service configured (sandbox: ${PaddleConfig.isSandbox})');
  }

  /// Check if the user has an active Pro subscription
  static Future<bool> isPro() async {
    final status = await getSubscriptionStatus();
    return status.isActive;
  }

  // ─── Checkout ───

  /// Open Paddle checkout in the browser for a given price ID.
  static Future<void> openCheckout({required String priceId}) async {
    final userId = await getAppUserId();
    final customerId = await _getPaddleCustomerId();

    final params = <String, String>{
      'price_id': priceId,
      'custom_data': jsonEncode({'app_user_id': userId}),
    };
    if (customerId != null) {
      params['customer_id'] = customerId;
    }

    final uri = Uri.parse(PaddleConfig.checkoutBaseUrl)
        .replace(queryParameters: params);

    await Process.run('open', [uri.toString()]);
    log('Opened Paddle checkout: $uri');
  }

  /// Open the billing portal for subscription management.
  static Future<void> openBillingPortal() async {
    final customerId = await _getPaddleCustomerId();
    if (customerId != null) {
      final url = '${PaddleConfig.billingPortalUrl}?customer_id=$customerId';
      await Process.run('open', [url]);
    }
  }

  // ─── Subscription Status ───

  /// Get subscription status (uses 1-hour cache).
  static Future<SubscriptionStatus> getSubscriptionStatus() async {
    // Return memory cache if fresh
    if (_cachedStatus != null) {
      final prefs = await SharedPreferences.getInstance();
      final cachedAt = prefs.getInt('subscription_cached_at') ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age < 3600000) return _cachedStatus!; // 1 hour cache
    }

    return _fetchAndCacheStatus();
  }

  /// Force refresh subscription status from Paddle API.
  static Future<SubscriptionStatus> refreshSubscriptionStatus() async {
    return _fetchAndCacheStatus();
  }

  static Future<SubscriptionStatus> _fetchAndCacheStatus() async {
    final customerId = await _getPaddleCustomerId();
    if (customerId == null) {
      _cachedStatus = const SubscriptionStatus(isActive: false);
      return _cachedStatus!;
    }

    try {
      final uri = Uri.parse('${PaddleConfig.apiBaseUrl}/subscriptions')
          .replace(queryParameters: {
        'customer_id': customerId,
        'status': 'active',
      });

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final subs = data['data'] as List;

        if (subs.isNotEmpty) {
          final sub = subs.first;
          final items = sub['items'] as List? ?? [];
          String? priceId;
          if (items.isNotEmpty) {
            priceId = items[0]['price']?['id'] as String?;
          }
          final nextBilledAt = sub['next_billed_at'] as String?;
          final scheduledChange = sub['scheduled_change'];
          final willRenew = scheduledChange?['action'] != 'cancel';
          final collectionMode = sub['collection_mode'] as String?;
          final status = sub['status'] as String?;

          final subStatus = SubscriptionStatus(
            isActive: true,
            subscriptionId: sub['id'] as String?,
            productIdentifier: priceId,
            expirationDate:
                nextBilledAt != null ? DateTime.tryParse(nextBilledAt) : null,
            willRenew: willRenew,
            isTrial: status == 'trialing',
            collectionMode: collectionMode,
          );

          // Cache it
          _cachedStatus = subStatus;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'subscription_status', jsonEncode(subStatus.toJson()));
          await prefs.setInt(
              'subscription_cached_at', DateTime.now().millisecondsSinceEpoch);

          _statusController.add(true);
          return subStatus;
        }
      }
    } catch (e) {
      log('Error fetching Paddle subscription status: $e');
    }

    _cachedStatus = const SubscriptionStatus(isActive: false);
    _statusController.add(false);
    return _cachedStatus!;
  }

  // ─── Post-Purchase Polling ───

  /// Poll Paddle API for subscription activation after a checkout.
  /// Returns true if a subscription becomes active within the timeout.
  static Future<bool> pollForActivation({
    Duration timeout = const Duration(minutes: 5),
    Duration interval = const Duration(seconds: 4),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      await Future.delayed(interval);

      try {
        final status = await refreshSubscriptionStatus();
        if (status.isActive) {
          log('Subscription activated after ${stopwatch.elapsed.inSeconds}s');
          return true;
        }
      } catch (e) {
        log('Polling error: $e');
      }
    }

    log('Polling timed out after ${timeout.inSeconds}s');
    return false;
  }

  // ─── Restore / Verify ───

  /// Manually verify subscription by refreshing from Paddle API.
  static Future<PremiumResult> verifySubscription() async {
    try {
      final status = await refreshSubscriptionStatus();
      if (status.isActive) {
        return const PremiumResult(
          success: true,
          message: 'Subscription verified! Pro features are now active.',
        );
      }
      return const PremiumResult(
        success: false,
        message: 'No active subscription found. Complete your purchase first.',
      );
    } catch (e) {
      return PremiumResult(
        success: false,
        message: 'Verification failed: $e',
      );
    }
  }

  /// Link an existing Paddle customer ID (e.g. from email lookup).
  static Future<PremiumResult> linkCustomer(String email) async {
    try {
      final uri = Uri.parse('${PaddleConfig.apiBaseUrl}/customers')
          .replace(queryParameters: {'email': email});

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final customers = data['data'] as List;

        if (customers.isNotEmpty) {
          final customerId = customers.first['id'] as String;
          await _savePaddleCustomerId(customerId);

          final status = await refreshSubscriptionStatus();
          if (status.isActive) {
            return const PremiumResult(
              success: true,
              message: 'Account linked! Pro features are now active.',
            );
          }
          return const PremiumResult(
            success: false,
            message:
                'Account found but no active subscription. Purchase a plan to get Pro.',
          );
        }
      }

      return const PremiumResult(
        success: false,
        message: 'No account found for that email.',
      );
    } catch (e) {
      return PremiumResult(
        success: false,
        message: 'Failed to link account: $e',
      );
    }
  }

  // ─── Subscription Management ───

  /// Cancel the current subscription.
  static Future<PremiumResult> cancelSubscription() async {
    final status = await getSubscriptionStatus();
    if (!status.isActive || status.subscriptionId == null) {
      return const PremiumResult(
        success: false,
        message: 'No active subscription to cancel.',
      );
    }

    try {
      final response = await http.post(
        Uri.parse(
            '${PaddleConfig.apiBaseUrl}/subscriptions/${status.subscriptionId}/cancel'),
        headers: _headers,
        body: jsonEncode({'effective_from': 'next_billing_period'}),
      );

      if (response.statusCode == 200) {
        await refreshSubscriptionStatus();
        return const PremiumResult(
          success: true,
          message:
              'Subscription cancelled. You\'ll keep access until the end of your billing period.',
        );
      }

      return PremiumResult(
        success: false,
        message: 'Failed to cancel: ${response.statusCode}',
      );
    } catch (e) {
      return PremiumResult(
        success: false,
        message: 'Cancellation failed: $e',
      );
    }
  }

  /// Listen for pro status changes.
  static void addStatusListener(void Function(bool isPro) listener) {
    proStatusStream.listen(listener);
  }
}

/// Result of a purchase or verification attempt
class PremiumResult {
  final bool success;
  final String message;

  const PremiumResult({
    required this.success,
    required this.message,
  });
}

/// Current subscription status
class SubscriptionStatus {
  final bool isActive;
  final String? subscriptionId;
  final String? productIdentifier;
  final DateTime? expirationDate;
  final bool? willRenew;
  final bool isTrial;
  final String? collectionMode;

  const SubscriptionStatus({
    required this.isActive,
    this.subscriptionId,
    this.productIdentifier,
    this.expirationDate,
    this.willRenew,
    this.isTrial = false,
    this.collectionMode,
  });

  String get planName {
    if (!isActive) return 'Free';
    if (isTrial) return 'Pro Trial';
    return 'Pro Monthly';
  }

  bool get isLifetime => false;

  int? get daysRemaining {
    if (isLifetime || expirationDate == null) return null;
    final remaining = expirationDate!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  Map<String, dynamic> toJson() => {
        'isActive': isActive,
        'subscriptionId': subscriptionId,
        'productIdentifier': productIdentifier,
        'expirationDate': expirationDate?.toIso8601String(),
        'willRenew': willRenew,
        'isTrial': isTrial,
        'collectionMode': collectionMode,
      };

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isActive: json['isActive'] as bool? ?? false,
      subscriptionId: json['subscriptionId'] as String?,
      productIdentifier: json['productIdentifier'] as String?,
      expirationDate: json['expirationDate'] != null
          ? DateTime.tryParse(json['expirationDate'])
          : null,
      willRenew: json['willRenew'] as bool?,
      isTrial: json['isTrial'] as bool? ?? false,
      collectionMode: json['collectionMode'] as String?,
    );
  }
}
