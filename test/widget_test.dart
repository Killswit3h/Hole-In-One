import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golf_swing_analyzer/main.dart';

void main() {
  testWidgets('App launches and shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GolfSwingApp());

    // Verify home screen renders with expected text
    expect(find.text('Golf Swing\nAnalyzer'), findsOneWidget);
    expect(find.text('Record Swing'), findsOneWidget);
    expect(find.text('View Past Swings'), findsOneWidget);
  });
}
