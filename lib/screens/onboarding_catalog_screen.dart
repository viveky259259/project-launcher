import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launcher_kit/launcher_kit.dart';
import 'package:launcher_models/launcher_models.dart';
import 'package:launcher_theme/launcher_theme.dart';

import '../services/catalog_service.dart';
import '../widgets/catalog/env_template_dialog.dart';

/// Full-screen onboarding checklist for a team catalog workspace.
///
/// Shows per-step progress for clone, env setup, build verify, and test verify
/// steps. Allows the user to set up env files for repos that need user input,
/// and to resume or complete the onboarding process.
class OnboardingCatalogScreen extends StatefulWidget {
  const OnboardingCatalogScreen({super.key});

  @override
  State<OnboardingCatalogScreen> createState() =>
      _OnboardingCatalogScreenState();
}

class _OnboardingCatalogScreenState extends State<OnboardingCatalogScreen> {
  bool _isResuming = false;
  String? _resumeError;

  String get _localBasePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Developer';
  }

  @override
  void initState() {
    super.initState();
    CatalogService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    CatalogService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _resume() async {
    setState(() {
      _isResuming = true;
      _resumeError = null;
    });
    try {
      await CatalogService.resumeOnboarding(_localBasePath);
    } catch (e) {
      if (mounted) {
        setState(() {
          _resumeError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isResuming = false);
    }
  }

  Future<void> _openEnvDialog(OnboardingStep step) async {
    final repoName = step.repoName;
    if (repoName == null) return;

    final catalog = CatalogService.catalog;
    if (catalog == null) return;

    final repo = catalog.repos
        .where((r) => r.name == repoName)
        .cast<CatalogRepo?>()
        .firstWhere((_) => true, orElse: () => null);
    if (repo?.envTemplateName == null) return;

    final template = catalog.envTemplates
        .where((t) => t.name == repo!.envTemplateName)
        .cast<EnvTemplate?>()
        .firstWhere((_) => true, orElse: () => null);
    if (template == null) return;

    final repoPath = '$_localBasePath${Platform.pathSeparator}$repoName';

    final applied = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EnvTemplateDialog(repoPath: repoPath, template: template),
    );

    if (applied == true) {
      await _resume();
    }
  }

  /// Group steps by prefix for display sections.
  _ChecklistSections _groupSteps(List<OnboardingStep> steps) {
    final cloneSteps = steps.where((s) => s.id.startsWith('clone_')).toList();
    final envSteps = steps.where((s) => s.id.startsWith('env_')).toList();
    final buildSteps =
        steps.where((s) => s.id == 'build_verify').toList();
    final testSteps =
        steps.where((s) => s.id == 'test_verify').toList();
    return _ChecklistSections(
      clone: cloneSteps,
      env: envSteps,
      build: buildSteps,
      test: testSteps,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checklist = CatalogService.onboardingChecklist;
    final workspace = CatalogService.workspace;

    if (checklist == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Onboarding'),
        ),
        body: const Center(child: UkSpinner(size: UkSpinnerSize.large)),
      );
    }

    if (checklist.isComplete) {
      return _CompletionScreen(
        checklist: checklist,
        workspaceName: workspace?.name ?? 'your workspace',
        onDone: () => Navigator.of(context).pop(),
      );
    }

    final sections = _groupSteps(checklist.steps);
    final totalSteps = checklist.steps.length;
    final doneSteps =
        checklist.steps.where((s) => s.status == OnboardingStatus.done).length;
    final progressPct = (checklist.progress * 100).round();

    final elapsed = DateTime.now().difference(checklist.startedAt);
    final elapsedLabel = elapsed.inMinutes < 1
        ? 'just started'
        : elapsed.inMinutes == 1
            ? '1 min ago'
            : '${elapsed.inMinutes} min ago';

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top bar ─────────────────────────────────────────────────────
          _TopBar(
            title: 'Setting up ${workspace?.name ?? 'workspace'}',
            subtitle:
                '$totalSteps steps · Started $elapsedLabel',
            onBack: () => Navigator.of(context).pop(),
            cs: cs,
          ),

          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Overall progress bar
                  _ProgressHeader(
                    progress: checklist.progress,
                    doneSteps: doneSteps,
                    totalSteps: totalSteps,
                    progressPct: progressPct,
                    cs: cs,
                  ),

                  const SizedBox(height: 24),

                  if (_resumeError != null) ...[
                    UkAlert(
                      message: _resumeError!,
                      type: UkAlertType.danger,
                      dismissible: true,
                      onDismissed: () =>
                          setState(() => _resumeError = null),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Clone section
                  if (sections.clone.isNotEmpty)
                    _StepSection(
                      title: 'Clone Repos',
                      steps: sections.clone,
                      summary:
                          '${sections.clone.where((s) => s.status == OnboardingStatus.done).length}/${sections.clone.length}',
                      cs: cs,
                      onEnvSetup: _openEnvDialog,
                    ),

                  if (sections.clone.isNotEmpty && sections.env.isNotEmpty)
                    const SizedBox(height: 16),

                  // Env section
                  if (sections.env.isNotEmpty)
                    _StepSection(
                      title: 'Environment Setup',
                      steps: sections.env,
                      summary:
                          '${sections.env.where((s) => s.status == OnboardingStatus.done).length}/${sections.env.length}',
                      cs: cs,
                      onEnvSetup: _openEnvDialog,
                    ),

                  if (sections.env.isNotEmpty &&
                      (sections.build.isNotEmpty || sections.test.isNotEmpty))
                    const SizedBox(height: 16),

                  // Build + Test aggregate steps
                  if (sections.build.isNotEmpty || sections.test.isNotEmpty)
                    _AggregateStepsCard(
                      buildSteps: sections.build,
                      testSteps: sections.test,
                      cs: cs,
                    ),

                  const SizedBox(height: 32),

                  // Action buttons
                  _ActionBar(
                    isComplete: checklist.isComplete,
                    isResuming: _isResuming,
                    onResume: _resume,
                    onDone: () => Navigator.of(context).pop(),
                    cs: cs,
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

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.cs,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
            tooltip: 'Back',
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Progress header ───────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.progress,
    required this.doneSteps,
    required this.totalSteps,
    required this.progressPct,
    required this.cs,
  });

  final double progress;
  final int doneSteps;
  final int totalSteps;
  final int progressPct;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Overall Progress',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                '$doneSteps / $totalSteps steps',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$progressPct%',
                  style: AppTypography.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          UkProgress(
            value: progress,
            variant: UkProgressVariant.primary,
            size: UkProgressSize.medium,
          ),
        ],
      ),
    );
  }
}

// ── Step section (clone or env) ───────────────────────────────────────────────

class _StepSection extends StatelessWidget {
  const _StepSection({
    required this.title,
    required this.steps,
    required this.summary,
    required this.cs,
    required this.onEnvSetup,
  });

  final String title;
  final List<OnboardingStep> steps;
  final String summary;
  final ColorScheme cs;
  final Future<void> Function(OnboardingStep) onEnvSetup;

  bool get _allDone =>
      steps.isNotEmpty && steps.every((s) => s.status == OnboardingStatus.done);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(
                  _allDone
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: _allDone ? AppColors.success : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _allDone
                        ? AppColors.success.withValues(alpha: 0.12)
                        : cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '$summary${_allDone ? ' ✓' : ''}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _allDone
                              ? AppColors.success
                              : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
              height: 1,
              thickness: 1,
              color: cs.outline.withValues(alpha: 0.08)),

          // Step rows
          ...steps.asMap().entries.map((entry) {
            final isLast = entry.key == steps.length - 1;
            return _StepRow(
              step: entry.value,
              isLast: isLast,
              cs: cs,
              onEnvSetup: onEnvSetup,
            );
          }),
        ],
      ),
    );
  }
}

// ── Individual step row ───────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isLast,
    required this.cs,
    required this.onEnvSetup,
  });

  final OnboardingStep step;
  final bool isLast;
  final ColorScheme cs;
  final Future<void> Function(OnboardingStep) onEnvSetup;

  @override
  Widget build(BuildContext context) {
    final isEnvStep = step.id.startsWith('env_');
    final needsEnvSetup = isEnvStep &&
        step.repoName != null &&
        CatalogService.needsEnvSetup(step.repoName!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 10, 12, isLast ? 14 : 6),
          child: Row(
            children: [
              // Connector line placeholder
              SizedBox(
                width: 8,
                child: isLast
                    ? null
                    : Container(
                        width: 1,
                        color: cs.outline.withValues(alpha: 0.15),
                      ),
              ),
              const SizedBox(width: 8),

              // Status icon
              _StatusIcon(status: step.status),

              const SizedBox(width: 10),

              // Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.repoName ?? step.label,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (step.status == OnboardingStatus.inProgress) ...[
                      const SizedBox(height: 2),
                      Text(
                        'working...',
                        style: AppTypography.mono(
                          fontSize: 11,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action: env setup button or status badge
              if (needsEnvSetup &&
                  step.status != OnboardingStatus.done) ...[
                const SizedBox(width: 8),
                UkButton(
                  label: 'Setup env',
                  variant: UkButtonVariant.tonal,
                  size: UkButtonSize.small,
                  icon: Icons.settings_input_component_rounded,
                  onPressed: () => onEnvSetup(step),
                ),
              ] else if (step.status == OnboardingStatus.inProgress) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: UkSpinner(size: UkSpinnerSize.small),
                ),
              ],
            ],
          ),
        ),

        // Error row (shown below the step row)
        if (step.status == OnboardingStatus.failed &&
            step.error != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 16, 8),
            child: Text(
              step.error!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.error,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],

        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            indent: 32,
            endIndent: 16,
            color: cs.outline.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

// ── Status icon ───────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final OnboardingStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      OnboardingStatus.done => const Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: AppColors.success,
        ),
      OnboardingStatus.failed => const Icon(
          Icons.cancel_rounded,
          size: 16,
          color: AppColors.error,
        ),
      OnboardingStatus.inProgress => const Icon(
          Icons.pending_rounded,
          size: 16,
          color: AppColors.warning,
        ),
      OnboardingStatus.pending => Icon(
          Icons.radio_button_unchecked_rounded,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    };
  }
}

// ── Aggregate steps card (build + test) ──────────────────────────────────────

class _AggregateStepsCard extends StatelessWidget {
  const _AggregateStepsCard({
    required this.buildSteps,
    required this.testSteps,
    required this.cs,
  });

  final List<OnboardingStep> buildSteps;
  final List<OnboardingStep> testSteps;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final all = [...buildSteps, ...testSteps];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: all.asMap().entries.map((entry) {
          final step = entry.value;
          final isLast = entry.key == all.length - 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, entry.key == 0 ? 14 : 10, 16, isLast ? 14 : 10),
                child: Row(
                  children: [
                    _StatusIcon(status: step.status),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step.label,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: step.status, cs: cs),
                  ],
                ),
              ),
              if (step.status == OnboardingStatus.failed &&
                  step.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(42, 0, 16, 8),
                  child: Text(
                    step.error!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.error,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outline.withValues(alpha: 0.08),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.cs});

  final OnboardingStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OnboardingStatus.done => ('done', AppColors.success),
      OnboardingStatus.failed => ('failed', AppColors.error),
      OnboardingStatus.inProgress => ('running', AppColors.warning),
      OnboardingStatus.pending => ('pending', cs.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isComplete,
    required this.isResuming,
    required this.onResume,
    required this.onDone,
    required this.cs,
  });

  final bool isComplete;
  final bool isResuming;
  final VoidCallback onResume;
  final VoidCallback onDone;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (isComplete) {
      return Center(
        child: UkButton(
          label: 'Ready to code! \u{1F389}',
          variant: UkButtonVariant.primary,
          size: UkButtonSize.large,
          icon: Icons.rocket_launch_rounded,
          onPressed: onDone,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        UkButton(
          label: isResuming ? 'Resuming...' : 'Resume',
          variant: UkButtonVariant.primary,
          size: UkButtonSize.medium,
          icon: isResuming ? null : Icons.play_arrow_rounded,
          onPressed: isResuming ? null : onResume,
        ),
      ],
    );
  }
}

// ── Completion screen ─────────────────────────────────────────────────────────

class _CompletionScreen extends StatelessWidget {
  const _CompletionScreen({
    required this.checklist,
    required this.workspaceName,
    required this.onDone,
  });

  final OnboardingChecklist checklist;
  final String workspaceName;
  final VoidCallback onDone;

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    final minutes = d.inMinutes;
    final secs = d.inSeconds % 60;
    return secs > 0 ? '${minutes}m ${secs}s' : '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final elapsed = checklist.completedAt != null
        ? checklist.completedAt!.difference(checklist.startedAt)
        : DateTime.now().difference(checklist.startedAt);

    final totalRepos = checklist.steps
        .where((s) => s.id.startsWith('clone_'))
        .length;

    // Summarize sections for completion view
    final sections = [
      _SectionSummary(
        label: 'Clone Repos',
        done: checklist.steps
            .where((s) =>
                s.id.startsWith('clone_') &&
                s.status == OnboardingStatus.done)
            .length,
        total: checklist.steps.where((s) => s.id.startsWith('clone_')).length,
      ),
      _SectionSummary(
        label: 'Environment Setup',
        done: checklist.steps
            .where((s) =>
                s.id.startsWith('env_') &&
                s.status == OnboardingStatus.done)
            .length,
        total: checklist.steps.where((s) => s.id.startsWith('env_')).length,
      ),
      _SectionSummary(
        label: 'Build Verification',
        done: checklist.steps
            .where((s) =>
                s.id == 'build_verify' &&
                s.status == OnboardingStatus.done)
            .length,
        total:
            checklist.steps.where((s) => s.id == 'build_verify').length,
      ),
      _SectionSummary(
        label: 'Test Suite',
        done: checklist.steps
            .where((s) =>
                s.id == 'test_verify' &&
                s.status == OnboardingStatus.done)
            .length,
        total: checklist.steps.where((s) => s.id == 'test_verify').length,
      ),
    ].where((s) => s.total > 0).toList();

    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color:
                              AppColors.success.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '\u{1F389}',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Ready to code!',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        totalRepos > 0
                            ? 'All $totalRepos repos set up in ${_formatDuration(elapsed)}'
                            : 'All steps complete in ${_formatDuration(elapsed)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Summary list
                Container(
                  decoration: BoxDecoration(
                    color:
                        cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                        color: cs.outline.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: sections.asMap().entries.map((entry) {
                      final s = entry.value;
                      final isLast = entry.key == sections.length - 1;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: cs.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                                Text(
                                  '${s.done}/${s.total}',
                                  style: AppTypography.mono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: cs.outline.withValues(alpha: 0.08),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 32),

                UkButton(
                  label: 'Open Project Launcher',
                  variant: UkButtonVariant.primary,
                  size: UkButtonSize.large,
                  icon: Icons.launch_rounded,
                  onPressed: onDone,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Internal data models ──────────────────────────────────────────────────────

class _ChecklistSections {
  final List<OnboardingStep> clone;
  final List<OnboardingStep> env;
  final List<OnboardingStep> build;
  final List<OnboardingStep> test;

  const _ChecklistSections({
    required this.clone,
    required this.env,
    required this.build,
    required this.test,
  });
}

class _SectionSummary {
  final String label;
  final int done;
  final int total;

  const _SectionSummary({
    required this.label,
    required this.done,
    required this.total,
  });
}
