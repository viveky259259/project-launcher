import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/native_lib.dart';

class StatusBar extends StatelessWidget {
  final DateTime? lastScanTime;

  const StatusBar({super.key, this.lastScanTime});

  String get _lastScanText {
    if (lastScanTime == null) return 'Never scanned';
    final diff = DateTime.now().difference(lastScanTime!);
    if (diff.inSeconds < 60) return 'Last scan: just now';
    if (diff.inMinutes < 60) return 'Last scan: ${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours < 24) return 'Last scan: ${diff.inHours}h ago';
    return 'Last scan: ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ffiAvailable = NativeLib.isAvailable;

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
            ffiAvailable ? 'Rust FFI Connected' : 'Rust FFI Unavailable',
            style: AppTypography.mono(
              fontSize: 10,
              color: ffiAvailable ? AppColors.success : AppColors.warning,
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
