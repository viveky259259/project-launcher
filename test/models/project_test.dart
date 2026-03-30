import 'package:flutter_test/flutter_test.dart';
import 'package:launcher_models/launcher_models.dart';

void main() {
  group('Project', () {
    final now = DateTime(2026, 3, 29);

    Project makeProject({
      String name = 'test-project',
      String path = '/Users/test/projects/test-project',
      bool isPinned = false,
      List<String> tags = const [],
      String? notes,
    }) {
      return Project(
        name: name,
        path: path,
        addedAt: now,
        isPinned: isPinned,
        tags: tags,
        notes: notes,
      );
    }

    test('fromJson creates a valid project', () {
      final json = {
        'name': 'my-app',
        'path': '/Users/test/my-app',
        'addedAt': '2026-03-29T00:00:00.000',
        'isPinned': true,
        'tags': ['flutter', 'mobile'],
        'notes': 'Main project',
      };

      final project = Project.fromJson(json);

      expect(project.name, 'my-app');
      expect(project.path, '/Users/test/my-app');
      expect(project.isPinned, true);
      expect(project.tags, ['flutter', 'mobile']);
      expect(project.notes, 'Main project');
      expect(project.lastOpenedAt, isNull);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'name': 'minimal',
        'path': '/tmp/minimal',
        'addedAt': '2026-01-01T00:00:00.000',
      };

      final project = Project.fromJson(json);

      expect(project.isPinned, false);
      expect(project.tags, isEmpty);
      expect(project.notes, isNull);
      expect(project.lastOpenedAt, isNull);
    });

    test('toJson roundtrips correctly', () {
      final project = makeProject(
        isPinned: true,
        tags: ['dart'],
        notes: 'A note',
      );

      final json = project.toJson();
      final restored = Project.fromJson(json);

      expect(restored.name, project.name);
      expect(restored.path, project.path);
      expect(restored.isPinned, project.isPinned);
      expect(restored.tags, project.tags);
      expect(restored.notes, project.notes);
    });

    test('copyWith updates specified fields only', () {
      final original = makeProject(tags: ['old']);
      final updated = original.copyWith(
        isPinned: true,
        tags: ['new', 'tags'],
      );

      expect(updated.isPinned, true);
      expect(updated.tags, ['new', 'tags']);
      expect(updated.name, original.name);
      expect(updated.path, original.path);
      expect(updated.notes, original.notes);
    });

    test('copyWith clearNotes removes notes', () {
      final project = makeProject(notes: 'Some notes');
      final cleared = project.copyWith(clearNotes: true);

      expect(cleared.notes, isNull);
    });

    test('equality is based on path', () {
      final a = makeProject(name: 'a', path: '/same/path');
      final b = makeProject(name: 'b', path: '/same/path');
      final c = makeProject(name: 'a', path: '/different/path');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });
  });
}
