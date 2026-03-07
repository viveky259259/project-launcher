import 'package:flutter/material.dart';
import '../services/native_lib.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onStartScan;
  final VoidCallback onAddManually;

  const OnboardingScreen({
    super.key,
    required this.onStartScan,
    required this.onAddManually,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.terminal_rounded,
                      size: 48,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Headline
                  Text(
                    'Welcome to your command center',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      'Project Launcher organizes your local repositories and gives you instant access to your code. Let\'s get started by indexing your machine.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Two action cards
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.search_rounded,
                            title: 'Auto-Scan Machine',
                            description: 'Automatically discover git repositories in common developer directories.',
                            buttonLabel: 'Start Deep Scan',
                            buttonColor: AppColors.accent,
                            onPressed: onStartScan,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.add_rounded,
                            title: 'Add Manually',
                            description: 'Browse your filesystem and select specific project folders to add.',
                            buttonLabel: 'Browse Files...',
                            buttonColor: const Color(0xFFE879F9),
                            onPressed: onAddManually,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Feature highlights
                  Text(
                    'Built for modern workflows',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FeatureHighlight(
                            icon: Icons.bolt_rounded,
                            title: 'Instant Launch',
                            description: 'Open in VS Code or Terminal',
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _FeatureHighlight(
                            icon: Icons.favorite_rounded,
                            title: 'Health Scoring',
                            description: 'Git activity & dependency audits',
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _FeatureHighlight(
                            icon: Icons.label_rounded,
                            title: 'Smart Tags',
                            description: 'Auto-categorize by language',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: NativeLib.isAvailable ? AppColors.success : AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                NativeLib.isAvailable ? 'Rust Engine Active' : 'Rust Engine Unavailable',
                style: AppTypography.mono(fontSize: 11, color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                'Default scan paths: ~/Projects, ~/Developer, ~/Code',
                style: AppTypography.mono(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final Color buttonColor;
  final VoidCallback onPressed;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onPressed,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _isHovered
                ? widget.buttonColor.withValues(alpha: 0.4)
                : cs.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.buttonColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(widget.icon, size: 22, color: widget.buttonColor),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: widget.buttonColor,
                  backgroundColor: widget.buttonColor.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: widget.buttonColor.withValues(alpha: 0.3)),
                  ),
                  textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: Text(widget.buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureHighlight extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureHighlight({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          textAlign: TextAlign.center,
          style: AppTypography.mono(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
