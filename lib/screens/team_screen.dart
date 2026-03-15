import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/team_service.dart';
import '../services/project_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';
import 'health_screen.dart';
import 'insights_screen.dart';
import 'year_review_screen.dart';
import 'referral_screen.dart';
import 'subscription_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<TeamWorkspace> _workspaces = [];
  TeamWorkspace? _selectedWorkspace;
  TeamHealthSummary? _healthSummary;
  List<TeamActivity> _activities = [];
  bool _isLoading = true;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _loadWorkspaces();
  }

  Future<void> _loadWorkspaces() async {
    final workspaces = await TeamService.loadWorkspaces();
    if (mounted) {
      setState(() {
        _workspaces = workspaces;
        _isLoading = false;
        if (workspaces.isNotEmpty && _selectedWorkspace == null) {
          _selectWorkspace(workspaces.first);
        }
      });
    }
  }

  Future<void> _selectWorkspace(TeamWorkspace workspace) async {
    setState(() {
      _selectedWorkspace = workspace;
      _isLoadingDetails = true;
    });

    final health = await TeamService.getTeamHealth(workspace);
    final activities = await TeamService.getRecentActivity(workspace);

    if (mounted) {
      setState(() {
        _healthSummary = health;
        _activities = activities;
        _isLoadingDetails = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AppSidebar(
            activeRoute: 'team',
            onNavigate: (route) {
              if (route == 'team') return;
              Navigator.of(context).pop();
              switch (route) {
                case 'health':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthScreen()));
                case 'insights':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InsightsScreen()));
                case 'year_review':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const YearReviewScreen()));
                case 'referrals':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReferralScreen()));
                case 'subscription':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
              }
            },
          ),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: cs.outline.withValues(alpha: 0.15))),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        color: cs.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text('Team Dashboard',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                            '${_workspaces.length} workspace${_workspaces.length != 1 ? 's' : ''}',
                            style: AppTypography.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showCreateWorkspace(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Workspace'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent))
                      : _workspaces.isEmpty
                          ? _buildEmptyState(cs)
                          : _buildDashboard(cs),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.groups_rounded,
                size: 48, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          Text('No Team Workspaces',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Create a workspace to share project lists,\ntrack team health, and see activity feeds.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showCreateWorkspace(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Workspace'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(ColorScheme cs) {
    return Row(
      children: [
        // Workspace list sidebar
        Container(
          width: 240,
          decoration: BoxDecoration(
            border:
                Border(right: BorderSide(color: cs.outline.withValues(alpha: 0.1))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('WORKSPACES',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant, letterSpacing: 1.2)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _workspaces.length,
                  itemBuilder: (context, index) {
                    final ws = _workspaces[index];
                    final isSelected = _selectedWorkspace?.id == ws.id;
                    return _WorkspaceListTile(
                      workspace: ws,
                      isSelected: isSelected,
                      onTap: () => _selectWorkspace(ws),
                      onDelete: () => _deleteWorkspace(ws),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Main detail area
        Expanded(
          child: _selectedWorkspace == null
              ? const Center(child: Text('Select a workspace'))
              : _isLoadingDetails
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent))
                  : _buildWorkspaceDetail(cs),
        ),
      ],
    );
  }

  Widget _buildWorkspaceDetail(ColorScheme cs) {
    final ws = _selectedWorkspace!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Workspace header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ws.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (ws.description != null) ...[
                    const SizedBox(height: 4),
                    Text(ws.description!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            _WorkspaceActionChip(
              icon: Icons.person_add_rounded,
              label: '${ws.members.length} member${ws.members.length != 1 ? 's' : ''}',
              onTap: () {},
            ),
            const SizedBox(width: 8),
            _WorkspaceActionChip(
              icon: Icons.share_rounded,
              label: 'Export',
              onTap: () => _exportWorkspace(ws),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Health summary row
        if (_healthSummary != null) ...[
          Text('Team Health',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              _HealthTile(
                label: 'Avg Score',
                value: '${_healthSummary!.avgScore.round()}',
                color: _healthSummary!.avgScore >= 80
                    ? AppColors.success
                    : _healthSummary!.avgScore >= 50
                        ? AppColors.warning
                        : AppColors.error,
                suffix: '/100',
              ),
              const SizedBox(width: 12),
              _HealthTile(
                label: 'Healthy',
                value: '${_healthSummary!.healthyCount}',
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _HealthTile(
                label: 'Needs Attention',
                value: '${_healthSummary!.attentionCount}',
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              _HealthTile(
                label: 'Critical',
                value: '${_healthSummary!.criticalCount}',
                color: AppColors.error,
              ),
              const SizedBox(width: 12),
              _HealthTile(
                label: 'Unpushed',
                value: '${_healthSummary!.totalUnpushed}',
                color: const Color(0xFFE879F9),
              ),
            ],
          ),
          if (_healthSummary!.weakestProject != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    'Weakest: ${_healthSummary!.weakestProject} (${_healthSummary!.weakestScore}/100)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
        ],

        // Shared projects
        Row(
          children: [
            Text('Shared Projects',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showAddProject(ws),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Project'),
              style:
                  TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (ws.projects.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_open_rounded,
                      size: 32, color: cs.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text('No shared projects yet',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          )
        else
          ...ws.projects.map((project) => _SharedProjectCard(
                project: project,
                onRemove: () async {
                  final updated = await TeamService
                      .removeProjectFromWorkspace(ws, project.localPath);
                  setState(() => _selectedWorkspace = updated);
                  _selectWorkspace(updated);
                },
              )),

        const SizedBox(height: 28),

        // Activity feed
        Text('Recent Activity',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),

        if (_activities.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Text('No recent activity',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ),
          )
        else
          ..._activities.take(15).map(
                (activity) => _ActivityCard(activity: activity),
              ),
      ],
    );
  }

  Future<void> _deleteWorkspace(TeamWorkspace ws) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workspace?'),
        content: Text('This will delete "${ws.name}" and all its data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await TeamService.deleteWorkspace(ws.id);
      if (_selectedWorkspace?.id == ws.id) {
        _selectedWorkspace = null;
        _healthSummary = null;
        _activities = [];
      }
      _loadWorkspaces();
    }
  }

  Future<void> _exportWorkspace(TeamWorkspace ws) async {
    final json = await TeamService.exportWorkspace(ws);
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Workspace JSON copied to clipboard'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _showCreateWorkspace(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: const Text('Create Workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Workspace Name',
                hintText: 'e.g. Backend Team',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. All backend microservices',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              final ws = await TeamService.createWorkspace(
                name: name,
                description: descController.text.trim().isNotEmpty
                    ? descController.text.trim()
                    : null,
              );
              await _loadWorkspaces();
              _selectWorkspace(ws);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddProject(TeamWorkspace workspace) async {
    final projects = await ProjectStorage.loadProjects();
    final existingPaths =
        workspace.projects.map((p) => p.localPath).toSet();
    final available =
        projects.where((p) => !existingPaths.contains(p.path)).toList();

    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: const Text('Add Project'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: available.isEmpty
              ? Center(
                  child: Text('All projects already added',
                      style: Theme.of(ctx)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant)),
                )
              : ListView.builder(
                  itemCount: available.length,
                  itemBuilder: (ctx, index) {
                    final project = available[index];
                    return ListTile(
                      leading: Icon(Icons.folder_rounded,
                          color: cs.onSurfaceVariant),
                      title: Text(project.name),
                      subtitle: Text(project.path,
                          style: Theme.of(ctx)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final updated =
                            await TeamService.addProjectToWorkspace(
                                workspace, project.path);
                        setState(() => _selectedWorkspace = updated);
                        _selectWorkspace(updated);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──

class _WorkspaceListTile extends StatelessWidget {
  final TeamWorkspace workspace;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WorkspaceListTile({
    required this.workspace,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: isSelected
              ? Border.all(color: AppColors.accent.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(Icons.workspaces_rounded,
                size: 16,
                color: isSelected ? AppColors.accent : cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workspace.name,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isSelected
                              ? AppColors.accent
                              : cs.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500)),
                  Text(
                    '${workspace.projects.length} projects',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant, fontSize: 10),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 16, color: cs.onSurfaceVariant),
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                    value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WorkspaceActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? suffix;

  const _HealthTile({
    required this.label,
    required this.value,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color, fontWeight: FontWeight.w700)),
                if (suffix != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 2),
                    child: Text(suffix!,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedProjectCard extends StatelessWidget {
  final SharedProject project;
  final VoidCallback onRemove;

  const _SharedProjectCard({
    required this.project,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.folder_rounded,
                size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(project.localPath,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis),
                if (project.remoteUrl != null) ...[
                  const SizedBox(height: 2),
                  Text(project.remoteUrl!,
                      style: AppTypography.mono(
                          fontSize: 10, color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          Text('by ${project.addedBy}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
            onPressed: onRemove,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final TeamActivity activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCommit = activity.type == 'commit';
    final age = DateTime.now().difference(activity.timestamp);
    final ageStr = age.inDays > 0
        ? '${age.inDays}d ago'
        : age.inHours > 0
            ? '${age.inHours}h ago'
            : '${age.inMinutes}m ago';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(
            isCommit
                ? Icons.commit_rounded
                : Icons.warning_amber_rounded,
            size: 16,
            color: isCommit ? AppColors.accent : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(activity.projectName,
                style: AppTypography.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activity.description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (activity.author != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(activity.author!,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ),
          const SizedBox(width: 8),
          Text(ageStr,
              style: AppTypography.mono(
                  fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
