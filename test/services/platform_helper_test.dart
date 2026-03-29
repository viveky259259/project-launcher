import 'package:flutter_test/flutter_test.dart';
import 'package:project_launcher/services/platform_helper.dart';

void main() {
  group('PlatformHelper.shortenPath', () {
    test('replaces home directory with tilde', () {
      final home = PlatformHelper.homeDir;
      if (home.isNotEmpty) {
        final result = PlatformHelper.shortenPath('$home/Documents/project');
        expect(result, '~/Documents/project');
      }
    });

    test('returns path unchanged when not under home', () {
      expect(PlatformHelper.shortenPath('/tmp/project'), '/tmp/project');
    });
  });

  group('PlatformHelper.parentDirName', () {
    test('extracts parent directory name', () {
      expect(PlatformHelper.parentDirName('/Users/test/projects/my-app'), 'projects');
    });

    test('handles single-component paths', () {
      final result = PlatformHelper.parentDirName('my-app');
      expect(result, 'my-app');
    });

    test('handles root path', () {
      final result = PlatformHelper.parentDirName('/');
      expect(result, '/');
    });
  });

  group('PlatformHelper.basename', () {
    test('extracts file name from path', () {
      expect(PlatformHelper.basename('/Users/test/projects/my-app'), 'my-app');
    });

    test('handles paths with forward slashes', () {
      expect(PlatformHelper.basename('path/to/file.dart'), 'file.dart');
    });

    test('returns input when no separator', () {
      expect(PlatformHelper.basename('filename'), 'filename');
    });
  });

  group('PlatformHelper directories', () {
    test('homeDir is non-empty', () {
      expect(PlatformHelper.homeDir, isNotEmpty);
    });

    test('dataDir contains project_launcher', () {
      expect(PlatformHelper.dataDir.toLowerCase(), contains('project_launcher'));
    });

    test('desktopDir ends with Desktop', () {
      expect(PlatformHelper.desktopDir, endsWith('Desktop'));
    });
  });
}
