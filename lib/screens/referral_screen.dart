import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/referral.dart';
import '../services/referral_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';
import 'health_screen.dart';
import 'year_review_screen.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  bool _isLoading = true;
  bool _isPro = false;
  ReferralData? _referralData;
  List<RewardStatus> _rewardStatuses = [];
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final data = await ReferralService.loadReferralData();
    final statuses = await ReferralService.getRewardStatuses();
    final isPro = await PremiumService.isPro();

    if (mounted) {
      setState(() {
        _referralData = data;
        _rewardStatuses = statuses;
        _isPro = isPro;
        _isLoading = false;
      });
    }
  }

  Future<void> _copyCode() async {
    if (_referralData == null) return;

    await Clipboard.setData(ClipboardData(text: _referralData!.myCode));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Referral code copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _enterCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final result = await ReferralService.enterReferralCode(code);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (result.success) {
        _codeController.clear();
        _loadData();
      }
    }
  }

  Future<void> _simulateReferral() async {
    await ReferralService.simulateReferral();
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Simulated a referral! Check your progress.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          AppSidebar(
            activeRoute: 'referrals',
            onNavigate: (route) {
              if (route == 'referrals') return;
              Navigator.of(context).pop();
              if (route == 'health') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HealthScreen()),
                );
              } else if (route == 'year_review') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const YearReviewScreen()),
                );
              }
            },
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    ),
                  )
                : _buildContent(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    return Column(
      children: [
        // Top bar
        Container(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Referrals & Rewards',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Invite developers and unlock exclusive themes.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _simulateReferral,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Simulate Referral'),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Referral code card
                _ReferralCodeCard(
                  code: _referralData?.myCode ?? '',
                  referralCount: _referralData?.referralCount ?? 0,
                  onCopy: _copyCode,
                ),
                const SizedBox(height: 32),

                // Enter a code
                Text(
                  'Have a referral code?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          hintText: 'PLR-XXXX-XXXX',
                          hintStyle: AppTypography.mono(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                          prefixIcon: Icon(Icons.card_giftcard_rounded, size: 18, color: cs.onSurfaceVariant),
                          filled: true,
                          fillColor: cs.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: const BorderSide(color: AppColors.accent),
                          ),
                        ),
                        style: AppTypography.mono(fontSize: 14, color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _enterCode,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Enter'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Rewards section
                Text(
                  'Unlock Rewards',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Invite fellow developers to unlock exclusive themes',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Reward cards
                ..._rewardStatuses.map((status) => _RewardCard(
                  status: status,
                  isPro: _isPro,
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  final String code;
  final int referralCount;
  final VoidCallback onCopy;

  const _ReferralCodeCard({
    required this.code,
    required this.referralCount,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.05),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REFERRAL CODE',
                    style: AppTypography.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$referralCount referral${referralCount == 1 ? '' : 's'}',
                    style: AppTypography.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    code,
                    style: AppTypography.mono(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy code',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Share this code with friends to earn rewards!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final RewardStatus status;
  final bool isPro;

  const _RewardCard({required this.status, this.isPro = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reward = status.reward;
    final isUnlocked = status.isUnlocked || isPro;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isUnlocked
              ? AppColors.success.withValues(alpha: 0.5)
              : cs.outline.withValues(alpha: 0.2),
          width: isUnlocked ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Theme preview
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: _getThemeGradient(reward),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: isUnlocked
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reward.name,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    if (isUnlocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isPro && !status.isUnlocked)
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          isPro && !status.isUnlocked ? 'PRO' : 'UNLOCKED',
                          style: AppTypography.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isPro && !status.isUnlocked ? AppColors.accent : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reward.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (!isUnlocked) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: status.progress,
                            backgroundColor: cs.outline.withValues(alpha: 0.15),
                            color: AppColors.accent,
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${status.currentReferrals}/${status.requiredReferrals}',
                        style: AppTypography.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _getThemeGradient(ReferralReward reward) {
    switch (reward) {
      case ReferralReward.darkThemeMidnight:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF11001C)],
        );
      case ReferralReward.darkThemeOcean:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0077B6), Color(0xFF023E8A)],
        );
      case ReferralReward.founderBadge:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
        );
    }
  }
}
