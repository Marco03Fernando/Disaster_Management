import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/data/seed_data.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:intl/intl.dart';

import '../../helpers/test_helpers.dart';

/// Widget tests for the Issue Warning form, area selector and confirmation.
void main() {
  late AppState state;

  Future<void> openForm(WidgetTester tester, String reportId) async {
    state = await createAppStateInWidgetTest(tester);
    await pumpApp(tester, state, '/officer/warnings/issue/$reportId');
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// Ticks or unticks an option inside the open area selector sheet (the
  /// same label also appears as a chip on the form behind it).
  Future<void> toggleArea(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(CheckboxListTile, label));
    await tester.pumpAndSettle();
  }

  group('initial state for a flood report (GR-2481)', () {
    testWidgets('shows the verified report, locked hazard type and defaults',
        (tester) async {
      await openForm(tester, 'GR-2481');

      expect(find.text('Issue warning'), findsOneWidget);
      expect(find.text('From verified report GR-2481'), findsOneWidget);
      expect(find.text('Rising river / flood'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
      expect(find.textContaining('Set by verified report GR-2481'),
          findsOneWidget);
    });

    testWidgets('defaults to the Kelani river basin with its recipient count',
        (tester) async {
      await openForm(tester, 'GR-2481');

      expect(find.textContaining('citizens registered in'), findsOneWidget);
      expect(find.text('12,480'), findsOneWidget);
      expect(find.text('citizens registered in Kelani river basin'),
          findsOneWidget);
      expect(find.text('Push'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Audible'), findsOneWidget);
    });

    testWidgets('explains why only the river basin scope is available',
        (tester) async {
      await openForm(tester, 'GR-2481');

      expect(
          find.text(HazardCategory.risingRiver.scopeReason), findsOneWidget);
    });

    testWidgets('a locked scope cannot be changed', (tester) async {
      await openForm(tester, 'GR-2481');

      await tapText(tester, 'Zone');
      await tapText(tester, 'District');

      expect(find.text('citizens registered in Kelani river basin'),
          findsOneWidget, reason: 'still the basin: other scopes are disabled');
    });
  });

  group('unknown report', () {
    testWidgets('shows only a Back button instead of crashing',
        (tester) async {
      await openForm(tester, 'GR-NOPE');

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Issue warning'), findsNothing);
    });
  });

  group('scope and areas for a local hazard (blocked road, GR-2476)', () {
    testWidgets('starts at zone scope with the first zone', (tester) async {
      await openForm(tester, 'GR-2476');

      expect(find.text('Kolonnawa zone'), findsOneWidget);
      expect(find.text('citizens registered in Kolonnawa zone'),
          findsOneWidget);
      expect(find.text('4,200'), findsOneWidget);
    });

    testWidgets('switching to district resets the area and recipients',
        (tester) async {
      await openForm(tester, 'GR-2476');

      await tapText(tester, 'District');

      expect(find.text('Colombo district'), findsOneWidget);
      expect(find.text('28,400'), findsOneWidget);
      expect(find.text('Kolonnawa zone'), findsNothing);
    });

    testWidgets('a scope the hazard does not allow is ignored',
        (tester) async {
      await openForm(tester, 'GR-2476');

      await tapText(tester, 'River basin');

      expect(find.text('Kolonnawa zone'), findsOneWidget);
      expect(find.text('4,200'), findsOneWidget);
    });

    testWidgets('the area selector lists every zone with its count',
        (tester) async {
      await openForm(tester, 'GR-2476');

      await tapText(tester, 'Add or remove zone areas');

      expect(find.text('Affected zone areas'), findsOneWidget);
      expect(find.text('Sedawatta zone'), findsOneWidget);
      expect(find.text('2,650 registered citizens'), findsOneWidget);
      expect(find.text('No registered citizens'), findsOneWidget,
          reason: 'Mutwal harbour zone');
    });

    testWidgets('selecting a second area adds its citizens to the total',
        (tester) async {
      await openForm(tester, 'GR-2476');
      await tapText(tester, 'Add or remove zone areas');

      await toggleArea(tester, 'Sedawatta zone');
      expect(find.text('2 selected · 6,850 citizens'), findsOneWidget);
      await tapText(tester, '2 selected · 6,850 citizens');

      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('6,850'), findsOneWidget);
      expect(find.text('citizens registered in 2 selected areas'),
          findsOneWidget);
      expect(find.textContaining('2 areas · 6,850 registered citizens'),
          findsOneWidget);
    });

    testWidgets('the last remaining area cannot be unticked', (tester) async {
      await openForm(tester, 'GR-2476');
      await tapText(tester, 'Add or remove zone areas');

      await toggleArea(tester, 'Kolonnawa zone');

      expect(find.text('1 selected · 4,200 citizens'), findsOneWidget);
    });

    testWidgets('Select all picks every area and Clear returns to one',
        (tester) async {
      await openForm(tester, 'GR-2476');
      final zones = SeedData.targetAreas(BroadcastScope.zone);
      final total = zones.fold<int>(0, (s, a) => s + a.recipientCount);
      await tapText(tester, 'Add or remove zone areas');

      await tapText(tester, 'Select all');
      expect(
        find.text(
            '${zones.length} selected · ${NumberFormat.decimalPattern().format(total)} citizens'),
        findsOneWidget,
      );

      await tapText(tester, 'Clear');
      expect(find.text('1 selected · 4,200 citizens'), findsOneWidget);
    });

    testWidgets('an area chip can be removed when several are selected',
        (tester) async {
      await openForm(tester, 'GR-2476');
      await tapText(tester, 'Add or remove zone areas');
      await toggleArea(tester, 'Sedawatta zone');
      await tapText(tester, '2 selected · 6,850 citizens');

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing,
          reason: 'with one area left there is nothing to remove');
    });
  });

  group('severity validation', () {
    testWidgets('a rapid-onset hazard cannot be sent as Low severity',
        (tester) async {
      await openForm(tester, 'GR-2491'); // dam overflow

      await tapText(tester, 'Low');
      await tapText(tester, 'Review recipients');

      expect(
        find.text(
            'Dam / reservoir overflow is a rapid-onset hazard. Choose at least Moderate severity.'),
        findsOneWidget,
      );
      expect(find.text('Confirm warning'), findsNothing);
    });

    testWidgets('the error is not shown before the officer tries to continue',
        (tester) async {
      await openForm(tester, 'GR-2491');

      await tapText(tester, 'Low');

      expect(find.textContaining('rapid-onset hazard'), findsNothing);
    });

    testWidgets('raising the severity clears the error and allows review',
        (tester) async {
      await openForm(tester, 'GR-2491');
      await tapText(tester, 'Low');
      await tapText(tester, 'Review recipients');

      await tapText(tester, 'Moderate');
      expect(find.textContaining('rapid-onset hazard'), findsNothing);
      await tapText(tester, 'Review recipients');

      expect(find.text('Confirm warning'), findsOneWidget);
    });

    testWidgets('a slow-onset hazard may be sent as Low severity',
        (tester) async {
      await openForm(tester, 'GR-2481'); // flood

      await tapText(tester, 'Low');
      await tapText(tester, 'Review recipients');

      expect(find.text('Confirm warning'), findsOneWidget);
    });
  });

  group('review and confirm', () {
    testWidgets('summarises hazard, severity, area, recipients and channels',
        (tester) async {
      await openForm(tester, 'GR-2481');

      await tapText(tester, 'Review recipients');

      expect(find.text('Confirm warning'), findsOneWidget);
      expect(find.text('Review who will be alerted before sending.'),
          findsOneWidget);
      expect(find.text('Hazard'), findsOneWidget);
      expect(find.text('High'), findsWidgets);
      expect(find.text('Target area'), findsOneWidget);
      expect(find.text('Recipients'), findsOneWidget);
      expect(find.text('12,480 citizens'), findsOneWidget);
      expect(find.text('Push · SMS · Audible'), findsOneWidget);
      expect(
        find.text('Audible alerts reach only recipients whose app is in the background.'),
        findsOneWidget,
      );
    });

    testWidgets('lists each area when several are selected', (tester) async {
      await openForm(tester, 'GR-2476');
      await tapText(tester, 'Add or remove zone areas');
      await toggleArea(tester, 'Sedawatta zone');
      await tapText(tester, '2 selected · 6,850 citizens');

      await tapText(tester, 'Review recipients');

      expect(find.text('• Kolonnawa zone'), findsOneWidget);
      expect(find.text('• Sedawatta zone'), findsOneWidget);
      expect(find.text('Total recipients'), findsOneWidget);
      expect(find.text('6,850 citizens'), findsOneWidget);
    });

    testWidgets('Go back closes the summary and issues nothing',
        (tester) async {
      await openForm(tester, 'GR-2481');
      await tapText(tester, 'Review recipients');

      await tapText(tester, 'Go back');

      expect(find.text('Confirm warning'), findsNothing);
      expect(find.text('Issue warning'), findsOneWidget);
      expect(state.warnings.length, 2);
    });

    testWidgets('Confirm issues the warning and opens the delivery screen',
        (tester) async {
      await openForm(tester, 'GR-2481');
      await tapText(tester, 'Review recipients');

      await tapText(tester, 'Confirm & send warning');

      expect(find.text('Warning dispatched'), findsOneWidget);
      expect(state.warnings.length, 3);
      final w = state.warnings.first;
      expect(w.sourceReportId, 'GR-2481');
      expect(w.category, HazardCategory.risingRiver);
      expect(w.severity, WarningSeverity.high);
      expect(w.level, WarningLevel.warning);
      expect(w.scope, BroadcastScope.riverBasin);
      expect(w.targetAreas, ['Kelani river basin']);
      expect(w.recipientCount, 12480);
    });

    testWidgets('the chosen severity decides the starting level',
        (tester) async {
      await openForm(tester, 'GR-2481');
      await tapText(tester, 'Moderate');
      await tapText(tester, 'Review recipients');

      await tapText(tester, 'Confirm & send warning');

      expect(state.warnings.first.severity, WarningSeverity.moderate);
      expect(state.warnings.first.level, WarningLevel.watch);
    });

    testWidgets('a warning for several areas stores every area and the total',
        (tester) async {
      await openForm(tester, 'GR-2476');
      await tapText(tester, 'Add or remove zone areas');
      await toggleArea(tester, 'Sedawatta zone');
      await tapText(tester, '2 selected · 6,850 citizens');
      await tapText(tester, 'Review recipients');

      await tapText(tester, 'Confirm & send warning');

      final w = state.warnings.first;
      expect(w.targetAreas, ['Kolonnawa zone', 'Sedawatta zone']);
      expect(w.recipientCount, 6850);
      expect(w.scope, BroadcastScope.zone);
    });

    testWidgets('the warned report no longer awaits a warning',
        (tester) async {
      await openForm(tester, 'GR-2481');
      await tapText(tester, 'Review recipients');

      await tapText(tester, 'Confirm & send warning');

      expect(state.verifiedAwaitingWarning.map((r) => r.id),
          isNot(contains('GR-2481')));
    });
  });

  group('area with no registered citizens', () {
    Future<void> selectOnlyMutwal(WidgetTester tester) async {
      await tapText(tester, 'Add or remove zone areas');
      await toggleArea(tester, 'Mutwal harbour zone');
      await toggleArea(tester, 'Kolonnawa zone');
      await tapText(tester, '1 selected · 0 citizens');
    }

    testWidgets('the form warns that no alert will be sent', (tester) async {
      await openForm(tester, 'GR-2476');

      await selectOnlyMutwal(tester);

      expect(find.text('No citizens in this area'), findsOneWidget);
      expect(find.textContaining('no alert will be sent'), findsOneWidget);
      expect(find.textContaining('citizens registered in'), findsNothing);
    });

    testWidgets('review reports an empty list and dispatches nothing',
        (tester) async {
      await openForm(tester, 'GR-2476');
      await selectOnlyMutwal(tester);

      await tapText(tester, 'Review recipients');

      expect(find.text('Empty recipient list'), findsOneWidget);
      expect(find.textContaining('no registered citizens in Mutwal harbour zone'),
          findsOneWidget);
      expect(find.text('Confirm & send warning'), findsNothing);
      expect(state.warnings.length, 2);
    });

    testWidgets('Change target area returns to the form', (tester) async {
      await openForm(tester, 'GR-2476');
      await selectOnlyMutwal(tester);
      await tapText(tester, 'Review recipients');

      await tapText(tester, 'Change target area');

      expect(find.text('Empty recipient list'), findsNothing);
      expect(find.text('Issue warning'), findsOneWidget);
      expect(state.warnings.length, 2);
    });
  });
}
