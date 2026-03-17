import 'dart:io';
import '../models/project.dart';
import 'app_logger.dart';
import 'platform_helper.dart';

/// Result of an export operation
class ExportResult {
  final String zipPath;
  final int projectCount;
  final int fileSizeBytes;

  const ExportResult({
    required this.zipPath,
    required this.projectCount,
    required this.fileSizeBytes,
  });

  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Service to export projects as a single zip archive for sharing.
class ExportService {
  static const _tag = 'Export';

  /// Directories to exclude from the zip archive
  static const List<String> excludePatterns = [
    'node_modules',
    '.dart_tool',
    'build',
    '.build',
    'Pods',
    'vendor',
    '__pycache__',
    '.gradle',
    '.idea',
    '.vs',
    'target', // Rust/Java
    'dist',
    '.next',
    '.nuxt',
    '.output',
    'coverage',
    '.cache',
    'DerivedData',
    '*.pyc',
    '.DS_Store',
  ];

  /// Create a zip archive of the given projects.
  ///
  /// Zips each project one at a time so [onProgress] fires with real
  /// per-project updates during the heavy I/O work.
  static Future<ExportResult> exportProjects({
    required List<Project> projects,
    String? outputDir,
    bool includeGitDir = false,
    void Function(int current, int total, String projectName)? onProgress,
  }) async {
    final destDir = outputDir ?? PlatformHelper.desktopDir;
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final zipName = 'projects-export-$timestamp.zip';
    final zipPath = '$destDir${Platform.pathSeparator}$zipName';

    AppLogger.info(_tag, 'Exporting ${projects.length} projects to $zipPath');

    // Build exclude args for zip command
    // Use both nested (*/) and top-level patterns for reliable exclusion
    final excludeArgs = <String>[];
    for (final pattern in excludePatterns) {
      excludeArgs.addAll(['-x', '*/$pattern/*', '-x', '$pattern/*']);
    }
    if (!includeGitDir) {
      excludeArgs.addAll(['-x', '*/.git/*', '-x', '.git/*']);
    }

    // Track used names to deduplicate projects with the same name
    final usedNames = <String, int>{};
    int addedCount = 0;

    // Zip each project one by one, appending to the same zip file.
    // This gives real progress feedback per project.
    for (var i = 0; i < projects.length; i++) {
      final project = projects[i];
      onProgress?.call(i + 1, projects.length, project.name);

      final projectDir = Directory(project.path);
      if (!await projectDir.exists()) {
        AppLogger.warn(_tag, 'Skipping missing project: ${project.path}');
        continue;
      }

      // Deduplicate: append suffix if name already used
      var folderName = project.name;
      final count = usedNames[folderName] ?? 0;
      usedNames[folderName] = count + 1;
      if (count > 0) {
        folderName = '${folderName}_$count';
      }

      // Use a temp dir with a symlink so the folder name in the zip is clean.
      // zip -r follows symlinks by default (without -y).
      // Use -g (grow) to append to an existing zip after the first project.
      final tmpDir = await Directory.systemTemp.createTemp('proj_zip_');
      try {
        final linkPath = '${tmpDir.path}${Platform.pathSeparator}$folderName';
        await Link(linkPath).create(project.path);

        final zipResult = await Process.run(
          'zip',
          [
            '-r',
            if (addedCount > 0) '-g', // append to existing zip
            zipPath,
            folderName,
            ...excludeArgs,
          ],
          workingDirectory: tmpDir.path,
        );

        if (zipResult.exitCode != 0 && zipResult.exitCode != 12) {
          final error = (zipResult.stderr as String).trim();
          AppLogger.warn(_tag, 'zip warning for ${project.name}: $error');
        }

        addedCount++;
      } finally {
        await tmpDir.delete(recursive: true);
      }
    }

    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception('Failed to create zip — no projects were exported');
    }
    final fileSize = await zipFile.length();

    AppLogger.info(
        _tag, 'Export complete: $zipPath (${_formatSize(fileSize)})');

    return ExportResult(
      zipPath: zipPath,
      projectCount: addedCount,
      fileSizeBytes: fileSize,
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
