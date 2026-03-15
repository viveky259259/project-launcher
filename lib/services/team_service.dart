import 'dart:convert';
import 'dart:io';
import 'platform_helper.dart';
import 'git_service.dart';
import 'health_service.dart';
import 'project_storage.dart';

/// A team member in a workspace
class TeamMember {
  final String name;
  final String? email;
  final DateTime joinedAt;

  const TeamMember({
    required this.name,
    this.email,
    required this.joinedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        name: json['name'] as String,
        email: json['email'] as String?,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'joinedAt': joinedAt.toIso8601String(),
      };
}

/// A shared project reference in a team workspace
class SharedProject {
  final String name;
  final String localPath;
  final String? remoteUrl;
  final String addedBy;
  final DateTime addedAt;

  const SharedProject({
    required this.name,
    required this.localPath,
    this.remoteUrl,
    required this.addedBy,
    required this.addedAt,
  });

  factory SharedProject.fromJson(Map<String, dynamic> json) => SharedProject(
        name: json['name'] as String,
        localPath: json['localPath'] as String,
        remoteUrl: json['remoteUrl'] as String?,
        addedBy: json['addedBy'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'localPath': localPath,
        'remoteUrl': remoteUrl,
        'addedBy': addedBy,
        'addedAt': addedAt.toIso8601String(),
      };
}

/// An activity event in the team feed
class TeamActivity {
  final String projectName;
  final String projectPath;
  final String type; // 'commit', 'health_change', 'project_added'
  final String description;
  final DateTime timestamp;
  final String? author;

  const TeamActivity({
    required this.projectName,
    required this.projectPath,
    required this.type,
    required this.description,
    required this.timestamp,
    this.author,
  });
}

/// A team workspace
class TeamWorkspace {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final List<TeamMember> members;
  final List<SharedProject> projects;

  const TeamWorkspace({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.members = const [],
    this.projects = const [],
  });

  factory TeamWorkspace.fromJson(Map<String, dynamic> json) => TeamWorkspace(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        members: (json['members'] as List<dynamic>?)
                ?.map((m) => TeamMember.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        projects: (json['projects'] as List<dynamic>?)
                ?.map((p) => SharedProject.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'members': members.map((m) => m.toJson()).toList(),
        'projects': projects.map((p) => p.toJson()).toList(),
      };

  TeamWorkspace copyWith({
    String? name,
    String? description,
    List<TeamMember>? members,
    List<SharedProject>? projects,
  }) =>
      TeamWorkspace(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt,
        members: members ?? this.members,
        projects: projects ?? this.projects,
      );
}

/// Team health summary for a workspace
class TeamHealthSummary {
  final int totalProjects;
  final int healthyCount;
  final int attentionCount;
  final int criticalCount;
  final double avgScore;
  final int totalUnpushed;
  final int totalUncommitted;
  final String? weakestProject;
  final int weakestScore;

  const TeamHealthSummary({
    required this.totalProjects,
    required this.healthyCount,
    required this.attentionCount,
    required this.criticalCount,
    required this.avgScore,
    required this.totalUnpushed,
    required this.totalUncommitted,
    this.weakestProject,
    this.weakestScore = 0,
  });
}

class TeamService {
  static String get _teamsDir =>
      '${PlatformHelper.dataDir}${Platform.pathSeparator}teams';

  /// Load all workspaces
  static Future<List<TeamWorkspace>> loadWorkspaces() async {
    final dir = Directory(_teamsDir);
    if (!await dir.exists()) return [];

    final workspaces = <TeamWorkspace>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          workspaces.add(TeamWorkspace.fromJson(json));
        } catch (_) {}
      }
    }
    workspaces.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return workspaces;
  }

  /// Create a new workspace
  static Future<TeamWorkspace> createWorkspace({
    required String name,
    String? description,
  }) async {
    final dir = Directory(_teamsDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final userName = await _getCurrentUserName();

    final workspace = TeamWorkspace(
      id: id,
      name: name,
      description: description,
      createdAt: DateTime.now(),
      members: [
        TeamMember(name: userName, joinedAt: DateTime.now()),
      ],
    );

    await _saveWorkspace(workspace);
    return workspace;
  }

  /// Save a workspace
  static Future<void> _saveWorkspace(TeamWorkspace workspace) async {
    final file = File(
        '$_teamsDir${Platform.pathSeparator}${workspace.id}.json');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(workspace.toJson()));
  }

  /// Delete a workspace
  static Future<void> deleteWorkspace(String id) async {
    final file = File('$_teamsDir${Platform.pathSeparator}$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Add a project to a workspace from existing projects
  static Future<TeamWorkspace> addProjectToWorkspace(
    TeamWorkspace workspace,
    String projectPath,
  ) async {
    final projects = await ProjectStorage.loadProjects();
    final project = projects.firstWhere(
      (p) => p.path == projectPath,
      orElse: () => throw Exception('Project not found'),
    );

    final remoteUrl = await GitService.getRemoteUrl(projectPath);
    final userName = await _getCurrentUserName();

    final shared = SharedProject(
      name: project.name,
      localPath: projectPath,
      remoteUrl: remoteUrl,
      addedBy: userName,
      addedAt: DateTime.now(),
    );

    final updatedProjects = [...workspace.projects, shared];
    final updated = workspace.copyWith(projects: updatedProjects);
    await _saveWorkspace(updated);
    return updated;
  }

  /// Remove a project from a workspace
  static Future<TeamWorkspace> removeProjectFromWorkspace(
    TeamWorkspace workspace,
    String projectPath,
  ) async {
    final updatedProjects =
        workspace.projects.where((p) => p.localPath != projectPath).toList();
    final updated = workspace.copyWith(projects: updatedProjects);
    await _saveWorkspace(updated);
    return updated;
  }

  /// Get team health summary for a workspace
  static Future<TeamHealthSummary> getTeamHealth(
      TeamWorkspace workspace) async {
    final healthCache = await HealthService.loadCache();

    int healthy = 0, attention = 0, critical = 0;
    int totalScore = 0, scoredCount = 0;
    int totalUnpushed = 0, totalUncommitted = 0;
    String? weakest;
    int weakestScore = 100;

    for (final project in workspace.projects) {
      final cached = healthCache[project.localPath];
      if (cached != null) {
        final score = cached.details.totalScore;
        totalScore += score;
        scoredCount++;

        if (score >= 80) {
          healthy++;
        } else if (score >= 50) {
          attention++;
        } else {
          critical++;
        }

        if (score < weakestScore) {
          weakestScore = score;
          weakest = project.name;
        }
      }

      final isGit = await GitService.isGitRepository(project.localPath);
      if (isGit) {
        final unpushed =
            await GitService.getUnpushedCommitCount(project.localPath);
        if (unpushed > 0) totalUnpushed += unpushed;

        final uncommitted =
            await GitService.hasUncommittedChanges(project.localPath);
        if (uncommitted) totalUncommitted++;
      }
    }

    return TeamHealthSummary(
      totalProjects: workspace.projects.length,
      healthyCount: healthy,
      attentionCount: attention,
      criticalCount: critical,
      avgScore: scoredCount > 0 ? totalScore / scoredCount : 0,
      totalUnpushed: totalUnpushed,
      totalUncommitted: totalUncommitted,
      weakestProject: weakest,
      weakestScore: weakestScore,
    );
  }

  /// Get recent activity across workspace projects
  static Future<List<TeamActivity>> getRecentActivity(
    TeamWorkspace workspace, {
    int limit = 20,
  }) async {
    final activities = <TeamActivity>[];

    for (final project in workspace.projects) {
      final isGit = await GitService.isGitRepository(project.localPath);
      if (!isGit) continue;

      // Get recent commits
      try {
        final result = await Process.run(
          'git',
          ['log', '--oneline', '--format=%H|%an|%s|%aI', '-5'],
          workingDirectory: project.localPath,
        );
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).trim().split('\n');
          for (final line in lines) {
            if (line.isEmpty) continue;
            final parts = line.split('|');
            if (parts.length >= 4) {
              activities.add(TeamActivity(
                projectName: project.name,
                projectPath: project.localPath,
                type: 'commit',
                description: parts[2],
                timestamp: DateTime.tryParse(parts[3]) ?? DateTime.now(),
                author: parts[1],
              ));
            }
          }
        }
      } catch (_) {}

      // Check for uncommitted changes
      final hasChanges =
          await GitService.hasUncommittedChanges(project.localPath);
      if (hasChanges) {
        activities.add(TeamActivity(
          projectName: project.name,
          projectPath: project.localPath,
          type: 'uncommitted',
          description: 'Has uncommitted changes',
          timestamp: DateTime.now(),
        ));
      }
    }

    // Sort by most recent first
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(limit).toList();
  }

  /// Export workspace as shareable JSON
  static Future<String> exportWorkspace(TeamWorkspace workspace) async {
    return const JsonEncoder.withIndent('  ').convert(workspace.toJson());
  }

  /// Import workspace from JSON
  static Future<TeamWorkspace> importWorkspace(String jsonStr) async {
    final dir = Directory(_teamsDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final workspace = TeamWorkspace.fromJson(json);
    await _saveWorkspace(workspace);
    return workspace;
  }

  static Future<String> _getCurrentUserName() async {
    try {
      final result = await Process.run('git', ['config', 'user.name']);
      if (result.exitCode == 0) {
        final name = (result.stdout as String).trim();
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    return Platform.environment['USER'] ??
        Platform.environment['USERNAME'] ??
        'Unknown';
  }
}
