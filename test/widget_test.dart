import 'package:flutter_test/flutter_test.dart';

import 'package:project_launcher/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProjectLauncherApp());

    // Verify that the app title is present
    expect(find.text('Project Launcher'), findsOneWidget);
  });
}
