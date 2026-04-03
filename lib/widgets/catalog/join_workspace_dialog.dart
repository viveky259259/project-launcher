import 'package:flutter/material.dart';
import 'package:launcher_kit/launcher_kit.dart';
import 'package:launcher_theme/launcher_theme.dart';
import '../../services/catalog_service.dart';

/// Dialog for entering the catalog server URL and joining a workspace.
class JoinWorkspaceDialog extends StatefulWidget {
  const JoinWorkspaceDialog({super.key});

  @override
  State<JoinWorkspaceDialog> createState() => _JoinWorkspaceDialogState();
}

class _JoinWorkspaceDialogState extends State<JoinWorkspaceDialog> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isConnecting = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a server URL');
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      final token = _tokenController.text.trim();
      if (token.isNotEmpty) {
        await CatalogService.joinWithToken(url, token);
      } else {
        await CatalogService.joinWorkspace(url);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.hub_rounded,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Connect to Team Catalog',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the URL of your organization\'s catalog server.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            UkTextField(
              controller: _urlController,
              label: 'Server URL',
              hint: 'https://catalog.acme.internal',
              prefixIcon: Icons.link_rounded,
              enabled: !_isConnecting,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            UkTextField(
              controller: _tokenController,
              label: 'API Token (optional)',
              hint: 'plk_xxxxx',
              prefixIcon: Icons.vpn_key_rounded,
              enabled: !_isConnecting,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _tokenController.text.trim().isNotEmpty
                  ? 'Token provided — will skip browser authentication.'
                  : 'You\'ll be redirected to GitHub for authentication.',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              UkAlert(
                message: _error!,
                type: UkAlertType.danger,
                dismissible: false,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isConnecting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isConnecting ? null : _connect,
          icon: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.login_rounded, size: 16),
          label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ],
    );
  }
}
