import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:launcher_native/launcher_native.dart';
import 'services/referral_service.dart';
import 'services/premium_service.dart';
import 'services/api_server.dart';
import 'services/notification_service.dart';
import 'services/background_monitor.dart';
import 'screens/home_screen.dart';
import 'package:launcher_theme/launcher_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('App', 'Project Launcher starting (${Platform.operatingSystem} ${Platform.operatingSystemVersion})');
  await PremiumService.configure();
  AppLogger.info('App', 'Premium service configured');

  // Start local API server if enabled
  final prefs = await SharedPreferences.getInstance();
  final apiEnabled = prefs.getBool('apiServerEnabled') ?? false;
  if (apiEnabled) {
    final apiPort = prefs.getInt('apiServerPort') ?? 9847;
    await ApiServer.start(port: apiPort);
  }

  // Initialize notification service
  await NotificationService.initialize();
  final notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
  if (notificationsEnabled) {
    NotificationService.start();
  }

  // Start background monitor — checks project health & git status on launch
  BackgroundMonitor.start();
  AppLogger.info('App', 'Background monitor started');

  AppLogger.info('App', 'Startup complete, launching UI');
  runApp(const ProjectLauncherApp());
}

class ProjectLauncherApp extends StatefulWidget {
  const ProjectLauncherApp({super.key});

  static ProjectLauncherAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<ProjectLauncherAppState>();
  }

  @override
  State<ProjectLauncherApp> createState() => ProjectLauncherAppState();
}

class ProjectLauncherAppState extends State<ProjectLauncherApp> {
  AppTheme currentTheme = AppTheme.dark;
  AppSkin currentSkin = const DefaultSkin();
  List<String> unlockedThemes = [];
  bool isPro = false;

  /// All available skins (order matters for the switcher UI).
  static const List<AppSkin> allSkins = [
    DefaultSkin(),
    MinimalSkin(),
    CorporateSkin(),
    GamingSkin(),
    TerminalSkin(),
  ];

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadSkinPreference();
    _setupPremiumListener();
  }

  void _setupPremiumListener() {
    PremiumService.addStatusListener((isActive) {
      if (mounted && isActive != isPro) {
        setState(() => isPro = isActive);
      }
    });
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('appTheme') ?? AppTheme.dark.index;
    final unlocked = await ReferralService.getUnlockedThemes();
    final pro = await PremiumService.isPro();

    if (mounted) {
      setState(() {
        currentTheme = AppTheme.values[themeIndex];
        unlockedThemes = unlocked;
        isPro = pro;

        if (!isPro &&
            currentTheme.requiresUnlock &&
            currentTheme.unlockRewardId != null &&
            !unlockedThemes.contains(currentTheme.unlockRewardId)) {
          currentTheme = AppTheme.dark;
        }
      });
    }
  }

  Future<void> refreshPremiumStatus() async {
    final pro = await PremiumService.isPro();
    if (mounted) {
      setState(() => isPro = pro);
    }
  }

  Future<void> _loadSkinPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final skinId = prefs.getString('appSkin') ?? 'default';
    var skin = allSkins.firstWhere(
      (s) => s.metadata.id == skinId,
      orElse: () => const DefaultSkin(),
    );

    // Validate premium access
    if (!isPro &&
        skin.metadata.requiresUnlock &&
        skin.metadata.unlockRewardId != null &&
        !unlockedThemes.contains(skin.metadata.unlockRewardId)) {
      skin = const DefaultSkin();
    }

    if (mounted) {
      setState(() => currentSkin = skin);
    }
  }

  bool canUseSkin(AppSkin skin) {
    if (!skin.metadata.requiresUnlock) return true;
    if (isPro) return true;
    if (skin.metadata.unlockRewardId != null &&
        unlockedThemes.contains(skin.metadata.unlockRewardId)) return true;
    return false;
  }

  Future<void> setSkin(AppSkin skin) async {
    if (!canUseSkin(skin)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appSkin', skin.metadata.id);

    // If the new skin doesn't support the current color theme, switch to its first supported theme
    if (!skin.supportedThemes.contains(currentTheme)) {
      await prefs.setInt('appTheme', skin.supportedThemes.first.index);
      if (mounted) {
        setState(() {
          currentSkin = skin;
          currentTheme = skin.supportedThemes.first;
        });
      }
    } else if (mounted) {
      setState(() => currentSkin = skin);
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    if (!isPro &&
        theme.requiresUnlock &&
        theme.unlockRewardId != null &&
        !unlockedThemes.contains(theme.unlockRewardId)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appTheme', theme.index);

    if (mounted) {
      setState(() => currentTheme = theme);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SkinProvider(
      skin: currentSkin,
      child: MaterialApp(
        title: 'Project Launcher',
        debugShowCheckedModeBanner: false,
        theme: currentSkin.buildThemeData(currentTheme),
        home: const HomeScreen(),
      ),
    );
  }
}
