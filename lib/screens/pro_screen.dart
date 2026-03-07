import 'dart:developer';
import 'package:flutter/material.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import 'subscription_screen.dart';

class ProScreen extends StatefulWidget {
  final VoidCallback? onStatusChanged;

  const ProScreen({super.key, this.onStatusChanged});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  bool _isLoading = true;
  SubscriptionStatus _status = const SubscriptionStatus(isActive: false);

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
      log('Error loading pro data: $e');
      if (mounted) {
        setState(() {
          _status = const SubscriptionStatus(isActive: false);
          _isLoading = false;
        });
      }
    }
  }

  void _openSubscriptionManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubscriptionScreen(
          onStatusChanged: () {
            widget.onStatusChanged?.call();
            _loadData();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          // Top bar with back button
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
                  'Project Launcher Pro',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (_status.isActive)
                  TextButton.icon(
                    onPressed: _openSubscriptionManagement,
                    icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                    label: const Text('Manage'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                      textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
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
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
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
                              _buildSubscribeButton(cs),
                              const SizedBox(height: 16),
                              Center(
                                child: TextButton(
                                  onPressed: () => _openSubscriptionManagement(),
                                  child: Text(
                                    'Already subscribed? Verify',
                                    style: AppTypography.inter(
                                      fontSize: 13,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
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
            const Color(0xFFFFD700).withValues(alpha: 0.1),
            const Color(0xFFFFA500).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 24),
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
              TextButton(
                onPressed: _openSubscriptionManagement,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFD700),
                  backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                  ),
                  textStyle: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: const Text('Manage'),
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
            AppColors.accent.withValues(alpha: 0.08),
            const Color(0xFFE879F9).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 24),
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
                      '\$100/month — 6 months free trial',
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
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('Feature', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
              ),
              Expanded(
                child: Center(child: Text('Free', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant))),
              ),
              Expanded(
                child: Center(
                  child: Text('Pro', style: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFFFD700))),
                ),
              ),
            ],
          ),
        ),
        _comparisonRow(cs, 'Project management', true, true),
        _comparisonRow(cs, 'Health scores & stale alerts', true, true),
        _comparisonRow(cs, 'Light & Dark themes', true, true),
        _comparisonRow(cs, 'Referral rewards', true, true),
        _comparisonRow(cs, 'Year in Review', false, true),
        _comparisonRow(cs, 'All premium themes', false, true),
        _comparisonRow(cs, 'Health history & trends', false, true),
        _comparisonRow(cs, 'Priority support', false, true, isLast: true),
      ],
    );
  }

  Widget _comparisonRow(ColorScheme cs, String feature, bool inFree, bool inPro, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
          right: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
          bottom: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
        ),
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(feature, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface)),
          ),
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

  Widget _buildSubscribeButton(ColorScheme cs) {
    return Center(
      child: TextButton.icon(
        onPressed: _openSubscriptionManagement,
        icon: const Icon(Icons.workspace_premium, size: 18),
        label: const Text('View Plans & Subscribe'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
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
