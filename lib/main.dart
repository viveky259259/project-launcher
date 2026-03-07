import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/referral_service.dart';
import 'services/premium_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PremiumService.configure();
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
  List<String> unlockedThemes = [];
  bool isPro = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _setupPremiumListener();
  }

  void _setupPremiumListener() {
    PremiumService.addCustomerInfoListener((customerInfo) {
      final isActive = customerInfo.entitlements.all[RevenueCatConfig.entitlementId]?.isActive ?? false;
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
    return MaterialApp(
      title: 'Project Launcher',
      debugShowCheckedModeBanner: false,
      theme: currentTheme.themeData,
      home: const HomeScreen(),
    );
  }
}
