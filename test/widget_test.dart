// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_reading_buddy/main.dart';

void main() {
  testWidgets('Smart Reading Buddy app smoke test', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartReadingBuddy());

    // Verify that splash screen appears with owl emoji
    expect(find.text('🦉'), findsOneWidget);
    expect(find.text('Smart Reading Buddy'), findsOneWidget);
    expect(find.text('Let\'s Learn Together! 🌟'), findsOneWidget);
  });
}
