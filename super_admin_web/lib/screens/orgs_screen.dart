import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launcher_kit/launcher_kit.dart';
import '../services/super_admin_api.dart';
import '../widgets/admin_navbar.dart';
import '../widgets/create_org_dialog.dart';

class OrgsScreen extends StatefulWidget {
  const OrgsScreen({super.key});

  @override
  State<OrgsScreen> createState() => _OrgsScreenState();
}

class _OrgsScreenState extends State<OrgsScreen> {
  List<OrgSummary>? _orgs;
  String _filter = '';
  bool _loading = true;
  String? _error;

  List<OrgSummary> get _filtered {
    final orgs = _orgs ?? [];
    if (_filter.isEmpty) return orgs;
    final q = _filter.toLowerCase();
    return orgs.where((o) {
      return o.slug.toLowerCase().contains(q) ||
          o.name.toLowerCase().contains(q) ||
          o.plan.toLowerCase().contains(q);
    }).toList();
  }

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
      final orgs = await SuperAdminApi.listOrgs();
      setState(() {
        _orgs = orgs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createOrg() async {
    final req = await showCreateOrgDialog(context);
    if (req == null) return;
    try {
      await SuperAdminApi.createOrg(req);
      if (mounted) {
        UkToast.show(
          context,
          message: 'Organization "${req.name}" created.',
          type: UkToastType.success,
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        UkToast.show(
          context,
          message: 'Failed to create org: $e',
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
          Text('Failed to load organizations: $_error'),
          const SizedBox(height: 16),
          UkButton(label: 'Retry', onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    final orgs = _filtered;
    final total = _orgs?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            children: [
              Text(
                'Organizations ($total)',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              UkButton(
                label: '+ Create Org',
                size: UkButtonSize.small,
                icon: Icons.add_rounded,
                onPressed: _createOrg,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter input
          UkTextField(
            hint: 'Filter by slug, name, or plan...',
            prefixIcon: Icons.search_rounded,
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 16),
          // Org list
          Expanded(
            child: orgs.isEmpty
                ? Center(
                    child: Text(
                      _filter.isEmpty
                          ? 'No organizations yet.'
                          : 'No orgs match "$_filter".',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: orgs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (ctx, i) => _OrgRow(
                      org: orgs[i],
                      onTap: () => context.go('/orgs/${orgs[i].slug}'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrgRow extends StatelessWidget {
  const _OrgRow({
    required this.org,
    required this.onTap,
  });

  final OrgSummary org;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final planVariant = switch (org.plan) {
      'enterprise' => UkBadgeVariant.primary,
      'pro' => UkBadgeVariant.secondary,
      _ => UkBadgeVariant.neutral,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Slug
              Expanded(
                flex: 2,
                child: Text(
                  org.slug,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'JetBrains Mono',
                      ),
                ),
              ),
              // Name
              Expanded(
                flex: 2,
                child: Text(
                  org.name,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              // Plan badge
              SizedBox(
                width: 100,
                child: UkBadge(org.plan, variant: planVariant),
              ),
              // Seats
              SizedBox(
                width: 70,
                child: Text(
                  '${org.seats} seats',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
              // Members
              SizedBox(
                width: 80,
                child: Text(
                  '${org.memberCount} members',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
              // Status
              SizedBox(
                width: 90,
                child: org.suspended
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: cs.error),
                          const SizedBox(width: 4),
                          Text(
                            'suspended',
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
                            'active',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.primary),
                          ),
                        ],
                      ),
              ),
              // Arrow
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
