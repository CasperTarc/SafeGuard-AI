import 'package:flutter_test/flutter_test.dart';
import 'package:safeguard_ai/main.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    // Build the app and wait for any animations/frames to settle.
    await tester.pumpWidget(const SafeGuardUIApp());
    await tester.pumpAndSettle();

    // The root widget should be present.
    expect(find.byType(SafeGuardUIApp), findsOneWidget);

    // Optionally also verify a MaterialApp is present in the tree.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}