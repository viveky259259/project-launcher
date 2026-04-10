import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launcher_kit/launcher_kit.dart';
import 'package:launcher_theme/launcher_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/admin_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = true;
  bool _useApiKey = true; // default to API key login
  String? _error;

  final _formKey = GlobalKey<FormState>();
  final _orgSlugCtrl = TextEditingController();
  final _serverUrlCtrl = TextEditingController(text: 'http://localhost:8743');
  final _apiKeyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkForToken();
  }

  @override
  void dispose() {
    _orgSlugCtrl.dispose();
    _serverUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkForToken() async {
    // Check URL params for ?token=<jwt>
    final uri = Uri.parse(web.window.location.href);
    final token = uri.queryParameters['token'];
    final serverFromUrl = uri.queryParameters['server'];

    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_token', token);
      if (serverFromUrl != null) await prefs.setString('server_url', serverFromUrl);
      final orgSlug = prefs.getString('org_slug') ?? '';
      final serverUrl = prefs.getString('server_url') ?? 'http://localhost:8743';
      if (orgSlug.isNotEmpty) {
        AdminApi.configure(serverUrl, token, orgSlug);
        web.window.history.replaceState(null, '', '/');
        if (mounted) context.go('/repos');
        return;
      }
      setState(() => _loading = false);
      return;
    }

    // Check stored credentials
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('admin_token');
    final storedServer = prefs.getString('server_url');
    final storedOrgSlug = prefs.getString('org_slug');
    if (storedToken != null && storedServer != null && storedOrgSlug != null) {
      AdminApi.configure(storedServer, storedToken, storedOrgSlug);
      if (mounted) context.go('/repos');
      return;
    }

    // Pre-fill from storage
    if (storedOrgSlug != null) _orgSlugCtrl.text = storedOrgSlug;
    if (storedServer != null) _serverUrlCtrl.text = storedServer;

    setState(() => _loading = false);
  }

  Future<void> _loginWithApiKey() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final orgSlug = _orgSlugCtrl.text.trim();
    final serverUrl = _serverUrlCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('org_slug', orgSlug);
    await prefs.setString('server_url', serverUrl);
    await prefs.setString('admin_token', apiKey);

    AdminApi.configure(serverUrl, apiKey, orgSlug);

    // Verify the key works by fetching members
    try {
      await AdminApi.getMembers();
      if (mounted) context.go('/repos');
    } catch (e) {
      await prefs.remove('admin_token');
      setState(() => _error = 'Login failed: $e');
    }
  }

  Future<void> _loginWithGitHub() async {
    if (!_formKey.currentState!.validate()) return;

    final orgSlug = _orgSlugCtrl.text.trim();
    final serverUrl = _serverUrlCtrl.text.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('org_slug', orgSlug);
    await prefs.setString('server_url', serverUrl);

    web.window.location.href = '$serverUrl/auth/$orgSlug/github';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.rocket_launch_rounded, size: 40, color: cs.primary),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Project Launcher Admin',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Manage your team catalog, env templates, and member activity.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      UkTextField(
                        controller: _serverUrlCtrl,
                        label: 'Server URL',
                        hint: 'http://localhost:8743',
                        prefixIcon: Icons.dns_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Server URL is required'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      UkTextField(
                        controller: _orgSlugCtrl,
                        label: 'Organization Slug',
                        hint: 'e.g. acme-corp',
                        prefixIcon: Icons.business_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Org slug is required'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Toggle between API key and GitHub OAuth
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _useApiKey = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _useApiKey
                                          ? cs.primary
                                          : cs.outline.withOpacity(0.3),
                                      width: _useApiKey ? 2 : 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'API Key',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _useApiKey ? cs.primary : cs.onSurfaceVariant,
                                    fontWeight: _useApiKey
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _useApiKey = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: !_useApiKey
                                          ? cs.primary
                                          : cs.outline.withOpacity(0.3),
                                      width: !_useApiKey ? 2 : 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'GitHub OAuth',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        !_useApiKey ? cs.primary : cs.onSurfaceVariant,
                                    fontWeight: !_useApiKey
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_useApiKey) ...[
                        UkTextField(
                          controller: _apiKeyCtrl,
                          label: 'API Key',
                          hint: 'plk_...',
                          prefixIcon: Icons.vpn_key_rounded,
                          isPassword: true,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'API key is required'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: UkButton(
                            label: 'Sign in',
                            icon: Icons.login_rounded,
                            size: UkButtonSize.large,
                            onPressed: _loginWithApiKey,
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: UkButton(
                            label: 'Continue with GitHub',
                            icon: Icons.link_rounded,
                            size: UkButtonSize.large,
                            onPressed: _loginWithGitHub,
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: TextStyle(color: cs.error, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
