import 'dart:convert';
import 'dart:io';
import '../models/project.dart';

class ProjectStorage {
  static const String _fileName = 'projects.json';

  static String get _filePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.project_launcher/$_fileName';
  }

  static Future<void> _ensureDirectoryExists() async {
    final home = Platform.environment['HOME'] ?? '';
    final dir = Directory('$home/.project_launcher');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static Future<List<Project>> loadProjects() async {
    try {
      await _ensureDirectoryExists();
      final file = File(_filePath);
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      if (content.isEmpty) {
        return [];
      }
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((j) => Project.fromJson(j)).toList();
    } catch (e) {
      print('Error loading projects: $e');
      return [];
    }
  }

  static Future<void> saveProjects(List<Project> projects) async {
    try {
      await _ensureDirectoryExists();
      final file = File(_filePath);
      final jsonList = projects.map((p) => p.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('Error saving projects: $e');
    }
  }

  static Future<void> addProject(Project project) async {
    final projects = await loadProjects();
    // Check if project already exists
    if (projects.any((p) => p.path == project.path)) {
      return;
    }
    projects.add(project);
    await saveProjects(projects);
  }

  static Future<void> removeProject(String path) async {
    final projects = await loadProjects();
    projects.removeWhere((p) => p.path == path);
    await saveProjects(projects);
  }

  static Future<void> updateLastOpened(String path) async {
    final projects = await loadProjects();
    final index = projects.indexWhere((p) => p.path == path);
    if (index != -1) {
      projects[index] = projects[index].copyWith(lastOpenedAt: DateTime.now());
      await saveProjects(projects);
    }
  }
}
