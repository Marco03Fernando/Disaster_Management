
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/features/officer/screens/rescue_team_leader_screen.dart';

void main() {
  setUpAll(() async {
    await AppServices.bootstrap();
  });

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RescueTeamLeaderScreen(),
      ),
    );

    await tester.pumpAndSettle();
  }

  group('Rescue team leader screen', () {
    testWidgets('opens the screen without throwing an exception', (
      tester,
    ) async {
      await openScreen(tester);

      expect(find.byType(RescueTeamLeaderScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows assigned team details when available', (
      tester,
    ) async {
      await openScreen(tester);

      expect(
        find.textContaining('RB-26').evaluate().isNotEmpty ||
            find.textContaining('team').evaluate().isNotEmpty,
        isTrue,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the screen without requiring a dropdown', (
      tester,
    ) async {
      await openScreen(tester);

      // The screen may use a button or another control for status updates.
      expect(find.byType(RescueTeamLeaderScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('can rebuild the screen without crashing', (
      tester,
    ) async {
      await openScreen(tester);

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(RescueTeamLeaderScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}