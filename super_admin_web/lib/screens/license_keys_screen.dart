import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launcher_kit/launcher_kit.dart';
import '../services/super_admin_api.dart';
import '../widgets/admin_navbar.dart';
import '../widgets/confirm_dialog.dart';

class LicenseKeysScreen extends StatefulWidget {
  const LicenseKeysScreen({super.key});

  @override
  State<LicenseKeysScreen> createState() => _LicenseKeysScreenState();
}

class _LicenseKeysScreenState extends State<LicenseKeysScreen> {
  List<LicenseKeyInfo>? _keys;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keys = await SuperAdminApi.listLicenseKeys();
      setState(() {
        _keys = keys;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generateKey() async {
    final result = await showDialog<_GenerateKeyResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _GenerateKeyDialog(),
    );
    if (result == null) return;

    try {
      final keyInfo = await SuperAdminApi.generateKey(
        result.orgSlug,
        result.seats,
      );
      if (mounted) {
        await _showKeyCreatedDialog(keyInfo.key);
      }
      _load();
    } catch (e) {
      if (mounted) {
        UkToast.show(
          context,
          message: 'Failed to generate key: $e',
          type: UkToastType.danger,
        );
      }
    }
  }

  Future<void> _showKeyCreatedDialog(String key) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('License Key Generated'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Copy this key now. It will not be shown again in full.',
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  key,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          actions: [
            UkButton(
              label: 'Copy',
              icon: Icons.copy_rounded,
              variant: UkButtonVariant.outline,
              size: UkButtonSize.small,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: key));
                UkToast.show(ctx,
                    message: 'Copied to clipboard.',
                    type: UkToastType.success);
              },
            ),
            const SizedBox(width: 8),
            UkButton(
              label: 'Done',
              size: UkButtonSize.small,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _revokeKey(LicenseKeyInfo keyInfo) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Revoke license key?',
      message:
          'This will immediately invalidate the key for org "${keyInfo.orgSlug}". This cannot be undone.',
      confirmLabel: 'Revoke',
    );
    if (!confirmed) return;

    try {
      await SuperAdminApi.revokeKey(keyInfo.key);
      if (mounted) {
        UkToast.show(
          context,
          message: 'Key revoked.',
          type: UkToastType.success,
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        UkToast.show(
          context,
          message: 'Failed to revoke: $e',
          type: UkToastType.danger,
        );
      }
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _truncateKey(String key) {
    if (key.length <= 16) return key;
    return '${key.substring(0, 16)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AdminNavbar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Failed to load license keys: $_error'),
          const SizedBox(height: 16),
          UkButton(label: 'Retry', onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    final keys = _keys ?? [];
    final total = keys.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Text(
                'License Keys ($total)',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              UkButton(
                label: '+ Generate Key',
                size: UkButtonSize.small,
                icon: Icons.add_rounded,
                onPressed: _generateKey,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Key list
          Expanded(
            child: keys.isEmpty
                ? Center(
                    child: Text(
                      'No license keys generated yet.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: keys.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (ctx, i) => _KeyRow(
                      keyInfo: keys[i],
                      truncateKey: _truncateKey,
                      formatTime: _formatTime,
                      onRevoke: keys[i].revoked
                          ? null
                          : () => _revokeKey(keys[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.keyInfo,
    required this.truncateKey,
    required this.formatTime,
    this.onRevoke,
  });

  final LicenseKeyInfo keyInfo;
  final String Function(String) truncateKey;
  final String Function(DateTime?) formatTime;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final planVariant = switch (keyInfo.plan) {
      'enterprise' => UkBadgeVariant.primary,
      'pro' => UkBadgeVariant.secondary,
      _ => UkBadgeVariant.neutral,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Key (truncated)
            Expanded(
              flex: 2,
              child: Text(
                truncateKey(keyInfo.key),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            // Org
            Expanded(
              flex: 2,
              child: Text(
                keyInfo.orgSlug,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            // Seats
            SizedBox(
              width: 70,
              child: Text(
                '${keyInfo.seats} seats',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
            // Plan
            SizedBox(
              width: 100,
              child: UkBadge(keyInfo.plan, variant: planVariant),
            ),
            // Status
            SizedBox(
              width: 80,
              child: keyInfo.revoked
                  ? Text(
                      'revoked',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.error),
                    )
                  : Text(
                      'active',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.primary),
                    ),
            ),
            // Last validated
            SizedBox(
              width: 100,
              child: Text(
                formatTime(keyInfo.lastValidatedAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
            // Revoke action
            SizedBox(
              width: 80,
              child: onRevoke != null
                  ? UkButton(
                      label: 'Revoke',
                      variant: UkButtonVariant.outline,
                      size: UkButtonSize.small,
                      onPressed: onRevoke,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerateKeyResult {
  final String orgSlug;
  final int seats;
  const _GenerateKeyResult({required this.orgSlug, required this.seats});
}

class _GenerateKeyDialog extends StatefulWidget {
  const _GenerateKeyDialog();

  @override
  State<_GenerateKeyDialog> createState() => _GenerateKeyDialogState();
}

class _GenerateKeyDialogState extends State<_GenerateKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _orgSlugCtrl;
  late final TextEditingController _seatsCtrl;

  @override
  void initState() {
    super.initState();
    _orgSlugCtrl = TextEditingController();
    _seatsCtrl = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _orgSlugCtrl.dispose();
    _seatsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_GenerateKeyResult(
      orgSlug: _orgSlugCtrl.text.trim(),
      seats: int.tryParse(_seatsCtrl.text.trim()) ?? 10,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate License Key'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UkTextField(
                controller: _orgSlugCtrl,
                label: 'Organization Slug',
                hint: 'e.g. acme-corp',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Org slug is required'
                    : null,
              ),
              const SizedBox(height: 12),
              UkTextField(
                controller: _seatsCtrl,
                label: 'Seats',
                hint: 'Number of seats',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Seats required';
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Must be > 0';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        UkButton(
          label: 'Cancel',
          variant: UkButtonVariant.outline,
          size: UkButtonSize.small,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        const SizedBox(width: 8),
        UkButton(
          label: 'Generate',
          size: UkButtonSize.small,
          onPressed: _submit,
        ),
      ],
    );
  }
}
