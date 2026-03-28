import 'package:flutter/material.dart';
import 'package:launcher_theme/launcher_theme.dart';
import 'package:launcher_native/launcher_native.dart';
import '../../services/background_monitor.dart';

class StatusBar extends StatefulWidget {
  final DateTime? lastScanTime;
  final int unreleasedCount;
  final int readyToShipCount;

  const StatusBar({
    super.key,
    this.lastScanTime,
    this.unreleasedCount = 0,
    this.readyToShipCount = 0,
  });

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  @override
  void initState() {
    super.initState();
    BackgroundMonitor.addListener(_onMonitorUpdate);
  }

  @override
  void dispose() {
    BackgroundMonitor.removeListener(_onMonitorUpdate);
    super.dispose();
  }

  void _onMonitorUpdate() {
    if (mounted) setState(() {});
  }

  String get _lastScanText {
    if (widget.lastScanTime == null) return 'Never scanned';
    final diff = DateTime.now().difference(widget.lastScanTime!);
    if (diff.inSeconds < 60) return 'Last scan: just now';
    if (diff.inMinutes < 60) return 'Last scan: ${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours < 24) return 'Last scan: ${diff.inHours}h ago';
    return 'Last scan: ${diff.inDays}d ago';
  }

  String get _monitorText {
    final snapshot = BackgroundMonitor.lastSnapshot;
    if (BackgroundMonitor.status == MonitorStatus.checking) {
      final p = BackgroundMonitor.checkProgress;
      final t = BackgroundMonitor.checkTotal;
      return t > 0 ? 'Checking projects ($p/$t)...' : 'Checking projects...';
    }
    if (snapshot != null) {
      final age = DateTime.now().difference(snapshot.checkedAt);
      final ageStr = age.inMinutes < 1
          ? 'just now'
          : age.inMinutes < 60
              ? '${age.inMinutes}m ago'
              : '${age.inHours}h ago';
      return 'Checked $ageStr — '
          '${snapshot.unpushedCount} unpushed, '
          '${snapshot.uncommittedCount} uncommitted';
    }
    return '';
  }

  Color _releaseStatusColor(AppSkin? skin) {
    if (widget.unreleasedCount == 0) return skin?.colors.success ?? AppColors.success;
    if (widget.unreleasedCount >= 3) return skin?.colors.error ?? AppColors.error;
    return skin?.colors.warning ?? AppColors.warning;
  }

  String get _releaseStatusText {
    final parts = <String>[];
    if (widget.unreleasedCount > 0) {
      parts.add('${widget.unreleasedCount} unreleased');
    }
    if (widget.readyToShipCount > 0) {
      parts.add('${widget.readyToShipCount} ready to ship');
    }
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skin = AppSkin.maybeOf(context);
    final skinSuccess = skin?.colors.success ?? AppColors.success;
    final skinWarning = skin?.colors.warning ?? AppColors.warning;
    final skinAccent = skin?.colors.accent ?? AppColors.accent;
    final statusHeight = skin?.spacing.statusBarHeight ?? 28.0;
    final statusFontSize = skin?.typography.statusBarSize ?? 10.0;
    final ffiAvailable = NativeLib.isAvailable;
    final isChecking = BackgroundMonitor.status == MonitorStatus.checking;
    final hasReleaseInfo = widget.unreleasedCount > 0 || widget.readyToShipCount > 0;

    return Container(
      height: statusHeight,
      padding: EdgeInsets.symmetric(horizontal: skin?.spacing.toolbarPaddingH ?? 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          // FFI status
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ffiAvailable ? skinSuccess : skinWarning,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ffiAvailable ? 'Rust FFI' : 'No FFI',
            style: AppTypography.mono(
              fontSize: statusFontSize,
              color: ffiAvailable ? skinSuccess : skinWarning,
            ),
          ),

          const SizedBox(width: 16),

          // Background monitor status
          if (isChecking) ...[
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: skinAccent.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BackgroundMonitor.isRunning
                    ? skinSuccess
                    : cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            _monitorText,
            style: AppTypography.mono(
              fontSize: statusFontSize,
              color: isChecking ? skinAccent : cs.onSurfaceVariant,
            ),
          ),

          const Spacer(),

          // Release pulse status
          if (hasReleaseInfo) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _releaseStatusColor(skin),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _releaseStatusText,
              style: AppTypography.mono(
                fontSize: statusFontSize,
                color: _releaseStatusColor(skin),
              ),
            ),
            const SizedBox(width: 16),
          ],

          // Last scan time
          Text(
            _lastScanText,
            style: AppTypography.mono(
              fontSize: statusFontSize,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
