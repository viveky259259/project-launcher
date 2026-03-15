import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import '../models/ai_insight.dart';
import 'app_logger.dart';
import 'platform_helper.dart';

class AIService {
  static const _tag = 'AI';
  static const String _insightsDirName = 'ai_insights';

  static String get _insightsBasePath {
    return '${PlatformHelper.dataDir}${Platform.pathSeparator}$_insightsDirName';
  }

  // --- Built-in Claude Skills ---

  static const List<Map<String, String>> _builtInSkills = [
    {
      'name': 'understand-project',
      'description': 'Analyze project structure, architecture, and key patterns',
      'prompt': 'Analyze this project thoroughly. Cover: 1) Project type and tech stack, 2) Architecture and file structure, 3) Key patterns and conventions, 4) Dependencies and their purpose, 5) Build/test/deploy setup. Be concise but comprehensive.',
    },
    {
      'name': 'code-review',
      'description': 'Review code quality, find bugs, and suggest improvements',
      'prompt': 'Review this codebase for: 1) Bugs and potential issues, 2) Security vulnerabilities, 3) Performance concerns, 4) Code quality and maintainability, 5) Missing error handling. Prioritize critical issues first.',
    },
    {
      'name': 'summarize-changes',
      'description': 'Summarize recent git changes and their impact',
      'prompt': 'Look at the recent git history (last 10-20 commits) and summarize: 1) What features/fixes were added, 2) Which areas of code changed most, 3) Any patterns in the changes, 4) Current state of uncommitted work if any.',
    },
    {
      'name': 'find-todos',
      'description': 'Find all TODOs, FIXMEs, and technical debt markers',
      'prompt': 'Search the entire codebase for TODO, FIXME, HACK, XXX, OPTIMIZE, and similar markers. List each one with its file location and context. Group by priority/category.',
    },
    {
      'name': 'dependency-audit',
      'description': 'Audit dependencies for security, freshness, and necessity',
      'prompt': 'Analyze the project dependencies: 1) List all direct dependencies and their purpose, 2) Flag any that look outdated or unmaintained, 3) Identify unused dependencies if possible, 4) Note any known security concerns, 5) Suggest alternatives where appropriate.',
    },
    {
      'name': 'test-coverage-analysis',
      'description': 'Analyze test coverage gaps and suggest what to test',
      'prompt': 'Analyze the test setup and coverage: 1) What testing frameworks are used, 2) Which parts of the code have tests, 3) Which critical paths lack tests, 4) Suggest specific test cases to write, prioritized by risk.',
    },
    {
      'name': 'architecture-review',
      'description': 'Deep-dive into architecture, patterns, and design decisions',
      'prompt': 'Provide an architecture review: 1) Overall architecture pattern (MVC, MVVM, clean arch, etc.), 2) Layer separation and dependency flow, 3) State management approach, 4) Data flow patterns, 5) Strengths and weaknesses, 6) Recommended improvements.',
    },
    {
      'name': 'onboarding-guide',
      'description': 'Generate a developer onboarding guide for this project',
      'prompt': 'Generate a concise developer onboarding guide for this project. Cover: 1) Prerequisites and setup steps, 2) How to build and run, 3) Project structure walkthrough, 4) Key files a new developer should read first, 5) Common workflows (adding features, fixing bugs), 6) Testing approach.',
    },
  ];

  // --- Skill Discovery ---

  /// Cached CLI-discovered skills (from `system/init` event).
  static List<String>? _cachedCLISkills;

  /// Fetch the list of skills from the Claude CLI `system/init` event.
  /// Runs a minimal command and parses the first JSON line.
  static Future<List<String>> fetchSkillsFromCLI() async {
    if (_cachedCLISkills != null) return _cachedCLISkills!;

    final bin = await _findClaude();
    if (bin == null) {
      AppLogger.warn(_tag, 'Cannot fetch CLI skills: Claude CLI not found');
      return [];
    }

    AppLogger.info(_tag, 'Fetching skills from Claude CLI init event...');
    try {
      final result = await Process.run(
        bin,
        ['-p', 'exit', '--output-format', 'stream-json', '--verbose', '--max-turns', '1'],
        environment: {...Platform.environment, 'TERM': 'dumb'},
      ).timeout(const Duration(seconds: 30));

      final stdout = result.stdout.toString();
      final skills = <String>[];

      for (final line in stdout.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final jsonObj = json.decode(trimmed) as Map<String, dynamic>;
          if (jsonObj['type'] == 'system' && jsonObj['subtype'] == 'init') {
            final skillsList = jsonObj['skills'] as List<dynamic>?;
            if (skillsList != null) {
              skills.addAll(skillsList.cast<String>());
            }
            AppLogger.info(_tag, 'CLI init event: found ${skills.length} skills');
            break;
          }
        } catch (_) {
          // Not valid JSON, skip
        }
      }

      _cachedCLISkills = skills;
      return skills;
    } on TimeoutException {
      AppLogger.warn(_tag, 'CLI skills fetch timed out (30s)');
      return [];
    } catch (e) {
      AppLogger.error(_tag, 'CLI skills fetch error: $e');
      return [];
    }
  }

  /// Get all available skills: built-in Claude skills + user-installed skills from ~/.claude/skills/ + CLI-discovered skills.
  static Future<List<ClaudeSkill>> getAvailableSkills() async {
    final skills = <ClaudeSkill>[];

    // Add built-in skills first
    for (final s in _builtInSkills) {
      skills.add(ClaudeSkill(
        name: s['name']!,
        description: s['description'],
        isBuiltIn: true,
        prompt: s['prompt'],
      ));
    }

    // Scan user-installed skills
    final skillsDir = Directory('${PlatformHelper.homeDir}/.claude/skills');
    if (await skillsDir.exists()) {
      await for (final entity in skillsDir.list()) {
        if (entity is Directory) {
          final skill = await _parseSkillDir(entity);
          if (skill != null) {
            skills.add(skill);
          } else {
            // Scan as a namespace directory (e.g., ~/.claude/skills/gstack/*)
            await for (final sub in entity.list()) {
              if (sub is Directory) {
                final nestedSkill = await _parseSkillDir(sub);
                if (nestedSkill != null) skills.add(nestedSkill);
              }
            }
          }
        }
      }
    }

    // Merge CLI-discovered skills (add any not already in the list)
    try {
      final cliSkills = await fetchSkillsFromCLI();
      final existingNames = skills.map((s) => s.name).toSet();
      for (final cliSkillName in cliSkills) {
        if (!existingNames.contains(cliSkillName)) {
          skills.add(ClaudeSkill(
            name: cliSkillName,
            description: 'CLI-discovered skill',
            isCLIDiscovered: true,
          ));
          existingNames.add(cliSkillName);
        }
      }
    } catch (e) {
      AppLogger.warn(_tag, 'Failed to merge CLI skills: $e');
    }

    // Deduplicate by name (user skills override built-in if same name)
    final seen = <String>{};
    skills.retainWhere((s) => seen.add(s.name));

    final builtIn = skills.where((s) => s.isBuiltIn).length;
    final cliDiscovered = skills.where((s) => s.isCLIDiscovered).length;
    final installed = skills.length - builtIn - cliDiscovered;
    AppLogger.info(_tag, 'Skills: $builtIn built-in, $installed installed, $cliDiscovered CLI-discovered (${skills.length} total)');
    return skills;
  }

  static Future<ClaudeSkill?> _parseSkillDir(Directory dir) async {
    final skillFile = File('${dir.path}/SKILL.md');
    if (!await skillFile.exists()) return null;

    final name = PlatformHelper.basename(dir.path);
    String? description;

    try {
      final content = await skillFile.readAsString();
      // Parse YAML-like frontmatter for description
      if (content.startsWith('---')) {
        final endIndex = content.indexOf('---', 3);
        if (endIndex > 0) {
          final frontmatter = content.substring(3, endIndex);
          for (final line in frontmatter.split('\n')) {
            final trimmed = line.trim();
            if (trimmed.startsWith('description:')) {
              description = trimmed.substring('description:'.length).trim();
              // Remove surrounding quotes
              if (description.startsWith('"') && description.endsWith('"')) {
                description = description.substring(1, description.length - 1);
              }
              if (description.startsWith("'") && description.endsWith("'")) {
                description = description.substring(1, description.length - 1);
              }
              break;
            }
          }
        }
      }
      // Fallback: use first non-empty, non-heading line as description
      if (description == null || description.isEmpty) {
        for (final line in content.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('#') && !trimmed.startsWith('---')) {
            description = trimmed.length > 100 ? '${trimmed.substring(0, 100)}...' : trimmed;
            break;
          }
        }
      }
    } catch (e) {
      log('Error parsing skill $name: $e');
    }

    return ClaudeSkill(
      name: name,
      description: description,
      path: dir.path,
    );
  }

  // --- Execution ---

  static String? _claudePath;

  /// Find the `claude` binary, searching common paths that GUI apps miss.
  static Future<String?> _findClaude() async {
    if (_claudePath != null) return _claudePath;

    final home = PlatformHelper.homeDir;
    final candidates = [
      '$home/.local/bin/claude',
      '$home/.nvm/versions/node/current/bin/claude',
      '/usr/local/bin/claude',
      '/opt/homebrew/bin/claude',
      '$home/.volta/bin/claude',
      '$home/.fnm/aliases/default/bin/claude',
    ];

    for (final path in candidates) {
      if (await File(path).exists()) {
        _claudePath = path;
        AppLogger.info(_tag, 'Claude CLI found at: $path');
        return path;
      }
    }

    // Last resort: try `which` via a login shell to get full PATH
    try {
      final result = await Process.run(
        '/bin/zsh',
        ['-l', '-c', 'which claude'],
      );
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty && await File(path).exists()) {
          _claudePath = path;
          AppLogger.info(_tag, 'Claude CLI found via shell: $path');
          return path;
        }
      }
    } catch (_) {}

    AppLogger.warn(_tag, 'Claude CLI not found in any known path');
    return null;
  }

  /// Check if the `claude` CLI is available.
  static Future<bool> isClaudeInstalled() async {
    return (await _findClaude()) != null;
  }

  /// Get the Claude CLI version string, or null if unavailable.
  static Future<String?> getClaudeVersion() async {
    final bin = await _findClaude();
    if (bin == null) return null;
    try {
      final result = await Process.run(bin, ['--version']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return null;
  }

  /// Test if Claude CLI can reach the API and respond.
  /// Returns a result string describing the status.
  static Future<String> testConnection() async {
    final bin = await _findClaude();
    if (bin == null) return 'FAIL: Claude CLI not found';

    AppLogger.info(_tag, 'Testing connection...');
    try {
      final result = await Process.run(
        bin,
        ['-p', 'Reply with exactly: CONNECTION_OK', '--output-format', 'text', '--max-turns', '1'],
        environment: {...Platform.environment, 'TERM': 'dumb'},
      ).timeout(const Duration(seconds: 30));

      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();

      if (result.exitCode == 0 && stdout.isNotEmpty) {
        AppLogger.info(_tag, 'Connection test OK: ${stdout.substring(0, stdout.length.clamp(0, 80))}');
        return 'OK: Claude responded (${stdout.length} chars)';
      } else {
        final error = stderr.isNotEmpty ? stderr : stdout.isNotEmpty ? stdout : 'exit code ${result.exitCode}';
        AppLogger.error(_tag, 'Connection test failed: $error');
        return 'FAIL: $error';
      }
    } on TimeoutException {
      AppLogger.error(_tag, 'Connection test timed out (30s)');
      return 'FAIL: Timed out after 30s';
    } catch (e) {
      AppLogger.error(_tag, 'Connection test error: $e');
      return 'FAIL: $e';
    }
  }

  static final _validSkillName = RegExp(r'^[a-zA-Z0-9_-]+$');

  /// Run a Claude skill on a project directory with real-time streaming.
  /// Uses `--output-format stream-json --verbose` to get partial message chunks.
  /// If [prompt] is provided (for built-in skills), it is sent directly instead of "/$skillName".
  static Future<AIInsight> runSkill({
    required String projectPath,
    required String skillName,
    String? prompt,
    void Function(String chunk)? onOutput,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (!_validSkillName.hasMatch(skillName)) {
      return AIInsight(
        skillName: skillName,
        output: 'Invalid skill name: only letters, numbers, hyphens, and underscores are allowed.',
        createdAt: DateTime.now(),
        durationSeconds: 0,
        isError: true,
      );
    }

    final claudeBin = await _findClaude();
    if (claudeBin == null) {
      return AIInsight(
        skillName: skillName,
        output: 'Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code',
        createdAt: DateTime.now(),
        durationSeconds: 0,
        isError: true,
      );
    }

    AppLogger.info(_tag, 'Running skill /$skillName on ${projectPath.split('/').last}');
    final stopwatch = Stopwatch()..start();
    final resultBuffer = StringBuffer();
    final cliPrompt = prompt ?? '/$skillName';
    var isError = false;

    try {
      final process = await Process.start(
        claudeBin,
        [
          '-p', cliPrompt,
          '--output-format', 'stream-json',
          '--verbose',
          '--include-partial-messages',
          '--allowedTools', 'Read', 'Glob', 'Grep', 'Bash', 'LSP',
        ],
        workingDirectory: projectPath,
        environment: {
          ...Platform.environment,
          'TERM': 'dumb',
        },
      );

      // Buffer for incomplete JSON lines
      var lineBuffer = '';
      // Accumulate all text across multiple assistant messages
      final allText = StringBuffer();

      final stdoutSub = process.stdout.transform(utf8.decoder).listen((data) {
        lineBuffer += data;
        // Process complete lines
        while (lineBuffer.contains('\n')) {
          final nlIndex = lineBuffer.indexOf('\n');
          final line = lineBuffer.substring(0, nlIndex).trim();
          lineBuffer = lineBuffer.substring(nlIndex + 1);

          if (line.isEmpty) continue;

          try {
            final jsonObj = json.decode(line) as Map<String, dynamic>;
            final type = jsonObj['type'] as String?;

            if (type == 'assistant') {
              final message = jsonObj['message'] as Map<String, dynamic>?;
              final content = message?['content'] as List<dynamic>?;
              if (content != null) {
                // Build the current message's text
                final msgText = StringBuffer();
                for (final block in content) {
                  if (block is Map<String, dynamic>) {
                    if (block['type'] == 'text') {
                      msgText.write(block['text'] as String? ?? '');
                    } else if (block['type'] == 'tool_use') {
                      final tool = block['name'] as String? ?? 'tool';
                      AppLogger.debug(_tag, 'Tool call: $tool');
                    }
                  }
                }
                // Update result with accumulated text so far + current partial
                final currentText = msgText.toString();
                if (currentText.isNotEmpty) {
                  resultBuffer.clear();
                  resultBuffer.write(allText.toString() + currentText);
                  onOutput?.call(resultBuffer.toString());
                }
              }
              // On complete messages (stop_reason set), commit text to accumulator
              final stopReason = message?['stop_reason'] as String?;
              if (stopReason != null && stopReason != 'stop_sequence' || stopReason == 'end_turn') {
                final committed = resultBuffer.toString();
                if (committed.length > allText.length) {
                  allText.clear();
                  allText.write(committed);
                }
              }
              if (jsonObj['error'] != null) {
                isError = true;
              }
            } else if (type == 'result') {
              // Final result — use it as the authoritative output
              final resultText = jsonObj['result'] as String?;
              if (resultText != null && resultText.isNotEmpty) {
                resultBuffer.clear();
                resultBuffer.write(resultText);
                onOutput?.call(resultText);
              }
              if (jsonObj['is_error'] == true) {
                isError = true;
              }
            }
          } catch (_) {
            // Not valid JSON, skip
          }
        }
      });

      final stderrBuffer = StringBuffer();
      final stderrSub = process.stderr.transform(utf8.decoder).listen((chunk) {
        stderrBuffer.write(chunk);
      });

      final exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          process.kill();
          return -1;
        },
      );

      await stdoutSub.cancel();
      await stderrSub.cancel();

      stopwatch.stop();

      final output = resultBuffer.toString().isNotEmpty
          ? resultBuffer.toString()
          : stderrBuffer.toString().isNotEmpty
              ? stderrBuffer.toString()
              : 'Claude exited with code $exitCode';

      if (exitCode != 0 || isError) {
        AppLogger.error(_tag, 'Skill /$skillName failed (exit=$exitCode, ${stopwatch.elapsed.inSeconds}s): ${output.substring(0, output.length.clamp(0, 150))}');
        return AIInsight(
          skillName: skillName,
          output: output,
          createdAt: DateTime.now(),
          durationSeconds: stopwatch.elapsed.inSeconds,
          isError: true,
        );
      }

      final insight = AIInsight(
        skillName: skillName,
        output: output,
        createdAt: DateTime.now(),
        durationSeconds: stopwatch.elapsed.inSeconds,
      );

      await saveInsight(projectPath, insight);
      AppLogger.info(_tag, 'Skill /$skillName completed: ${stopwatch.elapsed.inSeconds}s, ${output.length} chars');

      return insight;
    } catch (e) {
      stopwatch.stop();
      AppLogger.error(_tag, 'Skill /$skillName exception: $e');
      return AIInsight(
        skillName: skillName,
        output: 'Failed to run Claude: $e',
        createdAt: DateTime.now(),
        durationSeconds: stopwatch.elapsed.inSeconds,
        isError: true,
      );
    }
  }

  // --- Persistence ---

  static String _projectFileName(String projectPath) {
    // Deterministic FNV-1a hash (stable across runs, unlike String.hashCode)
    final hash = _fnv1a(projectPath).toRadixString(16).padLeft(8, '0');
    final safeName = PlatformHelper.basename(projectPath).replaceAll(RegExp(r'[^\w-]'), '_');
    return '${safeName}_$hash.json';
  }

  /// FNV-1a 32-bit hash — deterministic and stable across Dart runtimes.
  static int _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static String _insightFilePath(String projectPath) {
    return '$_insightsBasePath${Platform.pathSeparator}${_projectFileName(projectPath)}';
  }

  static Future<void> _ensureDirExists() async {
    final dir = Directory(_insightsBasePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Load all persisted insights for a project.
  static Future<List<AIInsight>> loadInsights(String projectPath) async {
    try {
      final file = File(_insightFilePath(projectPath));
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final data = json.decode(content) as Map<String, dynamic>;
      final insights = (data['insights'] as List<dynamic>?)
              ?.map((j) => AIInsight.fromJson(j as Map<String, dynamic>))
              .toList() ??
          [];

      // Sort newest first
      insights.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return insights;
    } catch (e) {
      log('Error loading AI insights: $e');
      return [];
    }
  }

  /// Save an insight for a project. Replaces any existing insight with the same skill name.
  static Future<void> saveInsight(String projectPath, AIInsight insight) async {
    try {
      await _ensureDirExists();
      final insights = await loadInsights(projectPath);

      // Replace existing insight for same skill, or add new
      final existingIndex = insights.indexWhere((i) => i.skillName == insight.skillName);
      if (existingIndex >= 0) {
        insights[existingIndex] = insight;
      } else {
        insights.insert(0, insight);
      }

      final data = {
        'projectPath': projectPath,
        'insights': insights.map((i) => i.toJson()).toList(),
      };

      final file = File(_insightFilePath(projectPath));
      await file.writeAsString(json.encode(data));
    } catch (e) {
      log('Error saving AI insight: $e');
    }
  }

  /// Delete a specific insight by skill name.
  static Future<void> deleteInsight(String projectPath, String skillName) async {
    try {
      final insights = await loadInsights(projectPath);
      insights.removeWhere((i) => i.skillName == skillName);

      if (insights.isEmpty) {
        final file = File(_insightFilePath(projectPath));
        if (await file.exists()) await file.delete();
        return;
      }

      final data = {
        'projectPath': projectPath,
        'insights': insights.map((i) => i.toJson()).toList(),
      };

      final file = File(_insightFilePath(projectPath));
      await file.writeAsString(json.encode(data));
    } catch (e) {
      log('Error deleting AI insight: $e');
    }
  }

  /// Delete all insights for a project.
  static Future<void> deleteAllInsights(String projectPath) async {
    try {
      final file = File(_insightFilePath(projectPath));
      if (await file.exists()) await file.delete();
    } catch (e) {
      log('Error deleting all AI insights: $e');
    }
  }

  /// Quickly check if a project has any saved AI insights (without reading the full file).
  static Future<bool> hasInsights(String projectPath) async {
    try {
      final file = File(_insightFilePath(projectPath));
      return await file.exists();
    } catch (_) {
      return false;
    }
  }
}
