import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launcher_kit/launcher_kit.dart';
import 'package:launcher_theme/launcher_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/super_admin_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = true;
  late final TextEditingController _serverUrlCtrl;

  @override
  void initState() {
    super.initState();
    _serverUrlCtrl =
        TextEditingController(text: 'https://api.plauncher.io');
    _checkForToken();
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkForToken() async {
    // Check URL params for ?token=<jwt>
    final uri = Uri.parse(web.window.location.href);
    final token = uri.queryParameters['token'];
    final serverUrl = uri.queryParameters['server'] ??
        _serverUrlCtrl.text.trim();

    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('super_admin_token', token);
      await prefs.setString('super_admin_server_url', serverUrl);
      SuperAdminApi.configure(serverUrl, token);

      // Clean up URL (remove token param)
      web.window.history.replaceState(null, '', '/');
      if (mounted) context.go('/orgs');
      return;
    }

    // Check stored token
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('super_admin_token');
    final storedServer = prefs.getString('super_admin_server_url');
    if (storedToken != null && storedServer != null) {
      SuperAdminApi.configure(storedServer, storedToken);
      if (mounted) context.go('/orgs');
      return;
    }

    setState(() => _loading = false);
  }

  void _loginWithGitHub() {
    final serverUrl = _serverUrlCtrl.text.trim();
    web.window.location.href =
        '$serverUrl/auth/super-admin/github?redirect=super-admin';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo / icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 40,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Project Launcher',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Super Admin',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Internal tool for managing customer organizations, licenses, and platform metrics.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                UkTextField(
                  controller: _serverUrlCtrl,
                  label: 'Server URL',
                  hint: 'https://api.plauncher.io',
                  prefixIcon: Icons.dns_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: UkButton(
                    label: 'Login with GitHub',
                    icon: Icons.link_rounded,
                    size: UkButtonSize.large,
                    onPressed: _loginWithGitHub,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Restricted to authorized super admins only.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
