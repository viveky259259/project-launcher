class Project {
  final String name;
  final String path;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;

  Project({
    required this.name,
    required this.path,
    required this.addedAt,
    this.lastOpenedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      name: json['name'] as String,
      path: json['path'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastOpenedAt: json['lastOpenedAt'] != null
          ? DateTime.parse(json['lastOpenedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'addedAt': addedAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
    };
  }

  Project copyWith({DateTime? lastOpenedAt}) {
    return Project(
      name: name,
      path: path,
      addedAt: addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}
