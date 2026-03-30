import 'package:flutter/material.dart';
import 'package:launcher_models/launcher_models.dart';
import 'package:launcher_native/launcher_native.dart';
import 'package:launcher_theme/launcher_theme.dart';
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
