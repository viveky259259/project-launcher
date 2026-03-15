import 'package:flutter/material.dart';
import '../../models/ai_insight.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';

/// A dialog that lists available Claude skills and lets the user run one on a project.
class AISkillPicker extends StatefulWidget {
  final String projectPath;
  final String projectName;

  const AISkillPicker({
    super.key,
    required this.projectPath,
    required this.projectName,
  });

  /// Show the skill picker dialog. Returns the AIInsight if a skill was run successfully.
  static Future<AIInsight?> show(BuildContext context, {
    required String projectPath,
    required String projectName,
  }) {
    return showDialog<AIInsight>(
      context: context,
      builder: (_) => AISkillPicker(
        projectPath: projectPath,
        projectName: projectName,
      ),
    );
  }

  @override
  State<AISkillPicker> createState() => _AISkillPickerState();
}

class _AISkillPickerState extends State<AISkillPicker> {
  List<ClaudeSkill>? _skills;
  bool _loading = true;
  bool _claudeInstalled = true;
  String? _runningSkill;
  String _streamedOutput = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    final installed = await AIService.isClaudeInstalled();
    if (!installed) {
      if (mounted) {
        setState(() {
          _claudeInstalled = false;
          _loading = false;
        });
      }
      return;
    }

    final skills = await AIService.getAvailableSkills();
    if (mounted) {
      setState(() {
        _skills = skills;
        _loading = false;
      });
    }
  }

  Future<void> _runSkill(ClaudeSkill skill) async {
    setState(() {
      _runningSkill = skill.name;
      _streamedOutput = '';
      _error = null;
    });

    final insight = await AIService.runSkill(
      projectPath: widget.projectPath,
      skillName: skill.name,
      onOutput: (chunk) {
        if (mounted) {
          setState(() => _streamedOutput += chunk);
        }
      },
    );

    if (!mounted) return;

    if (insight.isError) {
      setState(() {
        _error = insight.output;
        _runningSkill = null;
      });
    } else {
      Navigator.of(context).pop(insight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, size: 20, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Run Claude Skill',
                          style: AppTypography.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'on ${widget.projectName}',
                          style: AppTypography.inter(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _runningSkill != null ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, size: 20, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),

            // Content
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (!_claudeInstalled)
              _buildNotInstalled(cs)
            else if (_runningSkill != null)
              _buildRunning(cs)
            else if (_error != null)
              _buildError(cs)
            else
              _buildSkillList(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildNotInstalled(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.terminal_rounded, size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Claude CLI not found',
            style: AppTypography.inter(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Install Claude Code CLI to use AI skills on your projects.\n\nnpm install -g @anthropic-ai/claude-code',
            textAlign: TextAlign.center,
            style: AppTypography.inter(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildRunning(ColorScheme cs) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Running /$_runningSkill...',
                  style: AppTypography.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    _streamedOutput.isEmpty ? 'Waiting for output...' : _streamedOutput,
                    style: AppTypography.mono(
                      fontSize: 11,
                      color: _streamedOutput.isEmpty
                          ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                          : cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Skill failed',
                style: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: Text(
                _error ?? 'Unknown error',
                style: AppTypography.mono(fontSize: 11, color: cs.onSurface),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _error = null),
              child: const Text('Back to skills'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillList(ColorScheme cs) {
    final skills = _skills ?? [];

    if (skills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No skills found',
              style: AppTypography.inter(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'No Claude skills found in ~/.claude/skills/.\nAdd skills to use them on your projects.',
              textAlign: TextAlign.center,
              style: AppTypography.inter(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        shrinkWrap: true,
        itemCount: skills.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final skill = skills[index];
          return _SkillTile(
            skill: skill,
            onTap: () => _runSkill(skill),
          );
        },
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  final ClaudeSkill skill;
  final VoidCallback onTap;

  const _SkillTile({required this.skill, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '/',
                  style: AppTypography.mono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: AppTypography.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    if (skill.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        skill.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.inter(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.play_arrow_rounded,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
