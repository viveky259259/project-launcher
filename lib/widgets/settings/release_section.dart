import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launcher_models/launcher_models.dart';
import 'package:launcher_native/launcher_native.dart';
import 'package:launcher_theme/launcher_theme.dart';
import '../../services/gemini_service.dart';
import '../../services/netlaunch_service.dart';
import '../../services/platform_helper.dart';
import '../../services/release_service.dart';
import '../../services/version_detector.dart';

/// Self-contained release tab extracted from ProjectSettingsScreen.
class ReleaseSection extends StatefulWidget {
  final Project project;

  const ReleaseSection({super.key, required this.project});

  @override
  State<ReleaseSection> createState() => _ReleaseSectionState();
}

class _ReleaseSectionState extends State<ReleaseSection> {
  // Release data
  ReleaseInfo? _releaseInfo;
  ReadinessScore? _readinessScore;
  DeploymentConfig? _deploymentConfig;
  bool _releaseLoaded = false;
  bool _bumpingVersion = false;
  ReleaseProcess? _releaseProcess;
  bool _creatingTag = false;
  bool _shippingRelease = false;
  bool _deployingNetLaunch = false;

  @override
  void initState() {
    super.initState();
    _loadReleaseData();
  }

  Future<void> _loadReleaseData() async {
    final info = await VersionDetector.detect(widget.project.path);
    final score = await ReleaseService.getReadinessScore(widget.project.path);
    final deploy = ReleaseService.detectDeploymentConfig(widget.project.path);
    final process = await ReleaseService.detectReleaseProcess(
      widget.project.path,
    );
    if (mounted) {
      setState(() {
        _releaseInfo = info;
        _readinessScore = score;
        _deploymentConfig = deploy;
        _releaseProcess = process;
        _releaseLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _buildReleaseSection(cs);
  }

  Widget _buildReleaseSection(ColorScheme cs) {
    if (!_releaseLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final info = _releaseInfo!;
    final score = _readinessScore!;
    final deploy = _deploymentConfig!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with readiness score
        Row(
          children: [
            Text(
              'Release',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:
                    (score.total >= 80
                            ? AppColors.success
                            : score.total >= 50
                            ? AppColors.warning
                            : AppColors.error)
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${score.total}/100',
                style: AppTypography.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: score.total >= 80
                      ? AppColors.success
                      : score.total >= 50
                      ? AppColors.warning
                      : AppColors.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Version + Tag info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tag_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    info.version != null
                        ? 'v${info.version}'
                        : 'No version detected',
                    style: AppTypography.mono(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  if (info.versionSource != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'from ${info.versionSource}',
                      style: AppTypography.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (info.lastTag != null) ...[
                    Text(
                      'Last tag: ${info.lastTag}',
                      style: AppTypography.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (info.unreleasedCommits > 0)
                      Text(
                        ' (+${info.unreleasedCommits} unreleased)',
                        style: AppTypography.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                  ] else
                    Text(
                      'No tags yet',
                      style: AppTypography.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  if (info.isDeployable && info.deployTargets.isNotEmpty)
                    ...info.deployTargets.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            t,
                            style: AppTypography.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Readiness score breakdown
        Text(
          'Readiness Breakdown',
          style: AppTypography.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        // Score bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score.total / 100,
            backgroundColor: cs.outline.withValues(alpha: 0.1),
            color: score.total >= 80
                ? AppColors.success
                : score.total >= 50
                ? AppColors.warning
                : AppColors.error,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        // Individual items
        ...score.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  item.passed
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 16,
                  color: item.passed
                      ? AppColors.success
                      : cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTypography.inter(
                      fontSize: 12,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${item.points}/${item.maxPoints}',
                  style: AppTypography.mono(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (item.detail != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    item.detail!,
                    style: AppTypography.inter(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // CI/CD info
        if (deploy.ciProvider != null ||
            deploy.buildTools.isNotEmpty ||
            deploy.containerFiles.isNotEmpty) ...[
          Text(
            'Build & Deploy',
            style: AppTypography.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (deploy.ciProvider != null)
                _infoBadge(
                  deploy.ciProvider!,
                  Icons.play_circle_outline_rounded,
                  cs,
                ),
              ...deploy.buildTools.map(
                (t) => _infoBadge(t, Icons.build_rounded, cs),
              ),
              ...deploy.containerFiles.map(
                (f) => _infoBadge(f, Icons.view_in_ar_rounded, cs),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Detected release process
        if (_releaseProcess != null) ...[
          Row(
            children: [
              Text(
                'Release Process',
                style: AppTypography.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  _releaseProcess!.method,
                  style: AppTypography.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Show detected steps
          ...(_releaseProcess!.steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            final typeIcon = switch (step.type) {
              ReleaseStepType.script => Icons.description_rounded,
              ReleaseStepType.make => Icons.build_rounded,
              ReleaseStepType.npm => Icons.javascript_rounded,
              ReleaseStepType.fastlane => Icons.fast_forward_rounded,
              ReleaseStepType.githubAction => Icons.play_circle_outline_rounded,
              ReleaseStepType.tool => Icons.settings_rounded,
              ReleaseStepType.builtin => Icons.auto_fix_high_rounded,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: AppTypography.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(typeIcon, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.name,
                          style: AppTypography.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          step.description,
                          style: AppTypography.inter(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (step.isAutomated)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'auto',
                        style: AppTypography.mono(
                          fontSize: 9,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                ],
              ),
            );
          })),
          const SizedBox(height: 16),

          // Ship It button — runs the detected process
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shippingRelease ? null : _shipWithDetectedProcess,
              icon: _shippingRelease
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.rocket_launch_rounded, size: 18),
              label: Text(_shippingRelease ? 'Shipping...' : 'Ship It'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: cs.surface,
                textStyle: AppTypography.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Manual actions
        if (info.version != null) ...[
          Text(
            'Manual Actions',
            style: AppTypography.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _releaseAction(
                'Bump Patch',
                Icons.arrow_upward_rounded,
                _bumpingVersion ? null : () => _bumpVersionAction('patch'),
                cs,
              ),
              _releaseAction(
                'Bump Minor',
                Icons.arrow_upward_rounded,
                _bumpingVersion ? null : () => _bumpVersionAction('minor'),
                cs,
              ),
              _releaseAction(
                'Bump Major',
                Icons.arrow_upward_rounded,
                _bumpingVersion ? null : () => _bumpVersionAction('major'),
                cs,
              ),
              _releaseAction(
                'Tag & Push',
                Icons.local_offer_rounded,
                _creatingTag ? null : _tagAndPush,
                cs,
              ),
              _releaseAction(
                'GitHub Release',
                Icons.rocket_launch_rounded,
                _creatingTag ? null : _createGitHubRelease,
                cs,
              ),
              _releaseAction(
                'Deploy to NetLaunch',
                Icons.cloud_upload_rounded,
                _deployingNetLaunch ? null : () => _deployToNetLaunch(cs),
                cs,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _infoBadge(String label, IconData icon, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.inter(fontSize: 12, color: cs.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _releaseAction(
    String label,
    IconData icon,
    VoidCallback? onPressed,
    ColorScheme cs,
  ) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onSurface,
        side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
        textStyle: AppTypography.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  Future<void> _bumpVersionAction(String level) async {
    setState(() => _bumpingVersion = true);
    final newVersion = await ReleaseService.bumpVersion(
      widget.project.path,
      level,
    );
    if (mounted) {
      setState(() => _bumpingVersion = false);
      if (newVersion != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Version bumped to $newVersion'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadReleaseData();
      }
    }
  }

  Future<void> _tagAndPush() async {
    if (_releaseInfo?.version == null) return;
    setState(() => _creatingTag = true);
    final tagged = await ReleaseService.createTag(
      widget.project.path,
      _releaseInfo!.version!,
    );
    if (tagged) await ReleaseService.pushTags(widget.project.path);
    if (mounted) {
      setState(() => _creatingTag = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tagged
                ? 'Tagged v${_releaseInfo!.version} and pushed'
                : 'Failed to create tag',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadReleaseData();
    }
  }

  Future<void> _createGitHubRelease() async {
    if (_releaseInfo?.version == null) return;
    setState(() => _creatingTag = true);
    final url = await ReleaseService.createGitHubRelease(
      widget.project.path,
      _releaseInfo!.version!,
    );
    if (mounted) {
      setState(() => _creatingTag = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            url != null
                ? 'GitHub release created'
                : 'Failed to create release (is gh CLI installed?)',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadReleaseData();
    }
  }

  Future<void> _shipWithDetectedProcess() async {
    final process = _releaseProcess;
    if (process == null || process.steps.isEmpty) return;

    // Show confirmation with detected steps
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Row(
            children: [
              Icon(
                Icons.rocket_launch_rounded,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text('Ship It'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detected release process: ${process.method}',
                  style: AppTypography.inter(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Steps to execute:',
                  style: AppTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...process.steps.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text(
                          '${e.key + 1}. ',
                          style: AppTypography.mono(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.value.name,
                            style: AppTypography.inter(
                              fontSize: 12,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        if (e.value.isAutomated)
                          Text(
                            '(auto)',
                            style: AppTypography.mono(
                              fontSize: 10,
                              color: AppColors.success,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ship It'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _shippingRelease = true);
    AppLogger.info(
      'Release',
      'Starting release with ${process.method} process (${process.steps.length} steps)',
    );

    String? currentVersion;
    final results = <String>[];
    var failed = false;

    for (final step in process.steps) {
      if (step.isAutomated) {
        results.add('${step.name}: skipped (automated by CI)');
        continue;
      }

      final result = await ReleaseService.executeStep(
        widget.project.path,
        step,
        version: currentVersion,
      );
      results.add(
        '${step.name}: ${result.success ? "OK" : "FAILED"} — ${result.output.split('\n').first}',
      );

      if (result.version != null) currentVersion = result.version;

      if (!result.success) {
        failed = true;
        break;
      }
    }

    if (!mounted) return;

    setState(() => _shippingRelease = false);

    // Show results in a dialog
    final output =
        '# Release: ${process.method}\n\n${results.join('\n')}\n\n${failed ? "FAILED — stopped at first error" : "All steps completed successfully"}';
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            backgroundColor: cs.surface,
            title: Text(
              failed ? 'Release Failed' : 'Release Complete',
              style: AppTypography.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: failed ? AppColors.error : AppColors.success,
              ),
            ),
            content: SizedBox(
              width: 500,
              child: SelectableText(
                output,
                style: AppTypography.mono(
                  fontSize: 12,
                  color: cs.onSurface,
                ).copyWith(height: 1.6),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }

    _loadReleaseData();
  }

  Future<void> _deployToNetLaunch(ColorScheme cs) async {
    setState(() => _deployingNetLaunch = true);

    // Show the progress dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _NetLaunchDeployDialog(
        projectPath: widget.project.path,
        projectName: widget.project.name,
      ),
    );

    if (mounted) {
      setState(() => _deployingNetLaunch = false);
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Deployed to NetLaunch')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _oneClickRelease(String level) async {
    final currentVersion = _releaseInfo?.version;
    if (currentVersion == null) return;

    final newVersion = VersionDetector.bumpVersion(currentVersion, level);
    final tagName = 'v$newVersion';

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Row(
            children: [
              Icon(
                Icons.rocket_launch_rounded,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Ship It',
                style: AppTypography.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will perform the following steps:',
                style: AppTypography.inter(fontSize: 13, color: cs.onSurface),
              ),
              const SizedBox(height: 12),
              _shipStep(
                '1',
                'Bump version $currentVersion \u2192 $newVersion',
                cs,
              ),
              _shipStep('2', 'Commit: "Release $tagName"', cs),
              _shipStep('3', 'Create tag $tagName', cs),
              _shipStep('4', 'Push commits and tags', cs),
              _shipStep('5', 'Create GitHub release', cs),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: AppTypography.inter(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: cs.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(
                'Ship It',
                style: AppTypography.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _shippingRelease = true);
    AppLogger.info(
      'Release',
      'One-click release started: $level bump for ${widget.project.name}',
    );

    try {
      // Step 1: Bump version
      final bumped = await ReleaseService.bumpVersion(
        widget.project.path,
        level,
      );
      if (bumped == null) {
        _showShipResult(false, 'Failed to bump version');
        return;
      }
      AppLogger.info('Release', 'Version bumped to $bumped');

      // Step 2: Commit version bump
      final committed = await ReleaseService.commitVersionBump(
        widget.project.path,
        bumped,
      );
      if (!committed) {
        _showShipResult(false, 'Failed to commit version bump');
        return;
      }
      AppLogger.info('Release', 'Version bump committed');

      // Step 3: Create tag
      final tagged = await ReleaseService.createTag(
        widget.project.path,
        bumped,
      );
      if (!tagged) {
        _showShipResult(false, 'Failed to create tag');
        return;
      }
      AppLogger.info('Release', 'Tag created');

      // Step 4: Push everything
      final pushed = await ReleaseService.pushAll(widget.project.path);
      if (!pushed) {
        _showShipResult(false, 'Failed to push (tag was created locally)');
        return;
      }
      AppLogger.info('Release', 'Pushed commits and tags');

      // Step 5: Create GitHub release
      final url = await ReleaseService.createGitHubRelease(
        widget.project.path,
        bumped,
      );
      if (url != null) {
        AppLogger.info('Release', 'GitHub release created: $url');
      } else {
        AppLogger.warn(
          'Release',
          'GitHub release failed (gh CLI may not be installed)',
        );
      }

      _showShipResult(
        true,
        'Shipped v$bumped${url != null ? '' : ' (GitHub release skipped)'}',
      );
    } catch (e) {
      AppLogger.error('Release', 'One-click release failed: $e');
      _showShipResult(false, 'Release failed: $e');
    }
  }

  Widget _shipStep(String number, String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: AppTypography.mono(fontSize: 10, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.inter(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showShipResult(bool success, String message) {
    if (mounted) {
      setState(() => _shippingRelease = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: success ? AppColors.success : AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadReleaseData();
    }
  }
}

// ─── NetLaunch Deploy Dialog ───────────────────────────────────────────

enum _DeployStep { checkCli, install, login, configure, deploy, done }

class _NetLaunchDeployDialog extends StatefulWidget {
  final String projectPath;
  final String projectName;

  const _NetLaunchDeployDialog({
    required this.projectPath,
    required this.projectName,
  });

  @override
  State<_NetLaunchDeployDialog> createState() => _NetLaunchDeployDialogState();
}

class _NetLaunchDeployDialogState extends State<_NetLaunchDeployDialog> {
  _DeployStep _currentStep = _DeployStep.checkCli;
  final List<_StepLog> _logs = [];
  bool _cliInstalled = false;
  bool _loggedIn = false;
  bool _failed = false;
  String? _deployUrl;
  String? _errorDetail;

  // User-configurable fields
  late final TextEditingController _siteNameController;
  late final TextEditingController _deployDirController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _buildCmdController;
  late final TextEditingController _outputDirController;
  bool _showApiKey = false;
  bool _suggestingBuild = false;
  bool _runningBuild = false;
  bool _buildCompleted = false;

  @override
  void initState() {
    super.initState();
    // Default site name from project name (sanitized)
    final safeName = widget.projectName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    _siteNameController = TextEditingController(
      text: safeName.length >= 3 ? safeName : 'my-site',
    );
    _deployDirController = TextEditingController(text: widget.projectPath);
    _apiKeyController = TextEditingController();
    _buildCmdController = TextEditingController();
    _outputDirController = TextEditingController();
    _startChecks();
    _loadLastDeploy();
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _deployDirController.dispose();
    _apiKeyController.dispose();
    _buildCmdController.dispose();
    _outputDirController.dispose();
    super.dispose();
  }

  void _addLog(String message, {bool isError = false, bool isSuccess = false}) {
    if (mounted) {
      setState(() {
        _logs.add(_StepLog(
          message: message,
          isError: isError,
          isSuccess: isSuccess,
          timestamp: DateTime.now(),
        ));
      });
    }
  }

  Future<void> _loadLastDeploy() async {
    final history = await NetLaunchService.getDeployHistoryForProject(
      widget.projectPath,
    );
    if (history.isNotEmpty && mounted) {
      final last = history.first;
      setState(() {
        _siteNameController.text = last.siteName;
        if (last.buildCommand != null && last.buildCommand!.isNotEmpty) {
          _buildCmdController.text = last.buildCommand!;
        }
        if (last.outputDir != null && last.outputDir!.isNotEmpty) {
          _outputDirController.text = last.outputDir!;
        }
      });
      _addLog('Loaded last deploy: ${last.url}', isSuccess: true);
    }
  }

  Future<void> _startChecks() async {
    _addLog('Checking prerequisites...');

    // Check npm
    final npmAvailable = await NetLaunchService.isNpmAvailable();
    if (!npmAvailable) {
      _addLog('npm not found — Node.js is required', isError: true);
      setState(() {
        _failed = true;
        _errorDetail = 'Install Node.js from https://nodejs.org';
      });
      return;
    }
    _addLog('npm available', isSuccess: true);

    // Check netlaunch CLI
    _cliInstalled = await NetLaunchService.isInstalled();
    if (_cliInstalled) {
      _addLog('netlaunch CLI installed', isSuccess: true);

      // Check login
      _loggedIn = await NetLaunchService.isLoggedIn();
      if (_loggedIn) {
        _addLog('Logged in to NetLaunch', isSuccess: true);
      } else {
        _addLog('Not logged in (API key or login required)');
      }

      // Move to configure step
      if (mounted) setState(() => _currentStep = _DeployStep.configure);
    } else {
      _addLog('netlaunch CLI not found');
      // Check npx fallback
      final npxAvailable = await NetLaunchService.isNpxAvailable();
      if (npxAvailable) {
        _addLog('npx available (can deploy without installing)');
      }
      if (mounted) setState(() => _currentStep = _DeployStep.install);
    }
  }

  Future<void> _installCli() async {
    _addLog('Installing netlaunch...');
    setState(() => _currentStep = _DeployStep.install);

    final result = await NetLaunchService.install(
      onProgress: (status) => _addLog(status),
    );

    if (result.success) {
      _addLog(result.message, isSuccess: true);
      _cliInstalled = true;
      if (mounted) setState(() => _currentStep = _DeployStep.configure);
    } else {
      _addLog(result.message, isError: true);
      if (result.error != null) {
        _addLog(result.error!);
      }
      // Still allow configuring — npx fallback will be used
      if (mounted) setState(() => _currentStep = _DeployStep.configure);
    }
  }

  Future<void> _loginCli() async {
    _addLog('Opening browser for login...');
    setState(() => _currentStep = _DeployStep.login);

    final result = await NetLaunchService.login(
      onProgress: (status) => _addLog(status),
    );

    if (result.success) {
      _addLog(result.message, isSuccess: true);
      _loggedIn = true;
    } else {
      _addLog(result.message, isError: true);
      _addLog('You can still deploy using an API key');
    }

    if (mounted) setState(() => _currentStep = _DeployStep.configure);
  }

  Future<void> _suggestBuildWithGemini() async {
    setState(() => _suggestingBuild = true);
    _addLog('Asking Gemini to analyze project...');

    final suggestion = await GeminiService.suggestBuildCommands(
      projectPath: widget.projectPath,
      onProgress: (status) => _addLog(status),
    );

    if (suggestion != null) {
      setState(() {
        _buildCmdController.text = suggestion.buildCommand;
        _outputDirController.text = suggestion.outputDir;
        _suggestingBuild = false;
      });
      _addLog('Build: ${suggestion.buildCommand}', isSuccess: true);
      _addLog('Output: ${suggestion.outputDir}', isSuccess: true);
    } else {
      _addLog('Could not get suggestion — enter commands manually', isError: true);
      setState(() => _suggestingBuild = false);
    }
  }

  Future<void> _runBuildAndDeploy() async {
    final buildCmd = _buildCmdController.text.trim();
    final outputDir = _outputDirController.text.trim();

    if (buildCmd.isEmpty) {
      // No build needed, go straight to deploy
      _startDeploy();
      return;
    }

    setState(() => _runningBuild = true);
    _addLog('Running build commands...');
    _addLog('\$ $buildCmd');

    try {
      final result = await Process.run(
        '/bin/zsh',
        ['-l', '-c', buildCmd],
        workingDirectory: widget.projectPath,
        environment: Platform.environment,
      );

      // Show output lines
      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();
      if (stdout.isNotEmpty) {
        // Show last few lines of output
        final lines = stdout.split('\n');
        final tail = lines.length > 5 ? lines.sublist(lines.length - 5) : lines;
        for (final line in tail) {
          _addLog(line);
        }
      }

      if (result.exitCode != 0) {
        _addLog('Build failed (exit ${result.exitCode})', isError: true);
        if (stderr.isNotEmpty) {
          final errLines = stderr.split('\n');
          for (final line in errLines.take(3)) {
            _addLog(line, isError: true);
          }
        }
        setState(() => _runningBuild = false);
        return;
      }

      _addLog('Build completed successfully', isSuccess: true);

      // Update deploy dir to the build output
      final resolvedDir = outputDir.startsWith('/')
          ? outputDir
          : '${widget.projectPath}/$outputDir';
      _deployDirController.text = resolvedDir;
      setState(() {
        _runningBuild = false;
        _buildCompleted = true;
      });

      // Proceed to deploy
      _startDeploy();
    } catch (e) {
      _addLog('Build error: $e', isError: true);
      setState(() => _runningBuild = false);
    }
  }

  Future<void> _startDeploy() async {
    final siteName = _siteNameController.text.trim();
    final deployDir = _deployDirController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    // Validate site name
    if (siteName.length < 3 || siteName.length > 30) {
      _addLog('Site name must be 3-30 characters', isError: true);
      return;
    }
    if (!RegExp(r'^[a-z][a-z0-9-]*[a-z0-9]$').hasMatch(siteName)) {
      _addLog(
        'Site name: lowercase letters, numbers, hyphens only. Must start with a letter.',
        isError: true,
      );
      return;
    }

    setState(() => _currentStep = _DeployStep.deploy);
    _addLog('Starting deployment to $siteName.web.app...');

    final result = await NetLaunchService.deploy(
      deployDir: deployDir,
      siteName: siteName,
      apiKey: apiKey.isNotEmpty ? apiKey : null,
      onProgress: (status) => _addLog(status),
    );

    if (result.success) {
      _addLog('Deployed successfully!', isSuccess: true);
      _addLog(result.message, isSuccess: true);

      // Save deploy record
      await NetLaunchService.saveDeployRecord(DeployRecord(
        projectPath: widget.projectPath,
        projectName: widget.projectName,
        siteName: siteName,
        url: result.message,
        buildCommand: _buildCmdController.text.trim().isNotEmpty
            ? _buildCmdController.text.trim()
            : null,
        outputDir: _outputDirController.text.trim().isNotEmpty
            ? _outputDirController.text.trim()
            : null,
        deployedAt: DateTime.now(),
      ));
      _addLog('Deploy record saved', isSuccess: true);

      setState(() {
        _deployUrl = result.message;
        _currentStep = _DeployStep.done;
      });
    } else {
      _addLog(result.message, isError: true);
      if (result.error != null) {
        setState(() => _errorDetail = result.error);
      }
      setState(() => _failed = true);
    }
  }

  void _skipInstall() {
    _addLog('Skipping install — will use npx fallback');
    if (mounted) setState(() => _currentStep = _DeployStep.configure);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      title: Row(
        children: [
          Icon(Icons.cloud_upload_rounded, color: AppColors.accent, size: 22),
          const SizedBox(width: 10),
          Text(
            'Deploy to NetLaunch',
            style: AppTypography.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step indicator
            _buildStepIndicator(cs),
            const SizedBox(height: 16),

            // Action area (install/configure/deploy)
            if (_currentStep == _DeployStep.install && !_cliInstalled)
              _buildInstallPrompt(cs),
            if (_currentStep == _DeployStep.configure)
              _buildConfigForm(cs),

            // Progress log
            const SizedBox(height: 12),
            Container(
              height: 180,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (_, i) => _buildLogLine(_logs[i], cs),
              ),
            ),

            // Error detail
            if (_errorDetail != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                _errorDetail!,
                style: AppTypography.mono(
                  fontSize: 11,
                  color: AppColors.error.withValues(alpha: 0.8),
                ),
                maxLines: 3,
              ),
            ],

            // Success result
            if (_deployUrl != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: InkWell(
                  onTap: () => PlatformHelper.openUrl(_deployUrl!),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _deployUrl!,
                          style: AppTypography.mono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ).copyWith(decoration: TextDecoration.underline),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.open_in_new_rounded,
                          size: 16, color: AppColors.accent),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _currentStep == _DeployStep.done,
          ),
          child: Text(
            _currentStep == _DeployStep.done ? 'Done' : 'Cancel',
            style: AppTypography.inter(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
        if (_currentStep == _DeployStep.configure)
          ElevatedButton.icon(
            onPressed: (_failed || _runningBuild || _suggestingBuild)
                ? null
                : _runBuildAndDeploy,
            icon: _runningBuild
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    _buildCmdController.text.trim().isNotEmpty
                        ? Icons.build_circle_rounded
                        : Icons.cloud_upload_rounded,
                    size: 16,
                  ),
            label: Text(_runningBuild
                ? 'Building...'
                : _buildCmdController.text.trim().isNotEmpty
                    ? 'Build & Deploy'
                    : 'Deploy'),
            style: ElevatedButton.styleFrom(
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

  Widget _buildStepIndicator(ColorScheme cs) {
    final steps = [
      ('Check', _DeployStep.checkCli),
      ('Install', _DeployStep.install),
      ('Configure', _DeployStep.configure),
      ('Deploy', _DeployStep.deploy),
      ('Done', _DeployStep.done),
    ];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: steps[i].$2.index <= _currentStep.index
                    ? AppColors.accent
                    : cs.outline.withValues(alpha: 0.15),
              ),
            ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: steps[i].$2.index < _currentStep.index
                  ? AppColors.success
                  : steps[i].$2 == _currentStep
                      ? AppColors.accent
                      : cs.surfaceContainerHighest,
              border: Border.all(
                color: steps[i].$2.index <= _currentStep.index
                    ? AppColors.accent
                    : cs.outline.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Center(
              child: steps[i].$2.index < _currentStep.index
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${i + 1}',
                      style: AppTypography.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: steps[i].$2 == _currentStep
                            ? Colors.white
                            : cs.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInstallPrompt(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download_rounded, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'NetLaunch CLI not found',
                style: AppTypography.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Install globally for faster deploys, or skip to use npx (downloads each time).',
            style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _installCli,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Install netlaunch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  textStyle: AppTypography.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _skipInstall,
                child: Text(
                  'Skip (use npx)',
                  style: AppTypography.inter(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigForm(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Site name
        Text(
          'Site Name',
          style: AppTypography.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _siteNameController,
                style: AppTypography.mono(fontSize: 13, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'my-site',
                  hintStyle: AppTypography.mono(
                    fontSize: 13,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '.web.app',
              style: AppTypography.mono(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Deploy directory
        Text(
          'Deploy Directory',
          style: AppTypography.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _deployDirController,
          style: AppTypography.mono(fontSize: 12, color: cs.onSurface),
          decoration: InputDecoration(
            hintText: '/path/to/build',
            hintStyle: AppTypography.mono(
              fontSize: 12,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide:
                  BorderSide(color: cs.outline.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide:
                  BorderSide(color: cs.outline.withValues(alpha: 0.2)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Build commands section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    _buildCompleted ? 'Build Commands (done)' : 'Build Commands',
                    style: AppTypography.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _buildCompleted ? AppColors.success : cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(optional — skip if already built)',
                    style: AppTypography.inter(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  if (GeminiService.isConfigured)
                    TextButton.icon(
                      onPressed: _suggestingBuild ? null : _suggestBuildWithGemini,
                      icon: _suggestingBuild
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.accent,
                              ),
                            )
                          : Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.accent),
                      label: Text(
                        _suggestingBuild ? 'Asking Gemini...' : 'Ask Gemini',
                        style: AppTypography.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _buildCmdController,
                style: AppTypography.mono(fontSize: 12, color: cs.onSurface),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. flutter build web --release',
                  hintStyle: AppTypography.mono(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 4),
                    child: Text('\$', style: AppTypography.mono(fontSize: 12, color: cs.onSurfaceVariant)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Output directory',
                    style: AppTypography.inter(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _outputDirController,
                      style: AppTypography.mono(fontSize: 11, color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: 'build/web',
                        hintStyle: AppTypography.mono(
                          fontSize: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // API key (optional)
        Row(
          children: [
            Text(
              'API Key',
              style: AppTypography.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(optional if logged in)',
              style: AppTypography.inter(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (!_loggedIn && !_cliInstalled)
              TextButton.icon(
                onPressed: _cliInstalled ? _loginCli : null,
                icon: const Icon(Icons.login_rounded, size: 14),
                label: const Text('Login instead'),
                style: TextButton.styleFrom(
                  textStyle: AppTypography.inter(fontSize: 11),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _apiKeyController,
          obscureText: !_showApiKey,
          style: AppTypography.mono(fontSize: 12, color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'fk_...',
            hintStyle: AppTypography.mono(
              fontSize: 12,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide:
                  BorderSide(color: cs.outline.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide:
                  BorderSide(color: cs.outline.withValues(alpha: 0.2)),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _showApiKey
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 16,
              ),
              onPressed: () => setState(() => _showApiKey = !_showApiKey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogLine(_StepLog log, ColorScheme cs) {
    final icon = log.isError
        ? Icons.cancel_rounded
        : log.isSuccess
            ? Icons.check_circle_rounded
            : Icons.arrow_forward_rounded;
    final color = log.isError
        ? AppColors.error
        : log.isSuccess
            ? AppColors.success
            : cs.onSurfaceVariant.withValues(alpha: 0.6);
    final timeStr =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeStr,
            style: AppTypography.mono(
              fontSize: 10,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              log.message,
              style: AppTypography.mono(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLog {
  final String message;
  final bool isError;
  final bool isSuccess;
  final DateTime timestamp;

  const _StepLog({
    required this.message,
    this.isError = false,
    this.isSuccess = false,
    required this.timestamp,
  });
}
