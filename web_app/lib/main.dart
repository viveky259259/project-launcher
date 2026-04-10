import 'package:flutter/material.dart';
import 'package:launcher_theme/launcher_theme.dart';
import 'router.dart';

void main() {
  runApp(const CatalogAdminApp());
}

class CatalogAdminApp extends StatelessWidget {
  const CatalogAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();
    final skin = const CorporateSkin();
    final theme = skin.buildThemeData(AppTheme.dark);

    return SkinProvider(
      skin: skin,
      child: MaterialApp.router(
        title: 'Project Launcher Admin',
        debugShowCheckedModeBanner: false,
        theme: theme,
        routerConfig: router,
      ),
    );
  }
}
