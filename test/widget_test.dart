import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mnee_pulse/main.dart';

void main() {
  testWidgets('App shell shows Earn and Spend navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const MneePulseApp());

    // Check bottom navigation bar destinations exist
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_outlined), findsOneWidget);

    // Check we can tap Spend tab
    await tester.tap(find.byIcon(Icons.qr_code_scanner_outlined));
    await tester.pumpAndSettle();

    // After tapping Spend, the Spend screen should be visible
    expect(find.text('Scan QR (Simulated QRIS)'), findsOneWidget);
  });
}
