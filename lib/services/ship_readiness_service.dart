import 'dart:convert';
import 'dart:io';
import 'package:launcher_native/launcher_native.dart';
import 'git_service.dart';
import 'version_detector.dart';
import 'release_service.dart';
import 'platform_helper.dart';
import 'project_type_detector.dart';
import 'package:launcher_models/launcher_models.dart';

/// Comprehensive ship readiness evaluation: auto-detect, manual, AI-assisted.
class ShipReadinessService {
  static const _tag = 'Ship';
  static const _dirName = 'ship_checklists';

  // --- Checklist Definition ---

  /// Build the full checklist template for a project. Items are created with
  /// [CheckStatus.pending]; callers run [evaluate] to fill in auto-detected statuses.
  static List<ShipCategory> _buildTemplate(String projectPath) {
    final stack = ProjectStack.detect(projectPath);
    final isFlutter = stack.primary == ProjectType.flutter;
    final isNode = stack.primary == ProjectType.nodejs || stack.primary == ProjectType.typescript || stack.primary == ProjectType.react;
    final isRust = stack.primary == ProjectType.rust;
    final isMobile = isFlutter && (Directory('$projectPath/ios').existsSync() || Directory('$projectPath/android').existsSync());
    final isMacOS = isFlutter && Directory('$projectPath/macos').existsSync();
    final isWeb = isFlutter && Directory('$projectPath/web').existsSync() || isNode;
    final hasDocker = File('$projectPath/Dockerfile').existsSync();

    return [
      // --- BUILD & SIGNING ---
      ShipCategory(id: 'build', title: 'Build & Signing', icon: 'build', items: [
        ShipCheckItem(id: 'version_bumped', category: 'build', title: 'Version bumped', description: 'Version is set and valid semver', mode: CheckMode.auto, weight: 15),
        ShipCheckItem(id: 'changelog_updated', category: 'build', title: 'Changelog updated', description: 'CHANGELOG.md exists and has recent entry', mode: CheckMode.auto, weight: 10),
        ShipCheckItem(id: 'release_build', category: 'build', title: 'Release build passes', description: 'Builds without errors in release mode', mode: CheckMode.manual, weight: 15),
        ShipCheckItem(id: 'code_signed', category: 'build', title: 'Code signed', description: 'App is signed with distribution certificate', mode: CheckMode.auto, weight: 15),
        if (isFlutter || isRust)
          ShipCheckItem(id: 'native_libs', category: 'build', title: 'Native libraries bundled', description: 'FFI/native libs included in build', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'no_debug_flags', category: 'build', title: 'No debug flags', description: 'No debug/dev-only code in release', mode: CheckMode.ai, weight: 10),
      ]),

      // --- QUALITY GATE ---
      ShipCategory(id: 'quality', title: 'Quality Gate', icon: 'verified', items: [
        ShipCheckItem(id: 'tests_exist', category: 'quality', title: 'Tests exist', description: 'Test directory with test files', mode: CheckMode.auto, weight: 15),
        ShipCheckItem(id: 'tests_passing', category: 'quality', title: 'All tests passing', description: 'Test suite runs green', mode: CheckMode.manual, weight: 15),
        ShipCheckItem(id: 'git_clean', category: 'quality', title: 'Clean working tree', description: 'No uncommitted changes', mode: CheckMode.auto, weight: 15),
        ShipCheckItem(id: 'all_pushed', category: 'quality', title: 'All commits pushed', description: 'No unpushed commits', mode: CheckMode.auto, weight: 10),
        ShipCheckItem(id: 'release_branch', category: 'quality', title: 'On release branch', description: 'On main, master, or release/* branch', mode: CheckMode.auto, weight: 10),
        ShipCheckItem(id: 'git_tag', category: 'quality', title: 'Git tag created', description: 'Tag matches current version', mode: CheckMode.auto, weight: 10),
        ShipCheckItem(id: 'code_review', category: 'quality', title: 'Code reviewed', description: 'PR reviewed and approved', mode: CheckMode.manual, weight: 10),
      ]),

      // --- COMPLIANCE ---
      ShipCategory(id: 'compliance', title: 'Compliance', icon: 'shield', items: [
        ShipCheckItem(id: 'license', category: 'compliance', title: 'LICENSE file', description: 'Valid open-source or proprietary license', mode: CheckMode.auto, weight: 15),
        ShipCheckItem(id: 'no_secrets', category: 'compliance', title: 'No secrets in source', description: 'No API keys, tokens, or credentials committed', mode: CheckMode.auto, weight: 20),
        ShipCheckItem(id: 'sbom', category: 'compliance', title: 'SBOM available', description: 'Software Bill of Materials from lock files', mode: CheckMode.auto, weight: 10),
        ShipCheckItem(id: 'dep_licenses', category: 'compliance', title: 'Dependency licenses compatible', description: 'No GPL in proprietary, no conflicting licenses', mode: CheckMode.ai, weight: 15),
        ShipCheckItem(id: 'privacy_policy', category: 'compliance', title: 'Privacy policy', description: 'Privacy policy URL configured (if collecting data)', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'gdpr_ccpa', category: 'compliance', title: 'GDPR/CCPA compliance', description: 'Data collection disclosed, consent mechanisms', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'security_review', category: 'compliance', title: 'Security review', description: 'AI-powered security audit passed', mode: CheckMode.ai, weight: 15),
      ]),

      // --- PLATFORM ---
      ShipCategory(id: 'platform', title: 'Platform Delivery', icon: 'devices', items: [
        if (isMacOS) ...[
          ShipCheckItem(id: 'macos_dmg', category: 'platform', title: 'macOS DMG built', mode: CheckMode.manual, weight: 15),
          ShipCheckItem(id: 'macos_notarized', category: 'platform', title: 'macOS notarized', description: 'Apple notarization + stapling', mode: CheckMode.manual, weight: 15),
        ],
        if (isMobile) ...[
          ShipCheckItem(id: 'ios_archive', category: 'platform', title: 'iOS archive uploaded', description: 'Uploaded to App Store Connect', mode: CheckMode.manual, weight: 15),
          ShipCheckItem(id: 'ios_screenshots', category: 'platform', title: 'iOS screenshots ready', mode: CheckMode.manual, weight: 10),
          ShipCheckItem(id: 'android_aab', category: 'platform', title: 'Android AAB signed', description: 'Signed bundle for Play Console', mode: CheckMode.manual, weight: 15),
          ShipCheckItem(id: 'android_listing', category: 'platform', title: 'Play Store listing', mode: CheckMode.manual, weight: 10),
        ],
        if (isWeb)
          ShipCheckItem(id: 'web_deployed', category: 'platform', title: 'Web deployed', description: 'Build deployed with SSL', mode: CheckMode.manual, weight: 15),
        if (hasDocker)
          ShipCheckItem(id: 'docker_pushed', category: 'platform', title: 'Docker image pushed', description: 'Image pushed to registry', mode: CheckMode.manual, weight: 15),
        if (isNode)
          ShipCheckItem(id: 'npm_published', category: 'platform', title: 'npm published', mode: CheckMode.manual, weight: 15),
        if (isRust)
          ShipCheckItem(id: 'crate_published', category: 'platform', title: 'Crate published', mode: CheckMode.manual, weight: 15),
      ]),

      // --- DISTRIBUTION ---
      ShipCategory(id: 'distribution', title: 'Distribution', icon: 'share', items: [
        ShipCheckItem(id: 'github_release', category: 'distribution', title: 'GitHub Release created', description: 'Release with assets attached', mode: CheckMode.auto, weight: 15),
        ShipCheckItem(id: 'homebrew', category: 'distribution', title: 'Homebrew formula updated', description: 'Cask/formula with new version + SHA', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'download_page', category: 'distribution', title: 'Website download page', description: 'Download page updated with new version', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'auto_update', category: 'distribution', title: 'Auto-update mechanism', description: 'Sparkle/winget/apt configured', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'release_notes', category: 'distribution', title: 'Release notes published', description: 'User-facing changelog/blog post', mode: CheckMode.manual, weight: 10),
      ]),

      // --- MARKETING ---
      ShipCategory(id: 'marketing', title: 'Marketing', icon: 'campaign', items: [
        ShipCheckItem(id: 'landing_page', category: 'marketing', title: 'Landing page live', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'product_hunt', category: 'marketing', title: 'Product Hunt prepared', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'blog_post', category: 'marketing', title: 'Blog post / article', description: 'dev.to, Hashnode, or personal blog', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'demo_video', category: 'marketing', title: 'Demo video / GIF', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'readme_screenshots', category: 'marketing', title: 'README with screenshots', description: 'Clear value prop + visuals', mode: CheckMode.auto, weight: 10),
        ShipCheckItem(id: 'social_posts', category: 'marketing', title: 'Social media posts', description: 'Twitter/X, LinkedIn, Reddit drafted', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'community_notify', category: 'marketing', title: 'Communities notified', description: 'Discord, Slack, forums', mode: CheckMode.manual, weight: 5),
      ]),

      // --- OPERATIONS ---
      ShipCategory(id: 'operations', title: 'Operations & Monitoring', icon: 'monitoring', items: [
        ShipCheckItem(id: 'crash_reporting', category: 'operations', title: 'Crash reporting set up', description: 'Sentry, Crashlytics, or equivalent', mode: CheckMode.manual, weight: 15),
        ShipCheckItem(id: 'analytics', category: 'operations', title: 'Analytics configured', description: 'Download counts, DAU, feature usage', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'error_monitoring', category: 'operations', title: 'Error monitoring', description: 'Alerts for production errors', mode: CheckMode.manual, weight: 10),
        ShipCheckItem(id: 'feedback_channel', category: 'operations', title: 'Feedback channel', description: 'GitHub Issues, email, in-app feedback', mode: CheckMode.auto, weight: 10),
        ShipCheckItem(id: 'rollback_plan', category: 'operations', title: 'Rollback plan', description: 'Know how to revert if something breaks', mode: CheckMode.manual, weight: 15),
        ShipCheckItem(id: 'on_call', category: 'operations', title: 'On-call / response plan', description: 'Who responds to incidents and how', mode: CheckMode.manual, weight: 10),
      ]),
    ];
  }

  // --- Auto-Detection Engine ---

  /// Evaluate all auto-detectable items in the checklist.
  static Future<ShipReadiness> evaluate(String projectPath) async {
    AppLogger.info(_tag, 'Evaluating ship readiness for ${projectPath.split('/').last}');
    final categories = _buildTemplate(projectPath);

    // Load saved manual states
    final saved = await _loadManualStates(projectPath);
    for (final cat in categories) {
      for (final item in cat.items) {
        final savedItem = saved.firstWhere((s) => s['id'] == item.id, orElse: () => {});
        if (savedItem.isNotEmpty) item.applyManual(savedItem);
      }
    }

    // Run auto-detection
    for (final cat in categories) {
      for (final item in cat.items) {
        if (item.mode == CheckMode.auto) {
          await _autoDetect(item, projectPath);
        }
      }
    }

    final readiness = ShipReadiness(categories: categories, checkedAt: DateTime.now());
    AppLogger.info(_tag, '${projectPath.split('/').last}: ship readiness ${readiness.overallScore}/100 (${readiness.totalPass}/${readiness.totalItems} passed)');
    return readiness;
  }

  static Future<void> _autoDetect(ShipCheckItem item, String path) async {
    try {
      switch (item.id) {
        // BUILD
        case 'version_bumped':
          final info = await VersionDetector.detect(path);
          item.status = info.version != null ? CheckStatus.pass : CheckStatus.fail;
          item.detail = info.version != null ? 'v${info.version} (${info.versionSource})' : 'No version detected';

        case 'changelog_updated':
          final exists = File('$path/CHANGELOG.md').existsSync() || File('$path/CHANGES.md').existsSync();
          item.status = exists ? CheckStatus.pass : CheckStatus.fail;
          item.detail = exists ? 'Changelog found' : 'No CHANGELOG.md';

        case 'code_signed':
          final deploy = ReleaseService.detectDeploymentConfig(path);
          item.status = deploy.hasCodeSigning ? CheckStatus.pass : CheckStatus.skip;
          item.detail = deploy.signingDetail ?? 'No signing config detected';

        // QUALITY
        case 'tests_exist':
          final hasTests = ['test', 'tests', 'spec', '__tests__'].any((d) => Directory('$path/$d').existsSync());
          item.status = hasTests ? CheckStatus.pass : CheckStatus.fail;

        case 'git_clean':
          final dirty = await GitService.hasUncommittedChanges(path);
          item.status = !dirty ? CheckStatus.pass : CheckStatus.fail;
          item.detail = dirty ? 'Has uncommitted changes' : 'Clean';

        case 'all_pushed':
          final unpushed = await GitService.getUnpushedCommitCount(path);
          item.status = unpushed == 0 ? CheckStatus.pass : CheckStatus.fail;
          item.detail = unpushed > 0 ? '$unpushed unpushed commit(s)' : 'All pushed';

        case 'release_branch':
          final branch = await GitService.getCurrentBranch(path);
          final isRelease = branch == 'main' || branch == 'master' || (branch?.startsWith('release') ?? false);
          item.status = isRelease ? CheckStatus.pass : CheckStatus.warn;
          item.detail = branch ?? 'Unknown';

        case 'git_tag':
          final info = await VersionDetector.detect(path);
          final lastTag = await GitService.getLastTag(path);
          if (lastTag != null && info.version != null) {
            final tagVersion = lastTag.replaceFirst(RegExp(r'^v'), '');
            final matches = tagVersion == info.version || tagVersion == info.version!.split('+').first;
            item.status = matches ? CheckStatus.pass : CheckStatus.warn;
            item.detail = matches ? 'Tag $lastTag matches version' : 'Tag $lastTag != v${info.version}';
          } else {
            item.status = CheckStatus.fail;
            item.detail = lastTag == null ? 'No tags' : 'No version to compare';
          }

        // COMPLIANCE
        case 'license':
          final hasLicense = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'LICENCE'].any((f) => File('$path/$f').existsSync());
          item.status = hasLicense ? CheckStatus.pass : CheckStatus.fail;

        case 'no_secrets':
          // Quick check — full scan is in compliance service
          final envTracked = await _isFileTracked(path, '.env');
          item.status = !envTracked ? CheckStatus.pass : CheckStatus.fail;
          item.detail = envTracked ? '.env file is tracked in git!' : 'No obvious secrets';

        case 'sbom':
          final hasLock = ['pubspec.lock', 'package-lock.json', 'yarn.lock', 'Cargo.lock', 'Gemfile.lock', 'poetry.lock', 'go.sum']
              .any((f) => File('$path/$f').existsSync());
          item.status = hasLock ? CheckStatus.pass : CheckStatus.warn;
          item.detail = hasLock ? 'Lock file found' : 'No lock file for SBOM';

        // DISTRIBUTION
        case 'github_release':
          final remote = await GitService.getRemoteUrl(path);
          final isGithub = remote != null && remote.contains('github.com');
          if (!isGithub) {
            item.status = CheckStatus.skip;
            item.detail = 'Not a GitHub repo';
          } else {
            final lastTag = await GitService.getLastTag(path);
            item.status = lastTag != null ? CheckStatus.warn : CheckStatus.fail;
            item.detail = lastTag != null ? 'Tag exists, verify release created' : 'No tags — create release first';
          }

        // MARKETING
        case 'readme_screenshots':
          final readme = File('$path/README.md');
          if (readme.existsSync()) {
            final content = readme.readAsStringSync();
            final hasImages = content.contains('![') || content.contains('<img');
            item.status = hasImages ? CheckStatus.pass : CheckStatus.warn;
            item.detail = hasImages ? 'README has images' : 'README exists but no screenshots';
          } else {
            item.status = CheckStatus.fail;
            item.detail = 'No README.md';
          }

        // OPERATIONS
        case 'feedback_channel':
          final hasGhDir = Directory('$path/.github').existsSync();
          final hasIssueTemplate = File('$path/.github/ISSUE_TEMPLATE').existsSync() || Directory('$path/.github/ISSUE_TEMPLATE').existsSync();
          if (hasIssueTemplate) {
            item.status = CheckStatus.pass;
            item.detail = 'GitHub issue templates configured';
          } else if (hasGhDir) {
            item.status = CheckStatus.warn;
            item.detail = '.github exists but no issue templates';
          } else {
            item.status = CheckStatus.fail;
          }
      }
    } catch (e) {
      item.status = CheckStatus.warn;
      item.detail = 'Error: $e';
    }
  }

  static Future<bool> _isFileTracked(String path, String file) async {
    try {
      final result = await Process.run('git', ['ls-files', file], workingDirectory: path);
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // --- Persistence (manual states) ---

  static String get _basePath => '${PlatformHelper.dataDir}${Platform.pathSeparator}$_dirName';

  static String _filePath(String projectPath) {
    final hash = _fnv1a(projectPath).toRadixString(16).padLeft(8, '0');
    final name = projectPath.split('/').last.replaceAll(RegExp(r'[^\w-]'), '_');
    return '$_basePath${Platform.pathSeparator}${name}_$hash.json';
  }

  static int _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Save manual check states for a project.
  static Future<void> saveManualStates(String projectPath, List<ShipCategory> categories) async {
    final dir = Directory(_basePath);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final manualItems = <Map<String, dynamic>>[];
    for (final cat in categories) {
      for (final item in cat.items) {
        if (item.mode == CheckMode.manual || item.mode == CheckMode.ai) {
          manualItems.add(item.toJson());
        }
      }
    }

    final file = File(_filePath(projectPath));
    await file.writeAsString(json.encode({'projectPath': projectPath, 'items': manualItems, 'savedAt': DateTime.now().toIso8601String()}));
  }

  static Future<List<Map<String, dynamic>>> _loadManualStates(String projectPath) async {
    try {
      final file = File(_filePath(projectPath));
      if (!file.existsSync()) return [];
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      return (data['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
