import 'dart:io';
import 'app_logger.dart';
import 'git_service.dart';
import 'version_detector.dart';
import 'compliance_service.dart';
import '../models/release_info.dart';

/// Manages releases: readiness scoring, version bumping, tagging, and release creation.
class ReleaseService {
  static const _tag = 'Release';

  /// Calculate release readiness score for a project.
  static Future<ReadinessScore> getReadinessScore(String projectPath) async {
    AppLogger.info(_tag, 'Calculating readiness for ${projectPath.split('/').last}');
    final items = <ReadinessItem>[];
    var gitScore = 0, versionScore = 0, testsScore = 0;
    var cicdScore = 0, depsScore = 0, complianceScore = 0, signingScore = 0;

    // --- Git (20 pts) ---
    final isGit = await GitService.isGitRepository(projectPath);
    if (isGit) {
      final clean = !(await GitService.hasUncommittedChanges(projectPath));
      final unpushed = await GitService.getUnpushedCommitCount(projectPath);
      final branch = await GitService.getCurrentBranch(projectPath);
      final isReleaseBranch = branch == 'main' || branch == 'master' || (branch?.startsWith('release') ?? false);

      if (clean) gitScore += 10;
      items.add(ReadinessItem(category: 'Git', label: 'Clean working tree', passed: clean, points: clean ? 10 : 0, maxPoints: 10));

      final allPushed = unpushed == 0;
      if (allPushed) gitScore += 5;
      items.add(ReadinessItem(category: 'Git', label: 'All commits pushed', passed: allPushed, points: allPushed ? 5 : 0, maxPoints: 5, detail: allPushed ? null : '$unpushed unpushed'));

      if (isReleaseBranch) gitScore += 5;
      items.add(ReadinessItem(category: 'Git', label: 'On release branch', passed: isReleaseBranch, points: isReleaseBranch ? 5 : 0, maxPoints: 5, detail: branch));
    } else {
      items.add(ReadinessItem(category: 'Git', label: 'Git repository', passed: false, points: 0, maxPoints: 20, detail: 'Not a git repo'));
    }

    // --- Version (15 pts) ---
    final releaseInfo = await VersionDetector.detect(projectPath);
    final hasVersion = releaseInfo.version != null;
    if (hasVersion) versionScore += 10;
    items.add(ReadinessItem(category: 'Version', label: 'Valid version', passed: hasVersion, points: hasVersion ? 10 : 0, maxPoints: 10, detail: releaseInfo.version ?? 'Not detected'));

    final hasChangelog = File('$projectPath/CHANGELOG.md').existsSync() || File('$projectPath/CHANGES.md').existsSync();
    if (hasChangelog) versionScore += 5;
    items.add(ReadinessItem(category: 'Version', label: 'Changelog exists', passed: hasChangelog, points: hasChangelog ? 5 : 0, maxPoints: 5));

    // --- Tests (15 pts) ---
    final hasTestDir = ['test', 'tests', 'spec', '__tests__'].any((d) => Directory('$projectPath/$d').existsSync());
    if (hasTestDir) testsScore += 8;
    items.add(ReadinessItem(category: 'Tests', label: 'Test directory', passed: hasTestDir, points: hasTestDir ? 8 : 0, maxPoints: 8));

    final hasTestFiles = hasTestDir && _hasTestFiles(projectPath);
    if (hasTestFiles) testsScore += 7;
    items.add(ReadinessItem(category: 'Tests', label: 'Test files exist', passed: hasTestFiles, points: hasTestFiles ? 7 : 0, maxPoints: 7));

    // --- CI/CD (15 pts) ---
    final deploy = detectDeploymentConfig(projectPath);
    final hasCi = deploy.ciProvider != null;
    if (hasCi) cicdScore += 10;
    items.add(ReadinessItem(category: 'CI/CD', label: 'CI pipeline', passed: hasCi, points: hasCi ? 10 : 0, maxPoints: 10, detail: deploy.ciProvider));

    final hasBuildTool = deploy.buildTools.isNotEmpty;
    if (hasBuildTool) cicdScore += 5;
    items.add(ReadinessItem(category: 'CI/CD', label: 'Build tool', passed: hasBuildTool, points: hasBuildTool ? 5 : 0, maxPoints: 5, detail: hasBuildTool ? deploy.buildTools.join(', ') : null));

    // --- Dependencies (10 pts) ---
    final hasLockFile = _hasLockFile(projectPath);
    if (hasLockFile) depsScore += 5;
    items.add(ReadinessItem(category: 'Deps', label: 'Lock file', passed: hasLockFile, points: hasLockFile ? 5 : 0, maxPoints: 5));

    final hasDepFile = _hasDependencyFile(projectPath);
    if (hasDepFile) depsScore += 5;
    items.add(ReadinessItem(category: 'Deps', label: 'Dependency file', passed: hasDepFile, points: hasDepFile ? 5 : 0, maxPoints: 5));

    // --- Compliance (15 pts) ---
    final hasLicense = File('$projectPath/LICENSE').existsSync() || File('$projectPath/LICENSE.md').existsSync();
    if (hasLicense) complianceScore += 5;
    items.add(ReadinessItem(category: 'Compliance', label: 'LICENSE', passed: hasLicense, points: hasLicense ? 5 : 0, maxPoints: 5));

    final hasReadme = File('$projectPath/README.md').existsSync() || File('$projectPath/readme.md').existsSync();
    if (hasReadme) complianceScore += 5;
    items.add(ReadinessItem(category: 'Compliance', label: 'README', passed: hasReadme, points: hasReadme ? 5 : 0, maxPoints: 5));

    final hasGitignore = File('$projectPath/.gitignore').existsSync();
    if (hasGitignore) complianceScore += 5;
    items.add(ReadinessItem(category: 'Compliance', label: '.gitignore', passed: hasGitignore, points: hasGitignore ? 5 : 0, maxPoints: 5));

    // --- Signing (10 pts) ---
    final signing = _detectSigning(projectPath);
    if (signing != null) signingScore += 10;
    items.add(ReadinessItem(category: 'Signing', label: 'Code signing', passed: signing != null, points: signing != null ? 10 : 0, maxPoints: 10, detail: signing));

    final total = gitScore + versionScore + testsScore + cicdScore + depsScore + complianceScore + signingScore;
    AppLogger.info(_tag, '${projectPath.split('/').last}: readiness $total/100');

    return ReadinessScore(
      total: total,
      gitScore: gitScore,
      versionScore: versionScore,
      testsScore: testsScore,
      cicdScore: cicdScore,
      depsScore: depsScore,
      complianceScore: complianceScore,
      signingScore: signingScore,
      items: items,
    );
  }

  /// Detect CI/CD provider and build tools.
  static DeploymentConfig detectDeploymentConfig(String projectPath) {
    String? ciProvider;
    String? ciConfigPath;

    // CI providers
    if (Directory('$projectPath/.github/workflows').existsSync()) {
      ciProvider = 'GitHub Actions';
      ciConfigPath = '.github/workflows/';
    } else if (File('$projectPath/.gitlab-ci.yml').existsSync()) {
      ciProvider = 'GitLab CI';
      ciConfigPath = '.gitlab-ci.yml';
    } else if (Directory('$projectPath/.circleci').existsSync()) {
      ciProvider = 'CircleCI';
      ciConfigPath = '.circleci/';
    } else if (File('$projectPath/.travis.yml').existsSync()) {
      ciProvider = 'Travis CI';
      ciConfigPath = '.travis.yml';
    } else if (File('$projectPath/azure-pipelines.yml').existsSync()) {
      ciProvider = 'Azure Pipelines';
      ciConfigPath = 'azure-pipelines.yml';
    } else if (File('$projectPath/Jenkinsfile').existsSync()) {
      ciProvider = 'Jenkins';
      ciConfigPath = 'Jenkinsfile';
    } else if (Directory('$projectPath/.buildkite').existsSync()) {
      ciProvider = 'Buildkite';
      ciConfigPath = '.buildkite/';
    }

    // Build tools
    final buildTools = <String>[];
    if (File('$projectPath/Makefile').existsSync()) buildTools.add('make');
    if (File('$projectPath/Fastfile').existsSync() ||
        Directory('$projectPath/fastlane').existsSync()) buildTools.add('fastlane');
    if (File('$projectPath/Rakefile').existsSync()) buildTools.add('rake');
    if (File('$projectPath/Taskfile.yml').existsSync()) buildTools.add('task');
    if (File('$projectPath/justfile').existsSync()) buildTools.add('just');

    // Container files
    final containerFiles = <String>[];
    if (File('$projectPath/Dockerfile').existsSync()) containerFiles.add('Dockerfile');
    if (File('$projectPath/docker-compose.yml').existsSync()) containerFiles.add('docker-compose.yml');
    if (File('$projectPath/docker-compose.yaml').existsSync()) containerFiles.add('docker-compose.yaml');

    // Code signing
    final signing = _detectSigning(projectPath);

    return DeploymentConfig(
      ciProvider: ciProvider,
      ciConfigPath: ciConfigPath,
      buildTools: buildTools,
      containerFiles: containerFiles,
      hasCodeSigning: signing != null,
      signingDetail: signing,
    );
  }

  /// Bump the version in the project's version file.
  static Future<String?> bumpVersion(String projectPath, String level) async {
    final info = await VersionDetector.detect(projectPath);
    if (info.version == null || info.versionSource == null) {
      AppLogger.warn(_tag, 'Cannot bump: no version detected');
      return null;
    }

    final newVersion = VersionDetector.bumpVersion(info.version!, level);
    final filePath = '$projectPath/${info.versionSource}';
    AppLogger.info(_tag, 'Bumping ${info.version} → $newVersion in ${info.versionSource}');

    try {
      final file = File(filePath);
      var content = await file.readAsString();

      // Replace version in file based on source type
      switch (info.versionSource) {
        case 'pubspec.yaml':
          content = content.replaceFirst(
            RegExp(r'^version:\s*.+$', multiLine: true),
            'version: $newVersion',
          );
        case 'package.json':
          content = content.replaceFirst(
            RegExp(r'"version"\s*:\s*"[^"]+"'),
            '"version": "$newVersion"',
          );
        case 'Cargo.toml':
          content = content.replaceFirst(
            RegExp(r'version\s*=\s*"[^"]+"'),
            'version = "$newVersion"',
          );
        default:
          content = content.replaceFirst(info.version!, newVersion);
      }

      await file.writeAsString(content);
      return newVersion;
    } catch (e) {
      AppLogger.error(_tag, 'Failed to bump version: $e');
      return null;
    }
  }

  /// Create a git tag for the current version.
  static Future<bool> createTag(String projectPath, String version, {String? message}) async {
    final tagName = version.startsWith('v') ? version : 'v$version';
    final tagMessage = message ?? 'Release $tagName';

    AppLogger.info(_tag, 'Creating tag $tagName');
    try {
      final result = await Process.run(
        'git', ['tag', '-a', tagName, '-m', tagMessage],
        workingDirectory: projectPath,
      );
      return result.exitCode == 0;
    } catch (e) {
      AppLogger.error(_tag, 'Failed to create tag: $e');
      return false;
    }
  }

  /// Push tags to remote.
  static Future<bool> pushTags(String projectPath) async {
    AppLogger.info(_tag, 'Pushing tags to remote');
    try {
      final result = await Process.run(
        'git', ['push', '--tags'],
        workingDirectory: projectPath,
      );
      return result.exitCode == 0;
    } catch (e) {
      AppLogger.error(_tag, 'Failed to push tags: $e');
      return false;
    }
  }

  /// Create a GitHub release using gh CLI.
  static Future<String?> createGitHubRelease(String projectPath, String version, {String? notes}) async {
    final tagName = version.startsWith('v') ? version : 'v$version';
    AppLogger.info(_tag, 'Creating GitHub release $tagName');
    try {
      final args = ['release', 'create', tagName, '--title', 'Release $tagName'];
      if (notes != null) {
        args.addAll(['--notes', notes]);
      } else {
        args.add('--generate-notes');
      }
      final result = await Process.run('gh', args, workingDirectory: projectPath);
      if (result.exitCode == 0) {
        final url = result.stdout.toString().trim();
        AppLogger.info(_tag, 'GitHub release created: $url');
        return url;
      }
      AppLogger.error(_tag, 'gh release failed: ${result.stderr}');
    } catch (e) {
      AppLogger.error(_tag, 'GitHub release error: $e');
    }
    return null;
  }

  /// Commit a version bump with a standard message.
  static Future<bool> commitVersionBump(String projectPath, String version) async {
    final tagName = version.startsWith('v') ? version : 'v$version';
    AppLogger.info(_tag, 'Committing version bump to $tagName');
    try {
      final addResult = await Process.run(
        'git', ['add', '-A'],
        workingDirectory: projectPath,
      );
      if (addResult.exitCode != 0) {
        AppLogger.error(_tag, 'git add failed: ${addResult.stderr}');
        return false;
      }
      final commitResult = await Process.run(
        'git', ['commit', '-m', 'Release $tagName'],
        workingDirectory: projectPath,
      );
      if (commitResult.exitCode != 0) {
        AppLogger.error(_tag, 'git commit failed: ${commitResult.stderr}');
        return false;
      }
      return true;
    } catch (e) {
      AppLogger.error(_tag, 'Failed to commit version bump: $e');
      return false;
    }
  }

  /// Push all commits and tags to remote.
  static Future<bool> pushAll(String projectPath) async {
    AppLogger.info(_tag, 'Pushing commits and tags to remote');
    try {
      final pushResult = await Process.run(
        'git', ['push'],
        workingDirectory: projectPath,
      );
      if (pushResult.exitCode != 0) {
        AppLogger.error(_tag, 'git push failed: ${pushResult.stderr}');
        return false;
      }
      final tagsResult = await Process.run(
        'git', ['push', '--tags'],
        workingDirectory: projectPath,
      );
      if (tagsResult.exitCode != 0) {
        AppLogger.error(_tag, 'git push --tags failed: ${tagsResult.stderr}');
        return false;
      }
      return true;
    } catch (e) {
      AppLogger.error(_tag, 'Failed to push: $e');
      return false;
    }
  }

  /// Get list of git tags.
  static Future<List<String>> getTags(String projectPath) async {
    try {
      final result = await Process.run(
        'git', ['tag', '--sort=-creatordate'],
        workingDirectory: projectPath,
      );
      if (result.exitCode == 0) {
        return result.stdout.toString().trim().split('\n').where((t) => t.isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }

  // --- Release Process Detection ---

  /// Detect the project's existing release process by scanning for scripts,
  /// Makefile targets, npm scripts, Fastlane, and CI workflows.
  /// Returns an ordered list of steps the project uses to release.
  static Future<ReleaseProcess> detectReleaseProcess(String projectPath) async {
    AppLogger.info(_tag, 'Detecting release process for ${projectPath.split('/').last}');
    final steps = <ReleaseStep>[];
    String? method;

    // 1. Check for dedicated release scripts
    final scriptsDir = Directory('$projectPath/scripts');
    if (scriptsDir.existsSync()) {
      final releaseScripts = scriptsDir.listSync()
          .whereType<File>()
          .where((f) {
            final name = f.path.split('/').last.toLowerCase();
            return name.contains('release') || name.contains('deploy') || name.contains('publish') || name.contains('ship');
          })
          .toList();

      if (releaseScripts.isNotEmpty) {
        method = 'scripts';
        for (final script in releaseScripts) {
          final name = script.path.split('/').last;
          final description = await _parseScriptDescription(script.path);
          steps.add(ReleaseStep(
            name: name,
            command: 'scripts/$name',
            description: description ?? 'Run $name',
            type: ReleaseStepType.script,
          ));
        }
      }
    }

    // 2. Check Makefile for release/deploy/publish targets
    final makefile = File('$projectPath/Makefile');
    if (makefile.existsSync()) {
      final content = makefile.readAsStringSync();
      final targets = RegExp(r'^([a-z][\w-]*):',  multiLine: true).allMatches(content);
      final releaseTargets = targets
          .map((m) => m.group(1)!)
          .where((t) => {'release', 'deploy', 'publish', 'ship', 'dist', 'install', 'build-release'}.contains(t))
          .toList();

      if (releaseTargets.isNotEmpty && method == null) method = 'make';
      for (final target in releaseTargets) {
        steps.add(ReleaseStep(
          name: 'make $target',
          command: 'make $target',
          description: 'Makefile target: $target',
          type: ReleaseStepType.make,
        ));
      }
    }

    // 3. Check package.json scripts
    final pkgJson = File('$projectPath/package.json');
    if (pkgJson.existsSync()) {
      try {
        final content = pkgJson.readAsStringSync();
        for (final script in ['release', 'deploy', 'publish', 'ship', 'prepublishOnly']) {
          if (RegExp('"$script"\\s*:').hasMatch(content)) {
            if (method == null) method = 'npm';
            final cmdMatch = RegExp('"$script"\\s*:\\s*"([^"]+)"').firstMatch(content);
            steps.add(ReleaseStep(
              name: 'npm run $script',
              command: 'npm run $script',
              description: cmdMatch != null ? cmdMatch.group(1)! : 'npm script: $script',
              type: ReleaseStepType.npm,
            ));
          }
        }
      } catch (_) {}
    }

    // 4. Check Fastlane
    final fastlaneDir = Directory('$projectPath/fastlane');
    if (fastlaneDir.existsSync()) {
      if (method == null) method = 'fastlane';
      final fastfile = File('$projectPath/fastlane/Fastfile');
      if (fastfile.existsSync()) {
        final content = fastfile.readAsStringSync();
        final lanes = RegExp(r'lane\s*:(\w+)').allMatches(content);
        for (final lane in lanes) {
          final name = lane.group(1)!;
          if ({'release', 'deploy', 'beta', 'distribute', 'publish'}.contains(name)) {
            steps.add(ReleaseStep(
              name: 'fastlane $name',
              command: 'fastlane $name',
              description: 'Fastlane lane: $name',
              type: ReleaseStepType.fastlane,
            ));
          }
        }
      }
    }

    // 5. Check GitHub Actions release workflow
    final ghWorkflows = Directory('$projectPath/.github/workflows');
    if (ghWorkflows.existsSync()) {
      for (final file in ghWorkflows.listSync().whereType<File>()) {
        final name = file.path.split('/').last;
        if (name.contains('release') || name.contains('deploy') || name.contains('publish')) {
          try {
            final content = file.readAsStringSync();
            // Detect trigger
            String trigger = 'manual';
            if (content.contains("push:") && content.contains("tags:")) trigger = 'on tag push';
            if (content.contains("workflow_dispatch:")) trigger = 'manual dispatch';
            steps.add(ReleaseStep(
              name: 'GH Action: $name',
              command: 'gh workflow run $name',
              description: 'Triggered $trigger',
              type: ReleaseStepType.githubAction,
              isAutomated: trigger == 'on tag push',
            ));
          } catch (_) {}
        }
      }
    }

    // 6. Check for semantic-release / release-please / changesets
    if (File('$projectPath/.releaserc').existsSync() || File('$projectPath/.releaserc.json').existsSync()) {
      method ??= 'semantic-release';
      steps.add(ReleaseStep(name: 'semantic-release', command: 'npx semantic-release', description: 'Automated versioning from commits', type: ReleaseStepType.tool));
    }
    if (File('$projectPath/.release-please-manifest.json').existsSync()) {
      method ??= 'release-please';
      steps.add(ReleaseStep(name: 'release-please', command: 'release-please', description: 'Google release-please automation', type: ReleaseStepType.tool, isAutomated: true));
    }
    if (Directory('$projectPath/.changeset').existsSync()) {
      method ??= 'changesets';
      steps.add(ReleaseStep(name: 'changesets', command: 'npx changeset publish', description: 'Changeset-based publishing', type: ReleaseStepType.tool));
    }

    // If nothing detected, fall back to generic flow
    if (steps.isEmpty) {
      method = 'generic';
      steps.addAll([
        ReleaseStep(name: 'Bump version', command: '_builtin:bump', description: 'Increment version in project file', type: ReleaseStepType.builtin),
        ReleaseStep(name: 'Commit', command: '_builtin:commit', description: 'Commit version bump', type: ReleaseStepType.builtin),
        ReleaseStep(name: 'Tag', command: '_builtin:tag', description: 'Create git tag', type: ReleaseStepType.builtin),
        ReleaseStep(name: 'Push', command: '_builtin:push', description: 'Push to remote with tags', type: ReleaseStepType.builtin),
        ReleaseStep(name: 'GitHub Release', command: '_builtin:gh_release', description: 'Create GitHub release', type: ReleaseStepType.builtin),
      ]);
    }

    AppLogger.info(_tag, 'Release process: $method (${steps.length} steps)');
    return ReleaseProcess(method: method ?? 'unknown', steps: steps);
  }

  /// Execute a release step.
  static Future<StepResult> executeStep(String projectPath, ReleaseStep step, {String? version}) async {
    AppLogger.info(_tag, 'Executing: ${step.name}');

    if (step.command.startsWith('_builtin:')) {
      return _executeBuiltinStep(projectPath, step.command, version);
    }

    try {
      // Determine shell command
      String executable;
      List<String> args;

      if (step.type == ReleaseStepType.script) {
        final scriptPath = '$projectPath/${step.command}';
        executable = '/bin/bash';
        args = [scriptPath];
      } else if (step.type == ReleaseStepType.make) {
        executable = 'make';
        args = [step.command.replaceFirst('make ', '')];
      } else if (step.type == ReleaseStepType.npm) {
        executable = 'npm';
        args = ['run', step.command.replaceFirst('npm run ', '')];
      } else if (step.type == ReleaseStepType.fastlane) {
        executable = 'fastlane';
        args = [step.command.replaceFirst('fastlane ', '')];
      } else if (step.type == ReleaseStepType.githubAction) {
        executable = 'gh';
        args = step.command.replaceFirst('gh ', '').split(' ');
      } else {
        executable = '/bin/bash';
        args = ['-c', step.command];
      }

      final result = await Process.run(executable, args, workingDirectory: projectPath);

      if (result.exitCode == 0) {
        AppLogger.info(_tag, '${step.name}: OK');
        return StepResult(success: true, output: result.stdout.toString());
      } else {
        AppLogger.error(_tag, '${step.name}: FAILED (exit ${result.exitCode})\n${result.stderr}');
        return StepResult(success: false, output: result.stderr.toString().isNotEmpty ? result.stderr.toString() : result.stdout.toString());
      }
    } catch (e) {
      AppLogger.error(_tag, '${step.name}: exception $e');
      return StepResult(success: false, output: '$e');
    }
  }

  static Future<StepResult> _executeBuiltinStep(String projectPath, String command, String? version) async {
    switch (command) {
      case '_builtin:bump':
        final v = await bumpVersion(projectPath, 'patch');
        return v != null ? StepResult(success: true, output: 'Bumped to $v', version: v) : StepResult(success: false, output: 'Failed to bump version');
      case '_builtin:commit':
        final v = version ?? 'unknown';
        final ok = await commitVersionBump(projectPath, v);
        return StepResult(success: ok, output: ok ? 'Committed' : 'Failed to commit');
      case '_builtin:tag':
        final v = version ?? 'unknown';
        final ok = await createTag(projectPath, v);
        return StepResult(success: ok, output: ok ? 'Tagged v$v' : 'Failed to tag');
      case '_builtin:push':
        final ok = await pushAll(projectPath);
        return StepResult(success: ok, output: ok ? 'Pushed' : 'Failed to push');
      case '_builtin:gh_release':
        final v = version ?? 'unknown';
        final url = await createGitHubRelease(projectPath, v);
        return StepResult(success: url != null, output: url ?? 'Failed to create release');
      default:
        return StepResult(success: false, output: 'Unknown builtin: $command');
    }
  }

  static Future<String?> _parseScriptDescription(String scriptPath) async {
    try {
      final lines = await File(scriptPath).readAsLines();
      for (final line in lines.take(10)) {
        if (line.startsWith('#') && !line.startsWith('#!')) {
          return line.replaceFirst(RegExp(r'^#+\s*'), '').trim();
        }
      }
    } catch (_) {}
    return null;
  }

  // --- Private helpers ---

  static bool _hasTestFiles(String path) {
    for (final dir in ['test', 'tests', 'spec', '__tests__']) {
      final d = Directory('$path/$dir');
      if (d.existsSync()) {
        try {
          return d.listSync(recursive: true).any((f) =>
              f is File && (f.path.contains('_test.') || f.path.contains('.test.') || f.path.contains('_spec.')));
        } catch (_) {}
      }
    }
    return false;
  }

  static bool _hasLockFile(String path) {
    return ['pubspec.lock', 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml',
      'Cargo.lock', 'Gemfile.lock', 'poetry.lock', 'Pipfile.lock',
      'composer.lock', 'go.sum'].any((f) => File('$path/$f').existsSync());
  }

  static bool _hasDependencyFile(String path) {
    return ['pubspec.yaml', 'package.json', 'Cargo.toml', 'requirements.txt',
      'Pipfile', 'pyproject.toml', 'Gemfile', 'composer.json',
      'build.gradle', 'pom.xml', 'go.mod'].any((f) => File('$path/$f').existsSync());
  }

  static String? _detectSigning(String path) {
    // iOS/macOS
    if (File('$path/ios/Runner.xcodeproj/project.pbxproj').existsSync()) {
      try {
        final content = File('$path/ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
        if (content.contains('CODE_SIGN_IDENTITY') && !content.contains('CODE_SIGN_IDENTITY = "-"')) {
          return 'Xcode signing configured';
        }
      } catch (_) {}
    }
    // Android
    if (File('$path/android/app/build.gradle').existsSync()) {
      try {
        final content = File('$path/android/app/build.gradle').readAsStringSync();
        if (content.contains('signingConfigs')) return 'Gradle signing configured';
      } catch (_) {}
    }
    // macOS
    if (File('$path/macos/Runner.xcodeproj/project.pbxproj').existsSync()) {
      try {
        final content = File('$path/macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();
        if (content.contains('CODE_SIGN_IDENTITY') && !content.contains('CODE_SIGN_IDENTITY = "-"')) {
          return 'macOS signing configured';
        }
      } catch (_) {}
    }
    return null;
  }
}
