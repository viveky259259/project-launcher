import 'dart:io';
import 'package:flutter/material.dart';

enum ProjectType {
  flutter('Flutter', Icons.flutter_dash, Color(0xFF54C5F8)),
  dart('Dart', Icons.code, Color(0xFF00B4AB)),
  python('Python', Icons.data_object, Color(0xFFFFD43B)),
  nodejs('Node.js', Icons.hexagon_outlined, Color(0xFF68A063)),
  typescript('TypeScript', Icons.javascript, Color(0xFF3178C6)),
  react('React', Icons.blur_circular, Color(0xFF61DAFB)),
  rust('Rust', Icons.settings_suggest, Color(0xFFDEA584)),
  go('Go', Icons.directions_run, Color(0xFF00ADD8)),
  kotlin('Kotlin', Icons.android, Color(0xFF7F52FF)),
  java('Java', Icons.coffee, Color(0xFFED8B00)),
  swift('Swift', Icons.apple, Color(0xFFFA7343)),
  ios('iOS', Icons.phone_iphone, Color(0xFFFA7343)),
  ruby('Ruby', Icons.diamond, Color(0xFFCC342D)),
  php('PHP', Icons.php, Color(0xFF777BB4)),
  csharp('C#', Icons.window, Color(0xFF68217A)),
  cpp('C++', Icons.memory, Color(0xFF00599C)),
  unknown('Other', Icons.folder, Color(0xFF6B7280));

  final String label;
  final IconData icon;
  final Color color;

  const ProjectType(this.label, this.icon, this.color);
}

/// Represents a project's full technology stack
class ProjectStack {
  final ProjectType primary;
  final List<ProjectType> secondary;

  const ProjectStack({required this.primary, this.secondary = const []});

  /// All types (primary + secondary)
  List<ProjectType> get all => [primary, ...secondary];

  /// Whether this stack contains a given type
  bool contains(ProjectType type) => primary == type || secondary.contains(type);

  /// Whether this has multiple technologies
  bool get isMultiTech => secondary.isNotEmpty;

  /// Detect full technology stack from a project directory
  static ProjectStack detect(String path) {
    final primary = _detectPrimary(path);
    final secondary = _detectSecondary(path, primary);
    return ProjectStack(primary: primary, secondary: secondary);
  }

  // ---------------------------------------------------------------------------
  // Primary detection (root-level marker files)
  // ---------------------------------------------------------------------------

  static ProjectType _detectPrimary(String path) {
    if (_exists(path, 'pubspec.yaml')) {
      try {
        final content = File('$path/pubspec.yaml').readAsStringSync();
        if (content.contains('flutter:') || content.contains('flutter_test:')) {
          return ProjectType.flutter;
        }
      } catch (_) {}
      return ProjectType.dart;
    }

    if (_exists(path, 'Package.swift') || _hasSuffix(path, '.xcodeproj') || _hasSuffix(path, '.xcworkspace')) {
      if (_exists(path, 'Package.swift') || _hasSwiftFiles(path)) {
        return ProjectType.swift;
      }
      return ProjectType.ios;
    }

    if (_exists(path, 'Cargo.toml')) return ProjectType.rust;
    if (_exists(path, 'go.mod')) return ProjectType.go;

    if (_exists(path, 'build.gradle.kts') || _exists(path, 'build.gradle')) {
      if (_hasSubDir(path, 'src/main/kotlin') || _hasKotlinFiles(path)) {
        return ProjectType.kotlin;
      }
      return ProjectType.java;
    }

    if (_exists(path, 'pom.xml')) return ProjectType.java;

    if (_exists(path, 'package.json')) {
      try {
        final content = File('$path/package.json').readAsStringSync();
        if (content.contains('"react"') || content.contains('"react-native"') || content.contains('"next"')) {
          return ProjectType.react;
        }
      } catch (_) {}
      if (_exists(path, 'tsconfig.json')) return ProjectType.typescript;
      return ProjectType.nodejs;
    }

    if (_exists(path, 'tsconfig.json')) return ProjectType.typescript;

    if (_exists(path, 'requirements.txt') ||
        _exists(path, 'setup.py') ||
        _exists(path, 'pyproject.toml') ||
        _exists(path, 'Pipfile')) {
      return ProjectType.python;
    }

    if (_exists(path, 'Gemfile')) return ProjectType.ruby;
    if (_exists(path, 'composer.json')) return ProjectType.php;
    if (_hasSuffix(path, '.csproj') || _hasSuffix(path, '.sln')) return ProjectType.csharp;
    if (_exists(path, 'CMakeLists.txt') || _exists(path, 'Makefile')) {
      if (_hasCppFiles(path)) return ProjectType.cpp;
    }

    return ProjectType.unknown;
  }

  // ---------------------------------------------------------------------------
  // Secondary detection (known subfolder patterns)
  // ---------------------------------------------------------------------------

  /// Known subfolder names to check for secondary technologies
  static const _subfolderChecks = {
    // Rust FFI patterns
    'rust': _checkRust,
    'native': _checkRust,
    'crates': _checkRust,
    // Frontend patterns
    'frontend': _checkFrontend,
    'web': _checkFrontend,
    'client': _checkFrontend,
    'app': _checkFrontend,
    // Backend patterns
    'backend': _checkBackend,
    'server': _checkBackend,
    'api': _checkBackend,
    // Python patterns
    'ml': _checkPython,
    'scripts': _checkPython,
    // Go patterns
    'cmd': _checkGo,
  };

  static List<ProjectType> _detectSecondary(String path, ProjectType primary) {
    final secondary = <ProjectType>{};

    // Check known subfolders
    for (final entry in _subfolderChecks.entries) {
      final subPath = '$path/${entry.key}';
      if (Directory(subPath).existsSync()) {
        final detected = entry.value(subPath);
        if (detected != null && detected != primary) {
          secondary.add(detected);
        }
      }
    }

    // Special: Flutter projects — check for native platform code
    if (primary == ProjectType.flutter || primary == ProjectType.dart) {
      // Rust FFI in rust/ subfolder
      if (_exists('$path/rust', 'Cargo.toml') || _exists('$path/native', 'Cargo.toml')) {
        secondary.add(ProjectType.rust);
      }
      // Swift native code
      if (Directory('$path/ios').existsSync() && _hasSwiftFiles('$path/ios')) {
        // Only add if there's custom Swift beyond generated Flutter code
        if (_hasCustomSwift('$path/ios')) {
          secondary.add(ProjectType.swift);
        }
      }
    }

    // Special: Root-level has both package.json AND another primary
    // (e.g., Flutter project with a web dashboard)
    if (primary != ProjectType.nodejs &&
        primary != ProjectType.react &&
        primary != ProjectType.typescript &&
        _exists(path, 'package.json')) {
      try {
        final content = File('$path/package.json').readAsStringSync();
        if (content.contains('"react"') || content.contains('"next"')) {
          secondary.add(ProjectType.react);
        } else if (content.contains('"typescript"') || _exists(path, 'tsconfig.json')) {
          secondary.add(ProjectType.typescript);
        } else {
          secondary.add(ProjectType.nodejs);
        }
      } catch (_) {
        secondary.add(ProjectType.nodejs);
      }
    }

    // Special: Root-level has both Python markers AND another primary
    if (primary != ProjectType.python &&
        (_exists(path, 'requirements.txt') ||
         _exists(path, 'pyproject.toml') ||
         _exists(path, 'Pipfile'))) {
      secondary.add(ProjectType.python);
    }

    // Special: Root-level Go alongside another primary
    if (primary != ProjectType.go && _exists(path, 'go.mod')) {
      secondary.add(ProjectType.go);
    }

    // Special: Root-level Rust alongside another primary
    if (primary != ProjectType.rust && _exists(path, 'Cargo.toml')) {
      secondary.add(ProjectType.rust);
    }

    // Cap at 3 secondary types
    return secondary.take(3).toList();
  }

  // Subfolder checker functions
  static ProjectType? _checkRust(String subPath) {
    if (_exists(subPath, 'Cargo.toml')) return ProjectType.rust;
    return null;
  }

  static ProjectType? _checkFrontend(String subPath) {
    if (_exists(subPath, 'package.json')) {
      try {
        final content = File('$subPath/package.json').readAsStringSync();
        if (content.contains('"react"') || content.contains('"next"')) {
          return ProjectType.react;
        }
      } catch (_) {}
      if (_exists(subPath, 'tsconfig.json')) return ProjectType.typescript;
      return ProjectType.nodejs;
    }
    return null;
  }

  static ProjectType? _checkBackend(String subPath) {
    if (_exists(subPath, 'go.mod')) return ProjectType.go;
    if (_exists(subPath, 'Cargo.toml')) return ProjectType.rust;
    if (_exists(subPath, 'requirements.txt') ||
        _exists(subPath, 'pyproject.toml') ||
        _exists(subPath, 'Pipfile')) {
      return ProjectType.python;
    }
    if (_exists(subPath, 'package.json')) return ProjectType.nodejs;
    if (_exists(subPath, 'Gemfile')) return ProjectType.ruby;
    if (_exists(subPath, 'composer.json')) return ProjectType.php;
    if (_exists(subPath, 'pom.xml')) return ProjectType.java;
    if (_exists(subPath, 'build.gradle') || _exists(subPath, 'build.gradle.kts')) {
      return ProjectType.kotlin;
    }
    return null;
  }

  static ProjectType? _checkPython(String subPath) {
    if (_exists(subPath, 'requirements.txt') ||
        _exists(subPath, 'pyproject.toml') ||
        _exists(subPath, 'setup.py')) {
      return ProjectType.python;
    }
    return null;
  }

  static ProjectType? _checkGo(String subPath) {
    // cmd/ is a Go convention for CLI entry points
    if (_exists(subPath, 'main.go')) return ProjectType.go;
    return null;
  }

  // ---------------------------------------------------------------------------
  // File system helpers
  // ---------------------------------------------------------------------------

  static bool _exists(String dir, String file) {
    return File('$dir/$file').existsSync();
  }

  static bool _hasSuffix(String dir, String suffix) {
    try {
      return Directory(dir)
          .listSync(followLinks: false)
          .any((e) => e.path.endsWith(suffix));
    } catch (_) {
      return false;
    }
  }

  static bool _hasSubDir(String dir, String subDir) {
    return Directory('$dir/$subDir').existsSync();
  }

  static bool _hasSwiftFiles(String path) {
    try {
      return Directory(path)
          .listSync(followLinks: false)
          .any((e) => e.path.endsWith('.swift'));
    } catch (_) {
      return false;
    }
  }

  static bool _hasCustomSwift(String iosPath) {
    // Check if there are Swift files beyond Runner/AppDelegate.swift
    try {
      final runner = Directory('$iosPath/Runner');
      if (!runner.existsSync()) return false;
      final swiftFiles = runner
          .listSync(followLinks: false)
          .where((e) => e.path.endsWith('.swift'))
          .toList();
      // Flutter generates AppDelegate.swift and GeneratedPluginRegistrant.swift
      // If there are more, the user has custom Swift code
      return swiftFiles.length > 2;
    } catch (_) {
      return false;
    }
  }

  static bool _hasKotlinFiles(String path) {
    try {
      return Directory(path)
          .listSync(followLinks: false)
          .any((e) => e.path.endsWith('.kt') || e.path.endsWith('.kts'));
    } catch (_) {
      return false;
    }
  }

  static bool _hasCppFiles(String path) {
    try {
      return Directory(path)
          .listSync(followLinks: false)
          .any((e) => e.path.endsWith('.cpp') || e.path.endsWith('.cc') || e.path.endsWith('.h'));
    } catch (_) {
      return false;
    }
  }
}
