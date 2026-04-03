import 'package:flutter/material.dart';
import 'package:launcher_kit/launcher_kit.dart';
import 'package:launcher_models/launcher_models.dart';
import '../services/admin_api.dart';
import '../widgets/admin_navbar.dart';
import '../widgets/repo_form_dialog.dart';
import '../widgets/confirm_dialog.dart';

class ReposScreen extends StatefulWidget {
  const ReposScreen({super.key});

  @override
  State<ReposScreen> createState() => _ReposScreenState();
}

class _ReposScreenState extends State<ReposScreen> {
  Catalog? _catalog;
  String _filter = '';
  bool _loading = true;
  bool _publishing = false;
  String? _error;

  List<CatalogRepo> get _filtered {
    final repos = _catalog?.repos ?? [];
    if (_filter.isEmpty) return repos;
    final q = _filter.toLowerCase();
    return repos.where((r) {
      return r.name.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q)) ||
          r.url.toLowerCase().contains(q);
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
      final catalog = await AdminApi.getCatalog();
      setState(() {
        _catalog = catalog;
        _loading = false;
      });
    } catch (e) {
      // 404 = no catalog published yet — start with an empty one
      if (e is AdminApiException && e.statusCode == 404) {
        setState(() {
          _catalog = Catalog(
            version: '0.1.0',
            githubOrg: AdminApi.orgSlug,
            repos: [],
            envTemplates: [],
          );
          _loading = false;
        });
      } else {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _addRepo() async {
    final templateNames =
        _catalog?.envTemplates.map((t) => t.name).toList() ?? [];
    final repo = await showRepoFormDialog(
      context,
      templateNames: templateNames,
    );
    if (repo == null) return;
    setState(() {
      _catalog = _catalog?.copyWith(
        repos: [...?_catalog?.repos, repo],
      );
    });
  }

  Future<void> _editRepo(CatalogRepo repo) async {
    final templateNames =
        _catalog?.envTemplates.map((t) => t.name).toList() ?? [];
    final updated = await showRepoFormDialog(
      context,
      existing: repo,
      templateNames: templateNames,
    );
    if (updated == null) return;
    setState(() {
      final repos = _catalog?.repos.map((r) => r == repo ? updated : r).toList() ?? [];
      _catalog = _catalog?.copyWith(repos: repos);
    });
  }

  Future<void> _deleteRepo(CatalogRepo repo) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "${repo.name}"?',
      message: 'This will remove the repo from the catalog. Members will not be notified until you publish.',
    );
    if (!confirmed) return;
    setState(() {
      final repos = _catalog?.repos.where((r) => r != repo).toList() ?? [];
      _catalog = _catalog?.copyWith(repos: repos);
    });
  }

  Future<void> _publish() async {
    if (_catalog == null) return;
    setState(() => _publishing = true);
    try {
      await AdminApi.publishCatalog(_catalog!);
      if (mounted) {
        UkToast.show(
          context,
          message: 'Catalog published successfully.',
          type: UkToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        UkToast.show(
          context,
          message: 'Publish failed: $e',
          type: UkToastType.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final repos = _filtered;
    final total = _catalog?.repos.length ?? 0;

    return Scaffold(
      appBar: const AdminNavbar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(cs, repos, total),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Failed to load catalog: $_error'),
          const SizedBox(height: 16),
          UkButton(label: 'Retry', onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, List<CatalogRepo> repos, int total) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            children: [
              Text(
                'Repos ($total)',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              UkButton(
                label: '+ Add Repo',
                size: UkButtonSize.small,
                icon: Icons.add_rounded,
                onPressed: _addRepo,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter input
          UkTextField(
            hint: 'Filter repos...',
            prefixIcon: Icons.search_rounded,
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 16),
          // Repo list
          Expanded(
            child: repos.isEmpty
                ? Center(
                    child: Text(
                      _filter.isEmpty ? 'No repos in catalog yet.' : 'No repos match "$_filter".',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: repos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (ctx, i) => _RepoRow(
                      repo: repos[i],
                      onEdit: () => _editRepo(repos[i]),
                      onDelete: () => _deleteRepo(repos[i]),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // Publish button aligned right
          Align(
            alignment: Alignment.centerRight,
            child: UkButton(
              label: _publishing ? 'Publishing...' : 'Publish Catalog',
              icon: Icons.publish_rounded,
              onPressed: _publishing ? null : _publish,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepoRow extends StatelessWidget {
  const _RepoRow({
    required this.repo,
    required this.onEdit,
    required this.onDelete,
  });

  final CatalogRepo repo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isRequired = repo.required;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isRequired ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              flex: 3,
              child: Text(
                repo.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            // Tags
            Expanded(
              flex: 2,
              child: Wrap(
                spacing: 4,
                children: repo.tags
                    .take(3)
                    .map((t) => UkBadge(t, variant: UkBadgeVariant.neutral))
                    .toList(),
              ),
            ),
            // Required badge
            SizedBox(
              width: 90,
              child: isRequired
                  ? const UkBadge('required', variant: UkBadgeVariant.primary)
                  : const UkBadge('optional', variant: UkBadgeVariant.neutral),
            ),
            // Env template indicator
            SizedBox(
              width: 32,
              child: repo.envTemplateName != null
                  ? Tooltip(
                      message: 'Template: ${repo.envTemplateName}',
                      child: Icon(Icons.description_rounded,
                          size: 16, color: cs.primary),
                    )
                  : const SizedBox.shrink(),
            ),
            // Actions
            UkButton(
              label: 'Edit',
              variant: UkButtonVariant.outline,
              size: UkButtonSize.small,
              onPressed: onEdit,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: cs.error, size: 18),
              onPressed: onDelete,
              tooltip: 'Delete',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
