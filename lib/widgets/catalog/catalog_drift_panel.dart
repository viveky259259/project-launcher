import 'dart:io';
import 'package:flutter/material.dart';
import 'package:launcher_kit/launcher_kit.dart';
import 'package:launcher_theme/launcher_theme.dart';
import 'package:launcher_models/launcher_models.dart';
import '../../screens/onboarding_catalog_screen.dart';
import '../../services/catalog_service.dart';
import 'join_workspace_dialog.dart';

/// Panel showing catalog sync status and repo drift.
///
/// Displays connected org info, last-sync time, and three sections:
/// missing repos (red), synced repos (green), and extra repos (yellow).
class CatalogDriftPanel extends StatefulWidget {
  const CatalogDriftPanel({super.key});

  @override
  State<CatalogDriftPanel> createState() => _CatalogDriftPanelState();
}

class _CatalogDriftPanelState extends State<CatalogDriftPanel> {
  bool _isSyncing = false;
  String? _syncError;
  // Track per-repo clone in-progress
  final Set<String> _cloningRepos = {};

  @override
  void initState() {
    super.initState();
    CatalogService.instance.addListener(_onServiceUpdate);
    // Trigger initial diff fetch if connected and no diff yet
    if (CatalogService.instance.isConnected && CatalogService.instance.lastDiff == null) {
      _refreshDiff();
    }
  }

  @override
  void dispose() {
    CatalogService.instance.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshDiff() async {
    setState(() {
      _syncError = null;
    });
    try {
      await CatalogService.instance.computeDiff();
    } catch (e) {
      if (mounted) {
        setState(() => _syncError = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _syncAll() async {
    setState(() {
      _isSyncing = true;
      _syncError = null;
    });
    try {
      final basePath = _defaultBasePath;
      await CatalogService.instance.syncAllMissing(basePath);
      await _refreshDiff();
    } catch (e) {
      if (mounted) {
        setState(() => _syncError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _cloneRepo(CatalogRepo repo) async {
    setState(() => _cloningRepos.add(repo.name));
    try {
      final basePath = _defaultBasePath;
      await CatalogService.instance.syncRepo(repo, basePath);
      await _refreshDiff();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to clone ${repo.name}: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cloningRepos.remove(repo.name));
    }
  }

  /// Use ~/Developer as the default clone base path.
  String get _defaultBasePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Developer';
  }

  Future<void> _showJoinDialog() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const JoinWorkspaceDialog(),
    );
    // After dialog closes, refresh diff if now connected
    if (CatalogService.instance.isConnected) {
      await _refreshDiff();
    }
  }

  Future<void> _startOnboarding() async {
    try {
      await CatalogService.instance.startOnboarding();
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const OnboardingCatalogScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _syncError =
            e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _navigateToChecklist() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnboardingCatalogScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(cs),
          const Divider(height: 1, thickness: 1),
          _buildBody(cs),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    final workspace = CatalogService.instance.workspace;
    final diff = CatalogService.instance.lastDiff;

    String subtitle;
    if (!CatalogService.instance.isConnected) {
      subtitle = 'Not connected';
    } else if (diff == null) {
      subtitle = 'Tap sync to check status';
    } else {
      final age = DateTime.now().difference(diff.computedAt);
      if (age.inMinutes < 1) {
        subtitle = 'Last synced: just now';
      } else if (age.inHours < 1) {
        subtitle = 'Last synced: ${age.inMinutes}m ago';
      } else if (age.inDays < 1) {
        subtitle = 'Last synced: ${age.inHours}h ago';
      } else {
        subtitle = 'Last synced: ${age.inDays}d ago';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: CatalogService.instance.isConnected
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : cs.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              CatalogService.instance.isConnected
                  ? Icons.hub_rounded
                  : Icons.hub_outlined,
              size: 16,
              color: CatalogService.instance.isConnected
                  ? AppColors.accent
                  : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workspace != null
                      ? 'Team Catalog · ${workspace.githubOrg}'
                      : 'Team Catalog',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (CatalogService.instance.isConnected) ...[
            // Refresh button
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              onPressed: _isSyncing ? null : _refreshDiff,
              tooltip: 'Refresh diff',
              color: cs.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
            ),
            // Sync All button
            UkButton(
              label: _isSyncing ? 'Syncing...' : 'Sync All',
              icon: Icons.download_rounded,
              variant: UkButtonVariant.tonal,
              size: UkButtonSize.small,
              onPressed: (_isSyncing ||
                      (CatalogService.instance.lastDiff?.missingRepos.isEmpty ?? true))
                  ? null
                  : _syncAll,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (!CatalogService.instance.isConnected) {
      return _buildNotConnectedState(cs);
    }

    if (CatalogService.instance.lastDiff == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: UkSpinner(size: UkSpinnerSize.large),
        ),
      );
    }

    final diff = CatalogService.instance.lastDiff!;
    final checklist = CatalogService.instance.onboardingChecklist;
    final showOnboardingBanner =
        checklist != null && !checklist.isComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Onboarding-in-progress banner
        if (showOnboardingBanner)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _OnboardingProgressBanner(
              checklist: checklist,
              onViewChecklist: _navigateToChecklist,
            ),
          ),

        if (_syncError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: UkAlert(
              message: _syncError!,
              type: UkAlertType.danger,
              dismissible: true,
              onDismissed: () => setState(() => _syncError = null),
            ),
          ),

        // "Setup my machine" button — shown when there are missing repos
        // and no active onboarding already in progress
        if (diff.missingRepos.isNotEmpty && !showOnboardingBanner)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: UkButton(
              label: 'Setup my machine',
              icon: Icons.laptop_mac_rounded,
              variant: UkButtonVariant.tonal,
              size: UkButtonSize.small,
              onPressed: _startOnboarding,
            ),
          ),

        // Missing repos section
        _buildSection(
          context,
          cs,
          title: 'Missing',
          count: diff.missingRepos.length,
          badgeColor: AppColors.error,
          icon: Icons.cloud_download_outlined,
          iconColor: AppColors.error,
          emptyLabel: 'All catalog repos are cloned',
          children: diff.missingRepos
              .map((repo) => _buildMissingRepoRow(cs, repo))
              .toList(),
        ),

        if (diff.missingRepos.isNotEmpty && diff.syncedRepos.isNotEmpty)
          Divider(
              height: 1,
              thickness: 1,
              color: cs.outline.withValues(alpha: 0.08)),

        // Synced repos section
        _buildSection(
          context,
          cs,
          title: 'Synced',
          count: diff.syncedRepos.length,
          badgeColor: AppColors.success,
          icon: Icons.check_circle_outline_rounded,
          iconColor: AppColors.success,
          emptyLabel: 'No repos synced yet',
          children: diff.syncedRepos
              .map((repo) => _buildSyncedRepoRow(cs, repo))
              .toList(),
        ),

        if (diff.extraRepos.isNotEmpty)
          Divider(
              height: 1,
              thickness: 1,
              color: cs.outline.withValues(alpha: 0.08)),

        // Extra repos section
        if (diff.extraRepos.isNotEmpty)
          _buildSection(
            context,
            cs,
            title: 'Extra',
            count: diff.extraRepos.length,
            badgeColor: AppColors.warning,
            icon: Icons.folder_special_outlined,
            iconColor: AppColors.warning,
            emptyLabel: '',
            children: diff.extraRepos
                .map((name) => _buildExtraRepoRow(cs, name))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildNotConnectedState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hub_outlined,
              size: 32,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Connect to a Team Catalog',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Stay in sync with your team\'s required repositories.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 16),
          UkButton(
            label: 'Join Workspace',
            icon: Icons.login_rounded,
            variant: UkButtonVariant.primary,
            size: UkButtonSize.small,
            onPressed: _showJoinDialog,
          ),
          const SizedBox(height: 8),
          UkButton(
            label: 'Setup my machine',
            icon: Icons.laptop_mac_rounded,
            variant: UkButtonVariant.tonal,
            size: UkButtonSize.small,
            onPressed: CatalogService.instance.isConnected ? _startOnboarding : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    ColorScheme cs, {
    required String title,
    required int count,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required String emptyLabel,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: badgeColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // Rows or empty label
          if (children.isEmpty && emptyLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                emptyLabel,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _buildMissingRepoRow(ColorScheme cs, CatalogRepo repo) {
    final isCloning = _cloningRepos.contains(repo.name);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 14, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repo.name,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (repo.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: repo.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              tag,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isCloning)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            )
          else
            GestureDetector(
              onTap: () => _cloneRepo(repo),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border:
                      Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.download_rounded,
                        size: 12, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Clone',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncedRepoRow(ColorScheme cs, CatalogRepo repo) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 14, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repo.name,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (repo.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: repo.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              tag,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraRepoRow(ColorScheme cs, String repoName) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 14, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              repoName,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '(personal)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.warning,
                    fontSize: 10,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onboarding progress banner ────────────────────────────────────────────────

/// Compact banner shown when a catalog onboarding is in progress but not yet
/// complete. Displays the current progress percentage and a "View Checklist"
/// button.
class _OnboardingProgressBanner extends StatelessWidget {
  const _OnboardingProgressBanner({
    required this.checklist,
    required this.onViewChecklist,
  });

  final OnboardingChecklist checklist;
  final VoidCallback onViewChecklist;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (checklist.progress * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_rounded,
              size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Onboarding in progress ($pct%)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onViewChecklist,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.checklist_rounded,
                      size: 12, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'View Checklist',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
