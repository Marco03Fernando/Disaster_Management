import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';

import '../../helpers/test_helpers.dart';

/// Widget tests for the "Warning dispatched" screen: delivery status per
/// channel, retry on the fallback channel, and escalation.
void main() {
  late AppState state;

  /// A warning with known numbers: 240 targeted over three channels, 230
  /// reached, 10 failed (all on push).
  HazardWarning withFailures({WarningLevel level = WarningLevel.warning}) =>
      sampleWarning(
        id: 'HW-F1',
        recipientCount: 100,
        level: level,
        deliveries: [
          delivery(AlertChannel.push, targeted: 100, failed: 10),
          delivery(AlertChannel.sms, targeted: 100),
          delivery(AlertChannel.audible, targeted: 40),
        ],
      );

  Future<void> open(WidgetTester tester, HazardWarning warning) async {
    state = await createAppStateInWidgetTest(tester);
    await addWarning(tester, state, warning);
    await pumpApp(tester, state, '/officer/warnings/delivery/${warning.id}');
  }

  HazardWarning stored(String id) =>
      state.warnings.firstWhere((w) => w.id == id);

  /// Lets the simulated 900 ms gateway round trip and the follow-up UI settle.
  Future<void> waitForGateway(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  }

  group('summary', () {
    testWidgets('shows the warning id, level, hazard, severity and area',
        (tester) async {
      await open(tester, withFailures());

      expect(find.text('Warning dispatched'), findsOneWidget);
      expect(find.textContaining('HW-F1'), findsOneWidget);
      expect(find.text('WARNING SENT'), findsOneWidget);
      expect(find.text('Warning · Take action now'), findsOneWidget);
      expect(find.textContaining('Rising river / flood · High severity'),
          findsOneWidget);
      expect(find.textContaining('Kelani river basin'), findsOneWidget);
    });

    testWidgets('computes recipients, share reached and failures',
        (tester) async {
      await open(tester, withFailures());

      expect(find.text('100'), findsOneWidget); // recipients
      expect(find.text('95.8%'), findsOneWidget); // 230 of 240
      expect(find.text('10'), findsWidgets); // failed
      expect(find.text('Recipients'), findsOneWidget);
      expect(find.text('Reached'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('shows a card for every channel, audible counted separately',
        (tester) async {
      await open(tester, withFailures());

      expect(find.text('Push notification'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Audible alert'), findsOneWidget);
      expect(find.text('100 targeted'), findsNWidgets(2)); // push + SMS
      expect(find.text('40 with app in background'), findsOneWidget);
      expect(find.text('90 delivered'), findsOneWidget);
      expect(find.text('10 failed · network unavailable'), findsOneWidget);
    });

    testWidgets('the level bar and escalation badge reflect the level',
        (tester) async {
      await open(
          tester,
          sampleWarning(
              id: 'HW-E2',
              level: WarningLevel.watch,
              escalations: 2,
              deliveries: [delivery(AlertChannel.push, targeted: 10)]));

      expect(find.text('Watch · Be prepared'), findsOneWidget);
      expect(find.text('Escalated ×2'), findsOneWidget);
    });

    testWidgets('an unknown warning id shows only a Back button',
        (tester) async {
      state = await createAppStateInWidgetTest(tester);
      await pumpApp(tester, state, '/officer/warnings/delivery/HW-NOPE');

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Warning dispatched'), findsNothing);
    });
  });

  group('delivery failures and retry', () {
    testWidgets('failures raise a banner with a resend action',
        (tester) async {
      await open(tester, withFailures());

      expect(find.text('10 failed'), findsOneWidget); // header badge
      expect(find.text('10 deliveries failed'), findsOneWidget);
      expect(find.text('Resend on fallback channel'), findsOneWidget);
    });

    testWidgets('resending recovers citizens and records the fallback',
        (tester) async {
      await open(tester, withFailures());

      await tester.tap(find.text('Resend on fallback channel'));
      await waitForGateway(tester);

      final push = stored('HW-F1')
          .deliveries
          .firstWhere((d) => d.channel == AlertChannel.push);
      expect(push.recovered, 9); // round(10 * 0.92)
      expect(push.failed, 1);
      expect(push.fallback, AlertChannel.sms);
      expect(find.text('Resend on fallback channel'), findsNothing,
          reason: 'only one retry round is offered');
      expect(find.text('9 recovered via SMS'), findsOneWidget);
      expect(
        find.text(
            'Resent on fallback channel · delivery status updated'),
        findsOneWidget,
      );
    });

    testWidgets('citizens still unreachable after the retry are explained',
        (tester) async {
      await open(tester, withFailures());

      await tester.tap(find.text('Resend on fallback channel'));
      await waitForGateway(tester);

      expect(find.textContaining('1 citizens remain unreachable'),
          findsOneWidget);
    });

    testWidgets('a button shows progress while the resend is running',
        (tester) async {
      await open(tester, withFailures());

      await tester.tap(find.text('Resend on fallback channel'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(stored('HW-F1').failedCount, 10, reason: 'not updated yet');

      await waitForGateway(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('no failures: everything delivered and no retry offered',
        (tester) async {
      await open(
          tester,
          sampleWarning(id: 'HW-OK', deliveries: [
            delivery(AlertChannel.push, targeted: 100),
            delivery(AlertChannel.sms, targeted: 100),
          ]));

      expect(find.text('All delivered'), findsOneWidget);
      expect(find.text('Resend on fallback channel'), findsNothing);
      expect(find.textContaining('remain unreachable'), findsNothing);
      expect(find.text('100.0%'), findsOneWidget);
    });

    testWidgets('a successful earlier retry shows a success note',
        (tester) async {
      await open(
          tester,
          sampleWarning(id: 'HW-R', deliveries: [
            delivery(AlertChannel.push,
                targeted: 100, recovered: 5, fallback: AlertChannel.sms)
                .copyWith(failed: 0),
          ]));

      expect(find.text('Retry succeeded. Every recipient has now been reached.'),
          findsOneWidget);
    });

    testWidgets('a warning with no deliveries recorded still renders',
        (tester) async {
      await open(tester, sampleWarning(id: 'HW-EMPTY', deliveries: const []));

      expect(find.text('Warning dispatched'), findsOneWidget);
      expect(find.text('All delivered'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget,
          reason: 'nothing targeted counts as fully reached');
    });
  });

  group('escalation', () {
    testWidgets('offers escalation to the next level', (tester) async {
      await open(tester, withFailures());

      expect(find.text('Conditions worsen · Escalate to Evacuate'),
          findsOneWidget);
    });

    testWidgets('asks for confirmation naming both levels and the audience',
        (tester) async {
      await open(tester, withFailures());

      await tester.tap(find.textContaining('Conditions worsen'));
      await tester.pumpAndSettle();

      expect(find.text('Escalate to Evacuate?'), findsOneWidget);
      expect(
        find.text(
            'The warning level will be raised from Warning to Evacuate and re-broadcast to the same 100 recipients.'),
        findsOneWidget,
      );
    });

    testWidgets('Cancel leaves the warning untouched', (tester) async {
      await open(tester, withFailures());
      await tester.tap(find.textContaining('Conditions worsen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Escalate to Evacuate?'), findsNothing);
      expect(stored('HW-F1').level, WarningLevel.warning);
      expect(stored('HW-F1').escalations, 0);
    });

    testWidgets('confirming raises the level and re-broadcasts',
        (tester) async {
      await open(tester, withFailures());
      await tester.tap(find.textContaining('Conditions worsen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Escalate & resend'));
      await waitForGateway(tester);

      expect(stored('HW-F1').level, WarningLevel.evacuate);
      expect(stored('HW-F1').escalations, 1);
      expect(find.text('Evacuate · Leave immediately'), findsOneWidget);
      expect(find.text('Escalated ×1'), findsOneWidget);
      expect(find.text('Escalated to Evacuate · alert re-broadcast'),
          findsOneWidget);
    });

    testWidgets('the escalate button disappears at the highest level',
        (tester) async {
      await open(tester, withFailures());
      await tester.tap(find.textContaining('Conditions worsen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escalate & resend'));
      await waitForGateway(tester);

      expect(find.textContaining('Conditions worsen'), findsNothing);
    });

    testWidgets('a warning already at Evacuate cannot be escalated',
        (tester) async {
      await open(tester, withFailures(level: WarningLevel.evacuate));

      expect(find.textContaining('Conditions worsen'), findsNothing);
    });

    testWidgets('each level offers the next one by name', (tester) async {
      await open(tester, withFailures(level: WarningLevel.advisory));

      expect(find.text('Conditions worsen · Escalate to Watch'),
          findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('Dashboard returns to the officer home', (tester) async {
      await open(tester, withFailures());

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Duty officer console'), findsOneWidget);
    });

    testWidgets('Citizen view opens the citizen home', (tester) async {
      await open(tester, withFailures());

      await tester.tap(find.text('Citizen view'));
      await tester.pumpAndSettle();

      expect(find.text('Warning dispatched'), findsNothing);
    });
  });
}
