import 'dart:convert';
import 'dart:io';

import 'package:launcher_native/launcher_native.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CliInstallResult {
  final bool success;
  final String message;
  final String? error;
  final bool needsPathSetup;

  const CliInstallResult({
    required this.success,
    required this.message,
    this.error,
    this.needsPathSetup = false,
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
      final home = Platform.environment['HOME'] ?? '';
      final paths = [
        '/usr/local/bin/$_binaryName',
        '/opt/homebrew/bin/$_binaryName',
        '$home/.local/bin/$_binaryName',
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

  /// Check if ~/.local/bin is in the user's PATH.
  static bool isLocalBinInPath() {
    final path = Platform.environment['PATH'] ?? '';
    final home = Platform.environment['HOME'] ?? '';
    return path.contains('$home/.local/bin') || path.contains('\$HOME/.local/bin');
  }

  /// Detect the user's shell profile file.
  static String _shellProfile() {
    final home = Platform.environment['HOME'] ?? '';
    final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
    if (shell.contains('zsh')) return '$home/.zshrc';
    if (shell.contains('bash')) {
      // Prefer .bash_profile on macOS, .bashrc on Linux
      final bashProfile = File('$home/.bash_profile');
      if (bashProfile.existsSync()) return bashProfile.path;
      return '$home/.bashrc';
    }
    return '$home/.profile';
  }

  /// Add ~/.local/bin to the user's shell PATH automatically.
  static Future<CliInstallResult> addToPath() async {
    try {
      final profilePath = _shellProfile();
      final exportLine = '\nexport PATH="\$HOME/.local/bin:\$PATH"\n';

      // Check if already present
      final file = File(profilePath);
      if (file.existsSync()) {
        final content = await file.readAsString();
        if (content.contains('.local/bin')) {
          return const CliInstallResult(
            success: true,
            message: 'PATH already configured',
          );
        }
      }

      await file.writeAsString(exportLine, mode: FileMode.append);
      AppLogger.info(_tag, 'Added ~/.local/bin to PATH in $profilePath');
      return CliInstallResult(
        success: true,
        message: 'Added to PATH in ${profilePath.split('/').last}',
      );
    } catch (e) {
      AppLogger.error(_tag, 'Failed to add to PATH: $e');
      return CliInstallResult(
        success: false,
        message: 'Failed to update shell profile',
        error: e.toString(),
      );
    }
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

      // Find the latest release that has a CLI binary asset
      onProgress?.call('Finding latest CLI release...');
      final apiResult = await Process.run('curl', [
        '-fsSL',
        'https://api.github.com/repos/$_githubRepo/releases',
      ]);

      if (apiResult.exitCode != 0) {
        return CliInstallResult(
          success: false,
          message: 'Failed to fetch release info',
          error: apiResult.stderr.toString(),
        );
      }

      final releases = jsonDecode(apiResult.stdout.toString()) as List<dynamic>;
      final archLabel = arch == 'x86_64' ? 'x86_64' : 'arm64';
      final assetPattern = RegExp('plauncher.*macos.*$archLabel.*\\.tar\\.gz');

      String? downloadUrl;
      String? tag;
      for (final release in releases) {
        final releaseMap = release as Map<String, dynamic>;
        final assets = releaseMap['assets'] as List<dynamic>;
        final match = assets.cast<Map<String, dynamic>>().where(
          (a) => assetPattern.hasMatch(a['name'] as String),
        );
        if (match.isNotEmpty) {
          downloadUrl = match.first['browser_download_url'] as String;
          tag = releaseMap['tag_name'] as String;
          break;
        }
      }

      if (downloadUrl == null) {
        return const CliInstallResult(
          success: false,
          message: 'No CLI binary found in any release',
        );
      }

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

      // Install to ~/.local/bin (no admin permission needed)
      final home = Platform.environment['HOME'] ?? '/tmp';
      final installDir = '$home/.local/bin';
      await Directory(installDir).create(recursive: true);

      onProgress?.call('Installing to ~/.local/bin...');
      final cpResult = await Process.run(
        'cp',
        ['$tmpDir/$_binaryName', '$installDir/$_binaryName'],
      );

      if (cpResult.exitCode != 0) {
        return CliInstallResult(
          success: false,
          message: 'Failed to copy binary to $installDir',
          error: cpResult.stderr.toString(),
        );
      }

      await Process.run('chmod', ['+x', '$installDir/$_binaryName']);

      // Cleanup
      await Process.run('rm', ['-rf', tmpDir]);

      // Verify — binary exists even if not yet in PATH
      final binaryExists = await File('$installDir/$_binaryName').exists();
      if (binaryExists) {
        final pathOk = isLocalBinInPath();
        AppLogger.info(_tag, 'Installed via direct download ($tag, $archLabel), PATH ok: $pathOk');
        return CliInstallResult(
          success: true,
          message: 'plauncher $tag installed successfully',
          needsPathSetup: !pathOk,
        );
      }

      return const CliInstallResult(
        success: false,
        message: 'Installation completed but binary not found',
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
