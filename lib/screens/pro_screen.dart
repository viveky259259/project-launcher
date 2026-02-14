import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../services/premium_service.dart';
import '../kit/kit.dart';

class ProScreen extends StatefulWidget {
  final VoidCallback? onStatusChanged;

  const ProScreen({super.key, this.onStatusChanged});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  bool _isLoading = true;
  SubscriptionStatus _status = const SubscriptionStatus(isActive: false);
  Offerings? _offerings;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final status = await PremiumService.getSubscriptionStatus();
    final offerings = await PremiumService.getOfferings();

    if (mounted) {
      setState(() {
        _status = status;
        _offerings = offerings;
        _isLoading = false;
      });
    }
  }

  Future<void> _presentPaywall() async {
    final paywallResult = await RevenueCatUI.presentPaywallIfNeeded(
      RevenueCatConfig.entitlementId,
    );
    log('Paywall result: $paywallResult');
    widget.onStatusChanged?.call();
    _loadData();
  }

  Future<void> _presentCustomerCenter() async {
    await RevenueCatUI.presentCustomerCenter();
    widget.onStatusChanged?.call();
    _loadData();
  }

  Future<void> _purchasePackage(Package package) async {
    final result = await PremiumService.purchase(package);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (result.success) {
        widget.onStatusChanged?.call();
        _loadData();
      }
    }
  }

  Future<void> _restorePurchases() async {
    final result = await PremiumService.restorePurchases();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (result.success) {
        widget.onStatusChanged?.call();
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Launcher Pro'),
        actions: [
          if (_status.isActive)
            IconButton(
              icon: const Icon(Icons.manage_accounts_rounded),
              onPressed: _presentCustomerCenter,
              tooltip: 'Manage Subscription',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_status.isActive)
                    _buildActivatedCard(cs)
                  else
                    _buildUpgradeCard(cs),
                  const SizedBox(height: 32),
                  _buildComparisonTable(cs),
                  if (!_status.isActive) ...[
                    const SizedBox(height: 32),
                    if (_offerings != null)
                      _buildOfferingsSection(cs)
                    else
                      _buildPaywallButton(cs),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _restorePurchases,
                        child: Text(
                          'Restore Purchases',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildActivatedCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.15),
            const Color(0xFFFFA500).withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _status.planName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFFD700),
                          ),
                    ),
                    if (_status.expirationDate != null && !_status.isLifetime)
                      Text(
                        _status.willRenew == true
                            ? 'Renews ${_formatDate(_status.expirationDate!)}'
                            : 'Expires ${_formatDate(_status.expirationDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      )
                    else if (_status.isLifetime)
                      Text(
                        'Lifetime access - never expires',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
              UkButton(
                label: 'Manage',
                variant: UkButtonVariant.outline,
                size: UkButtonSize.small,
                onPressed: _presentCustomerCenter,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'You have access to all premium features including Year in Review, all themes, and advanced health history.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.15),
            cs.tertiary.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Pro',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monthly, yearly, or lifetime plans available',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock Year in Review, all premium themes, advanced health history, and priority support.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Free vs Pro',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        _comparisonRow(cs, 'Project management', true, true),
        _comparisonRow(cs, 'Health scores & stale alerts', true, true),
        _comparisonRow(cs, 'Light & Dark themes', true, true),
        _comparisonRow(cs, 'Referral rewards', true, true),
        _comparisonRow(cs, 'Year in Review', false, true),
        _comparisonRow(cs, 'All premium themes', false, true),
        _comparisonRow(cs, 'Health history & trends', false, true),
        _comparisonRow(cs, 'Priority support', false, true),
      ],
    );
  }

  Widget _comparisonRow(ColorScheme cs, String feature, bool inFree, bool inPro) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                inFree ? Icons.check_circle : Icons.remove_circle_outline,
                color: inFree ? Colors.green : cs.onSurfaceVariant.withValues(alpha: 0.3),
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                inPro ? Icons.check_circle : Icons.remove_circle_outline,
                color: inPro ? const Color(0xFFFFD700) : cs.onSurfaceVariant.withValues(alpha: 0.3),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingsSection(ColorScheme cs) {
    final packages = _offerings!.current!.availablePackages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Plan',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        ...packages.map((pkg) => _PackageCard(
              package: pkg,
              onPurchase: () => _purchasePackage(pkg),
            )),
        const SizedBox(height: 12),
        Center(
          child: UkButton(
            label: 'View Full Paywall',
            variant: UkButtonVariant.outline,
            icon: Icons.storefront_rounded,
            onPressed: _presentPaywall,
          ),
        ),
      ],
    );
  }

  Widget _buildPaywallButton(ColorScheme cs) {
    return Center(
      child: UkButton(
        label: 'View Plans & Subscribe',
        variant: UkButtonVariant.primary,
        icon: Icons.workspace_premium,
        onPressed: _presentPaywall,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _PackageCard extends StatelessWidget {
  final Package package;
  final VoidCallback onPurchase;

  const _PackageCard({
    required this.package,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final product = package.storeProduct;
    final isLifetime = package.packageType == PackageType.lifetime;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onPurchase,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _packageTitle(package),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (isLifetime) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'BEST VALUE',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFFFFD700),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLifetime ? 'One-time purchase, never expires' : 'Cancel anytime',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                product.priceString,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _packageTitle(Package package) {
    switch (package.packageType) {
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.annual:
        return 'Yearly';
      case PackageType.lifetime:
        return 'Lifetime';
      default:
        return package.storeProduct.title;
    }
  }
}
