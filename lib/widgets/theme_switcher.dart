import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ThemeSwitcherPanel extends StatelessWidget {
  final AppTheme currentTheme;
  final List<String> unlockedThemes;
  final bool isPro;
  final ValueChanged<AppTheme> onThemeChanged;
  final VoidCallback onClose;
  final VoidCallback onEarnThemes;
  final VoidCallback onUnlockWithPro;

  const ThemeSwitcherPanel({
    super.key,
    required this.currentTheme,
    required this.unlockedThemes,
    required this.isPro,
    required this.onThemeChanged,
    required this.onClose,
    required this.onEarnThemes,
    required this.onUnlockWithPro,
  });

  bool _isThemeUnlocked(AppTheme theme) {
    if (!theme.requiresUnlock) return true;
    if (isPro) return true;
    if (theme.unlockRewardId != null && unlockedThemes.contains(theme.unlockRewardId)) return true;
    return false;
  }

  String _lockText(AppTheme theme) {
    switch (theme) {
      case AppTheme.midnight: return 'Unlock with 3 referrals';
      case AppTheme.ocean: return 'Unlock with 5 referrals';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // Theme options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: AppTheme.values.map((theme) {
                final isActive = currentTheme == theme;
                final isUnlocked = _isThemeUnlocked(theme);

                return _ThemeRow(
                  theme: theme,
                  isActive: isActive,
                  isUnlocked: isUnlocked,
                  lockText: _lockText(theme),
                  onTap: isUnlocked ? () => onThemeChanged(theme) : null,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Earn Premium Themes card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GestureDetector(
              onTap: onEarnThemes,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded, size: 18, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Earn Premium Themes',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                          Text(
                            'Share your referral code',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.accent),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Unlock All with Pro button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isPro ? null : onUnlockWithPro,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF69B4),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: cs.surfaceContainerHighest,
                  disabledForegroundColor: cs.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  isPro ? 'All Themes Unlocked' : 'Unlock All with Pro',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isPro ? cs.onSurfaceVariant : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeRow extends StatefulWidget {
  final AppTheme theme;
  final bool isActive;
  final bool isUnlocked;
  final String lockText;
  final VoidCallback? onTap;

  const _ThemeRow({
    required this.theme,
    required this.isActive,
    required this.isUnlocked,
    required this.lockText,
    this.onTap,
  });

  @override
  State<_ThemeRow> createState() => _ThemeRowState();
}

class _ThemeRowState extends State<_ThemeRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = widget.theme.previewColors;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.accent.withValues(alpha: 0.1)
                : _isHovered
                    ? cs.onSurface.withValues(alpha: 0.03)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: widget.isActive
                ? Border.all(color: AppColors.accent.withValues(alpha: 0.5))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              // Color preview dots
              Row(
                mainAxisSize: MainAxisSize.min,
                children: colors.map((c) => Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(width: 10),

              // Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.theme.name,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    if (!widget.isUnlocked)
                      Text(
                        widget.lockText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                        ),
                      )
                    else
                      Text(
                        widget.theme.description,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),

              // Status icon
              if (widget.isActive)
                const Icon(Icons.check_circle, size: 18, color: AppColors.accent)
              else if (!widget.isUnlocked)
                Icon(Icons.lock, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
