import 'package:flutter/material.dart';
import '../services/premium_service.dart';
import 'package:launcher_theme/launcher_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  final VoidCallback? onStatusChanged;

  const SubscriptionScreen({super.key, this.onStatusChanged});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  SubscriptionStatus _status = const SubscriptionStatus(isActive: false);
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final status = await PremiumService.getSubscriptionStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = const SubscriptionStatus(isActive: false);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifySubscription() async {
    setState(() => _isProcessing = true);
    final result = await PremiumService.verifySubscription();
    setState(() => _isProcessing = false);

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

  Future<void> _manageSubscription() async {
    try {
      await PremiumService.openBillingPortal();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open billing portal. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 24, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Text(
                  'Subscription',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isProcessing ? null : _verifySubscription,
                  child: Text(
                    'Verify Subscription',
                    style: AppTypography.inter(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: SizedBox(
                      width: 32, height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    ),
                  )
                : _isProcessing
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32, height: 32,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                            ),
                            const SizedBox(height: 16),
                            Text('Processing...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: _status.isActive ? _buildActiveView(cs) : _buildFreeView(cs),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Active subscriber view ──

  Widget _buildActiveView(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCurrentPlanCard(cs),
        const SizedBox(height: 24),
        _buildFeaturesIncluded(cs),
        const SizedBox(height: 24),
        _buildBillingSection(cs),
        const SizedBox(height: 24),
        _buildQuickActions(cs),
      ],
    );
  }

  Widget _buildCurrentPlanCard(ColorScheme cs) {
    final gold = const Color(0xFFFFD700);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gold.withValues(alpha: 0.12), gold.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(Icons.workspace_premium, color: gold, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _status.planName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: gold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_status.isTrial ? AppColors.warning : _status.isPromo ? AppColors.accent : AppColors.success).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            _status.isTrial ? 'TRIAL' : _status.isPromo ? 'PROMO' : 'ACTIVE',
                            style: AppTypography.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _status.isTrial ? AppColors.warning : _status.isPromo ? AppColors.accent : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subscriptionSubtitle(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _subscriptionSubtitle() {
    if (_status.isLifetime) return 'Lifetime access — never expires';
    if (_status.isPromo && _status.daysRemaining != null) {
      return 'Promo active — ${_status.daysRemaining} days remaining';
    }
    if (_status.expirationDate != null) {
      final dateStr = _formatDate(_status.expirationDate!);
      if (_status.willRenew == true) return 'Auto-renews on $dateStr';
      return 'Expires on $dateStr';
    }
    return 'Active subscription';
  }

  Widget _buildFeaturesIncluded(ColorScheme cs) {
    final features = [
      _FeatureItem(Icons.insights_rounded, 'Year in Review', 'Visualize your coding journey with stats & charts'),
      _FeatureItem(Icons.palette_rounded, 'All Premium Themes', 'Midnight, Ocean, and all future themes'),
      _FeatureItem(Icons.trending_up_rounded, 'Health History', 'Track how project health changes over time'),
      _FeatureItem(Icons.support_agent_rounded, 'Priority Support', 'Get help faster with priority queue access'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INCLUDED IN YOUR PLAN',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: features.asMap().entries.map((entry) {
              final i = entry.key;
              final f = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: i < features.length - 1
                      ? Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1)))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(f.icon, size: 18, color: AppColors.accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface)),
                          const SizedBox(height: 2),
                          Text(f.subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBillingSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BILLING', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              _billingRow(cs, 'Plan', _status.planName),
              if (_status.expirationDate != null && !_status.isLifetime) ...[
                _billingDivider(cs),
                _billingRow(
                  cs,
                  _status.willRenew == true ? 'Next billing date' : 'Expires',
                  _formatDate(_status.expirationDate!),
                ),
              ],
              if (_status.isTrial && _status.daysRemaining != null) ...[
                _billingDivider(cs),
                _billingRow(
                  cs,
                  'Trial remaining',
                  '${_status.daysRemaining} day${_status.daysRemaining == 1 ? '' : 's'}',
                  valueColor: AppColors.warning,
                ),
              ],
              if (_status.isPromo && _status.daysRemaining != null) ...[
                _billingDivider(cs),
                _billingRow(
                  cs,
                  'Promo remaining',
                  '${_status.daysRemaining} day${_status.daysRemaining == 1 ? '' : 's'}',
                  valueColor: AppColors.accent,
                ),
              ],
              if (_status.isPromo && _status.productIdentifier != null) ...[
                _billingDivider(cs),
                _billingRow(cs, 'Promo code', _status.productIdentifier!),
              ],
              _billingDivider(cs),
              _billingRow(
                cs,
                'Status',
                _status.isPromo
                    ? 'Promo active'
                    : _status.isTrial
                        ? 'Free trial'
                        : _status.willRenew == true
                            ? 'Auto-renewing'
                            : _status.isLifetime
                                ? 'Lifetime'
                                : 'Not renewing',
                valueColor: _status.willRenew == true || _status.isLifetime || _status.isPromo ? AppColors.success : AppColors.warning,
              ),
              if (!_status.isPromo) ...[
                _billingDivider(cs),
                _billingRow(cs, 'Payment', 'Paddle'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _billingRow(ColorScheme cs, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          Text(value, style: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? cs.onSurface)),
        ],
      ),
    );
  }

  Widget _billingDivider(ColorScheme cs) {
    return Divider(height: 1, color: cs.outline.withValues(alpha: 0.1));
  }

  Widget _buildQuickActions(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MANAGE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(
          children: [
            if (!_status.isLifetime)
              Expanded(
                child: _ActionButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Change Plan',
                  onTap: _manageSubscription,
                ),
              ),
            if (!_status.isLifetime) const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.receipt_long_rounded,
                label: 'Billing Portal',
                onTap: _manageSubscription,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.help_outline_rounded,
                label: 'Get Support',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact support@projectlauncher.dev for help'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Free user view ──

  Future<void> _startPaddleCheckout(String priceId) async {
    setState(() => _isProcessing = true);

    try {
      await PremiumService.openCheckout(priceId: priceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete your purchase in the browser. We\'ll activate your subscription automatically.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }

      final activated = await PremiumService.pollForActivation();

      if (mounted) {
        if (activated) {
          widget.onStatusChanged?.call();
          await _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome to Pro! All premium features are now unlocked.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() => _isProcessing = false);
          _showManualVerifyDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open checkout. Please check your internet connection.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showManualVerifyDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: const Text('Verify Purchase'),
        content: const Text(
          'If you completed your purchase in the browser, '
          'tap "Check Status" to activate your subscription. '
          'It may take a moment for the payment to process.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isProcessing = true);
              final activated = await PremiumService.pollForActivation(
                timeout: const Duration(seconds: 15),
              );
              if (mounted) {
                setState(() => _isProcessing = false);
                if (activated) {
                  widget.onStatusChanged?.call();
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subscription not yet active. If you completed payment, try again in a moment.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Check Status'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog() {
    final cs = Theme.of(context).colorScheme;
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: const Text('Restore Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the email you used for your Paddle purchase to restore your subscription.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                hintText: 'your@email.com',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              Navigator.of(ctx).pop();

              setState(() => _isProcessing = true);
              final result = await PremiumService.linkCustomer(email);
              if (mounted) {
                setState(() => _isProcessing = false);
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
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showPromoCodeDialog() {
    final cs = Theme.of(context).colorScheme;
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.card_giftcard_rounded, color: AppColors.accent, size: 22),
            const SizedBox(width: 8),
            const Text('Redeem Promo Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your promo code to unlock Pro features for free.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. LAUNCH6M',
                hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.confirmation_number_outlined, color: AppColors.accent, size: 20),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: AppTypography.mono(fontSize: 16, color: cs.onSurface),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              Navigator.of(ctx).pop();

              setState(() => _isProcessing = true);
              final result = await PremiumService.redeemPromoCode(code);
              if (mounted) {
                setState(() => _isProcessing = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          result.success ? Icons.check_circle : Icons.error_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(result.message)),
                      ],
                    ),
                    backgroundColor: result.success ? AppColors.success : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                if (result.success) {
                  widget.onStatusChanged?.call();
                  _loadData();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Redeem', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeView(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHero(cs),
        const SizedBox(height: 32),
        Text(
          'CHOOSE YOUR PLAN',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),
        _buildPricingCards(cs),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _showRestoreDialog,
              child: Text(
                'Restore Purchases',
                style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
            Text('·', style: TextStyle(color: cs.onSurfaceVariant)),
            TextButton(
              onPressed: _showPromoCodeDialog,
              child: Text(
                'Have a Promo Code?',
                style: AppTypography.inter(fontSize: 12, color: AppColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildFeatureComparison(cs),
        const SizedBox(height: 24),
        _buildFAQ(cs),
      ],
    );
  }

  Widget _buildHero(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.1),
            const Color(0xFFE879F9).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium, size: 40, color: Color(0xFFFFD700)),
          ),
          const SizedBox(height: 20),
          Text(
            'Upgrade to Pro',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock premium themes, Year in Review, health trends,\nand more. Start with a 6-month free trial.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCards(ColorScheme cs) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: _PricingCard(
          title: 'Pro Monthly',
          price: '\$100',
          period: '/month',
          badge: '6 MONTHS FREE TRIAL',
          badgeColor: AppColors.accent,
          isHighlighted: true,
          features: [
            'All premium themes',
            'Year in Review',
            'Health history & trends',
            'Priority support',
            'Cancel anytime',
          ],
          onSubscribe: () => _startPaddleCheckout(PaddleConfig.monthlyPriceId),
        ),
      ),
    );
  }

  Widget _buildFeatureComparison(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FEATURE COMPARISON', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('Feature', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant))),
                    Expanded(child: Center(child: Text('Free', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)))),
                    Expanded(child: Center(child: Text('Pro', style: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFFFD700))))),
                  ],
                ),
              ),
              _featureRow(cs, 'Project management', true, true),
              _featureRow(cs, 'Health scores', true, true),
              _featureRow(cs, 'Light & Dark themes', true, true),
              _featureRow(cs, 'Referral rewards', true, true),
              _featureRow(cs, 'Year in Review', false, true),
              _featureRow(cs, 'Premium themes', false, true),
              _featureRow(cs, 'Health history & trends', false, true),
              _featureRow(cs, 'Priority support', false, true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featureRow(ColorScheme cs, String feature, bool inFree, bool inPro) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(feature, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface))),
          Expanded(
            child: Center(
              child: Icon(
                inFree ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                color: inFree ? AppColors.success : cs.onSurfaceVariant.withValues(alpha: 0.2),
                size: 18,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                inPro ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                color: inPro ? const Color(0xFFFFD700) : cs.onSurfaceVariant.withValues(alpha: 0.2),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ(ColorScheme cs) {
    final faqs = [
      _FAQItem('Can I cancel anytime?', 'Yes! Monthly and yearly subscriptions can be cancelled at any time through your billing portal. You\'ll keep access until the end of your billing period.'),
      _FAQItem('What happens to my data if I cancel?', 'All your projects and settings are kept. You just lose access to premium features like Year in Review and premium themes.'),
      _FAQItem('Is the lifetime plan really forever?', 'Yes — one purchase gives you permanent access to all current and future Pro features.'),
      _FAQItem('How are payments handled?', 'Payments are securely processed by Paddle, a trusted payment provider. They handle tax and compliance globally.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FAQ', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ...faqs.map((faq) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: const Border(),
            title: Text(faq.question, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface)),
            children: [
              Text(faq.answer, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.5)),
            ],
          ),
        )),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ── Supporting classes ──

class _Plan {
  final String priceId;
  final String title;
  final String price;
  final String period;
  final String? badge;
  final Color? badgeColor;
  final bool isHighlighted;
  final List<String> features;
  const _Plan(this.priceId, this.title, this.price, this.period, this.badge, this.badgeColor, this.isHighlighted, this.features);
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureItem(this.icon, this.title, this.subtitle);
}

class _FAQItem {
  final String question;
  final String answer;
  const _FAQItem(this.question, this.answer);
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered ? cs.surfaceContainerHighest : cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: _isHovered ? 0.3 : 0.15)),
          ),
          child: Column(
            children: [
              Icon(widget.icon, size: 22, color: cs.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingCard extends StatefulWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final Color? badgeColor;
  final bool isHighlighted;
  final List<String> features;
  final VoidCallback onSubscribe;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    this.badgeColor,
    this.isHighlighted = false,
    required this.features,
    required this.onSubscribe,
  });

  @override
  State<_PricingCard> createState() => _PricingCardState();
}

class _PricingCardState extends State<_PricingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = widget.isHighlighted
        ? AppColors.accent.withValues(alpha: 0.5)
        : cs.outline.withValues(alpha: _isHovered ? 0.3 : 0.15);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isHovered ? cs.surfaceContainerHighest : cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: borderColor, width: widget.isHighlighted ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (widget.badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (widget.badgeColor ?? AppColors.accent).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      widget.badge!,
                      style: AppTypography.inter(fontSize: 9, fontWeight: FontWeight.w700, color: widget.badgeColor ?? AppColors.accent),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(widget.price, style: AppTypography.mono(fontSize: 28, fontWeight: FontWeight.w700, color: cs.onSurface)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(widget.period, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...widget.features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
                ],
              ),
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isHighlighted ? AppColors.accent : cs.surfaceContainerHighest,
                  foregroundColor: widget.isHighlighted ? Colors.black : cs.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: Text(widget.isHighlighted ? 'Subscribe' : 'Choose'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
