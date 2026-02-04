import 'dart:io';

class LauncherService {
  static Future<void> openInTerminal(String path) async {
    // Open Terminal.app at the specified path
    await Process.run('open', ['-a', 'Terminal', path]);
  }

  static Future<void> openInVSCode(String path) async {
    // Try to open with 'code' command first, fallback to VS Code app
    try {
      final result = await Process.run('which', ['code']);
      if (result.exitCode == 0) {
        await Process.run('code', [path]);
      } else {
        await Process.run('open', ['-a', 'Visual Studio Code', path]);
      }
    } catch (e) {
      // Fallback to opening VS Code app directly
      await Process.run('open', ['-a', 'Visual Studio Code', path]);
    }
  }

  static Future<void> openInFinder(String path) async {
    await Process.run('open', [path]);
  }
}
