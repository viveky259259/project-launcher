import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:launcher_theme/launcher_theme.dart';
import '../services/platform_helper.dart';
import '../services/project_scanner.dart';

class ScanDialog extends StatefulWidget {
  const ScanDialog();

  @override
  State<ScanDialog> createState() => ScanDialogState();
}

class ScanDialogState extends State<ScanDialog> {
  bool _isScanning = false;
  bool _isDone = false;
  String _currentPath = '';
  int _foundCount = 0;
  int _dirCount = 0;
  ScanResult? _result;
  final _customPathController = TextEditingController();
  final Stopwatch _stopwatch = Stopwatch();
  int _scanDepth = 3;
  bool _infiniteDepth = false;

  @override
  void dispose() {
    _customPathController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _currentPath = 'Starting scan...';
      _foundCount = 0;
      _dirCount = 0;
    });
    _stopwatch.start();

    final result = await ProjectScanner.scanAndAddProjects(
      maxDepth: _infiniteDepth ? null : _scanDepth,
      onProgress: (path) {
        if (mounted) {
          setState(() {
            _currentPath = path;
            _dirCount++;
          });
        }
      },
      onFound: (count) {
        if (mounted) {
          setState(() => _foundCount = count);
        }
      },
    );

    _stopwatch.stop();
    if (mounted) {
      setState(() {
        _isScanning = false;
        _isDone = true;
        _result = result;
      });
    }
  }

  Future<void> _browseFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder to scan',
    );
    if (result != null) {
      _customPathController.text = result;
    }
  }

  Future<void> _scanCustomPath() async {
    final path = _customPathController.text.trim();
    if (path.isEmpty) return;

    setState(() {
      _isScanning = true;
      _currentPath = path;
    });

    final result = await ProjectScanner.scanCustomPath(
      path,
      maxDepth: _infiniteDepth ? null : _scanDepth,
    );

    if (mounted) {
      setState(() {
        _isScanning = false;
        _isDone = true;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan for Projects',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Automatically discover git repositories on your machine',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(_result),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_isDone)
              _buildResultView(cs)
            else if (_isScanning)
              _buildScanningView(cs)
            else
              _buildStartView(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildStartView(ColorScheme cs) {
    final scanPaths = ProjectScanner.getScanPaths();
    final home = PlatformHelper.homeDir;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT DIRECTORIES',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...scanPaths.take(4).map((path) {
          final exists = Directory(path).existsSync();
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: exists
                  ? AppColors.accent.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: exists
                    ? AppColors.accent.withValues(alpha: 0.3)
                    : cs.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  exists ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: exists ? AppColors.accent : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path.replaceFirst(home, '~'),
                        style: AppTypography.mono(
                          fontSize: 13,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        // Add custom folder
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customPathController,
                decoration: InputDecoration(
                  hintText: 'Custom folder path...',
                  hintStyle: AppTypography.mono(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.folder_open,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: cs.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                style: AppTypography.mono(fontSize: 12, color: cs.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _browseFolder,
              icon: const Icon(Icons.folder_open, size: 18),
              tooltip: 'Browse',
              style: IconButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: _scanCustomPath,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: const Text('Scan'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Scan depth
        Row(
          children: [
            Text(
              'Scan Depth',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: cs.onSurface),
            ),
            const Spacer(),
            if (!_infiniteDepth) ...[
              IconButton(
                onPressed: _scanDepth > 1
                    ? () => setState(() => _scanDepth--)
                    : null,
                icon: const Icon(Icons.remove, size: 16),
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  maximumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  foregroundColor: cs.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_scanDepth',
                  style: AppTypography.mono(
                    fontSize: 14,
                    color: AppColors.accent,
                  ),
                ),
              ),
              IconButton(
                onPressed: _scanDepth < 20
                    ? () => setState(() => _scanDepth++)
                    : null,
                icon: const Icon(Icons.add, size: 16),
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  maximumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  foregroundColor: cs.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '∞',
                  style: AppTypography.mono(
                    fontSize: 18,
                    color: AppColors.accent,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => setState(() => _infiniteDepth = !_infiniteDepth),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _infiniteDepth
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _infiniteDepth
                        ? AppColors.accent
                        : cs.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Infinite',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _infiniteDepth
                        ? AppColors.accent
                        : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Start scan button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startScan,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            child: const Text('Start Scan'),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningView(ColorScheme cs) {
    final home = PlatformHelper.homeDir;
    final elapsed = _stopwatch.elapsed;
    final elapsedStr =
        '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}s';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Scanning Filesystem...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            _currentPath.replaceFirst(home, '~'),
            style: AppTypography.mono(fontSize: 11, color: AppColors.accent),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ScanStat(label: 'DIRECTORIES', value: _dirCount.toString()),
            ScanStat(label: 'REPOS FOUND', value: _foundCount.toString()),
            ScanStat(label: 'ELAPSED', value: elapsedStr),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildResultView(ColorScheme cs) {
    final result = _result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 20),
        Text('Scan Complete', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ScanStat(label: 'Found', value: result.totalFound.toString()),
            ScanStat(label: 'Added', value: result.newlyAdded.toString()),
            ScanStat(label: 'Existing', value: result.alreadyExists.toString()),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_result),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

class ScanStat extends StatelessWidget {
  final String label;
  final String value;
  const ScanStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.mono(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
