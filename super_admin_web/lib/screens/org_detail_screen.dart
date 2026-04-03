import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launcher_kit/launcher_kit.dart';
import '../services/super_admin_api.dart';
import '../widgets/admin_navbar.dart';
import '../widgets/confirm_dialog.dart';

class OrgDetailScreen extends StatefulWidget {
  const OrgDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  State<OrgDetailScreen> createState() => _OrgDetailScreenState();
}

class _OrgDetailScreenState extends State<OrgDetailScreen> {
  OrgDetail? _org;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Editable copies of feature flags
  Map<String, bool> _editedFlags = {};

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
      final org = await SuperAdminApi.getOrg(widget.slug);
      setState(() {
        _org = org;
        _editedFlags = Map.from(org.featureFlags);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_org == null) return;
    setState(() => _saving = true);
    try {
      await SuperAdminApi.updateOrg(
        widget.slug,
        UpdateOrgRequest(featureFlags: _editedFlags),
      );
      if (mounted) {
        UkToast.show(
          context,
          message: 'Changes saved.',
          type: UkToastType.success,
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        UkToast.show(
          context,
          message: 'Failed to save: $e',
          type: UkToastType.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleSuspend() async {
    if (_org == null) return;
    final isSuspended = _org!.suspended;
    final action = isSuspended ? 'unsuspend' : 'suspend';

    final confirmed = await showConfirmDialog(
      context,
      title: '${isSuspended ? 'Unsuspend' : 'Suspend'} "${_org!.name}"?',
      message: isSuspended
          ? 'This will reactivate the organization and restore access for all members.'
          : 'This will immediately block all members from accessing Project Launcher.',
      confirmLabel: isSuspended ? 'Unsuspend' : 'Suspend',
      destructive: !isSuspended,
    );
    if (!confirmed) return;

    try {
      if (isSuspended) {
        await SuperAdminApi.unsuspendOrg(widget.slug);
      } else {
        await SuperAdminApi.suspendOrg(widget.slug);
      }
      if (mounted) {
        UkToast.show(
          context,
          message: 'Organization ${action}ed.',
          type: UkToastType.success,
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        UkToast.show(
          context,
          message: 'Failed to $action: $e',
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

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
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
          Text('Failed to load org: $_error'),
          const SizedBox(height: 16),
          UkButton(label: 'Retry', onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    final org = _org!;

    final planVariant = switch (org.plan) {
      'enterprise' => UkBadgeVariant.primary,
      'pro' => UkBadgeVariant.secondary,
      _ => UkBadgeVariant.neutral,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back + title row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/orgs'),
                tooltip: 'Back to Orgs',
              ),
              const SizedBox(width: 8),
              Text(
                '${org.name} ',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '(${org.slug})',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (org.suspended) ...[
                const SizedBox(width: 12),
                UkBadge('SUSPENDED', variant: UkBadgeVariant.tertiary),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Info row
          UkCard(
            child: Row(
              children: [
                _InfoChip(label: 'Plan', value: org.plan, variant: planVariant),
                const SizedBox(width: 24),
                _InfoItem(label: 'Seats', value: '${org.seats}'),
                const SizedBox(width: 24),
                _InfoItem(label: 'Members', value: '${org.memberCount}'),
                const SizedBox(width: 24),
                _InfoItem(label: 'GitHub', value: org.githubOrg),
                const SizedBox(width: 24),
                _InfoItem(label: 'Created', value: _formatDate(org.createdAt)),
                const Spacer(),
                UkButton(
                  label: org.suspended ? 'Unsuspend' : 'Suspend',
                  icon: org.suspended
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  variant: org.suspended
                      ? UkButtonVariant.primary
                      : UkButtonVariant.outline,
                  size: UkButtonSize.small,
                  onPressed: _toggleSuspend,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Feature Flags
          UkCard(
            header: const Text('Feature Flags'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_editedFlags.isEmpty)
                  Text(
                    'No feature flags configured.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                else
                  ..._editedFlags.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: UkSwitch(
                        value: entry.value,
                        label: _formatFlagName(entry.key),
                        onChanged: (v) {
                          setState(() {
                            _editedFlags[entry.key] = v;
                          });
                        },
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: UkButton(
                    label: _saving ? 'Saving...' : 'Save Changes',
                    size: UkButtonSize.small,
                    onPressed: _saving ? null : _saveChanges,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Members table
          Text(
            'Members (${org.members.length})',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (org.members.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No members.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: org.members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) =>
                  _MemberRow(member: org.members[i], formatTime: _formatTime),
            ),
        ],
      ),
    );
  }

  String _formatFlagName(String key) {
    // Convert camelCase or snake_case to Title Case
    return key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.variant,
  });

  final String label;
  final String value;
  final UkBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        UkBadge(value, variant: variant),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.formatTime});

  final OrgMember member;
  final String Function(DateTime?) formatTime;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final roleVariant = switch (member.role) {
      'admin' => UkBadgeVariant.primary,
      'owner' => UkBadgeVariant.secondary,
      _ => UkBadgeVariant.neutral,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              backgroundImage: member.avatarUrl != null &&
                      member.avatarUrl!.isNotEmpty
                  ? NetworkImage(member.avatarUrl!)
                  : null,
              child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                  ? Text(
                      member.githubLogin.isNotEmpty
                          ? member.githubLogin[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: cs.onPrimaryContainer, fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Login
            Expanded(
              flex: 2,
              child: Text(
                member.githubLogin,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            // Role
            SizedBox(
              width: 90,
              child: UkBadge(member.role, variant: roleVariant),
            ),
            // Joined
            SizedBox(
              width: 120,
              child: Text(
                'Joined ${formatTime(member.joinedAt)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
            // Last seen
            SizedBox(
              width: 120,
              child: Text(
                'Last seen ${formatTime(member.lastSeenAt)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
