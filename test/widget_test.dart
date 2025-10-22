import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbx/app.dart';

void main() {
  testWidgets('OrbX App smoke test', (WidgetTester tester) async {
    // Build our app
    await tester.pumpWidget(const OrbXApp());

    // Wait for async operations
    await tester.pumpAndSettle();

    // Verify that the app renders without crashing
    expect(find.byType(MaterialApp), findsOneWidget);

    // You can add more specific tests here as you build features
  });
}
