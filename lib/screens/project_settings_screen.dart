import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launcher_models/launcher_models.dart';
import '../services/git_service.dart';
import '../services/launcher_service.dart';
import '../services/project_storage.dart';
import '../services/project_type_detector.dart';
import '../services/ai_service.dart';
import 'package:launcher_native/launcher_native.dart';
import '../services/release_service.dart';
import '../services/compliance_service.dart';
import '../services/version_detector.dart';
import '../services/ship_readiness_service.dart';
import 'package:launcher_theme/launcher_theme.dart';

class ProjectSettingsScreen extends StatefulWidget {
  final Project project;
  final CachedHealthScore? healthScore;
  final VoidCallback onSaved;
  final VoidCallback onRemoved;
  final VoidCallback? onOpenTerminal;
  final VoidCallback? onOpenVSCode;
  final VoidCallback? onTogglePin;

  const ProjectSettingsScreen({
    super.key,
    required this.project,
    this.healthScore,
    required this.onSaved,
    required this.onRemoved,
    this.onOpenTerminal,
    this.onOpenVSCode,
    this.onTogglePin,
  });

  @override
  State<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends State<ProjectSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late List<String> _tags;
  String _activeSection = 'overview';
  bool _hasChanges = false;

  // Overview data
  ProjectStack? _projectStack;
  String? _branchName;
  String? _remoteUrl;
  String? _gitEmail;
  List<String> _platforms = [];
  Map<String, bool> _projectFiles = {};
  bool _overviewLoaded = false;

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

  // Release data
  ReleaseInfo? _releaseInfo;
  ReadinessScore? _readinessScore;
  DeploymentConfig? _deploymentConfig;
  bool _releaseLoaded = false;
  bool _bumpingVersion = false;
  ReleaseProcess? _releaseProcess;
  bool _creatingTag = false;
  bool _shippingRelease = false;

  // Compliance data
  ComplianceReport? _complianceReport;
  bool _complianceLoaded = false;
  bool _runningAudit = false;

  // Ship readiness data
  ShipReadiness? _shipReadiness;
  bool _shipLoaded = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _notesController = TextEditingController(text: widget.project.notes ?? '');
    _tags = List.from(widget.project.tags);

    _nameController.addListener(_markChanged);
    _notesController.addListener(_markChanged);

    _loadOverviewData();
    _loadAIData();
    _loadReleaseData();
  }

  Future<void> _loadOverviewData() async {
    final path = widget.project.path;

    // Detect tech stack
    final stack = ProjectStack.detect(path);

    // Detect platforms (Flutter-specific)
    final platforms = <String>[];
    for (final p in ['macos', 'ios', 'android', 'web', 'linux', 'windows']) {
      if (Directory('$path/$p').existsSync()) {
        platforms.add(p);
      }
    }

    // Git info
    String? branch;
    String? remote;
    String? email;
    final isGit = await GitService.isGitRepository(path);
    if (isGit) {
      branch = await GitService.getCurrentBranch(path);
      remote = await GitService.getRemoteUrl(path);
      email = await GitService.getUserEmail(path);
    }

    // Detect common project files
    final files = <String, bool>{};
    for (final f in ['README.md', 'LICENSE', '.gitignore', '.github', '.gitlab-ci.yml', 'Dockerfile', '.env', 'Makefile']) {
      final isDir = f == '.github';
      if (isDir) {
        files[f] = Directory('$path/$f').existsSync();
      } else {
        files[f] = File('$path/$f').existsSync();
      }
    }

    if (mounted) {
      setState(() {
        _projectStack = stack;
        _branchName = branch;
        _remoteUrl = remote;
        _gitEmail = email;
        _platforms = platforms;
        _projectFiles = files;
        _overviewLoaded = true;
      });
    }
  }

  Future<void> _loadReleaseData() async {
    final info = await VersionDetector.detect(widget.project.path);
    final score = await ReleaseService.getReadinessScore(widget.project.path);
    final deploy = ReleaseService.detectDeploymentConfig(widget.project.path);
    final process = await ReleaseService.detectReleaseProcess(widget.project.path);
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

  Future<void> _loadComplianceData() async {
    setState(() => _runningAudit = true);
    final report = await ComplianceService.audit(widget.project.path);
    if (mounted) {
      setState(() {
        _complianceReport = report;
        _complianceLoaded = true;
        _runningAudit = false;
      });
    }
  }

  Future<void> _loadAIData() async {
    AppLogger.info('AI', 'Loading AI data for ${widget.project.name}');
    final installed = await AIService.isClaudeInstalled();
    String? version;
    if (installed) {
      version = await AIService.getClaudeVersion();
      AppLogger.info('AI', 'Claude version: ${version ?? "unknown"}');
    }
    final skills = installed ? await AIService.getAvailableSkills() : <ClaudeSkill>[];
    final insights = await AIService.loadInsights(widget.project.path);
    AppLogger.info('AI', 'Loaded ${insights.length} saved insights for ${widget.project.name}');
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
    AppLogger.info('AI', 'User triggered /${skill.name} on ${widget.project.name}');
    setState(() {
      _runningSkill = skill.name;
      _streamedOutput = '';
      _outputPanelOpen = true;
      _viewingInsightSkill = null;
    });

    final insight = await AIService.runSkill(
      projectPath: widget.project.path,
      skillName: skill.name,
      prompt: skill.prompt,
      onOutput: (text) {
        if (mounted) {
          setState(() => _streamedOutput = text);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_outputScrollController.hasClients) {
              _outputScrollController.jumpTo(_outputScrollController.position.maxScrollExtent);
            }
          });
        }
      },
    );

    if (!mounted) return;

    final insights = await AIService.loadInsights(widget.project.path);
    if (!mounted) return;

    setState(() {
      _runningSkill = null;
      _streamedOutput = insight.output;
      _insights = insights;
    });

    if (insight.isError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skill failed: ${insight.output.substring(0, insight.output.length.clamp(0, 100))}'),
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
    AppLogger.info('AI', 'Running custom prompt on ${widget.project.name}: "${promptText.substring(0, promptText.length.clamp(0, 80))}..."');
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
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _outputScrollController.dispose();
    _customPromptController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _save() async {
    final projects = await ProjectStorage.loadProjects();
    final index = projects.indexWhere((p) => p.path == widget.project.path);
    if (index == -1) return;

    projects[index] = projects[index].copyWith(
      tags: _tags,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      clearNotes: _notesController.text.isEmpty,
    );

    await ProjectStorage.saveProjects(projects);
    widget.onSaved();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved'), behavior: SnackBarBehavior.floating),
      );
      setState(() => _hasChanges = false);
    }
  }

  Future<void> _removeProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: const Text('Remove Project?'),
          content: Text(
            'This will remove "${widget.project.name}" from Project Launcher. Your local files will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final projects = await ProjectStorage.loadProjects();
      projects.removeWhere((p) => p.path == widget.project.path);
      await ProjectStorage.saveProjects(projects);
      widget.onRemoved();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _addTag() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: const Text('Add Tag'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Tag name',
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.of(ctx).pop(value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ).then((tag) {
      if (tag != null && tag is String && !_tags.contains(tag)) {
        setState(() {
          _tags.add(tag);
          _hasChanges = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = widget.healthScore?.details;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          Row(
        children: [
          // Settings sub-nav sidebar
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(right: BorderSide(color: cs.outline.withValues(alpha: 0.3))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back to Dashboard'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                      textStyle: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w500),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _NavItem(
                  label: 'Overview',
                  icon: Icons.analytics_outlined,
                  isActive: _activeSection == 'overview',
                  onTap: () => setState(() => _activeSection = 'overview'),
                ),
                _NavItem(
                  label: 'Quick Actions',
                  icon: Icons.bolt_rounded,
                  isActive: _activeSection == 'actions',
                  onTap: () => setState(() => _activeSection = 'actions'),
                ),
                _NavItem(
                  label: 'General Settings',
                  icon: Icons.settings_rounded,
                  isActive: _activeSection == 'general',
                  onTap: () => setState(() => _activeSection = 'general'),
                ),
                _NavItem(
                  label: 'Health Rules',
                  icon: Icons.favorite_rounded,
                  isActive: _activeSection == 'health',
                  onTap: () => setState(() => _activeSection = 'health'),
                ),
                _NavItem(
                  label: 'Environment',
                  icon: Icons.terminal_rounded,
                  isActive: _activeSection == 'environment',
                  onTap: () => setState(() => _activeSection = 'environment'),
                ),
                _NavItem(
                  label: 'AI Insights',
                  icon: Icons.auto_awesome_rounded,
                  isActive: _activeSection == 'ai',
                  onTap: () => setState(() => _activeSection = 'ai'),
                ),
                _NavItem(
                  label: 'Ship',
                  icon: Icons.flight_takeoff_rounded,
                  isActive: _activeSection == 'ship',
                  onTap: () => setState(() => _activeSection = 'ship'),
                ),
                _NavItem(
                  label: 'Release',
                  icon: Icons.rocket_launch_rounded,
                  isActive: _activeSection == 'release',
                  onTap: () => setState(() => _activeSection = 'release'),
                ),
                _NavItem(
                  label: 'Compliance',
                  icon: Icons.verified_user_rounded,
                  isActive: _activeSection == 'compliance',
                  onTap: () => setState(() => _activeSection = 'compliance'),
                ),
                _NavItem(
                  label: 'Danger Zone',
                  icon: Icons.warning_amber_rounded,
                  isActive: _activeSection == 'danger',
                  onTap: () => setState(() => _activeSection = 'danger'),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    children: [
                      // Project avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Center(
                          child: Text(
                            widget.project.name.substring(0, widget.project.name.length >= 2 ? 2 : 1).toUpperCase(),
                            style: AppTypography.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.project.name,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (score != null) ...[
                                  const SizedBox(width: 12),
                                  _HealthBadge(category: score.category),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${score.totalScore}/100',
                                    style: AppTypography.mono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_hasChanges) ...[
                        TextButton(
                          onPressed: () {
                            _nameController.text = widget.project.name;
                            _notesController.text = widget.project.notes ?? '';
                            _tags = List.from(widget.project.tags);
                            setState(() => _hasChanges = false);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                            textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Discard'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _save,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                            ),
                            textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ],
                  ),
                ),

                // Content area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildSection(cs),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

          // Sliding output panel
          _buildOutputPanel(cs),
        ],
      ),
    );
  }

  Widget _buildOutputPanel(ColorScheme cs) {
    final panelContent = _streamedOutput;
    final isRunning = _runningSkill != null;
    final isShowingLogs = !isRunning && _viewingInsightSkill == null && AppLogger.count > 0 && panelContent == AppLogger.logsText;
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
                _panelWidthFraction = ((_panelWidthFraction * screenWidth - details.delta.dx) / screenWidth)
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
                  border: Border(left: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Panel header
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
                      ),
                      child: Row(
                        children: [
                          if (isRunning) ...[
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                            const SizedBox(width: 12),
                          ] else ...[
                            Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.accent),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
                            ),
                          ),
                          if (!isRunning && panelContent.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.copy_rounded, size: 16, color: cs.onSurfaceVariant),
                              tooltip: 'Copy to clipboard',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: panelContent));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied to clipboard'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
                                );
                              },
                            ),
                          if (isShowingLogs) ...[
                            // Refresh logs
                            IconButton(
                              icon: Icon(Icons.refresh_rounded, size: 16, color: cs.onSurfaceVariant),
                              tooltip: 'Refresh logs',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _streamedOutput = AppLogger.logsText),
                            ),
                            // Clear logs
                            IconButton(
                              icon: Icon(Icons.delete_sweep_rounded, size: 16, color: cs.onSurfaceVariant),
                              tooltip: 'Clear logs',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                AppLogger.clear();
                                setState(() => _streamedOutput = 'Logs cleared.');
                              },
                            ),
                          ] else ...[
                            // Switch to logs view
                            IconButton(
                              icon: Icon(Icons.bug_report_outlined, size: 16, color: cs.onSurfaceVariant),
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
                            icon: Icon(Icons.close_rounded, size: 20, color: cs.onSurfaceVariant),
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
                                style: AppTypography.inter(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                              ),
                            )
                          : SingleChildScrollView(
                              controller: _outputScrollController,
                              padding: const EdgeInsets.all(20),
                              child: SelectableText(
                                panelContent,
                                style: AppTypography.mono(fontSize: 12, color: cs.onSurface).copyWith(height: 1.6),
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

  Widget _buildSection(ColorScheme cs) {
    switch (_activeSection) {
      case 'overview':
        return _buildOverviewSection(cs);
      case 'actions':
        return _buildActionsSection(cs);
      case 'health':
        return _buildHealthSection(cs);
      case 'environment':
        return _buildEnvironmentSection(cs);
      case 'ai':
        return _buildAIInsightsSection(cs);
      case 'ship':
        return _buildShipSection(cs);
      case 'release':
        return _buildReleaseSection(cs);
      case 'compliance':
        return _buildComplianceSection(cs);
      case 'danger':
        return _buildDangerSection(cs);
      default:
        return _buildGeneralSection(cs);
    }
  }

  Widget _buildOverviewSection(ColorScheme cs) {
    if (!_overviewLoaded) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
    }

    final stack = _projectStack;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tech Stack
        _SectionHeader(title: 'Tech Stack'),
        const SizedBox(height: 16),
        if (stack != null) ...[
          _OverviewInfoCard(
            children: [
              _StackRow(
                label: 'Primary',
                type: stack.primary,
                isPrimary: true,
              ),
              if (stack.secondary.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...stack.secondary.map((type) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _StackRow(label: 'Secondary', type: type),
                )),
              ],
            ],
          ),
        ],

        // Platforms (Flutter/Dart projects)
        if (_platforms.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionHeader(title: 'Platforms'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _platforms.map((p) => _PlatformChip(platform: p)).toList(),
          ),
        ],

        // Git Info
        const SizedBox(height: 24),
        _SectionHeader(title: 'Git'),
        const SizedBox(height: 16),
        _OverviewInfoCard(
          children: [
            _InfoRow(
              icon: Icons.fork_right_rounded,
              label: 'Branch',
              value: _branchName ?? 'N/A',
              valueColor: _branchName != null ? AppColors.accent : null,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.cloud_outlined,
              label: 'Remote',
              value: _remoteUrl ?? 'No remote',
              mono: true,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Author',
              value: _gitEmail ?? 'Not configured',
            ),
          ],
        ),

        // Project Files
        const SizedBox(height: 24),
        _SectionHeader(title: 'Project Files'),
        const SizedBox(height: 16),
        _OverviewInfoCard(
          children: _projectFiles.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  e.value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  size: 16,
                  color: e.value ? AppColors.success : cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 10),
                Text(
                  e.key,
                  style: AppTypography.mono(
                    fontSize: 13,
                    color: e.value ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildActionsSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Open In'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.terminal_rounded,
                label: 'Terminal',
                subtitle: 'Open project in Terminal',
                color: const Color(0xFF34D399),
                onTap: widget.onOpenTerminal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.code_rounded,
                label: 'VS Code',
                subtitle: 'Open project in editor',
                color: const Color(0xFF60A5FA),
                onTap: widget.onOpenVSCode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.folder_open_rounded,
                label: 'Finder',
                subtitle: 'Reveal in Finder',
                color: const Color(0xFFA78BFA),
                onTap: () => LauncherService.openInFinder(widget.project.path),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: widget.project.isPinned ? Icons.star_rounded : Icons.star_border_rounded,
                label: widget.project.isPinned ? 'Unpin' : 'Pin Project',
                subtitle: widget.project.isPinned ? 'Remove from pinned' : 'Pin to top of list',
                color: AppColors.accent,
                onTap: widget.onTogglePin,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        _SectionHeader(title: 'Copy'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.copy_rounded,
                label: 'Copy Path',
                subtitle: widget.project.path,
                color: cs.onSurfaceVariant,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.project.path));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Path copied'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.content_copy_rounded,
                label: 'Copy Name',
                subtitle: widget.project.name,
                color: cs.onSurfaceVariant,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.project.name));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name copied'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneralSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Project Identity
        _SectionHeader(title: 'Project Identity'),
        const SizedBox(height: 16),
        _FieldLabel(label: 'Display Name'),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          enabled: false,
          decoration: _inputDecoration(cs, hint: 'Project name'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: 16),
        _FieldLabel(label: 'Project Path'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.project.path,
                  style: AppTypography.mono(fontSize: 13, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.folder_open_rounded, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Tags & Categorization
        _SectionHeader(title: 'Tags & Categorization'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tags.map((tag) => _TagChip(
              label: tag,
              onRemove: () {
                setState(() {
                  _tags.remove(tag);
                  _hasChanges = true;
                });
              },
            )),
            ActionChip(
              label: Text(
                '+ Add Tag',
                style: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
              onPressed: _addTag,
              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _FieldLabel(label: 'Project Notes'),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 4,
          decoration: _inputDecoration(cs, hint: 'Add notes about this project...'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
        ),
      ],
    );
  }

  Widget _buildHealthSection(ColorScheme cs) {
    final score = widget.healthScore?.details;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Health Overview'),
        const SizedBox(height: 16),
        if (score != null) ...[
          _HealthRow(label: 'Git Activity', score: score.gitScore, maxScore: 40),
          const SizedBox(height: 12),
          _HealthRow(label: 'Dependencies', score: score.depsScore, maxScore: 30),
          const SizedBox(height: 12),
          _HealthRow(label: 'Tests', score: score.testsScore, maxScore: 30),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Details', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 12),
                _DetailRow(label: 'Recent commits', value: score.hasRecentCommits),
                _DetailRow(label: 'No uncommitted changes', value: score.noUncommittedChanges),
                _DetailRow(label: 'No unpushed commits', value: score.noUnpushedCommits),
                _DetailRow(label: 'Has dependency file', value: score.hasDependencyFile),
                _DetailRow(label: 'Has lock file', value: score.hasLockFile),
                _DetailRow(label: 'Has test folder', value: score.hasTestFolder),
                _DetailRow(label: 'Has test files', value: score.hasTestFiles),
              ],
            ),
          ),
        ] else
          Text(
            'No health data available. Run a health check from the dashboard.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _buildEnvironmentSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Quick Launch'),
        const SizedBox(height: 16),
        _SettingRow(
          label: 'Primary Terminal',
          value: 'Terminal.app (Default)',
          icon: Icons.terminal_rounded,
        ),
        const SizedBox(height: 12),
        _SettingRow(
          label: 'Editor',
          value: 'VS Code',
          icon: Icons.code_rounded,
        ),
        const SizedBox(height: 24),
        Text(
          'Terminal and editor detection is automatic. Custom configuration coming in a future update.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
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
      statusLabel = 'Connected${_claudeVersion != null ? ' · $_claudeVersion' : ''}';
      statusIcon = Icons.check_circle_rounded;
    }

    return Row(
      children: [
        Text('AI Insights', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
                style: AppTypography.inter(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.bug_report_outlined, size: 16, color: cs.onSurfaceVariant),
          tooltip: 'View debug logs',
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final isShowingLogs = _outputPanelOpen && _viewingInsightSkill == null && _runningSkill == null;
            if (isShowingLogs) {
              // Toggle off
              setState(() => _outputPanelOpen = false);
            } else {
              setState(() {
                _outputPanelOpen = true;
                _viewingInsightSkill = null;
                _streamedOutput = AppLogger.count == 0 ? 'No logs yet.' : AppLogger.logsText;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildAIInsightsSection(ColorScheme cs) {
    if (!_aiLoaded) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
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
                Icon(Icons.terminal_rounded, size: 36, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text('Claude CLI not found', style: AppTypography.inter(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 6),
                Text(
                  'Install Claude Code to use AI skills.\n\nnpm install -g @anthropic-ai/claude-code',
                  textAlign: TextAlign.center,
                  style: AppTypography.inter(fontSize: 13, color: cs.onSurfaceVariant),
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
                style: AppTypography.inter(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _testingConnection ? null : () async {
                setState(() => _testingConnection = true);
                final result = await AIService.testConnection();
                if (!mounted) return;
                setState(() {
                  _testingConnection = false;
                  _outputPanelOpen = true;
                  _viewingInsightSkill = null;
                  _streamedOutput = '${AppLogger.logsText}\n\n--- Connection Test ---\n$result';
                });
              },
              icon: _testingConnection
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurfaceVariant))
                  : Icon(Icons.wifi_tethering_rounded, size: 16),
              label: Text(_testingConnection ? 'Testing...' : 'Test'),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                textStyle: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
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
                  hintStyle: AppTypography.inter(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
                  ),
                  prefixIcon: Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accent.withValues(alpha: 0.6)),
                ),
                style: AppTypography.inter(fontSize: 13, color: cs.onSurface),
                maxLines: 1,
                onSubmitted: _runningSkill != null ? null : (_) => _runCustomPrompt(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _runningSkill != null || _customPromptController.text.trim().isEmpty
                    ? null
                    : _runCustomPrompt,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Run'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: cs.surfaceContainerHighest,
                  disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Running indicator — compact, click to open panel
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
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Running /$_runningSkill...', style: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ),
                  Text('View output', style: AppTypography.inter(fontSize: 12, color: AppColors.accent)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.accent),
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
          skills: _availableSkills.where((s) => !s.isBuiltIn && !s.isCLIDiscovered).toList(),
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
          Text('Saved Insights', style: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 12),
          ..._insights.map((insight) => _AIInsightCard(
            insight: insight,
            onView: () => _viewInsight(insight),
            onDelete: () async {
              await AIService.deleteInsight(widget.project.path, insight.skillName);
              final updated = await AIService.loadInsights(widget.project.path);
              if (mounted) setState(() => _insights = updated);
            },
            onRerun: () {
              final skill = _availableSkills.where((s) => s.name == insight.skillName).firstOrNull;
              if (skill != null) _runAISkill(skill);
            },
          )),
        ],
      ],
    );
  }

  List<Widget> _buildSkillGroup(ColorScheme cs, {
    required String title,
    String? subtitle,
    required List<ClaudeSkill> skills,
  }) {
    if (skills.isEmpty) return [];
    return [
      const SizedBox(height: 4),
      Row(
        children: [
          Text(title, style: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(subtitle, style: AppTypography.mono(fontSize: 11, color: cs.onSurfaceVariant)),
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
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : Text('/', style: AppTypography.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
              label: Text(skill.name),
              labelStyle: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w500),
              backgroundColor: isRunning ? AppColors.accent.withValues(alpha: 0.1) : null,
              side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
              onPressed: _runningSkill != null ? null : () => _runAISkill(skill),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
    ];
  }

  Future<void> _loadShipReadiness() async {
    final readiness = await ShipReadinessService.evaluate(widget.project.path);
    if (mounted) setState(() { _shipReadiness = readiness; _shipLoaded = true; });
  }

  Future<void> _toggleManualItem(ShipCheckItem item) async {
    setState(() {
      if (item.status == CheckStatus.pass) {
        item.status = CheckStatus.pending;
      } else {
        item.status = CheckStatus.pass;
      }
    });
    if (_shipReadiness != null) {
      await ShipReadinessService.saveManualStates(widget.project.path, _shipReadiness!.categories);
    }
  }

  Widget _buildShipSection(ColorScheme cs) {
    if (!_shipLoaded) {
      _loadShipReadiness();
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final readiness = _shipReadiness!;
    final scoreColor = readiness.overallScore >= 80 ? AppColors.success
        : readiness.overallScore >= 50 ? AppColors.warning : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with overall score
        Row(
          children: [
            Text('Ship Readiness', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${readiness.overallScore}', style: AppTypography.mono(fontSize: 18, fontWeight: FontWeight.w800, color: scoreColor)),
                  Text('/100', style: AppTypography.mono(fontSize: 12, color: scoreColor.withValues(alpha: 0.6))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Re-evaluate',
              onPressed: () { setState(() => _shipLoaded = false); _loadShipReadiness(); },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${readiness.totalPass}/${readiness.totalItems} checks passed',
          style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        // Overall progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: readiness.overallScore / 100,
            backgroundColor: cs.outline.withValues(alpha: 0.1),
            color: scoreColor,
            minHeight: 8,
          ),
        ),

        // Critical failures callout
        if (readiness.criticalFailures.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Blockers', style: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
                const SizedBox(height: 6),
                ...readiness.criticalFailures.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Icon(Icons.cancel_rounded, size: 14, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text(item.title, style: AppTypography.inter(fontSize: 12, color: cs.onSurface)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Categories
        ...readiness.categories.map((cat) => _buildShipCategory(cat, cs)),

        // Legend
        const SizedBox(height: 16),
        Row(
          children: [
            _legendItem(Icons.smart_toy_outlined, 'Auto-detected', cs),
            const SizedBox(width: 16),
            _legendItem(Icons.check_box_outline_blank, 'Manual toggle', cs),
            const SizedBox(width: 16),
            _legendItem(Icons.auto_awesome_outlined, 'AI-assisted', cs),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(IconData icon, String label, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.inter(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
      ],
    );
  }

  Widget _buildShipCategory(ShipCategory category, ColorScheme cs) {
    if (category.items.isEmpty) return const SizedBox();
    final catScoreColor = category.score >= 80 ? AppColors.success
        : category.score >= 50 ? AppColors.warning : AppColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Text(category.title, style: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const Spacer(),
                  Text(
                    '${category.passCount}/${category.applicableCount}',
                    style: AppTypography.mono(fontSize: 12, fontWeight: FontWeight.w600, color: catScoreColor),
                  ),
                ],
              ),
            ),
            // Items
            ...category.items.map((item) => _buildShipItem(item, cs)),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildShipItem(ShipCheckItem item, ColorScheme cs) {
    final statusColor = switch (item.status) {
      CheckStatus.pass => AppColors.success,
      CheckStatus.fail => AppColors.error,
      CheckStatus.warn => AppColors.warning,
      CheckStatus.skip => const Color(0xFF6B7280),
      CheckStatus.pending => cs.onSurfaceVariant.withValues(alpha: 0.4),
      CheckStatus.running => AppColors.accent,
    };
    final statusIcon = switch (item.status) {
      CheckStatus.pass => Icons.check_circle_rounded,
      CheckStatus.fail => Icons.cancel_rounded,
      CheckStatus.warn => Icons.warning_amber_rounded,
      CheckStatus.skip => Icons.remove_circle_outline_rounded,
      CheckStatus.pending => Icons.radio_button_unchecked_rounded,
      CheckStatus.running => Icons.sync_rounded,
    };
    final modeIcon = switch (item.mode) {
      CheckMode.auto => Icons.smart_toy_outlined,
      CheckMode.manual => Icons.check_box_outline_blank,
      CheckMode.ai => Icons.auto_awesome_outlined,
    };

    return InkWell(
      onTap: item.mode == CheckMode.manual ? () => _toggleManualItem(item) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: item.status == CheckStatus.skip ? cs.onSurfaceVariant.withValues(alpha: 0.5) : cs.onSurface,
                    ),
                  ),
                  if (item.detail != null)
                    Text(item.detail!, style: AppTypography.inter(fontSize: 10, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(modeIcon, size: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseSection(ColorScheme cs) {
    if (!_releaseLoaded) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(strokeWidth: 2)));
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
            Text('Release', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (score.total >= 80 ? AppColors.success : score.total >= 50 ? AppColors.warning : AppColors.error).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${score.total}/100',
                style: AppTypography.mono(fontSize: 13, fontWeight: FontWeight.w700, color: score.total >= 80 ? AppColors.success : score.total >= 50 ? AppColors.warning : AppColors.error),
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
                    info.version != null ? 'v${info.version}' : 'No version detected',
                    style: AppTypography.mono(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                  if (info.versionSource != null) ...[
                    const SizedBox(width: 8),
                    Text('from ${info.versionSource}', style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (info.lastTag != null) ...[
                    Text('Last tag: ${info.lastTag}', style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant)),
                    if (info.unreleasedCommits > 0)
                      Text(' (+${info.unreleasedCommits} unreleased)', style: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning)),
                  ] else
                    Text('No tags yet', style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  if (info.isDeployable && info.deployTargets.isNotEmpty)
                    ...info.deployTargets.map((t) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(t, style: AppTypography.mono(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accent)),
                      ),
                    )),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Readiness score breakdown
        Text('Readiness Breakdown', style: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
        const SizedBox(height: 8),
        // Score bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score.total / 100,
            backgroundColor: cs.outline.withValues(alpha: 0.1),
            color: score.total >= 80 ? AppColors.success : score.total >= 50 ? AppColors.warning : AppColors.error,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        // Individual items
        ...score.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                item.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: item.passed ? AppColors.success : cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.label, style: AppTypography.inter(fontSize: 12, color: cs.onSurface)),
              ),
              Text(
                '${item.points}/${item.maxPoints}',
                style: AppTypography.mono(fontSize: 11, color: cs.onSurfaceVariant),
              ),
              if (item.detail != null) ...[
                const SizedBox(width: 8),
                Text(item.detail!, style: AppTypography.inter(fontSize: 11, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        )),
        const SizedBox(height: 20),

        // CI/CD info
        if (deploy.ciProvider != null || deploy.buildTools.isNotEmpty || deploy.containerFiles.isNotEmpty) ...[
          Text('Build & Deploy', style: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (deploy.ciProvider != null)
                _infoBadge(deploy.ciProvider!, Icons.play_circle_outline_rounded, cs),
              ...deploy.buildTools.map((t) => _infoBadge(t, Icons.build_rounded, cs)),
              ...deploy.containerFiles.map((f) => _infoBadge(f, Icons.view_in_ar_rounded, cs)),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Detected release process
        if (_releaseProcess != null) ...[
          Row(
            children: [
              Text('Release Process', style: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  _releaseProcess!.method,
                  style: AppTypography.mono(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accent),
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
                    width: 20, height: 20,
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
                    child: Center(child: Text('${i + 1}', style: AppTypography.mono(fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant))),
                  ),
                  const SizedBox(width: 10),
                  Icon(typeIcon, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.name, style: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface)),
                        Text(step.description, style: AppTypography.inter(fontSize: 10, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (step.isAutomated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text('auto', style: AppTypography.mono(fontSize: 9, color: AppColors.success)),
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
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                  : const Icon(Icons.rocket_launch_rounded, size: 18),
              label: Text(_shippingRelease ? 'Shipping...' : 'Ship It'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: cs.surface,
                textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Manual actions
        if (info.version != null) ...[
          Text('Manual Actions', style: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _releaseAction('Bump Patch', Icons.arrow_upward_rounded, _bumpingVersion ? null : () => _bumpVersionAction('patch'), cs),
              _releaseAction('Bump Minor', Icons.arrow_upward_rounded, _bumpingVersion ? null : () => _bumpVersionAction('minor'), cs),
              _releaseAction('Bump Major', Icons.arrow_upward_rounded, _bumpingVersion ? null : () => _bumpVersionAction('major'), cs),
              _releaseAction('Tag & Push', Icons.local_offer_rounded, _creatingTag ? null : _tagAndPush, cs),
              _releaseAction('GitHub Release', Icons.rocket_launch_rounded, _creatingTag ? null : _createGitHubRelease, cs),
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
          Text(label, style: AppTypography.inter(fontSize: 12, color: cs.onSurface)),
        ],
      ),
    );
  }

  Widget _releaseAction(String label, IconData icon, VoidCallback? onPressed, ColorScheme cs) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onSurface,
        side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
        textStyle: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  Future<void> _bumpVersionAction(String level) async {
    setState(() => _bumpingVersion = true);
    final newVersion = await ReleaseService.bumpVersion(widget.project.path, level);
    if (mounted) {
      setState(() => _bumpingVersion = false);
      if (newVersion != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Version bumped to $newVersion'), behavior: SnackBarBehavior.floating));
        _loadReleaseData();
      }
    }
  }

  Future<void> _tagAndPush() async {
    if (_releaseInfo?.version == null) return;
    setState(() => _creatingTag = true);
    final tagged = await ReleaseService.createTag(widget.project.path, _releaseInfo!.version!);
    if (tagged) await ReleaseService.pushTags(widget.project.path);
    if (mounted) {
      setState(() => _creatingTag = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tagged ? 'Tagged v${_releaseInfo!.version} and pushed' : 'Failed to create tag'),
        behavior: SnackBarBehavior.floating,
      ));
      _loadReleaseData();
    }
  }

  Future<void> _createGitHubRelease() async {
    if (_releaseInfo?.version == null) return;
    setState(() => _creatingTag = true);
    final url = await ReleaseService.createGitHubRelease(widget.project.path, _releaseInfo!.version!);
    if (mounted) {
      setState(() => _creatingTag = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(url != null ? 'GitHub release created' : 'Failed to create release (is gh CLI installed?)'),
        behavior: SnackBarBehavior.floating,
      ));
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
              Icon(Icons.rocket_launch_rounded, color: AppColors.accent, size: 22),
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
                  style: AppTypography.inter(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Text('Steps to execute:', style: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...process.steps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text('${e.key + 1}. ', style: AppTypography.mono(fontSize: 12, color: cs.onSurfaceVariant)),
                      Expanded(child: Text(e.value.name, style: AppTypography.inter(fontSize: 12, color: cs.onSurface))),
                      if (e.value.isAutomated)
                        Text('(auto)', style: AppTypography.mono(fontSize: 10, color: AppColors.success)),
                    ],
                  ),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: const Text('Ship It'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _shippingRelease = true);
    AppLogger.info('Release', 'Starting release with ${process.method} process (${process.steps.length} steps)');

    String? currentVersion;
    final results = <String>[];
    var failed = false;

    for (final step in process.steps) {
      if (step.isAutomated) {
        results.add('${step.name}: skipped (automated by CI)');
        continue;
      }

      final result = await ReleaseService.executeStep(widget.project.path, step, version: currentVersion);
      results.add('${step.name}: ${result.success ? "OK" : "FAILED"} — ${result.output.split('\n').first}');

      if (result.version != null) currentVersion = result.version;

      if (!result.success) {
        failed = true;
        break;
      }
    }

    if (!mounted) return;

    setState(() => _shippingRelease = false);

    // Show results in the output panel
    setState(() {
      _outputPanelOpen = true;
      _viewingInsightSkill = null;
      _streamedOutput = '# Release: ${process.method}\n\n${results.join('\n')}\n\n${failed ? "FAILED — stopped at first error" : "All steps completed successfully"}';
    });

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          title: Row(
            children: [
              Icon(Icons.rocket_launch_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Text('Ship It', style: AppTypography.inter(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
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
              _shipStep('1', 'Bump version $currentVersion \u2192 $newVersion', cs),
              _shipStep('2', 'Commit: "Release $tagName"', cs),
              _shipStep('3', 'Create tag $tagName', cs),
              _shipStep('4', 'Push commits and tags', cs),
              _shipStep('5', 'Create GitHub release', cs),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: AppTypography.inter(fontSize: 13, color: cs.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: cs.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: Text('Ship It', style: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _shippingRelease = true);
    AppLogger.info('Release', 'One-click release started: $level bump for ${widget.project.name}');

    try {
      // Step 1: Bump version
      final bumped = await ReleaseService.bumpVersion(widget.project.path, level);
      if (bumped == null) {
        _showShipResult(false, 'Failed to bump version');
        return;
      }
      AppLogger.info('Release', 'Version bumped to $bumped');

      // Step 2: Commit version bump
      final committed = await ReleaseService.commitVersionBump(widget.project.path, bumped);
      if (!committed) {
        _showShipResult(false, 'Failed to commit version bump');
        return;
      }
      AppLogger.info('Release', 'Version bump committed');

      // Step 3: Create tag
      final tagged = await ReleaseService.createTag(widget.project.path, bumped);
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
      final url = await ReleaseService.createGitHubRelease(widget.project.path, bumped);
      if (url != null) {
        AppLogger.info('Release', 'GitHub release created: $url');
      } else {
        AppLogger.warn('Release', 'GitHub release failed (gh CLI may not be installed)');
      }

      _showShipResult(true, 'Shipped v$bumped${url != null ? '' : ' (GitHub release skipped)'}');
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
            child: Text(number, style: AppTypography.mono(fontSize: 10, color: AppColors.accent)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  void _showShipResult(bool success, String message) {
    if (mounted) {
      setState(() => _shippingRelease = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
      ));
      _loadReleaseData();
    }
  }

  Widget _buildComplianceSection(ColorScheme cs) {
    if (!_complianceLoaded) {
      // Auto-trigger on first view
      if (!_runningAudit) _loadComplianceData();
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final report = _complianceReport!;
    final scoreColor = report.score >= 80 ? AppColors.success : report.score >= 50 ? AppColors.warning : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text('Compliance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('${report.score}/100', style: AppTypography.mono(fontSize: 13, fontWeight: FontWeight.w700, color: scoreColor)),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Re-audit',
              onPressed: _runningAudit ? null : () {
                setState(() => _complianceLoaded = false);
                _loadComplianceData();
              },
            ),
          ],
        ),
        if (report.licenseType != null) ...[
          const SizedBox(height: 4),
          Text('License: ${report.licenseType}', style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),

        // Compliance items
        ...report.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: _complianceStatusColor(item.status).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(_complianceStatusIcon(item.status), size: 18, color: _complianceStatusColor(item.status)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
                      if (item.detail != null)
                        Text(item.detail!, style: AppTypography.inter(fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(
                  item.status.name.toUpperCase(),
                  style: AppTypography.mono(fontSize: 10, fontWeight: FontWeight.w700, color: _complianceStatusColor(item.status)),
                ),
              ],
            ),
          ),
        )),

        // Secrets section
        if (report.secrets.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Potential Secrets (${report.secrets.length})', style: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
          const SizedBox(height: 8),
          ...report.secrets.take(10).map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${s.file}:${s.line} — ${s.pattern}',
              style: AppTypography.mono(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          )),
        ],

        // SBOM summary
        if (report.sbom.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('SBOM (${report.sbom.length} dependencies)', style: AppTypography.inter(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 8),
          Text('Dependencies cataloged from ${report.sbom.map((s) => s.source).toSet().join(', ')}', style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant)),
        ],

        // AI audit button
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _runningAudit ? null : () async {
            setState(() => _runningAudit = true);
            final result = await ComplianceService.aiAudit(widget.project.path);
            if (mounted) {
              setState(() {
                _runningAudit = false;
                if (result != null) {
                  _outputPanelOpen = true;
                  _viewingInsightSkill = 'compliance-audit';
                  _streamedOutput = result;
                }
              });
            }
          },
          icon: Icon(Icons.auto_awesome_rounded, size: 16),
          label: Text(_runningAudit ? 'Running AI audit...' : 'Run AI Compliance Audit'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
            textStyle: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Color _complianceStatusColor(ComplianceStatus status) {
    switch (status) {
      case ComplianceStatus.pass: return AppColors.success;
      case ComplianceStatus.warn: return AppColors.warning;
      case ComplianceStatus.fail: return AppColors.error;
      case ComplianceStatus.skip: return const Color(0xFF6B7280);
    }
  }

  IconData _complianceStatusIcon(ComplianceStatus status) {
    switch (status) {
      case ComplianceStatus.pass: return Icons.check_circle_rounded;
      case ComplianceStatus.warn: return Icons.warning_amber_rounded;
      case ComplianceStatus.fail: return Icons.cancel_rounded;
      case ComplianceStatus.skip: return Icons.remove_circle_outline_rounded;
    }
  }

  Widget _buildDangerSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Danger Zone', color: AppColors.error),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remove Project',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Removing the project from Launcher will not delete the local files. You can always re-add it later by scanning or browsing.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _removeProject,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('Remove Project'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(ColorScheme cs, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.mono(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
      filled: true,
      fillColor: cs.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );
  }
}

// -- Sub-widgets --

class _NavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.accent.withValues(alpha: 0.15)
                : _isHovered
                    ? cs.onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isActive ? AppColors.accent : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: AppTypography.inter(
                  fontSize: 13,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isActive ? AppColors.accent : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionHeader({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _TagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = AppColors.languageColors[label] ?? AppColors.accent;

    return Chip(
      label: Text(
        label,
        style: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
      deleteIcon: Icon(Icons.close, size: 14, color: color),
      onDeleted: onRemove,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final HealthCategory category;
  const _HealthBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (category) {
      case HealthCategory.healthy:
        color = AppColors.success;
      case HealthCategory.needsAttention:
        color = AppColors.warning;
      case HealthCategory.critical:
        color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        category.label,
        style: AppTypography.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final int score;
  final int maxScore;

  const _HealthRow({required this.label, required this.score, required this.maxScore});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = maxScore > 0 ? score / maxScore : 0.0;
    Color barColor;
    if (fraction >= 0.8) {
      barColor = AppColors.success;
    } else if (fraction >= 0.5) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.error;
    }

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: cs.outline.withValues(alpha: 0.1),
              color: barColor,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            '$score/$maxScore',
            textAlign: TextAlign.right,
            style: AppTypography.mono(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final bool value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: value ? AppColors.success : cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.08)
                : cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.4)
                  : cs.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(widget.icon, size: 20, color: widget.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: AppTypography.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: AppTypography.inter(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: _hovered ? widget.color : cs.outline.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewInfoCard extends StatelessWidget {
  final List<Widget> children;
  const _OverviewInfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _StackRow extends StatelessWidget {
  final String label;
  final ProjectType type;
  final bool isPrimary;

  const _StackRow({required this.label, required this.type, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: type.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(type.icon, size: 18, color: type.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type.label,
                style: AppTypography.inter(
                  fontSize: 14,
                  fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              Text(
                label,
                style: AppTypography.inter(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: type.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            type.label,
            style: AppTypography.inter(fontSize: 10, fontWeight: FontWeight.w600, color: type.color),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: mono
                ? AppTypography.mono(fontSize: 12, color: valueColor ?? cs.onSurface)
                : AppTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? cs.onSurface,
                  ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String platform;
  const _PlatformChip({required this.platform});

  static const _platformMeta = {
    'macos': ('macOS', Icons.desktop_mac_rounded, Color(0xFF60A5FA)),
    'ios': ('iOS', Icons.phone_iphone_rounded, Color(0xFFFA7343)),
    'android': ('Android', Icons.android_rounded, Color(0xFF34D399)),
    'web': ('Web', Icons.language_rounded, Color(0xFFFBBF24)),
    'linux': ('Linux', Icons.computer_rounded, Color(0xFFA78BFA)),
    'windows': ('Windows', Icons.window_rounded, Color(0xFF60A5FA)),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _platformMeta[platform];
    final label = meta?.$1 ?? platform;
    final icon = meta?.$2 ?? Icons.devices_rounded;
    final color = meta?.$3 ?? const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SettingRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AIInsightCard extends StatelessWidget {
  final AIInsight insight;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback onRerun;

  const _AIInsightCard({
    required this.insight,
    required this.onView,
    required this.onDelete,
    required this.onRerun,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = insight.output.length > 150 ? '${insight.output.substring(0, 150)}...' : insight.output;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: insight.isError
                ? AppColors.error.withValues(alpha: 0.03)
                : cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: insight.isError
                  ? AppColors.error.withValues(alpha: 0.2)
                  : cs.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: (insight.isError ? AppColors.error : AppColors.accent).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '/',
                  style: AppTypography.mono(fontSize: 12, fontWeight: FontWeight.w700, color: insight.isError ? AppColors.error : AppColors.accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(insight.skillName, style: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatDate(insight.createdAt)} · ${insight.durationSeconds}s',
                          style: AppTypography.inter(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.mono(fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh_rounded, size: 16), tooltip: 'Re-run', onPressed: onRerun, visualDensity: VisualDensity.compact),
              IconButton(icon: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error.withValues(alpha: 0.6)), tooltip: 'Delete', onPressed: onDelete, visualDensity: VisualDensity.compact),
              Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
