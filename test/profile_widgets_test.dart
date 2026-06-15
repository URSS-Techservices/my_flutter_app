import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state_rich.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_title.dart';

void main() {
  testWidgets('ProfileSectionTitle renders title and trailing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSectionTitle(
            title: 'Social Links',
            trailing: TextButton(onPressed: () {}, child: const Text('Edit')),
          ),
        ),
      ),
    );

    expect(find.text('Social Links'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('ProfileEmptyState renders card text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileEmptyState(
            text: 'No reviews yet',
            card: true,
          ),
        ),
      ),
    );

    expect(find.text('No reviews yet'), findsOneWidget);
  });

  testWidgets('ProfileEmptyStateRich action callback is invoked', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileEmptyStateRich(
            text: 'No goals set yet',
            icon: Icons.flag_outlined,
            actionLabel: 'Set Your First Goal',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('No goals set yet'), findsOneWidget);
    expect(find.text('Set Your First Goal'), findsOneWidget);

    await tester.tap(find.text('Set Your First Goal'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
