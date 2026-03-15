import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/native_lib.dart';
import '../../services/background_monitor.dart';

class StatusBar extends StatefulWidget {
  final DateTime? lastScanTime;

  const StatusBar({super.key, this.lastScanTime});

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ffiAvailable = NativeLib.isAvailable;
    final isChecking = BackgroundMonitor.status == MonitorStatus.checking;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              color: ffiAvailable ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ffiAvailable ? 'Rust FFI' : 'No FFI',
            style: AppTypography.mono(
              fontSize: 10,
              color: ffiAvailable ? AppColors.success : AppColors.warning,
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
                color: AppColors.accent.withValues(alpha: 0.6),
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
                    ? AppColors.success
                    : cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            _monitorText,
            style: AppTypography.mono(
              fontSize: 10,
              color: isChecking ? AppColors.accent : cs.onSurfaceVariant,
            ),
          ),

          const Spacer(),

          // Last scan time
          Text(
            _lastScanText,
            style: AppTypography.mono(
              fontSize: 10,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
