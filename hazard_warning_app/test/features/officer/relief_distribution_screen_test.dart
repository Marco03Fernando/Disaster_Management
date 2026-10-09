import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/features/officer/screens/relief_distribution_screen.dart';

void main() {
  setUpAll(() async {
    await AppServices.bootstrap();
  });

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReliefDistributionScreen()),
    );
    await tester.pumpAndSettle();
  }

  group('Relief distribution screen', () {
    testWidgets('shows the relief stock heading and add button',
        (tester) async {
      await openScreen(tester);

      expect(find.text('Relief stock'), findsOneWidget);
      expect(find.text('Add Relief Stock'), findsOneWidget);
    });

    testWidgets('shows stock records or the empty-state message',
        (tester) async {
      await openScreen(tester);

      expect(
        find.text('No relief stock records').evaluate().isNotEmpty ||
            find.byType(Card).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('opens the add relief stock form', (tester) async {
      await openScreen(tester);
      await tester.tap(find.text('Add Relief Stock'));
      await tester.pumpAndSettle();

      expect(find.text('Add Relief Stock'), findsWidgets);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows edit and delete controls when stock exists',
        (tester) async {
      await openScreen(tester);

      final hasStock = find.byType(Card).evaluate().isNotEmpty;
      if (hasStock) {
        expect(find.byTooltip('Edit stock'), findsWidgets);
        expect(find.byTooltip('Delete stock'), findsWidgets);
      } else {
        expect(find.text('No relief stock records'), findsOneWidget);
      }
    });
  });
}
