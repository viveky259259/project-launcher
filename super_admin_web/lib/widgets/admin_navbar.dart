import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launcher_kit/launcher_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminNavbar extends StatelessWidget implements PreferredSizeWidget {
  const AdminNavbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('super_admin_token');
    await prefs.remove('super_admin_server_url');
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    int selectedIndex = 0;
    if (location.startsWith('/orgs')) selectedIndex = 0;
    if (location.startsWith('/license-keys')) selectedIndex = 1;
    if (location.startsWith('/metrics')) selectedIndex = 2;

    return UkNavbar(
      title: 'Project Launcher Admin',
      selectedIndex: selectedIndex,
      onItemSelected: (i) {
        switch (i) {
          case 0:
            context.go('/orgs');
          case 1:
            context.go('/license-keys');
          case 2:
            context.go('/metrics');
        }
      },
      items: const [
        UkNavbarItem('Orgs', icon: Icons.business_rounded),
        UkNavbarItem('License Keys', icon: Icons.vpn_key_rounded),
        UkNavbarItem('Metrics', icon: Icons.insights_rounded),
      ],
      actions: [
        UkButton(
          label: 'Logout',
          variant: UkButtonVariant.outline,
          size: UkButtonSize.small,
          icon: Icons.logout_rounded,
          onPressed: () => _logout(context),
        ),
      ],
    );
  }
}
