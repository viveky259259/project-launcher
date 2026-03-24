import 'dart:io';
import 'package:launcher_native/launcher_native.dart';
import 'git_service.dart';
import 'project_type_detector.dart';
import 'package:launcher_models/launcher_models.dart';

/// Detects version, release tags, and deployment targets for any project type.
class VersionDetector {
  static const _tag = 'Version';

  /// Detect version and release info for a project.
  static Future<ReleaseInfo> detect(String projectPath) async {
    final stack = ProjectStack.detect(projectPath);
    final primary = stack.primary;

    String? version;
    String? versionSource;

    // Try type-specific detection first
    final result = await _detectForType(projectPath, primary);
    version = result.$1;
    versionSource = result.$2;

    // Fallback: VERSION file
    if (version == null) {
      for (final f in ['VERSION', 'version.txt', 'version']) {
        final file = File('$projectPath/$f');
        if (await file.exists()) {
          final content = (await file.readAsString()).trim();
          if (_isValidVersion(content)) {
            version = content;
            versionSource = f;
            break;
          }
        }
      }
    }

    // Git tag info
    final lastTag = await _getLastTag(projectPath);
    final unreleasedCommits = lastTag != null
        ? await _getCommitsSinceTag(projectPath, lastTag)
        : 0;

    // Fallback version from tag
    if (version == null && lastTag != null) {
      version = lastTag.replaceFirst(RegExp(r'^v'), '');
      versionSource = 'git tag';
    }

    // Detect deploy targets
    final deployTargets = await _detectDeployTargets(projectPath, primary);
    final isDeployable = deployTargets.isNotEmpty ||
        _isAppType(primary) ||
        File('$projectPath/Dockerfile').existsSync();

    if (version != null) {
      AppLogger.debug(_tag, '${projectPath.split('/').last}: v$version (from $versionSource)');
    }

    return ReleaseInfo(
      version: version,
      lastTag: lastTag,
      unreleasedCommits: unreleasedCommits,
      versionSource: versionSource,
      isDeployable: isDeployable,
      deployTargets: deployTargets,
    );
  }

  static Future<(String?, String?)> _detectForType(String path, ProjectType type) async {
    switch (type) {
      case ProjectType.flutter:
      case ProjectType.dart:
        return _parseYamlVersion('$path/pubspec.yaml', 'pubspec.yaml');
      case ProjectType.nodejs:
      case ProjectType.typescript:
      case ProjectType.react:
        return _parseJsonVersion('$path/package.json', 'package.json');
      case ProjectType.rust:
        return _parseTomlVersion('$path/Cargo.toml', 'Cargo.toml');
      case ProjectType.python:
        return await _detectPythonVersion(path);
      case ProjectType.swift:
      case ProjectType.ios:
        return _parsePlistVersion(path);
      case ProjectType.kotlin:
      case ProjectType.java:
        return _parseGradleVersion(path);
      case ProjectType.ruby:
        return _parseGemVersion(path);
      case ProjectType.go:
        return (null, null); // Go uses git tags
      default:
        return (null, null);
    }
  }

  static (String?, String?) _parseYamlVersion(String filePath, String source) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return (null, null);
      final content = file.readAsStringSync();
      final match = RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(content);
      if (match != null) {
        return (match.group(1)!.trim(), source);
      }
    } catch (_) {}
    return (null, null);
  }

  static (String?, String?) _parseJsonVersion(String filePath, String source) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return (null, null);
      final content = file.readAsStringSync();
      final match = RegExp(r'"version"\s*:\s*"([^"]+)"').firstMatch(content);
      if (match != null) {
        return (match.group(1), source);
      }
    } catch (_) {}
    return (null, null);
  }

  static (String?, String?) _parseTomlVersion(String filePath, String source) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return (null, null);
      final content = file.readAsStringSync();
      // Match version under [package]
      final match = RegExp(r'version\s*=\s*"([^"]+)"').firstMatch(content);
      if (match != null) {
        return (match.group(1), source);
      }
    } catch (_) {}
    return (null, null);
  }

  static Future<(String?, String?)> _detectPythonVersion(String path) async {
    // Try pyproject.toml
    final pyproject = _parseTomlVersion('$path/pyproject.toml', 'pyproject.toml');
    if (pyproject.$1 != null) return pyproject;

    // Try setup.cfg
    try {
      final file = File('$path/setup.cfg');
      if (await file.exists()) {
        final content = await file.readAsString();
        final match = RegExp(r'version\s*=\s*(.+)$', multiLine: true).firstMatch(content);
        if (match != null) return (match.group(1)!.trim(), 'setup.cfg');
      }
    } catch (_) {}

    // Try setup.py
    try {
      final file = File('$path/setup.py');
      if (await file.exists()) {
        final content = await file.readAsString();
        final match = RegExp(r'''version\s*=\s*['"]([^'"]+)['"]''').firstMatch(content);
        if (match != null) return (match.group(1), 'setup.py');
      }
    } catch (_) {}

    return (null, null);
  }

  static (String?, String?) _parsePlistVersion(String path) {
    // Check Info.plist in common locations
    for (final plistPath in [
      '$path/ios/Runner/Info.plist',
      '$path/macos/Runner/Info.plist',
      '$path/Info.plist',
    ]) {
      try {
        final file = File(plistPath);
        if (!file.existsSync()) continue;
        final content = file.readAsStringSync();
        final match = RegExp(
          r'<key>CFBundleShortVersionString</key>\s*<string>([^<]+)</string>',
        ).firstMatch(content);
        if (match != null) {
          return (match.group(1), 'Info.plist');
        }
      } catch (_) {}
    }
    return (null, null);
  }

  static (String?, String?) _parseGradleVersion(String path) {
    for (final gradlePath in [
      '$path/app/build.gradle',
      '$path/app/build.gradle.kts',
      '$path/android/app/build.gradle',
      '$path/android/app/build.gradle.kts',
      '$path/build.gradle',
      '$path/build.gradle.kts',
    ]) {
      try {
        final file = File(gradlePath);
        if (!file.existsSync()) continue;
        final content = file.readAsStringSync();
        final match = RegExp(r'versionName\s*[="]?\s*"?([^"\s]+)"?').firstMatch(content);
        if (match != null) {
          return (match.group(1), 'build.gradle');
        }
      } catch (_) {}
    }
    return (null, null);
  }

  static (String?, String?) _parseGemVersion(String path) {
    try {
      // Try .gemspec files
      final dir = Directory(path);
      final gemspecs = dir.listSync().where((f) => f.path.endsWith('.gemspec'));
      for (final gemspec in gemspecs) {
        final content = File(gemspec.path).readAsStringSync();
        final match = RegExp(r'''version\s*=\s*['"]([^'"]+)['"]''').firstMatch(content);
        if (match != null) {
          return (match.group(1), gemspec.path.split('/').last);
        }
      }
    } catch (_) {}
    return (null, null);
  }

  static Future<String?> _getLastTag(String projectPath) async {
    try {
      final result = await Process.run(
        'git', ['describe', '--tags', '--abbrev=0'],
        workingDirectory: projectPath,
      );
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return null;
  }

  static Future<int> _getCommitsSinceTag(String projectPath, String tag) async {
    try {
      final result = await Process.run(
        'git', ['rev-list', '--count', '$tag..HEAD'],
        workingDirectory: projectPath,
      );
      if (result.exitCode == 0) {
        return int.tryParse(result.stdout.toString().trim()) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  static Future<List<String>> _detectDeployTargets(String path, ProjectType type) async {
    final targets = <String>[];

    // Flutter platform targets
    if (type == ProjectType.flutter) {
      for (final p in ['ios', 'android', 'web', 'macos', 'linux', 'windows']) {
        if (Directory('$path/$p').existsSync()) targets.add(p);
      }
    }

    // Docker
    if (File('$path/Dockerfile').existsSync()) targets.add('Docker');
    if (File('$path/docker-compose.yml').existsSync() ||
        File('$path/docker-compose.yaml').existsSync()) {
      if (!targets.contains('Docker')) targets.add('Docker');
    }

    // npm publish
    if (type == ProjectType.nodejs || type == ProjectType.typescript) {
      final pkgJson = File('$path/package.json');
      if (pkgJson.existsSync()) {
        final content = pkgJson.readAsStringSync();
        if (!content.contains('"private": true') && !content.contains('"private":true')) {
          targets.add('npm');
        }
      }
    }

    // Rust crates.io
    if (type == ProjectType.rust) {
      final cargoToml = File('$path/Cargo.toml');
      if (cargoToml.existsSync()) {
        final content = cargoToml.readAsStringSync();
        if (!content.contains('publish = false')) targets.add('crates.io');
      }
    }

    // Python PyPI
    if (type == ProjectType.python) {
      if (File('$path/setup.py').existsSync() ||
          File('$path/pyproject.toml').existsSync()) {
        targets.add('PyPI');
      }
    }

    // Ruby gems
    if (type == ProjectType.ruby) {
      final gemspecs = Directory(path).listSync().where((f) => f.path.endsWith('.gemspec'));
      if (gemspecs.isNotEmpty) targets.add('RubyGems');
    }

    return targets;
  }

  static bool _isAppType(ProjectType type) {
    return {
      ProjectType.flutter,
      ProjectType.ios,
      ProjectType.swift,
      ProjectType.kotlin,
      ProjectType.react,
    }.contains(type);
  }

  static bool _isValidVersion(String v) {
    return RegExp(r'^\d+\.\d+').hasMatch(v.trim());
  }

  /// Bump version string. Supports semver (x.y.z) and Flutter (x.y.z+N).
  static String bumpVersion(String version, String level) {
    // Handle Flutter version+build format
    final parts = version.split('+');
    final semver = parts[0];
    final buildNum = parts.length > 1 ? int.tryParse(parts[1]) : null;

    final segments = semver.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (segments.length < 3) segments.add(0);

    switch (level) {
      case 'major':
        segments[0]++;
        segments[1] = 0;
        segments[2] = 0;
      case 'minor':
        segments[1]++;
        segments[2] = 0;
      case 'patch':
      default:
        segments[2]++;
    }

    var result = segments.take(3).join('.');
    if (buildNum != null) {
      result += '+${buildNum + 1}';
    }
    return result;
  }
}
