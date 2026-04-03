import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launcher_kit/launcher_kit.dart';
import '../services/admin_api.dart';
import '../widgets/admin_navbar.dart';
import '../widgets/confirm_dialog.dart';

enum _SortBy { name, lastSeen, drift }

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<MemberActivity>? _members;
  bool _loading = true;
  String? _error;
  _SortBy _sortBy = _SortBy.lastSeen;

  List<MemberActivity> get _sorted {
    final list = List<MemberActivity>.from(_members ?? []);
    switch (_sortBy) {
      case _SortBy.name:
        list.sort((a, b) => a.githubLogin.compareTo(b.githubLogin));
      case _SortBy.lastSeen:
        list.sort((a, b) {
          if (a.lastSeenAt == null && b.lastSeenAt == null) return 0;
          if (a.lastSeenAt == null) return 1;
          if (b.lastSeenAt == null) return -1;
          return b.lastSeenAt!.compareTo(a.lastSeenAt!);
        });
      case _SortBy.drift:
        list.sort((a, b) => b.missingCount.compareTo(a.missingCount));
    }
    return list;
  }

  int get _syncedCount => _members?.where((m) => !m.isDrifted).length ?? 0;
  int get _driftedCount => _members?.where((m) => m.isDrifted).length ?? 0;

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
      final members = await AdminApi.getMembers();
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _inviteMember() async {
    final result = await showDialog<_InviteFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _InviteMemberDialog(),
    );
    if (result == null) return;

    try {
      final inviteResult =
          await AdminApi.inviteMember(result.githubLogin, result.role);
      if (mounted) {
        await _showApiKeyDialog(
          title: 'Member Invited',
          message:
              '${result.githubLogin} has been invited as a ${result.role}.',
          apiKey: inviteResult.apiKey,
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        UkToast.show(
          context,
          message: 'Invite failed: $e',
          type: UkToastType.danger,
        );
      }
    }
  }

  Future<void> _showApiKeyDialog({
    required String title,
    required String message,
    required String apiKey,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ApiKeyRevealDialog(
        title: title,
        message: message,
        apiKey: apiKey,
      ),
    );
  }

  Future<void> _manageKeys(MemberActivity member) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ManageKeysDialog(
        member: member,
        onKeyGenerated: (key) {
          _showApiKeyDialog(
            title: 'New API Key Generated',
            message:
                'A new API key has been generated for ${member.githubLogin}.',
            apiKey: key,
          );
        },
      ),
    );
  }

  Future<void> _changeRole(MemberActivity member, String newRole) async {
    try {
      await AdminApi.updateMemberRole(member.githubLogin, newRole);
      if (mounted) {
        UkToast.show(
          context,
          message: '${member.githubLogin} role changed to $newRole.',
          type: UkToastType.success,
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        UkToast.show(
          context,
          message: 'Role change failed: $e',
          type: UkToastType.danger,
        );
      }
    }
  }

  Future<void> _removeMember(MemberActivity member) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove "${member.githubLogin}"?',
      message:
          'This will remove the member from the organization. They will lose access immediately.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;

    try {
      await AdminApi.removeMember(member.githubLogin);
      if (mounted) {
        UkToast.show(
          context,
          message: '${member.githubLogin} has been removed.',
          type: UkToastType.success,
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        UkToast.show(
          context,
          message: 'Remove failed: $e',
          type: UkToastType.danger,
        );
      }
    }
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
          Text('Failed to load members: $_error'),
          const SizedBox(height: 16),
          UkButton(label: 'Retry', onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    final members = _sorted;
    final total = _members?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header + stats
          Row(
            children: [
              Text(
                'Members ($total)',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 24),
              _StatChip(
                label: 'Synced',
                value: '$_syncedCount',
                color: cs.primary,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: 'Drifted',
                value: '$_driftedCount',
                color: cs.error,
              ),
              const Spacer(),
              UkButton(
                label: '+ Invite Member',
                size: UkButtonSize.small,
                icon: Icons.person_add_rounded,
                onPressed: _inviteMember,
              ),
              const SizedBox(width: 16),
              // Sort selector
              Text('Sort by:', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: UkSelect<_SortBy>(
                  options: const [
                    UkOption('Last Seen', _SortBy.lastSeen),
                    UkOption('Name', _SortBy.name),
                    UkOption('Drift Count', _SortBy.drift),
                  ],
                  value: _sortBy,
                  size: UkFieldSize.small,
                  onChanged: (v) {
                    if (v != null) setState(() => _sortBy = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Member list
          Expanded(
            child: members.isEmpty
                ? Center(
                    child: Text(
                      'No members found.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (ctx, i) => _MemberRow(
                      member: members[i],
                      onChangeRole: (role) => _changeRole(members[i], role),
                      onRemove: () => _removeMember(members[i]),
                      onManageKeys: () => _manageKeys(members[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.8),
                ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.onChangeRole,
    required this.onRemove,
    required this.onManageKeys,
  });

  final MemberActivity member;
  final void Function(String role) onChangeRole;
  final VoidCallback onRemove;
  final VoidCallback onManageKeys;

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'never';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDrifted = member.isDrifted;
    final missing = member.missingCount;
    final avatarUrl = member.avatarUrl ?? '';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      member.githubLogin.isNotEmpty
                          ? member.githubLogin[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: cs.onPrimaryContainer),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Login
            SizedBox(
              width: 140,
              child: Text(
                member.githubLogin,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            // Role badge
            SizedBox(
              width: 90,
              child: UkBadge(
                member.role,
                variant: member.role == 'admin'
                    ? UkBadgeVariant.primary
                    : UkBadgeVariant.neutral,
              ),
            ),
            const SizedBox(width: 12),
            // Progress bar + count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UkProgress(
                    value: member.syncProgress,
                    variant: isDrifted
                        ? UkProgressVariant.warning
                        : UkProgressVariant.success,
                    size: UkProgressSize.small,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${member.syncedRepos}/${member.totalRepos} repos',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Last seen
            SizedBox(
              width: 110,
              child: Text(
                'Last seen: ${_formatRelativeTime(member.lastSeenAt)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            // Drift indicator
            SizedBox(
              width: 100,
              child: isDrifted
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: cs.error),
                        const SizedBox(width: 4),
                        Text(
                          '$missing missing',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.error),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Synced',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.primary),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 12),
            // Role change dropdown
            SizedBox(
              width: 120,
              child: UkSelect<String>(
                options: const [
                  UkOption('Admin', 'org_admin'),
                  UkOption('Developer', 'developer'),
                ],
                value: member.role,
                size: UkFieldSize.small,
                onChanged: (v) {
                  if (v != null && v != member.role) {
                    onChangeRole(v);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            // Manage keys button
            IconButton(
              icon: Icon(Icons.vpn_key_rounded,
                  color: cs.onSurfaceVariant, size: 18),
              onPressed: onManageKeys,
              tooltip: 'Manage API keys',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 4),
            // Remove button
            IconButton(
              icon: Icon(Icons.person_remove_rounded,
                  color: cs.error, size: 18),
              onPressed: onRemove,
              tooltip: 'Remove member',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invite member dialog
// ---------------------------------------------------------------------------

class _InviteFormResult {
  final String githubLogin;
  final String role;
  const _InviteFormResult({required this.githubLogin, required this.role});
}

class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog();

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  String _role = 'developer';

  @override
  void dispose() {
    _loginCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _InviteFormResult(githubLogin: _loginCtrl.text.trim(), role: _role),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Member'),
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
                controller: _loginCtrl,
                label: 'GitHub Login',
                hint: 'e.g. octocat',
                prefixIcon: Icons.person_rounded,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'GitHub login is required'
                    : null,
              ),
              const SizedBox(height: 16),
              UkSelect<String>(
                label: 'Role',
                options: const [
                  UkOption('Developer', 'developer'),
                  UkOption('Admin', 'admin'),
                ],
                value: _role,
                onChanged: (v) {
                  if (v != null) setState(() => _role = v);
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
          label: 'Invite',
          size: UkButtonSize.small,
          onPressed: _submit,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// API key reveal dialog (shown once after invite or key generation)
// ---------------------------------------------------------------------------

class _ApiKeyRevealDialog extends StatefulWidget {
  const _ApiKeyRevealDialog({
    required this.title,
    required this.message,
    required this.apiKey,
  });

  final String title;
  final String message;
  final String apiKey;

  @override
  State<_ApiKeyRevealDialog> createState() => _ApiKeyRevealDialogState();
}

class _ApiKeyRevealDialogState extends State<_ApiKeyRevealDialog> {
  bool _copied = false;

  Future<void> _copyKey() async {
    await Clipboard.setData(ClipboardData(text: widget.apiKey));
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            Text(
              'Their API key (copy now -- won\'t be shown again):',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      widget.apiKey,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 18,
                      color: _copied ? cs.primary : cs.onSurfaceVariant,
                    ),
                    onPressed: _copyKey,
                    tooltip: _copied ? 'Copied!' : 'Copy to clipboard',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Give this key to the developer. They can join with:',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                'plauncher join <server-url> --token <key>',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        UkButton(
          label: 'Done',
          size: UkButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Manage keys dialog (list, generate, revoke)
// ---------------------------------------------------------------------------

class _ManageKeysDialog extends StatefulWidget {
  const _ManageKeysDialog({
    required this.member,
    required this.onKeyGenerated,
  });

  final MemberActivity member;
  final void Function(String key) onKeyGenerated;

  @override
  State<_ManageKeysDialog> createState() => _ManageKeysDialogState();
}

class _ManageKeysDialogState extends State<_ManageKeysDialog> {
  List<ApiKeyInfo>? _keys;
  bool _loading = true;
  String? _error;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keys =
          await AdminApi.listMemberKeys(widget.member.githubLogin);
      if (mounted) {
        setState(() {
          _keys = keys;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _generateKey() async {
    setState(() => _generating = true);
    try {
      final fullKey =
          await AdminApi.generateMemberKey(widget.member.githubLogin);
      if (mounted) {
        setState(() => _generating = false);
        Navigator.of(context).pop();
        widget.onKeyGenerated(fullKey);
      }
      await _loadKeys();
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        UkToast.show(
          context,
          message: 'Failed to generate key: $e',
          type: UkToastType.danger,
        );
      }
    }
  }

  Future<void> _revokeKey(ApiKeyInfo keyInfo) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Revoke API key?',
      message:
          'This will immediately invalidate the key "${keyInfo.key}". '
          'The member will lose access until a new key is generated.',
      confirmLabel: 'Revoke',
    );
    if (!confirmed) return;

    try {
      await AdminApi.revokeMemberKey(
          widget.member.githubLogin, keyInfo.key);
      if (mounted) {
        UkToast.show(
          context,
          message: 'API key revoked.',
          type: UkToastType.success,
        );
      }
      await _loadKeys();
    } catch (e) {
      if (mounted) {
        UkToast.show(
          context,
          message: 'Revoke failed: $e',
          type: UkToastType.danger,
        );
      }
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'never';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('API Keys: ${widget.member.githubLogin}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: 520,
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Active API keys for this member.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                UkButton(
                  label: _generating ? 'Generating...' : 'Generate New Key',
                  size: UkButtonSize.small,
                  icon: Icons.add_rounded,
                  onPressed: _generating ? null : _generateKey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Failed to load keys: $_error'),
                              const SizedBox(height: 8),
                              UkButton(
                                label: 'Retry',
                                size: UkButtonSize.small,
                                onPressed: _loadKeys,
                              ),
                            ],
                          ),
                        )
                      : _keys!.isEmpty
                          ? Center(
                              child: Text(
                                'No API keys found.',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _keys!.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (ctx, i) {
                                final k = _keys![i];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: k.revoked
                                        ? cs.errorContainer
                                            .withValues(alpha: 0.3)
                                        : cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.vpn_key_rounded,
                                        size: 16,
                                        color: k.revoked
                                            ? cs.error
                                            : cs.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              k.key,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontFamily: 'monospace',
                                                    fontWeight: FontWeight.w500,
                                                    decoration: k.revoked
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Created: ${_formatDate(k.createdAt)} '
                                              '| Last used: ${_formatDate(k.lastUsedAt)}'
                                              '${k.revoked ? ' | REVOKED' : ''}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color:
                                                        cs.onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!k.revoked) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(Icons.block_rounded,
                                              color: cs.error, size: 16),
                                          onPressed: () => _revokeKey(k),
                                          tooltip: 'Revoke key',
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        UkButton(
          label: 'Close',
          variant: UkButtonVariant.outline,
          size: UkButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
