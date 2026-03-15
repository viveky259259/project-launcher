import 'dart:convert';
import 'dart:io';
import 'dart:developer';
import 'project_storage.dart';
import 'health_service.dart';
import 'git_service.dart';
import 'project_scanner.dart';
import 'stats_service.dart';
import 'project_type_detector.dart';

/// Local HTTP API server for Project Launcher
/// Enables external tools (scripts, Alfred, Hammerspoon, etc.) to query project data.
class ApiServer {
  static HttpServer? _server;
  static int _port = 9847; // Default port

  static bool get isRunning => _server != null;
  static int get port => _port;

  /// Start the API server on the given port
  static Future<bool> start({int port = 9847}) async {
    if (_server != null) return true;

    try {
      _port = port;
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      log('API server started on http://localhost:$port');

      _server!.listen(_handleRequest);
      return true;
    } catch (e) {
      log('Failed to start API server: $e');
      return false;
    }
  }

  /// Stop the API server
  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    log('API server stopped');
  }

  static void _handleRequest(HttpRequest request) async {
    // CORS headers for browser access
    request.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type')
      ..set('Content-Type', 'application/json');

    // Handle preflight
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    final query = request.uri.queryParameters;

    try {
      switch (path) {
        case '/':
        case '/api':
          await _handleIndex(request);
        case '/api/projects':
          await _handleProjects(request, query);
        case '/api/health':
          await _handleHealth(request, query);
        case '/api/stats':
          await _handleStats(request);
        case '/api/status':
          await _handleStatus(request);
        case '/api/scan':
          if (request.method == 'POST') {
            await _handleScan(request);
          } else {
            _sendError(request, 405, 'Use POST for /api/scan');
          }
        default:
          // Check for /api/projects/:name pattern
          if (path.startsWith('/api/projects/') && path.split('/').length == 4) {
            final name = Uri.decodeComponent(path.split('/')[3]);
            await _handleProjectDetail(request, name);
          } else {
            _sendError(request, 404, 'Not found');
          }
      }
    } catch (e) {
      _sendError(request, 500, 'Internal error: $e');
    }
  }

  // ── Handlers ──

  static Future<void> _handleIndex(HttpRequest request) async {
    final data = {
      'name': 'Project Launcher API',
      'version': '1.0.0',
      'endpoints': {
        'GET /api/projects': 'List all projects',
        'GET /api/projects?tag=work': 'Filter by tag',
        'GET /api/projects/:name': 'Get project details with health & git info',
        'GET /api/health': 'Health summary across all projects',
        'GET /api/health?path=/path/to/project': 'Health for specific project',
        'GET /api/stats': 'Year-in-review stats',
        'GET /api/status': 'Git status across all projects',
        'POST /api/scan': 'Trigger project scan',
      },
    };
    _sendJson(request, data);
  }

  static Future<void> _handleProjects(
    HttpRequest request,
    Map<String, String> query,
  ) async {
    var projects = await ProjectStorage.loadProjects();

    // Filter by tag
    final tag = query['tag'];
    if (tag != null) {
      projects = projects.where((p) => p.tags.contains(tag)).toList();
    }

    // Filter by pinned
    if (query['pinned'] == 'true') {
      projects = projects.where((p) => p.isPinned).toList();
    }

    final healthCache = await HealthService.loadCache();

    final result = projects.map((p) {
      final health = healthCache[p.path];
      return {
        'name': p.name,
        'path': p.path,
        'tags': p.tags,
        'isPinned': p.isPinned,
        'addedAt': p.addedAt.toIso8601String(),
        'lastOpenedAt': p.lastOpenedAt?.toIso8601String(),
        'health': health != null
            ? {
                'score': health.details.totalScore,
                'category': health.details.category.name,
                'staleness': health.staleness.name,
                'git': health.details.gitScore,
                'deps': health.details.depsScore,
                'tests': health.details.testsScore,
              }
            : null,
      };
    }).toList();

    _sendJson(request, {'projects': result, 'count': result.length});
  }

  static Future<void> _handleProjectDetail(
    HttpRequest request,
    String name,
  ) async {
    final projects = await ProjectStorage.loadProjects();
    final nameLower = name.toLowerCase();
    final matches =
        projects.where((p) => p.name.toLowerCase() == nameLower).toList();

    if (matches.isEmpty) {
      // Try fuzzy match
      final fuzzy = projects
          .where((p) => p.name.toLowerCase().contains(nameLower))
          .toList();
      if (fuzzy.isEmpty) {
        _sendError(request, 404, 'Project not found: $name');
        return;
      }
      if (fuzzy.length > 1) {
        _sendJson(request, {
          'error': 'Ambiguous name',
          'matches': fuzzy.map((p) => p.name).toList(),
        }, status: 400);
        return;
      }
      matches.addAll(fuzzy);
    }

    final project = matches.first;
    final health = await HealthService.getHealthScore(project.path);
    final isGit = await GitService.isGitRepository(project.path);
    final stack = ProjectStack.detect(project.path);

    final data = {
      'name': project.name,
      'path': project.path,
      'tags': project.tags,
      'isPinned': project.isPinned,
      'notes': project.notes,
      'addedAt': project.addedAt.toIso8601String(),
      'lastOpenedAt': project.lastOpenedAt?.toIso8601String(),
      'stack': {
        'primary': stack.primary.label,
        'secondary': stack.secondary.map((t) => t.label).toList(),
      },
      'health': {
        'score': health.details.totalScore,
        'category': health.details.category.name,
        'staleness': health.staleness.name,
        'breakdown': {
          'git': health.details.gitScore,
          'deps': health.details.depsScore,
          'tests': health.details.testsScore,
        },
        'details': {
          'hasRecentCommits': health.details.hasRecentCommits,
          'noUncommittedChanges': health.details.noUncommittedChanges,
          'noUnpushedCommits': health.details.noUnpushedCommits,
          'hasDependencyFile': health.details.hasDependencyFile,
          'hasLockFile': health.details.hasLockFile,
          'hasTestFolder': health.details.hasTestFolder,
          'hasTestFiles': health.details.hasTestFiles,
          'lastCommitDate':
              health.details.lastCommitDate?.toIso8601String(),
        },
      },
      'git': isGit
          ? {
              'isRepo': true,
              'branch': await GitService.getCurrentBranch(project.path),
              'hasUncommitted':
                  await GitService.hasUncommittedChanges(project.path),
              'unpushedCount':
                  await GitService.getUnpushedCommitCount(project.path),
              'remoteUrl': await GitService.getRemoteUrl(project.path),
            }
          : {'isRepo': false},
    };

    _sendJson(request, data);
  }

  static Future<void> _handleHealth(
    HttpRequest request,
    Map<String, String> query,
  ) async {
    // Single project health
    final path = query['path'];
    if (path != null) {
      final health = await HealthService.getHealthScore(path);
      _sendJson(request, {
        'path': path,
        'score': health.details.totalScore,
        'category': health.details.category.name,
        'staleness': health.staleness.name,
        'breakdown': {
          'git': health.details.gitScore,
          'deps': health.details.depsScore,
          'tests': health.details.testsScore,
        },
      });
      return;
    }

    // All projects health summary
    final projects = await ProjectStorage.loadProjects();
    final healthCache = await HealthService.loadCache();

    int healthy = 0, attention = 0, critical = 0, unscored = 0;
    int totalScore = 0, scoredCount = 0;

    for (final project in projects) {
      final health = healthCache[project.path];
      if (health != null) {
        final score = health.details.totalScore;
        totalScore += score;
        scoredCount++;
        if (score >= 80) {
          healthy++;
        } else if (score >= 50) {
          attention++;
        } else {
          critical++;
        }
      } else {
        unscored++;
      }
    }

    _sendJson(request, {
      'totalProjects': projects.length,
      'healthy': healthy,
      'needsAttention': attention,
      'critical': critical,
      'unscored': unscored,
      'averageScore':
          scoredCount > 0 ? (totalScore / scoredCount).round() : 0,
    });
  }

  static Future<void> _handleStats(HttpRequest request) async {
    final stats = await StatsService.generateStats();
    _sendJson(request, stats.toJson());
  }

  static Future<void> _handleStatus(HttpRequest request) async {
    final projects = await ProjectStorage.loadProjects();
    final statuses = <Map<String, dynamic>>[];

    for (final project in projects) {
      final isGit = await GitService.isGitRepository(project.path);
      if (!isGit) continue;

      final uncommitted =
          await GitService.hasUncommittedChanges(project.path);
      final unpushed =
          await GitService.getUnpushedCommitCount(project.path);

      if (uncommitted || unpushed > 0) {
        statuses.add({
          'name': project.name,
          'path': project.path,
          'hasUncommitted': uncommitted,
          'unpushedCount': unpushed,
        });
      }
    }

    _sendJson(request, {
      'dirtyProjects': statuses,
      'count': statuses.length,
      'totalProjects': projects.length,
    });
  }

  static Future<void> _handleScan(HttpRequest request) async {
    final result = await ProjectScanner.scanAndAddProjects(maxDepth: 3);
    _sendJson(request, {
      'totalFound': result.totalFound,
      'newlyAdded': result.newlyAdded,
      'alreadyExists': result.alreadyExists,
    });
  }

  // ── Helpers ──

  static void _sendJson(HttpRequest request, dynamic data, {int status = 200}) {
    request.response.statusCode = status;
    request.response.write(const JsonEncoder.withIndent('  ').convert(data));
    request.response.close();
  }

  static void _sendError(HttpRequest request, int status, String message) {
    request.response.statusCode = status;
    request.response.write(jsonEncode({'error': message}));
    request.response.close();
  }
}
