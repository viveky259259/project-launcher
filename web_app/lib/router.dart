import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/repos_screen.dart';
import 'screens/templates_screen.dart';
import 'screens/members_screen.dart';
import 'services/admin_api.dart';

Future<bool> _isAuthenticated() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('admin_token');
  final server = prefs.getString('server_url');
  final orgSlug = prefs.getString('org_slug');
  if (token != null && server != null && orgSlug != null) {
    AdminApi.configure(server, token, orgSlug);
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
      // Redirect root to repos
      if (location == '/') return '/repos';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/repos',
        builder: (context, state) => const ReposScreen(),
      ),
      GoRoute(
        path: '/templates',
        builder: (context, state) => const TemplatesScreen(),
      ),
      GoRoute(
        path: '/members',
        builder: (context, state) => const MembersScreen(),
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
