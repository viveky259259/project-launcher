import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final String routeId;
  final bool isPro;

  const SidebarItem({
    required this.icon,
    required this.label,
    required this.routeId,
    this.isPro = false,
  });
}

class AppSidebar extends StatelessWidget {
  final String activeRoute;
  final ValueChanged<String> onNavigate;
  final String? userName;
  final bool isPro;

  const AppSidebar({
    super.key,
    required this.activeRoute,
    required this.onNavigate,
    this.userName,
    this.isPro = false,
  });

  static const List<SidebarItem> items = [
    SidebarItem(icon: Icons.dashboard_rounded, label: 'Dashboard', routeId: 'home'),
    SidebarItem(icon: Icons.folder_rounded, label: 'All Projects', routeId: 'projects'),
    SidebarItem(icon: Icons.favorite_rounded, label: 'Health Dashboard', routeId: 'health'),
    SidebarItem(icon: Icons.insights_rounded, label: 'Year in Review', routeId: 'year_review', isPro: true),
    SidebarItem(icon: Icons.card_giftcard_rounded, label: 'Referrals', routeId: 'referrals'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        children: [
          // App branding
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(Icons.rocket_launch, color: AppColors.accent, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Launcher',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'v2.0.0',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: items.map((item) {
                final isActive = activeRoute == item.routeId;
                return _SidebarNavItem(
                  icon: item.icon,
                  label: item.label,
                  isActive: isActive,
                  isPro: item.isPro,
                  onTap: () => onNavigate(item.routeId),
                );
              }).toList(),
            ),
          ),

          // Subscription status at bottom
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
              ),
            ),
            child: isPro
                ? GestureDetector(
                    onTap: () => onNavigate('subscription'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.workspace_premium, size: 18, color: Color(0xFFFFD700)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pro Member',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFFFFD700),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Manage subscription',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => onNavigate('subscription'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0.1),
                            const Color(0xFFE879F9).withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.workspace_premium, size: 18, color: Color(0xFFFFD700)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Upgrade to Pro',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Unlock all features',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
          ),

          // User profile at bottom
          if (userName != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                    child: Text(
                      userName!.substring(0, 2).toUpperCase(),
                      style: AppTypography.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName!,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isPro)
                          Text(
                            'Pro Member',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isPro;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isPro,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
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
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.accent.withValues(alpha: 0.15)
                : _isHovered
                    ? cs.onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: widget.isActive
                ? Border.all(color: AppColors.accent.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isActive ? AppColors.accent : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: widget.isActive ? AppColors.accent : cs.onSurfaceVariant,
                    fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'PRO',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
