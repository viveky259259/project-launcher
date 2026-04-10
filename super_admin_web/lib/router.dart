import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/orgs_screen.dart';
import 'screens/org_detail_screen.dart';
import 'screens/license_keys_screen.dart';
import 'screens/metrics_screen.dart';
import 'services/super_admin_api.dart';

Future<bool> _isAuthenticated() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('super_admin_token');
  final server = prefs.getString('super_admin_server_url');
  if (token != null && server != null) {
    SuperAdminApi.configure(server, token);
    return true;
  }
  return false;
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final location = state.uri.toString();
      // Always allow login page
      if (location == '/login') return null;

      final authed = await _isAuthenticated();
      if (!authed) return '/login';
      // Redirect root to orgs
      if (location == '/') return '/orgs';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/orgs',
        builder: (context, state) => const OrgsScreen(),
      ),
      GoRoute(
        path: '/orgs/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return OrgDetailScreen(slug: slug);
        },
      ),
      GoRoute(
        path: '/license-keys',
        builder: (context, state) => const LicenseKeysScreen(),
      ),
      GoRoute(
        path: '/metrics',
        builder: (context, state) => const MetricsScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const _LoadingScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
