import 'dart:io';
import 'app_logger.dart';
import 'ai_service.dart';
import '../models/release_info.dart';

/// Enterprise compliance auditing: license detection, secret scanning, SBOM generation.
class ComplianceService {
  static const _tag = 'Compliance';

  /// Run a full compliance audit on a project.
  static Future<ComplianceReport> audit(String projectPath) async {
    AppLogger.info(_tag, 'Auditing ${projectPath.split('/').last}');
    final items = <ComplianceItem>[];
    final sbom = <SBOMEntry>[];
    final secrets = <SecretFinding>[];

    // --- LICENSE ---
    final licenseResult = _checkLicense(projectPath);
    items.add(licenseResult.$1);
    final licenseType = licenseResult.$2;

    // --- README ---
    items.add(_checkReadme(projectPath));

    // --- .gitignore ---
    items.add(_checkGitignore(projectPath));

    // --- No .env committed ---
    items.add(await _checkNoEnvCommitted(projectPath));

    // --- Secret scanning ---
    final secretFindings = await _scanSecrets(projectPath);
    secrets.addAll(secretFindings);
    items.add(ComplianceItem(
      id: 'secrets',
      category: 'secrets',
      title: 'No secrets in source',
      status: secretFindings.isEmpty ? ComplianceStatus.pass : ComplianceStatus.fail,
      detail: secretFindings.isEmpty ? 'No secrets found' : '${secretFindings.length} potential secret(s) found',
      weight: 20,
    ));

    // --- SBOM from lock files ---
    final sbomEntries = await _generateSBOM(projectPath);
    sbom.addAll(sbomEntries);
    items.add(ComplianceItem(
      id: 'sbom',
      category: 'sbom',
      title: 'SBOM available',
      status: sbomEntries.isNotEmpty ? ComplianceStatus.pass : ComplianceStatus.warn,
      detail: sbomEntries.isNotEmpty ? '${sbomEntries.length} dependencies cataloged' : 'No lock file found',
      weight: 10,
    ));

    // --- Dependency licenses ---
    final depLicenseCheck = _checkDependencyLicenses(sbomEntries);
    items.add(depLicenseCheck);

    // --- Code signing ---
    items.add(_checkCodeSigning(projectPath));

    // Calculate score
    var totalWeight = 0;
    var earnedWeight = 0;
    for (final item in items) {
      totalWeight += item.weight;
      if (item.status == ComplianceStatus.pass) {
        earnedWeight += item.weight;
      } else if (item.status == ComplianceStatus.warn) {
        earnedWeight += (item.weight * 0.5).round();
      }
    }
    final score = totalWeight > 0 ? (earnedWeight * 100 / totalWeight).round() : 0;

    AppLogger.info(_tag, '${projectPath.split('/').last}: compliance $score/100 (${items.where((i) => i.status == ComplianceStatus.fail).length} failures)');

    return ComplianceReport(
      items: items,
      score: score,
      licenseType: licenseType,
      sbom: sbom,
      secrets: secrets,
      auditedAt: DateTime.now(),
    );
  }

  /// Run a Claude AI-powered deep compliance review.
  static Future<String?> aiAudit(String projectPath) async {
    AppLogger.info(_tag, 'Running AI compliance audit on ${projectPath.split('/').last}');
    final installed = await AIService.isClaudeInstalled();
    if (!installed) return null;

    final insight = await AIService.runSkill(
      projectPath: projectPath,
      skillName: 'compliance-audit',
      prompt: 'Audit this project for enterprise compliance. Check: 1) License compatibility of all dependencies, 2) Any committed secrets, API keys, or credentials, 3) Security vulnerabilities in the code, 4) Missing documentation, 5) Dependency health (outdated, unmaintained, vulnerable). Format as a compliance report with PASS/WARN/FAIL per category.',
    );

    return insight.isError ? null : insight.output;
  }

  // --- Checks ---

  static (ComplianceItem, String?) _checkLicense(String path) {
    for (final name in ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'LICENCE']) {
      final file = File('$path/$name');
      if (file.existsSync()) {
        final content = file.readAsStringSync().toLowerCase();
        String? type;
        if (content.contains('mit license') || content.contains('permission is hereby granted')) {
          type = 'MIT';
        } else if (content.contains('apache license')) {
          type = 'Apache-2.0';
        } else if (content.contains('gnu general public license') || content.contains('gpl')) {
          type = content.contains('version 3') ? 'GPL-3.0' : 'GPL-2.0';
        } else if (content.contains('bsd')) {
          type = 'BSD';
        } else if (content.contains('isc license')) {
          type = 'ISC';
        } else if (content.contains('mozilla public license')) {
          type = 'MPL-2.0';
        }
        return (ComplianceItem(
          id: 'license',
          category: 'license',
          title: 'LICENSE file',
          status: ComplianceStatus.pass,
          detail: type != null ? 'Detected: $type' : 'License file exists',
          weight: 15,
        ), type);
      }
    }
    return (ComplianceItem(
      id: 'license',
      category: 'license',
      title: 'LICENSE file',
      status: ComplianceStatus.fail,
      detail: 'No LICENSE file found',
      weight: 15,
    ), null);
  }

  static ComplianceItem _checkReadme(String path) {
    for (final name in ['README.md', 'readme.md', 'README.txt', 'README']) {
      final file = File('$path/$name');
      if (file.existsSync()) {
        final size = file.lengthSync();
        return ComplianceItem(
          id: 'readme',
          category: 'docs',
          title: 'README',
          status: size > 100 ? ComplianceStatus.pass : ComplianceStatus.warn,
          detail: size > 100 ? 'README exists (${(size / 1024).toStringAsFixed(1)}KB)' : 'README exists but very short',
          weight: 10,
        );
      }
    }
    return ComplianceItem(
      id: 'readme',
      category: 'docs',
      title: 'README',
      status: ComplianceStatus.fail,
      detail: 'No README found',
      weight: 10,
    );
  }

  static ComplianceItem _checkGitignore(String path) {
    final exists = File('$path/.gitignore').existsSync();
    return ComplianceItem(
      id: 'gitignore',
      category: 'docs',
      title: '.gitignore',
      status: exists ? ComplianceStatus.pass : ComplianceStatus.warn,
      detail: exists ? '.gitignore present' : 'No .gitignore',
      weight: 5,
    );
  }

  static Future<ComplianceItem> _checkNoEnvCommitted(String path) async {
    try {
      final result = await Process.run(
        'git', ['ls-files', '.env', '.env.local', '.env.production'],
        workingDirectory: path,
      );
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        return ComplianceItem(
          id: 'env_committed',
          category: 'secrets',
          title: 'No .env in git',
          status: ComplianceStatus.fail,
          detail: '.env file is tracked by git',
          weight: 15,
        );
      }
    } catch (_) {}
    return ComplianceItem(
      id: 'env_committed',
      category: 'secrets',
      title: 'No .env in git',
      status: ComplianceStatus.pass,
      detail: 'Environment files not tracked',
      weight: 15,
    );
  }

  static ComplianceItem _checkCodeSigning(String path) {
    // Check platform-specific signing
    for (final check in [
      ('ios/Runner.xcodeproj/project.pbxproj', 'CODE_SIGN_IDENTITY'),
      ('android/app/build.gradle', 'signingConfigs'),
      ('macos/Runner.xcodeproj/project.pbxproj', 'CODE_SIGN_IDENTITY'),
    ]) {
      final file = File('$path/${check.$1}');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        if (content.contains(check.$2)) {
          return ComplianceItem(
            id: 'signing',
            category: 'signing',
            title: 'Code signing',
            status: ComplianceStatus.pass,
            detail: 'Signing configured in ${check.$1.split('/').first}',
            weight: 10,
          );
        }
      }
    }

    return ComplianceItem(
      id: 'signing',
      category: 'signing',
      title: 'Code signing',
      status: ComplianceStatus.skip,
      detail: 'No signing config detected (may not apply)',
      weight: 10,
    );
  }

  /// Scan tracked files for potential secrets using regex patterns.
  static Future<List<SecretFinding>> _scanSecrets(String path) async {
    final findings = <SecretFinding>[];
    final patterns = {
      'API key': RegExp(r'''(api[_-]?key|apikey)\s*[:=]\s*['"][A-Za-z0-9_\-]{16,}''', caseSensitive: false),
      'AWS key': RegExp(r'AKIA[0-9A-Z]{16}'),
      'Private key': RegExp(r'-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----'),
      'Token/Secret': RegExp(r'''(token|secret|password|passwd|credential)\s*[:=]\s*['"][^\s'"]{8,}''', caseSensitive: false),
      'Connection string': RegExp(r'(mongodb|postgres|mysql|redis|amqp)://[^\s]+'),
    };

    try {
      // Get tracked files (skip binaries)
      final result = await Process.run(
        'git', ['ls-files', '--cached'],
        workingDirectory: path,
      );
      if (result.exitCode != 0) return findings;

      final files = result.stdout.toString().trim().split('\n');
      final textExtensions = {'.dart', '.ts', '.js', '.py', '.rb', '.go', '.rs', '.java', '.kt', '.swift', '.yml', '.yaml', '.json', '.toml', '.cfg', '.ini', '.env', '.sh'};

      for (final filePath in files) {
        if (filePath.isEmpty) continue;
        final ext = filePath.contains('.') ? '.${filePath.split('.').last}' : '';
        if (!textExtensions.contains(ext)) continue;

        // Skip lock files and test fixtures
        if (filePath.contains('.lock') || filePath.contains('fixtures') || filePath.contains('__mocks__')) continue;

        try {
          final file = File('$path/$filePath');
          if (!file.existsSync() || file.lengthSync() > 500000) continue; // Skip large files
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            for (final entry in patterns.entries) {
              if (entry.value.hasMatch(line)) {
                // Redact the actual secret
                final snippet = line.length > 80 ? '${line.substring(0, 80)}...' : line;
                findings.add(SecretFinding(
                  file: filePath,
                  line: i + 1,
                  pattern: entry.key,
                  snippet: snippet.replaceAll(RegExp(r'''['"][A-Za-z0-9_\-/+=]{8,}['"]'''), '"***REDACTED***"'),
                ));
                break; // One finding per line
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.warn(_tag, 'Secret scanning error: $e');
    }

    if (findings.isNotEmpty) {
      AppLogger.warn(_tag, 'Found ${findings.length} potential secret(s)');
    }
    return findings;
  }

  /// Generate SBOM from lock files.
  static Future<List<SBOMEntry>> _generateSBOM(String path) async {
    final entries = <SBOMEntry>[];

    // pubspec.lock (Flutter/Dart)
    await _parsePubspecLock(path, entries);
    // package-lock.json (Node.js)
    await _parsePackageLock(path, entries);
    // Cargo.lock (Rust)
    await _parseCargoLock(path, entries);

    return entries;
  }

  static Future<void> _parsePubspecLock(String path, List<SBOMEntry> entries) async {
    final file = File('$path/pubspec.lock');
    if (!file.existsSync()) return;
    try {
      final content = await file.readAsString();
      final packageRegex = RegExp(r'^\s{2}(\w[\w-]*):$', multiLine: true);
      final versionRegex = RegExp(r'^\s{4}version:\s*"?([^"\n]+)"?$', multiLine: true);
      final packages = packageRegex.allMatches(content);
      final versions = versionRegex.allMatches(content);

      for (var i = 0; i < packages.length && i < versions.length; i++) {
        entries.add(SBOMEntry(
          name: packages.elementAt(i).group(1)!,
          version: versions.elementAt(i).group(1)?.trim(),
          source: 'pubspec.lock',
        ));
      }
    } catch (_) {}
  }

  static Future<void> _parsePackageLock(String path, List<SBOMEntry> entries) async {
    final file = File('$path/package-lock.json');
    if (!file.existsSync()) return;
    try {
      final content = await file.readAsString();
      // Simple regex approach — gets top-level dependencies
      final regex = RegExp(r'"([@\w/.-]+)":\s*\{\s*"version":\s*"([^"]+)"');
      for (final match in regex.allMatches(content)) {
        final name = match.group(1)!;
        if (name == 'name' || name == 'version' || name.isEmpty) continue;
        entries.add(SBOMEntry(
          name: name,
          version: match.group(2),
          source: 'package-lock.json',
        ));
      }
    } catch (_) {}
  }

  static Future<void> _parseCargoLock(String path, List<SBOMEntry> entries) async {
    final file = File('$path/Cargo.lock');
    if (!file.existsSync()) return;
    try {
      final content = await file.readAsString();
      final packageRegex = RegExp(r'name\s*=\s*"([^"]+)"\nversion\s*=\s*"([^"]+)"');
      for (final match in packageRegex.allMatches(content)) {
        entries.add(SBOMEntry(
          name: match.group(1)!,
          version: match.group(2),
          source: 'Cargo.lock',
        ));
      }
    } catch (_) {}
  }

  static ComplianceItem _checkDependencyLicenses(List<SBOMEntry> sbom) {
    if (sbom.isEmpty) {
      return ComplianceItem(
        id: 'dep_licenses',
        category: 'license',
        title: 'Dependency licenses',
        status: ComplianceStatus.skip,
        detail: 'No SBOM to analyze',
        weight: 15,
      );
    }
    // Without a license database, we report the SBOM exists
    return ComplianceItem(
      id: 'dep_licenses',
      category: 'license',
      title: 'Dependency licenses',
      status: ComplianceStatus.warn,
      detail: '${sbom.length} deps cataloged — run AI audit for license analysis',
      weight: 15,
    );
  }
}
