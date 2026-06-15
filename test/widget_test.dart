import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic scaffold smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Halo Test'),
        ),
      ),
    );

    expect(find.text('Halo Test'), findsOneWidget);
  });
}
