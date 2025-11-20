import 'package:flutter_test/flutter_test.dart';
import 'package:safeguard_ai_app/main.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    // Build our app and ensure it renders
    await tester.pumpWidget(const SafeGuardApp());
    expect(find.byType(SafeGuardApp), findsOneWidget);
  });
}