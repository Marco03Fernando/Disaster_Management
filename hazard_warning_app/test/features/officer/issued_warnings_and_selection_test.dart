import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/features/officer/widgets/escalate_warning.dart';
import 'package:provider/provider.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late AppState state;

  Future<void> waitForGateway(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  }

  group('Select report for warning', () {
    Future<void> open(WidgetTester tester) async {
      state = await createAppStateInWidgetTest(tester);
      await pumpApp(tester, state, '/officer/warnings/select');
    }

    testWidgets('lists only verified reports that still need a warning',
        (tester) async {
      await open(tester);

      expect(find.text('Issue hazard warning'), findsOneWidget);
      expect(find.text('4 verified'), findsOneWidget);
      expect(find.text('GR-2481'), findsOneWidget);
      expect(find.text('GR-2488'), findsOneWidget);
      expect(find.text('GR-2495'), findsOneWidget);
      expect(find.text('GR-2491'), findsOneWidget);
      // already warned, pending and rejected reports are not offered
      expect(find.text('GR-2465'), findsNothing);
      expect(find.text('GR-2440'), findsNothing);
      expect(find.text('GR-2476'), findsNothing);
      expect(find.text('GR-2459'), findsNothing);
    });

    testWidgets('the most recently verified report comes first',
        (tester) async {
      await open(tester);

      double top(String id) => tester.getTopLeft(find.text(id)).dy;
      // verified: GR-2495 1h ago, GR-2488 2h10, GR-2491 3h30, GR-2481 4h20
      expect(top('GR-2495'), lessThan(top('GR-2488')));
      expect(top('GR-2488'), lessThan(top('GR-2491')));
      expect(top('GR-2491'), lessThan(top('GR-2481')));
    });

    testWidgets('each card shows the hazard and where it was seen',
        (tester) async {
      await open(tester);

      expect(find.text('Dam / reservoir overflow'), findsOneWidget);
      expect(find.text('Kukule Ganga reservoir spill gates'), findsOneWidget);
      expect(find.textContaining('Verified'), findsNWidgets(4));
    });

    testWidgets('tapping a report opens the warning form for it',
        (tester) async {
      await open(tester);

      await tester.tap(find.text('GR-2488'));
      await tester.pumpAndSettle();

      expect(find.text('Issue warning'), findsOneWidget);
      expect(find.text('From verified report GR-2488'), findsOneWidget);
    });

    testWidgets('a report disappears from the list once it has a warning',
        (tester) async {
      await open(tester);

      await state.issueWarning(
        report: state.reports.firstWhere((r) => r.id == 'GR-2481'),
        category: HazardCategory.risingRiver,
        severity: WarningSeverity.high,
        scope: BroadcastScope.riverBasin,
        targetAreas: const ['Kelani river basin'],
        recipientCount: 12480,
      );
      await tester.pumpAndSettle();

      expect(find.text('GR-2481'), findsNothing);
      expect(find.text('3 verified'), findsOneWidget);
    });

    testWidgets('shows an empty state with a way to verify more reports',
        (tester) async {
      state = await createAppStateInWidgetTest(tester);
      for (final r in [...state.verifiedAwaitingWarning]) {
        await state.issueWarning(
          report: r,
          category: r.category,
          severity: WarningSeverity.moderate,
          scope: r.category.allowedScopes.first,
          targetAreas: const ['x'],
          recipientCount: 1,
        );
      }
      await tester.pump();
      await pumpApp(tester, state, '/officer/warnings/select');

      expect(find.text('No reports need a warning'), findsOneWidget);

      await tester.tap(find.text('Go to pending reports'));
      await tester.pumpAndSettle();

      expect(find.text('Pending reports'), findsOneWidget);
    });
  });

  group('Issued warnings', () {
    Future<void> open(WidgetTester tester) async {
      state = await createAppStateInWidgetTest(tester);
      await pumpApp(tester, state, '/officer/warnings');
    }

    testWidgets('shows the overview and a card for every warning',
        (tester) async {
      await open(tester);

      expect(find.text('Issued warnings'), findsOneWidget);
      expect(find.text('ALL-TIME OVERVIEW'), findsOneWidget);
      expect(find.text('Warnings'), findsOneWidget);
      expect(find.text('Citizens alerted'), findsOneWidget);
      expect(find.text('Delivery rate'), findsOneWidget);
      expect(find.text('Failed deliveries'), findsOneWidget);
      expect(find.text('Escalated'), findsOneWidget);
      expect(find.textContaining('HW-1042'), findsOneWidget);
      expect(find.textContaining('HW-1031'), findsOneWidget);
    });

    testWidgets('newest warning is listed first', (tester) async {
      await open(tester);

      double top(String id) => tester.getTopLeft(find.textContaining(id)).dy;
      expect(top('HW-1042'), lessThan(top('HW-1031')));
    });

    testWidgets('a warning below the top level offers the next level',
        (tester) async {
      await open(tester);

      expect(find.text('Escalate to Warning'), findsOneWidget); // HW-1042
    });

    testWidgets('a warning at the top level is marked as such',
        (tester) async {
      await open(tester);

      expect(find.text('Highest level'), findsOneWidget); // HW-1031
      expect(find.textContaining('escalated ×2'), findsOneWidget);
    });

    testWidgets('escalating from the list confirms, then updates the card',
        (tester) async {
      await open(tester);

      await tester.tap(find.text('Escalate to Warning'));
      await tester.pumpAndSettle();
      expect(find.text('Escalate to Warning?'), findsOneWidget);
      await tester.tap(find.text('Escalate & resend'));
      await waitForGateway(tester);

      final w = state.warnings.firstWhere((w) => w.id == 'HW-1042');
      expect(w.level, WarningLevel.warning);
      expect(w.escalations, 1);
      expect(find.text('Escalate to Evacuate'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation changes nothing', (tester) async {
      await open(tester);

      await tester.tap(find.text('Escalate to Warning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final w = state.warnings.firstWhere((w) => w.id == 'HW-1042');
      expect(w.level, WarningLevel.watch);
      expect(find.text('Escalate to Warning'), findsOneWidget);
    });

    testWidgets('tapping a card opens its delivery status', (tester) async {
      await open(tester);

      await tester.tap(find.textContaining('HW-1042'));
      await tester.pumpAndSettle();

      expect(find.text('Warning dispatched'), findsOneWidget);
    });

    testWidgets('with no warnings it shows an empty state and a way to issue',
        (tester) async {
      state = await createAppStateInWidgetTest(tester,
          repository: NoWarningsRepository());
      await pumpApp(tester, state, '/officer/warnings');

      expect(find.text('No warnings issued yet'), findsOneWidget);
      expect(find.text('ALL-TIME OVERVIEW'), findsNothing);

      await tester.tap(find.text('Issue a warning'));
      await tester.pumpAndSettle();

      expect(find.text('Select a verified report to warn about'),
          findsOneWidget);
    });
  });

  group('escalateWithConfirmation', () {
    Future<bool?> run(WidgetTester tester, HazardWarning warning,
        {required Future<void> Function() tapDialog}) async {
      state = await createAppStateInWidgetTest(tester);
      await addWarning(tester, state, warning);
      bool? result;
      final busy = <bool>[];
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => result = await escalateWithConfirmation(
                      context, warning,
                      onBusy: busy.add),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tapDialog();
      expect(busy, anyOf(isEmpty, [true, false]));
      return result;
    }

    testWidgets('returns true after the officer confirms', (tester) async {
      final result = await run(tester, sampleWarning(), tapDialog: () async {
        await tester.tap(find.text('Escalate & resend'));
        await waitForGateway(tester);
      });

      expect(result, isTrue);
      expect(state.warnings.firstWhere((w) => w.id == 'HW-T1').level,
          WarningLevel.evacuate);
    });

    testWidgets('returns false when the officer cancels', (tester) async {
      final result = await run(tester, sampleWarning(), tapDialog: () async {
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });

      expect(result, isFalse);
      expect(state.warnings.firstWhere((w) => w.id == 'HW-T1').level,
          WarningLevel.warning);
    });

    testWidgets('returns false without a dialog at the highest level',
        (tester) async {
      state = await createAppStateInWidgetTest(tester);
      bool? result;
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => result = await escalateWithConfirmation(
                      context, sampleWarning(level: WarningLevel.evacuate)),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
