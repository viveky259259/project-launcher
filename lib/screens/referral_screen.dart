import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/referral.dart';
import '../services/referral_service.dart';
import '../services/premium_service.dart';
import '../kit/kit.dart';

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
      appBar: AppBar(
        title: const Text('Referrals & Rewards'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Your referral code card
                  _ReferralCodeCard(
                    code: _referralData?.myCode ?? '',
                    referralCount: _referralData?.referralCount ?? 0,
                    onCopy: _copyCode,
                  ),
                  const SizedBox(height: 24),

                  // Enter a code section
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
                        child: UkTextField(
                          controller: _codeController,
                          hint: 'PLR-XXXX-XXXX',
                          prefixIcon: Icons.card_giftcard_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      UkButton(
                        label: 'Enter',
                        onPressed: _enterCode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Rewards section
                  Row(
                    children: [
                      Text(
                        'Unlock Rewards',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      // Demo button
                      TextButton.icon(
                        onPressed: _simulateReferral,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Simulate Referral'),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.tertiary,
                        ),
                      ),
                    ],
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
                  color: cs.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.card_giftcard_rounded, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Referral Code',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$referralCount referral${referralCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              UkButton(
                label: 'Copy',
                icon: Icons.copy,
                variant: UkButtonVariant.outline,
                onPressed: onCopy,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? Colors.green.withValues(alpha: 0.5)
              : cs.outline.withValues(alpha: 0.2),
          width: isUnlocked ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Theme preview
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: _getThemeGradient(reward),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isUnlocked
                ? const Icon(Icons.check, color: Colors.white)
                : Icon(
                    Icons.lock,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reward.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (isUnlocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPro && !status.isUnlocked ? 'PRO' : 'UNLOCKED',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isPro && !status.isUnlocked
                                    ? const Color(0xFFFFD700)
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: status.progress,
                          backgroundColor: cs.primary.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(cs.primary),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${status.currentReferrals}/${status.requiredReferrals}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
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
          colors: [
            Color(0xFF2D1B69),
            Color(0xFF11001C),
          ],
        );
      case ReferralReward.darkThemeOcean:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0077B6),
            Color(0xFF023E8A),
          ],
        );
    }
  }
}
