import 'app_logger.dart';
import 'platform_helper.dart';

class LauncherService {
  static const _tag = 'Launcher';

  static Future<void> openInTerminal(String path) async {
    AppLogger.info(_tag, 'Opening Terminal: ${path.split('/').last}');
    await PlatformHelper.openInTerminal(path);
  }

  static Future<void> openInVSCode(String path) async {
    AppLogger.info(_tag, 'Opening VS Code: ${path.split('/').last}');
    await PlatformHelper.openInVSCode(path);
  }

  static Future<void> openInFinder(String path) async {
    AppLogger.info(_tag, 'Opening Finder: ${path.split('/').last}');
    await PlatformHelper.openInFileManager(path);
  }

  static Future<void> openTerminal() async {
    AppLogger.info(_tag, 'Opening Terminal (home)');
    await PlatformHelper.openInTerminal(PlatformHelper.homeDir);
  }

  static Future<void> openVSCode() async {
    AppLogger.info(_tag, 'Opening VS Code (home)');
    await PlatformHelper.openInVSCode(PlatformHelper.homeDir);
  }
}
