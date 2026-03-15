import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import '../models/project.dart';
import 'app_logger.dart';
import 'platform_helper.dart';

class ProjectStorage {
  static const _tag = 'Storage';
  static const String _fileName = 'projects.json';
  static int _lastCount = -1;

  static String get _filePath {
    return '${PlatformHelper.dataDir}${Platform.pathSeparator}$_fileName';
  }

  static Future<void> _ensureDirectoryExists() async {
    final dir = Directory(PlatformHelper.dataDir);
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
      final projects = jsonList.map((j) => Project.fromJson(j)).toList();
      if (_lastCount != projects.length) {
        AppLogger.info(_tag, 'Loaded ${projects.length} projects');
        _lastCount = projects.length;
      }
      return projects;
    } catch (e) {
      log('Error loading projects: $e');
      AppLogger.error(_tag, 'Failed to load projects: $e');
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
      log('Error saving projects: $e');
      AppLogger.error(_tag, 'Failed to save projects: $e');
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

  static Future<void> togglePinned(String path) async {
    final projects = await loadProjects();
    final index = projects.indexWhere((p) => p.path == path);
    if (index != -1) {
      projects[index] = projects[index].copyWith(isPinned: !projects[index].isPinned);
      await saveProjects(projects);
    }
  }

  static Future<void> updateTags(String path, List<String> tags) async {
    final projects = await loadProjects();
    final index = projects.indexWhere((p) => p.path == path);
    if (index != -1) {
      projects[index] = projects[index].copyWith(tags: tags);
      await saveProjects(projects);
    }
  }

  static Future<void> updateNotes(String path, String? notes) async {
    final projects = await loadProjects();
    final index = projects.indexWhere((p) => p.path == path);
    if (index != -1) {
      if (notes == null || notes.isEmpty) {
        projects[index] = projects[index].copyWith(clearNotes: true);
      } else {
        projects[index] = projects[index].copyWith(notes: notes);
      }
      await saveProjects(projects);
    }
  }

  static Future<List<String>> getAllTags() async {
    final projects = await loadProjects();
    final tags = <String>{};
    for (final p in projects) {
      tags.addAll(p.tags);
    }
    return tags.toList()..sort();
  }
}
