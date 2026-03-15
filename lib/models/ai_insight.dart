/// A Claude skill — either user-installed from ~/.claude/skills/, a built-in Claude capability,
/// or a CLI-discovered skill from the `system/init` event.
class ClaudeSkill {
  final String name;
  final String? description;
  final String path;
  final bool isBuiltIn;
  final bool isCLIDiscovered;
  /// For built-in skills, the prompt to send to Claude CLI instead of "/skillName".
  final String? prompt;

  ClaudeSkill({
    required this.name,
    this.description,
    this.path = '',
    this.isBuiltIn = false,
    this.isCLIDiscovered = false,
    this.prompt,
  });
}

/// A persisted result from running a Claude skill on a project.
class AIInsight {
  final String skillName;
  final String output;
  final DateTime createdAt;
  final int durationSeconds;
  final bool isError;

  AIInsight({
    required this.skillName,
    required this.output,
    required this.createdAt,
    required this.durationSeconds,
    this.isError = false,
  });

  factory AIInsight.fromJson(Map<String, dynamic> json) {
    return AIInsight(
      skillName: json['skillName'] as String,
      output: json['output'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      durationSeconds: json['durationSeconds'] as int,
      isError: json['isError'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skillName': skillName,
      'output': output,
      'createdAt': createdAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'isError': isError,
    };
  }
}
