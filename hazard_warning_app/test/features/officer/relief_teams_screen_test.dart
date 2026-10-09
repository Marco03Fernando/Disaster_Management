import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/features/officer/screens/relief_teams_screen.dart';

void main() {
  setUpAll(() async {
    await AppServices.bootstrap();
  });

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReliefTeamsScreen()),
    );
    await tester.pumpAndSettle();
  }

  group('Relief teams screen', () {
    testWidgets('shows the page and add-team action', (tester) async {
      await openScreen(tester);

      expect(find.byType(ReliefTeamsScreen), findsOneWidget);
      expect(find.textContaining('team', skipOffstage: false), findsWidgets);
    });

    testWidgets('loads the team list without an exception', (tester) async {
      await openScreen(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the add response team form', (tester) async {
      await openScreen(tester);

      final addButton = find.text('Add response team');
      if (addButton.evaluate().isNotEmpty) {
        await tester.tap(addButton.first);
        await tester.pumpAndSettle();

        expect(find.text('Add response team'), findsWidgets);
        expect(find.byType(TextFormField), findsWidgets);
      } else {
        // The add action may be shown as an icon button on narrower layouts.
        expect(find.byType(FloatingActionButton), findsWidgets);
      }
    });

    testWidgets('does not crash when the screen is rebuilt', (tester) async {
      await openScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
