import 'package:flutter/material.dart';
import 'package:launcher_theme/launcher_theme.dart';

class SyncingPill extends StatefulWidget {
  final int progress;
  final int total;

  const SyncingPill({super.key, required this.progress, required this.total});

  @override
  State<SyncingPill> createState() => SyncingPillState();
}

class SyncingPillState extends State<SyncingPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.total > 0
        ? 'Syncing ${widget.progress}/${widget.total}'
        : 'Syncing...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _controller,
            child: const Icon(
              Icons.sync_rounded,
              size: 13,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? accentColor;

  const HeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accentColor,
  });

  @override
  State<HeaderButton> createState() => HeaderButtonState();
}

class HeaderButtonState extends State<HeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.accentColor ?? cs.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _hovered
                  ? (widget.accentColor ?? cs.onSurface).withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: _hovered
                  ? (widget.accentColor ?? cs.onSurface)
                  : color.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
