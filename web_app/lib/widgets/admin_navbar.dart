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
    await prefs.remove('admin_token');
    await prefs.remove('server_url');
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    int selectedIndex = 0;
    if (location.startsWith('/repos')) selectedIndex = 0;
    if (location.startsWith('/templates')) selectedIndex = 1;
    if (location.startsWith('/members')) selectedIndex = 2;

    return UkNavbar(
      title: 'Project Launcher Admin',
      selectedIndex: selectedIndex,
      onItemSelected: (i) {
        switch (i) {
          case 0:
            context.go('/repos');
          case 1:
            context.go('/templates');
          case 2:
            context.go('/members');
        }
      },
      items: const [
        UkNavbarItem('Repos', icon: Icons.source_rounded),
        UkNavbarItem('Templates', icon: Icons.description_rounded),
        UkNavbarItem('Members', icon: Icons.group_rounded),
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
