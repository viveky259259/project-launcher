import 'dart:convert';
import 'dart:io';

import 'package:launcher_native/launcher_native.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CliInstallResult {
  final bool success;
  final String message;
  final String? error;

  const CliInstallResult({
    required this.success,
    required this.message,
    this.error,
  });
}

class CliInstallService {
  static const _tag = 'CliInstall';
  static const _prefDontAskKey = 'cli_install_dont_ask';
  static const _githubRepo = 'viveky259259/project-launcher';
  static const _brewFormula = 'plauncher';
  static const _brewTap = 'viveky259259/project-launcher';
  static const _binaryName = 'plauncher';

  /// Check if plauncher CLI is installed.
  static Future<bool> isInstalled() async {
    try {
      // Try `which` first
      final result = await Process.run('which', [_binaryName]);
      if (result.exitCode == 0) return true;

      // Fallback: check common install locations directly
      final paths = [
        '/usr/local/bin/$_binaryName',
        '/opt/homebrew/bin/$_binaryName',
      ];
      for (final path in paths) {
        if (await File(path).exists()) return true;
      }
      return false;
    } catch (e) {
      AppLogger.error(_tag, 'Error checking if CLI is installed: $e');
      return false;
    }
  }

  /// Whether we should show the install prompt.
  static Future<bool> shouldPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefDontAskKey) == true) return false;
    final installed = await isInstalled();
    if (installed) return false;
    return true;
  }

  /// Persist user's "don't ask again" choice.
  static Future<void> setDontAskAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDontAskKey, true);
    AppLogger.info(_tag, 'User chose "don\'t ask again" for CLI install');
  }

  /// Check if Homebrew is available.
  static Future<bool> isBrewAvailable() async {
    try {
      final result = await Process.run('which', ['brew']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Install plauncher CLI with brew-first, download-fallback strategy.
  static Future<CliInstallResult> install({
    void Function(String status)? onProgress,
  }) async {
    try {
      // Strategy 1: Homebrew
      onProgress?.call('Checking for Homebrew...');
      if (await isBrewAvailable()) {
        onProgress?.call('Installing via Homebrew...');
        AppLogger.info(_tag, 'Attempting brew install');

        // Tap first
        await Process.run('brew', ['tap', _brewTap]);

        // Install
        final brewResult = await Process.run(
          'brew',
          ['install', _brewFormula],
          environment: {'HOMEBREW_NO_AUTO_UPDATE': '1'},
        );

        if (brewResult.exitCode == 0) {
          AppLogger.info(_tag, 'Installed via Homebrew');
          return const CliInstallResult(
            success: true,
            message: 'plauncher installed via Homebrew',
          );
        }

        AppLogger.warn(
          _tag,
          'Brew install failed (exit ${brewResult.exitCode}), trying direct download',
        );
      }

      // Strategy 2: Direct download from GitHub releases
      onProgress?.call('Downloading from GitHub...');
      AppLogger.info(_tag, 'Attempting direct download');

      // Detect architecture
      final archResult = await Process.run('uname', ['-m']);
      final arch = archResult.stdout.toString().trim(); // arm64 or x86_64

      // Get latest release tag
      onProgress?.call('Finding latest release...');
      final apiResult = await Process.run('curl', [
        '-fsSL',
        'https://api.github.com/repos/$_githubRepo/releases/latest',
      ]);

      if (apiResult.exitCode != 0) {
        return CliInstallResult(
          success: false,
          message: 'Failed to fetch release info',
          error: apiResult.stderr.toString(),
        );
      }

      final releaseJson = jsonDecode(apiResult.stdout.toString()) as Map<String, dynamic>;
      final tag = releaseJson['tag_name'] as String;
      final assets = releaseJson['assets'] as List<dynamic>;

      // Find matching asset
      final archLabel = arch == 'x86_64' ? 'x86_64' : 'arm64';
      final assetPattern = RegExp('plauncher.*macos.*$archLabel.*\\.tar\\.gz');
      final asset = assets.cast<Map<String, dynamic>>().where(
        (a) => assetPattern.hasMatch(a['name'] as String),
      );

      if (asset.isEmpty) {
        return CliInstallResult(
          success: false,
          message: 'No CLI binary found for macOS $archLabel in release $tag',
        );
      }

      final downloadUrl = asset.first['browser_download_url'] as String;

      // Download
      onProgress?.call('Downloading plauncher $tag...');
      final tmpDir = '/tmp/plauncher_install';
      await Directory(tmpDir).create(recursive: true);

      final dlResult = await Process.run('curl', [
        '-fSL',
        '-o', '$tmpDir/plauncher.tar.gz',
        downloadUrl,
      ]);

      if (dlResult.exitCode != 0) {
        return CliInstallResult(
          success: false,
          message: 'Download failed',
          error: dlResult.stderr.toString(),
        );
      }

      // Extract
      onProgress?.call('Extracting...');
      await Process.run('tar', ['-xzf', '$tmpDir/plauncher.tar.gz', '-C', tmpDir]);

      // Install to /usr/local/bin
      onProgress?.call('Installing to /usr/local/bin...');
      final cpResult = await Process.run(
        'cp',
        ['$tmpDir/$_binaryName', '/usr/local/bin/$_binaryName'],
      );

      if (cpResult.exitCode != 0) {
        // Needs elevated privileges — use osascript for native admin prompt
        onProgress?.call('Requesting admin permission...');
        final sudoResult = await Process.run('osascript', [
          '-e',
          'do shell script "cp $tmpDir/$_binaryName /usr/local/bin/$_binaryName && chmod +x /usr/local/bin/$_binaryName" with administrator privileges',
        ]);

        if (sudoResult.exitCode != 0) {
          return CliInstallResult(
            success: false,
            message: 'Installation failed — permission denied',
            error: sudoResult.stderr.toString(),
          );
        }
      } else {
        // Ensure executable
        await Process.run('chmod', ['+x', '/usr/local/bin/$_binaryName']);
      }

      // Cleanup
      await Process.run('rm', ['-rf', tmpDir]);

      // Verify
      final verified = await isInstalled();
      if (verified) {
        AppLogger.info(_tag, 'Installed via direct download ($tag, $archLabel)');
        return CliInstallResult(
          success: true,
          message: 'plauncher $tag installed successfully',
        );
      }

      return const CliInstallResult(
        success: false,
        message: 'Installation completed but plauncher not found in PATH',
      );
    } catch (e) {
      AppLogger.error(_tag, 'Install failed: $e');
      return CliInstallResult(
        success: false,
        message: 'Installation failed',
        error: e.toString(),
      );
    }
  }
}
