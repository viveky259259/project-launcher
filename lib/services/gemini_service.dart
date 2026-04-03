import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:launcher_native/launcher_native.dart';

/// Suggested build configuration from Gemini.
class BuildSuggestion {
  final String buildCommand;
  final String outputDir;
  final String explanation;

  const BuildSuggestion({
    required this.buildCommand,
    required this.outputDir,
    required this.explanation,
  });
}

/// Calls Gemini API to analyze projects and suggest build commands.
class GeminiService {
  static const _tag = 'Gemini';
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _model = 'gemini-3.1-flash-lite-preview';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// Whether the API key is configured.
  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Analyze a project directory and suggest build commands.
  static Future<BuildSuggestion?> suggestBuildCommands({
    required String projectPath,
    void Function(String status)? onProgress,
  }) async {
    if (!isConfigured) {
      AppLogger.warn(_tag, 'Gemini API key not configured');
      return null;
    }

    onProgress?.call('Scanning project structure...');

    // Gather project context
    final context = await _gatherProjectContext(projectPath);

    onProgress?.call('Asking Gemini for build commands...');
    AppLogger.info(_tag, 'Requesting build suggestion for ${projectPath.split('/').last}');

    try {
      final response = await http.post(
        Uri.parse('$_endpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''You are a build system expert. Analyze this project and suggest the exact commands to produce a deployable static build (HTML/CSS/JS output).

PROJECT STRUCTURE:
$context

RESPOND IN EXACTLY THIS JSON FORMAT (no markdown, no code fences, just raw JSON):
{
  "build_command": "the full shell command(s) to build the project, separated by &&",
  "output_dir": "relative path to the build output directory containing index.html",
  "explanation": "one-line explanation of what the build does"
}

RULES:
- The build_command should be runnable from the project root directory.
- Include dependency install steps if needed (npm install, flutter pub get, etc).
- The output_dir must be the directory that contains the index.html after build.
- For Flutter web: "flutter build web --release" outputs to "build/web".
- For React/Vite: "npm ci && npm run build" outputs to "dist".
- For Next.js static: "npm ci && next build && next export" outputs to "out".
- For plain HTML: build_command can be "echo 'No build needed'" and output_dir is ".".
- Only respond with the JSON object, nothing else.'''
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 512,
          }
        }),
      );

      if (response.statusCode != 200) {
        AppLogger.error(_tag, 'Gemini API error: ${response.statusCode} ${response.body}');
        onProgress?.call('Gemini API error (${response.statusCode})');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = body['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        AppLogger.warn(_tag, 'No candidates in Gemini response');
        return null;
      }

      final content = candidates[0]['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List<dynamic>;
      var text = (parts[0]['text'] as String).trim();

      // Strip markdown code fences if Gemini wraps them
      if (text.startsWith('```')) {
        text = text.replaceAll(RegExp(r'^```\w*\n?'), '').replaceAll(RegExp(r'\n?```$'), '').trim();
      }

      final parsed = jsonDecode(text) as Map<String, dynamic>;

      final suggestion = BuildSuggestion(
        buildCommand: parsed['build_command'] as String? ?? '',
        outputDir: parsed['output_dir'] as String? ?? 'build',
        explanation: parsed['explanation'] as String? ?? '',
      );

      AppLogger.info(_tag, 'Suggestion: ${suggestion.buildCommand} -> ${suggestion.outputDir}');
      onProgress?.call('Got suggestion: ${suggestion.explanation}');
      return suggestion;
    } catch (e) {
      AppLogger.error(_tag, 'Gemini request failed: $e');
      onProgress?.call('Gemini error: $e');
      return null;
    }
  }

  /// Gather lightweight project context for the prompt.
  static Future<String> _gatherProjectContext(String projectPath) async {
    final buffer = StringBuffer();

    // Top-level file listing
    final dir = Directory(projectPath);
    if (!dir.existsSync()) return 'Directory not found';

    final entries = dir.listSync().map((e) {
      final name = e.path.split('/').last;
      final isDir = e is Directory;
      return isDir ? '$name/' : name;
    }).toList()
      ..sort();
    buffer.writeln('Files: ${entries.join(', ')}');

    // Key config files content (first 30 lines each)
    final configFiles = [
      'pubspec.yaml',
      'package.json',
      'Cargo.toml',
      'Makefile',
      'Dockerfile',
      'build.gradle',
      'pom.xml',
      'Gemfile',
      'requirements.txt',
      'pyproject.toml',
      'go.mod',
      'angular.json',
      'vite.config.ts',
      'vite.config.js',
      'next.config.js',
      'next.config.mjs',
      'astro.config.mjs',
      'nuxt.config.ts',
    ];

    for (final name in configFiles) {
      final file = File('$projectPath/$name');
      if (file.existsSync()) {
        try {
          final lines = file.readAsLinesSync();
          final preview = lines.take(30).join('\n');
          buffer.writeln('\n--- $name ---');
          buffer.writeln(preview);
        } catch (_) {}
      }
    }

    // Check for web/ directory (Flutter web enabled)
    if (Directory('$projectPath/web').existsSync()) {
      buffer.writeln('\nweb/ directory exists (Flutter web enabled)');
    }

    // Check for src/ or lib/ structure
    for (final subdir in ['src', 'lib', 'app', 'pages', 'public']) {
      if (Directory('$projectPath/$subdir').existsSync()) {
        buffer.writeln('$subdir/ directory exists');
      }
    }

    return buffer.toString();
  }
}
