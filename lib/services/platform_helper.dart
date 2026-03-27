import 'dart:io';

/// Cross-platform helpers for file paths, launching apps, and environment.
class PlatformHelper {
  /// Get the user's home directory (works on macOS, Linux, and Windows)
  static String get homeDir {
    if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'] ??
          Platform.environment['APPDATA'] ??
          '';
    }
    return Platform.environment['HOME'] ?? '';
  }

  /// Get the Project Launcher data directory
  static String get dataDir {
    final home = homeDir;
    if (Platform.isWindows) {
      final appData = Platform.environment['LOCALAPPDATA'] ?? '$home\\AppData\\Local';
      return '$appData\\ProjectLauncher';
    }
    return '$home/.project_launcher';
  }

  /// Get the Desktop directory
  static String get desktopDir {
    final home = homeDir;
    if (Platform.isWindows) {
      return '$home\\Desktop';
    }
    return '$home/Desktop';
  }

  /// Open a folder in the system file manager
  static Future<void> openInFileManager(String path) async {
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else {
      await Process.run('xdg-open', [path]);
    }
  }

  /// Open a URL in the default browser
  static Future<void> openUrl(String url) async {
    if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url]);
    } else {
      await Process.run('xdg-open', [url]);
    }
  }

  /// Open a file with its default application
  static Future<void> openFile(String path) async {
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      await Process.run('xdg-open', [path]);
    }
  }

  /// Open a path in the default terminal
  static Future<void> openInTerminal(String path) async {
    if (Platform.isMacOS) {
      await Process.run('open', ['-a', 'Terminal', path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', 'cmd', '/k', 'cd /d "$path"']);
    } else {
      // Try common Linux terminals
      final terminals = ['gnome-terminal', 'konsole', 'xfce4-terminal', 'xterm'];
      for (final term in terminals) {
        try {
          final result = await Process.run('which', [term]);
          if (result.exitCode == 0) {
            if (term == 'gnome-terminal') {
              await Process.run(term, ['--working-directory=$path']);
            } else {
              await Process.run(term, ['--workdir', path]);
            }
            return;
          }
        } catch (_) {}
      }
      // Fallback
      await Process.run('xdg-open', [path]);
    }
  }

  /// Open a path in VS Code
  static Future<void> openInVSCode(String path) async {
    // First, check if `code` exists anywhere in PATH
    final envPath = Platform.environment['PATH'] ?? '';
    for (final dir in envPath.split(':')) {
      if (dir.isEmpty) continue;
      final codeBin = File('$dir/code');
      if (codeBin.existsSync()) {
        try {
          final result = await Process.run('$dir/code', [path]);
          if (result.exitCode == 0) return;
        } catch (_) {}
        break;
      }
    }

    if (Platform.isMacOS) {
      // Fallback: open via app bundle name
      final appNames = [
        'Visual Studio Code',
        'Visual Studio Code - Insiders',
        'VSCodium',
      ];
      for (final app in appNames) {
        try {
          final result = await Process.run('open', ['-a', app, path]);
          if (result.exitCode == 0) return;
        } catch (_) {}
      }
    } else {
      // Linux / Windows — try bare `code` command
      try {
        final result = await Process.run('code', [path]);
        if (result.exitCode == 0) return;
      } catch (_) {}
    }
  }

  /// Get the short path for display (replaces home dir with ~)
  static String shortenPath(String path) {
    final home = homeDir;
    if (home.isNotEmpty && path.startsWith(home)) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }

  /// Get the parent directory name from a path
  static String parentDirName(String path) {
    final sep = Platform.pathSeparator;
    final lastSep = path.lastIndexOf(sep);
    if (lastSep <= 0) return path;
    final parent = path.substring(0, lastSep);
    final parentLastSep = parent.lastIndexOf(sep);
    return parentLastSep >= 0 ? parent.substring(parentLastSep + 1) : parent;
  }

  /// Get the file/folder name from a full path
  static String basename(String path) {
    final sep = Platform.pathSeparator;
    final lastSep = path.lastIndexOf(sep);
    // Also check for / on Windows (git paths use /)
    final lastSlash = path.lastIndexOf('/');
    final idx = lastSep > lastSlash ? lastSep : lastSlash;
    return idx >= 0 ? path.substring(idx + 1) : path;
  }
}
