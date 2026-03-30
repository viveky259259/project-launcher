import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launcher_models/launcher_models.dart';
import 'package:launcher_native/launcher_native.dart';
import 'package:launcher_theme/launcher_theme.dart';
import '../../services/ai_service.dart';
import 'settings_components.dart';

/// Self-contained AI Insights section for the project settings screen.
///
/// Manages its own AI-related state (skills, insights, streaming output,
/// connection status) and renders the full section including a sliding
/// output panel overlay.
class AIInsightsSection extends StatefulWidget {
  final String projectPath;

  const AIInsightsSection({super.key, required this.projectPath});

  @override
  State<AIInsightsSection> createState() => _AIInsightsSectionState();
}

class _AIInsightsSectionState extends State<AIInsightsSection> {
  // AI Insights data
  List<ClaudeSkill> _availableSkills = [];
  List<AIInsight> _insights = [];
  bool _aiLoaded = false;
  String? _runningSkill;
  String _streamedOutput = '';
  bool _claudeInstalled = true;
  String? _claudeVersion; // null = not checked, '' = error
  bool _outputPanelOpen = false;
  bool _testingConnection = false;
  double _panelWidthFraction = 0.7; // 0.3 to 0.85
  String? _viewingInsightSkill;
  final _outputScrollController = ScrollController();
  final _customPromptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAIData();
  }

  @override
  void dispose() {
    _outputScrollController.dispose();
    _customPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadAIData() async {
    AppLogger.info('AI', 'Loading AI data for ${widget.projectPath}');
    final installed = await AIService.isClaudeInstalled();
    String? version;
    if (installed) {
      version = await AIService.getClaudeVersion();
      AppLogger.info('AI', 'Claude version: ${version ?? "unknown"}');
    }
    final skills = installed
        ? await AIService.getAvailableSkills()
        : <ClaudeSkill>[];
    final insights = await AIService.loadInsights(widget.projectPath);
    AppLogger.info(
      'AI',
      'Loaded ${insights.length} saved insights for ${widget.projectPath}',
    );
    if (mounted) {
      setState(() {
        _claudeInstalled = installed;
        _claudeVersion = version;
        _availableSkills = skills;
        _insights = insights;
        _aiLoaded = true;
      });
    }
  }

  Future<void> _runAISkill(ClaudeSkill skill) async {
    AppLogger.info(
      'AI',
      'User triggered /${skill.name} on ${widget.projectPath}',
    );
    setState(() {
      _runningSkill = skill.name;
      _streamedOutput = '';
      _outputPanelOpen = true;
      _viewingInsightSkill = null;
    });

    final insight = await AIService.runSkill(
      projectPath: widget.projectPath,
      skillName: skill.name,
      prompt: skill.prompt,
      onOutput: (text) {
        if (mounted) {
          setState(() => _streamedOutput = text);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_outputScrollController.hasClients) {
              _outputScrollController.jumpTo(
                _outputScrollController.position.maxScrollExtent,
              );
            }
          });
        }
      },
    );

    if (!mounted) return;

    final insights = await AIService.loadInsights(widget.projectPath);
    if (!mounted) return;

    setState(() {
      _runningSkill = null;
      _streamedOutput = insight.output;
      _insights = insights;
    });

    if (insight.isError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skill failed: ${insight.output.substring(0, insight.output.length.clamp(0, 100))}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _viewInsight(AIInsight insight) {
    setState(() {
      _outputPanelOpen = true;
      _viewingInsightSkill = insight.skillName;
      _streamedOutput = insight.output;
      _runningSkill = null;
    });
  }

  void _runCustomPrompt() {
    final promptText = _customPromptController.text.trim();
    if (promptText.isEmpty) return;
    AppLogger.info(
      'AI',
      'Running custom prompt on ${widget.projectPath}: "${promptText.substring(0, promptText.length.clamp(0, 80))}..."',
    );
    final customSkill = ClaudeSkill(
      name: 'custom-prompt',
      description: 'Custom prompt',
      prompt: promptText,
      isBuiltIn: true, // use prompt directly, not /skillName
    );
    _runAISkill(customSkill);
    _customPromptController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildContent(context),
        _buildOutputPanel(Theme.of(context).colorScheme),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_aiLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!_claudeInstalled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIHeader(cs),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.terminal_rounded,
                  size: 36,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Claude CLI not found',
                  style: AppTypography.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Install Claude Code to use AI skills.\n\nnpm install -g @anthropic-ai/claude-code',
                  textAlign: TextAlign.center,
                  style: AppTypography.inter(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAIHeader(cs),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Run Claude skills on this project to generate insights. Results are saved and persist across sessions.',
                style: AppTypography.inter(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _testingConnection
                  ? null
                  : () async {
                      setState(() => _testingConnection = true);
                      final result = await AIService.testConnection();
                      if (!mounted) return;
                      setState(() {
                        _testingConnection = false;
                        _outputPanelOpen = true;
                        _viewingInsightSkill = null;
                        _streamedOutput =
                            '${AppLogger.logsText}\n\n--- Connection Test ---\n$result';
                      });
                    },
              icon: _testingConnection
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  : Icon(Icons.wifi_tethering_rounded, size: 16),
              label: Text(_testingConnection ? 'Testing...' : 'Test'),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                textStyle: AppTypography.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Custom prompt input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customPromptController,
                decoration: InputDecoration(
                  hintText: 'Type a custom prompt to run on this project...',
                  hintStyle: AppTypography.inter(
                    fontSize: 13,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppColors.accent.withValues(alpha: 0.6),
                  ),
                ),
                style: AppTypography.inter(fontSize: 13, color: cs.onSurface),
                maxLines: 1,
                onSubmitted: _runningSkill != null
                    ? null
                    : (_) => _runCustomPrompt(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed:
                    _runningSkill != null ||
                        _customPromptController.text.trim().isEmpty
                    ? null
                    : _runCustomPrompt,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Run'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: cs.surfaceContainerHighest,
                  disabledForegroundColor: cs.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  textStyle: AppTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Running indicator -- compact, click to open panel
        if (_runningSkill != null) ...[
          InkWell(
            onTap: () => setState(() => _outputPanelOpen = true),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Running /$_runningSkill...',
                      style: AppTypography.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    'View output',
                    style: AppTypography.inter(
                      fontSize: 12,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Built-in Claude skills
        ..._buildSkillGroup(
          cs,
          title: 'Built-in Skills',
          skills: _availableSkills.where((s) => s.isBuiltIn).toList(),
        ),

        // User-installed skills
        ..._buildSkillGroup(
          cs,
          title: 'Installed Skills',
          subtitle: '~/.claude/skills/',
          skills: _availableSkills
              .where((s) => !s.isBuiltIn && !s.isCLIDiscovered)
              .toList(),
        ),

        // CLI-discovered skills
        ..._buildSkillGroup(
          cs,
          title: 'CLI Skills',
          subtitle: 'from Claude CLI',
          skills: _availableSkills.where((s) => s.isCLIDiscovered).toList(),
        ),

        // Persisted insights
        if (_insights.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            'Saved Insights',
            style: AppTypography.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ..._insights.map(
            (insight) => AIInsightCard(
              insight: insight,
              onView: () => _viewInsight(insight),
              onDelete: () async {
                await AIService.deleteInsight(
                  widget.projectPath,
                  insight.skillName,
                );
                final updated = await AIService.loadInsights(
                  widget.projectPath,
                );
                if (mounted) setState(() => _insights = updated);
              },
              onRerun: () {
                final skill = _availableSkills
                    .where((s) => s.name == insight.skillName)
                    .firstOrNull;
                if (skill != null) _runAISkill(skill);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAIHeader(ColorScheme cs) {
    // Status: connected (version known), not connected, error (running skill failed)
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (!_claudeInstalled) {
      statusColor = AppColors.error;
      statusLabel = 'Not Connected';
      statusIcon = Icons.cancel_rounded;
    } else if (_runningSkill != null) {
      statusColor = AppColors.accent;
      statusLabel = 'Running...';
      statusIcon = Icons.sync_rounded;
    } else if (_insights.any((i) => i.isError)) {
      statusColor = AppColors.warning;
      statusLabel = 'Connected (last run had errors)';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = AppColors.success;
      statusLabel =
          'Connected${_claudeVersion != null ? ' · $_claudeVersion' : ''}';
      statusIcon = Icons.check_circle_rounded;
    }

    return Row(
      children: [
        Text(
          'AI Insights',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Tooltip(
          message: statusLabel,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 5),
              Text(
                _claudeInstalled ? 'Connected' : 'Not Connected',
                style: AppTypography.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            Icons.bug_report_outlined,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
          tooltip: 'View debug logs',
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final isShowingLogs =
                _outputPanelOpen &&
                _viewingInsightSkill == null &&
                _runningSkill == null;
            if (isShowingLogs) {
              // Toggle off
              setState(() => _outputPanelOpen = false);
            } else {
              setState(() {
                _outputPanelOpen = true;
                _viewingInsightSkill = null;
                _streamedOutput = AppLogger.count == 0
                    ? 'No logs yet.'
                    : AppLogger.logsText;
              });
            }
          },
        ),
      ],
    );
  }

  List<Widget> _buildSkillGroup(
    ColorScheme cs, {
    required String title,
    String? subtitle,
    required List<ClaudeSkill> skills,
  }) {
    if (skills.isEmpty) return [];
    return [
      const SizedBox(height: 4),
      Row(
        children: [
          Text(
            title,
            style: AppTypography.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle,
              style: AppTypography.mono(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: skills.map((skill) {
          final isRunning = _runningSkill == skill.name;
          return Tooltip(
            message: skill.description ?? skill.name,
            child: ActionChip(
              avatar: isRunning
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : Text(
                      '/',
                      style: AppTypography.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
              label: Text(skill.name),
              labelStyle: AppTypography.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              backgroundColor: isRunning
                  ? AppColors.accent.withValues(alpha: 0.1)
                  : null,
              side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
              onPressed: _runningSkill != null
                  ? null
                  : () => _runAISkill(skill),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildOutputPanel(ColorScheme cs) {
    final panelContent = _streamedOutput;
    final isRunning = _runningSkill != null;
    final isShowingLogs =
        !isRunning &&
        _viewingInsightSkill == null &&
        AppLogger.count > 0 &&
        panelContent == AppLogger.logsText;
    final title = isRunning
        ? 'Running /$_runningSkill...'
        : isShowingLogs
        ? 'Debug Logs'
        : _viewingInsightSkill != null
        ? '/$_viewingInsightSkill'
        : 'Output';
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * _panelWidthFraction;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: _outputPanelOpen ? 0 : -panelWidth,
      width: panelWidth,
      child: Row(
        children: [
          // Drag handle
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _panelWidthFraction =
                    ((_panelWidthFraction * screenWidth - details.delta.dx) /
                            screenWidth)
                        .clamp(0.3, 0.85);
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: Container(
                width: 8,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Panel body
          Expanded(
            child: Material(
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.3),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    left: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Panel header
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: cs.outline.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isRunning) ...[
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ] else ...[
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: AppTypography.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          if (!isRunning && panelContent.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              tooltip: 'Copy to clipboard',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: panelContent),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied to clipboard'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          if (isShowingLogs) ...[
                            // Refresh logs
                            IconButton(
                              icon: Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              tooltip: 'Refresh logs',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(
                                () => _streamedOutput = AppLogger.logsText,
                              ),
                            ),
                            // Clear logs
                            IconButton(
                              icon: Icon(
                                Icons.delete_sweep_rounded,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              tooltip: 'Clear logs',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                AppLogger.clear();
                                setState(
                                  () => _streamedOutput = 'Logs cleared.',
                                );
                              },
                            ),
                          ] else ...[
                            // Switch to logs view
                            IconButton(
                              icon: Icon(
                                Icons.bug_report_outlined,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              tooltip: 'View logs',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setState(() {
                                  _viewingInsightSkill = null;
                                  _streamedOutput = AppLogger.logsText;
                                });
                              },
                            ),
                          ],
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                            tooltip: 'Close',
                            onPressed: () => setState(() {
                              _outputPanelOpen = false;
                              _viewingInsightSkill = null;
                            }),
                          ),
                        ],
                      ),
                    ),

                    // Panel content
                    Expanded(
                      child: panelContent.isEmpty
                          ? Center(
                              child: Text(
                                'Waiting for output...',
                                style: AppTypography.inter(
                                  fontSize: 13,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              controller: _outputScrollController,
                              padding: const EdgeInsets.all(20),
                              child: SelectableText(
                                panelContent,
                                style: AppTypography.mono(
                                  fontSize: 12,
                                  color: cs.onSurface,
                                ).copyWith(height: 1.6),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
