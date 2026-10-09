import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';

import '../../helpers/test_helpers.dart';

/// The officer's path into Issue Hazard Warning: dashboard, pending reports,
/// verification, and the citizen-side alert that results.
void main() {
  late AppState state;

  HazardReport report(String id) => state.reports.firstWhere((r) => r.id == id);

  group('Officer home', () {
    Future<void> open(WidgetTester tester) async {
      state = await createAppStateInWidgetTest(tester);
      await pumpApp(tester, state, '/officer/home');
    }

    testWidgets('summarises reports to verify and warnings issued',
        (tester) async {
      await open(tester);

      expect(find.text('Duty officer console'), findsOneWidget);
      expect(find.text('Reports to verify'), findsOneWidget);
      expect(find.text('Warnings issued'), findsOneWidget);
      expect(find.text('3 awaiting verification'), findsOneWidget);
      expect(find.text('4 verified reports awaiting a warning'),
          findsOneWidget);
      expect(find.text('2 issued · statistics & escalation'), findsOneWidget);
    });

    testWidgets('links to the most recent warning', (tester) async {
      await open(tester);

      expect(find.text('Latest: Watch · Gampaha district'), findsOneWidget);

      await tester.tap(find.textContaining('Latest:'));
      await tester.pumpAndSettle();

      expect(find.text('Warning dispatched'), findsOneWidget);
    });

    testWidgets('"Issue hazard warning" opens the report picker',
        (tester) async {
      await open(tester);

      await tester.tap(find.text('Issue hazard warning'));
      await tester.pumpAndSettle();

      expect(find.text('Select a verified report to warn about'),
          findsOneWidget);
    });

    testWidgets('"Issued warnings" opens the issued warnings list',
        (tester) async {
      await open(tester);

      await tester.tap(find.text('Issued warnings'));
      await tester.pumpAndSettle();

      expect(find.text('ALL-TIME OVERVIEW'), findsOneWidget);
    });

    testWidgets('counts update after a warning is issued', (tester) async {
      await open(tester);

      await state.issueWarning(
        report: report('GR-2481'),
        category: HazardCategory.risingRiver,
        severity: WarningSeverity.high,
        scope: BroadcastScope.riverBasin,
        targetAreas: const ['Kelani river basin'],
        recipientCount: 12480,
      );
      await tester.pumpAndSettle();

      expect(find.text('3 verified reports awaiting a warning'),
          findsOneWidget);
      expect(find.text('3 issued · statistics & escalation'), findsOneWidget);
      expect(find.textContaining('Latest: Warning ·'), findsOneWidget);
    });

    testWidgets('uses the singular and an all-clear message when empty',
        (tester) async {
      state = await createAppStateInWidgetTest(tester,
          repository: NoWarningsRepository());
      await pumpApp(tester, state, '/officer/home');

      expect(find.text('No warnings issued yet'), findsOneWidget);
      expect(find.textContaining('Latest:'), findsNothing);
    });

    testWidgets('says so when no verified report is waiting', (tester) async {
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
      await pumpApp(tester, state, '/officer/home');

      expect(find.text('No verified reports waiting'), findsOneWidget);
    });
  });

  group('Pending reports and verification', () {
    Future<void> openPending(WidgetTester tester) async {
      state = await createAppStateInWidgetTest(tester);
      await pumpApp(tester, state, '/officer/reports/pending');
    }

    testWidgets('lists unverified reports only', (tester) async {
      await openPending(tester);

      expect(find.text('3 in queue'), findsOneWidget);
      expect(find.text('GR-2476'), findsOneWidget);
      expect(find.text('GR-2490'), findsOneWidget);
      expect(find.text('GR-2493'), findsOneWidget);
      expect(find.text('GR-2481'), findsNothing);
    });

    testWidgets('an empty queue says it is clear', (tester) async {
      state = await createAppStateInWidgetTest(tester);
      for (final r in [...state.pendingReports]) {
        await state.rejectReport(r.id);
      }
      await tester.pump();
      await pumpApp(tester, state, '/officer/reports/pending');

      expect(find.text('Queue is clear'), findsOneWidget);
    });

    testWidgets('opening a report shows its evidence', (tester) async {
      await openPending(tester);

      await tester.tap(find.text('GR-2476'));
      await tester.pumpAndSettle();

      expect(find.text('Verify report'), findsOneWidget);
      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text('Sedawatta Road junction'), findsOneWidget);
      expect(find.text('Immediate · localized impact'), findsOneWidget);
      expect(find.text('Fallen tree blocking both lanes.'), findsOneWidget);
      expect(find.text('6.9310° N, 79.8950° E'), findsOneWidget);
    });

    testWidgets('verifying marks the report and continues to the warning form',
        (tester) async {
      await openPending(tester);
      await tester.tap(find.text('GR-2476'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark verified & continue'));
      await tester.pumpAndSettle();

      expect(report('GR-2476').status, ReportStatus.verified);
      expect(find.text('From verified report GR-2476'), findsOneWidget);
      expect(state.verifiedAwaitingWarning.map((r) => r.id),
          contains('GR-2476'));
    });

    testWidgets('rejecting marks the report and returns to the queue',
        (tester) async {
      await openPending(tester);
      await tester.tap(find.text('GR-2476'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject report'));
      await tester.pumpAndSettle();

      expect(report('GR-2476').status, ReportStatus.rejected);
      expect(find.text('Pending reports'), findsOneWidget);
      expect(find.text('2 in queue'), findsOneWidget);
      expect(state.verifiedAwaitingWarning.map((r) => r.id),
          isNot(contains('GR-2476')));
    });

    testWidgets('an unknown report id shows only a Back button',
        (tester) async {
      state = await createAppStateInWidgetTest(tester);
      await pumpApp(tester, state, '/officer/reports/GR-NOPE/verify');

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Verify report'), findsNothing);
    });
  });

  group('Citizen alert detail', () {
    Future<void> open(WidgetTester tester, String warningId) async {
      state = await createAppStateInWidgetTest(tester);
      await pumpApp(tester, state, '/citizen/alerts/$warningId');
    }

    testWidgets('shows the official warning text and SMS copy',
        (tester) async {
      await open(tester, 'HW-1042');

      expect(find.text('Official warning'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('Blocked road — Watch'), findsOneWidget);
      expect(
        find.textContaining(
            'WATCH: Moderate severity Blocked road for Gampaha district. Be prepared.'),
        findsWidgets,
      );
      expect(find.text('SMS copy'), findsOneWidget);
      expect(find.textContaining('DMC ALERT [MODERATE]: Blocked road affecting Gampaha district.'),
          findsOneWidget);
    });

    testWidgets('reflects an escalation of the warning', (tester) async {
      await open(tester, 'HW-1042');

      await state.escalateWarning('HW-1042');
      await tester.pumpAndSettle();

      expect(find.text('Blocked road — Warning'), findsOneWidget);
      expect(find.textContaining('Take action now.'), findsWidgets);
    });

    testWidgets('an unknown warning shows only a Back button', (tester) async {
      await open(tester, 'HW-NOPE');

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Official warning'), findsNothing);
    });
  });
}
