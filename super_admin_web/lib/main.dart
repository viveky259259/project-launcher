import 'package:flutter/material.dart';
import 'package:launcher_theme/launcher_theme.dart';
import 'router.dart';

void main() {
  runApp(const SuperAdminApp());
}

class SuperAdminApp extends StatelessWidget {
  const SuperAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();
    const skin = DefaultSkin();
    final theme = skin.buildThemeData(AppTheme.dark);

    return SkinProvider(
      skin: skin,
      child: MaterialApp.router(
        title: 'Project Launcher — Super Admin',
        debugShowCheckedModeBanner: false,
        theme: theme,
        routerConfig: router,
      ),
    );
  }
}
