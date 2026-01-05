// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mnee_pulse/main.dart';

void main() {
  testWidgets('App shell shows Earn and Spend tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const MneePulseApp());

    expect(find.text('Earn'), findsOneWidget);
    expect(find.text('Spend'), findsOneWidget);
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_outlined), findsOneWidget);
  });
}
