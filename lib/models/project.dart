class Project {
  final String name;
  final String path;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final bool isPinned;
  final List<String> tags;
  final String? notes;

  Project({
    required this.name,
    required this.path,
    required this.addedAt,
    this.lastOpenedAt,
    this.isPinned = false,
    this.tags = const [],
    this.notes,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      name: json['name'] as String,
      path: json['path'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastOpenedAt: json['lastOpenedAt'] != null
          ? DateTime.parse(json['lastOpenedAt'] as String)
          : null,
      isPinned: json['isPinned'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'addedAt': addedAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      'isPinned': isPinned,
      'tags': tags,
      'notes': notes,
    };
  }

  Project copyWith({
    DateTime? lastOpenedAt,
    bool? isPinned,
    List<String>? tags,
    String? notes,
    bool clearNotes = false,
  }) {
    return Project(
      name: name,
      path: path,
      addedAt: addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      isPinned: isPinned ?? this.isPinned,
      tags: tags ?? this.tags,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}
