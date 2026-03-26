import 'package:flutter/material.dart';
import 'package:launcher_theme/launcher_theme.dart';
import '../../services/cli_install_service.dart';

class CliInstallBanner extends StatefulWidget {
  final VoidCallback onInstalled;
  final VoidCallback onDismissed;

  const CliInstallBanner({
    super.key,
    required this.onInstalled,
    required this.onDismissed,
  });

  @override
  State<CliInstallBanner> createState() => _CliInstallBannerState();
}

enum _BannerState { prompt, installing, success, error }

class _CliInstallBannerState extends State<CliInstallBanner> {
  _BannerState _state = _BannerState.prompt;
  String _statusMessage = '';
  String? _errorMessage;

  Future<void> _onInstall() async {
    setState(() {
      _state = _BannerState.installing;
      _statusMessage = 'Starting...';
    });

    final result = await CliInstallService.install(
      onProgress: (status) {
        if (mounted) setState(() => _statusMessage = status);
      },
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _state = _BannerState.success;
        _statusMessage = result.message;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) widget.onInstalled();
    } else {
      setState(() {
        _state = _BannerState.error;
        _errorMessage = result.error ?? result.message;
      });
    }
  }

  void _onLater() {
    widget.onDismissed();
  }

  void _onDontAskAgain() {
    CliInstallService.setDontAskAgain();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: _buildContent(cs),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    switch (_state) {
      case _BannerState.prompt:
        return _buildPrompt(cs);
      case _BannerState.installing:
        return _buildInstalling(cs);
      case _BannerState.success:
        return _buildSuccess(cs);
      case _BannerState.error:
        return _buildError(cs);
    }
  }

  Widget _buildPrompt(ColorScheme cs) {
    return Row(
      children: [
        const Icon(Icons.terminal_rounded, size: 18, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Install plauncher CLI',
                style: AppTypography.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Text(
                'Open projects from your terminal',
                style: AppTypography.inter(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _onInstall,
          style: TextButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          child: Text(
            'Install',
            style: AppTypography.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'later') _onLater();
            if (value == 'never') _onDontAskAgain();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'later', child: Text('Later')),
            const PopupMenuItem(value: 'never', child: Text('Don\'t ask again')),
          ],
          padding: EdgeInsets.zero,
          child: Icon(
            Icons.more_horiz_rounded,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildInstalling(ColorScheme cs) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _statusMessage,
            style: AppTypography.inter(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess(ColorScheme cs) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _statusMessage,
            style: AppTypography.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _errorMessage ?? 'Installation failed',
            style: AppTypography.inter(fontSize: 11, color: AppColors.error),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: _onInstall,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Retry',
            style: AppTypography.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
        TextButton(
          onPressed: _onLater,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Dismiss',
            style: AppTypography.inter(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
