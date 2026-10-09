import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/repositories/local_data_repository.dart';
import 'package:hazard_warning_app/core/services/notification_gateway.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';

import '../../helpers/test_helpers.dart';

void main() {
  const gateway = NotificationGateway();
  late LocalDataRepository repo;
  late AppState state;

  setUp(() async {
    repo = LocalDataRepository();
    state = await createAppState(repository: repo);
  });

  tearDown(() => state.dispose());

  HazardReport report(String id) => state.reports.firstWhere((r) => r.id == id);

  Future<HazardWarning> issue({
    String reportId = 'GR-2481',
    HazardCategory category = HazardCategory.risingRiver,
    WarningSeverity severity = WarningSeverity.high,
    BroadcastScope scope = BroadcastScope.riverBasin,
    List<String> areas = const ['Kelani river basin'],
    int recipients = 12480,
  }) async {
    final warning = await state.issueWarning(
      report: report(reportId),
      category: category,
      severity: severity,
      scope: scope,
      targetAreas: areas,
      recipientCount: recipients,
    );
    await pumpEventQueue();
    return warning;
  }

  HazardWarning stored(String id) =>
      state.warnings.firstWhere((w) => w.id == id);

  group('loading', () {
    test('picks up the seeded reports and warnings', () {
      expect(state.reports, isNotEmpty);
      expect(state.warnings.map((w) => w.id), ['HW-1042', 'HW-1031']);
    });

    test('derives one citizen alert per warning', () {
      expect(state.alerts.map((a) => a.warningId),
          state.warnings.map((w) => w.id));
    });

    test('exposes the repository it was built with', () {
      expect(state.repository, same(repo));
    });
  });

  group('verifiedAwaitingWarning', () {
    test('contains verified reports that have no warning yet', () {
      expect(state.verifiedAwaitingWarning.map((r) => r.id),
          unorderedEquals(['GR-2481', 'GR-2488', 'GR-2495', 'GR-2491']));
    });

    test('excludes reports that already have a warning', () {
      final ids = state.verifiedAwaitingWarning.map((r) => r.id);

      expect(ids, isNot(contains('GR-2465')));
      expect(ids, isNot(contains('GR-2440')));
    });

    test('excludes pending and rejected reports', () {
      final ids = state.verifiedAwaitingWarning.map((r) => r.id);

      expect(ids, isNot(contains('GR-2476'))); // pending
      expect(ids, isNot(contains('GR-2459'))); // rejected
    });

    test('drops a report as soon as a warning is issued for it', () async {
      await issue(reportId: 'GR-2481');

      expect(state.verifiedAwaitingWarning.map((r) => r.id),
          isNot(contains('GR-2481')));
      expect(state.verifiedAwaitingWarning.length, 3);
    });

    test('gains a report when the duty officer verifies it', () async {
      await state.verifyReport('GR-2476');
      await pumpEventQueue();

      expect(state.verifiedAwaitingWarning.map((r) => r.id),
          contains('GR-2476'));
      expect(state.pendingReports.map((r) => r.id), isNot(contains('GR-2476')));
    });

    test('does not gain a report that was rejected', () async {
      await state.rejectReport('GR-2476');
      await pumpEventQueue();

      expect(state.verifiedAwaitingWarning.map((r) => r.id),
          isNot(contains('GR-2476')));
      expect(state.pendingReports.map((r) => r.id), isNot(contains('GR-2476')));
    });
  });

  group('issueWarning', () {
    test('records what the officer decided and links the source report',
        () async {
      final w = await issue(
        severity: WarningSeverity.moderate,
        areas: const ['Kelani river basin', 'Kalu river basin'],
        recipients: 21580,
      );

      expect(w.sourceReportId, 'GR-2481');
      expect(w.category, HazardCategory.risingRiver);
      expect(w.severity, WarningSeverity.moderate);
      expect(w.scope, BroadcastScope.riverBasin);
      expect(w.targetAreas, ['Kelani river basin', 'Kalu river basin']);
      expect(w.recipientCount, 21580);
      expect(w.escalations, 0);
    });

    test('generates an HW- id and stamps the current time', () async {
      final before = DateTime.now();

      final w = await issue();

      expect(w.id, matches(RegExp(r'^HW-\d+$')));
      expect(w.issuedAt.isBefore(before), isFalse);
      expect(DateTime.now().difference(w.issuedAt).inSeconds, lessThan(5));
    });

    for (final entry in {
      WarningSeverity.low: WarningLevel.advisory,
      WarningSeverity.moderate: WarningLevel.watch,
      WarningSeverity.high: WarningLevel.warning,
    }.entries) {
      test('${entry.key.name} severity starts at the ${entry.value.name} level',
          () async {
        final w = await issue(severity: entry.key);

        expect(w.level, entry.value);
      });
    }

    test('dispatches through the gateway and keeps the per-channel result',
        () async {
      final w = await issue(recipients: 12480);

      final expected = gateway.dispatch(12480);
      expect(w.deliveries.map((d) => d.channel), AlertChannel.values);
      for (var i = 0; i < expected.length; i++) {
        expect(w.deliveries[i].targeted, expected[i].targeted);
        expect(w.deliveries[i].failed, expected[i].failed);
      }
    });

    test('persists the warning and makes it the newest one', () async {
      final w = await issue();

      expect(state.warnings.first.id, w.id);
      expect(state.warnings.length, 3);
    });

    test('derives a citizen alert for the new warning', () async {
      final w = await issue();

      expect(state.alerts.first.warningId, w.id);
      expect(state.alerts.length, 3);
    });

    test('notifies listeners', () async {
      var notifications = 0;
      state.addListener(() => notifications++);

      await issue();

      expect(notifications, greaterThan(0));
    });

    test('with zero recipients nothing is targeted and nothing fails',
        () async {
      final w = await issue(
        reportId: 'GR-2495',
        category: HazardCategory.coastalSurge,
        scope: BroadcastScope.district,
        areas: const ['Colombo district'],
        recipients: 0,
      );

      expect(w.deliveries.every((d) => d.targeted == 0), isTrue);
      expect(w.hasFailures, isFalse);
    });
  });

  group('citizen alert text', () {
    test('title combines hazard and level; body states severity, area, action',
        () async {
      final w = await issue();

      final alert = state.alerts.firstWhere((a) => a.warningId == w.id);
      expect(alert.title, 'Rising river / flood — Warning');
      expect(
        alert.body,
        'WARNING: High severity Rising river / flood for Kelani river basin. '
        'Take action now. Follow DMC instructions and move to higher ground if advised.',
      );
      expect(alert.severity, WarningSeverity.high);
      expect(alert.issuedAt, w.issuedAt);
    });

    test('SMS text is the alert prefix followed by the body', () async {
      final w = await issue();

      final alert = state.alerts.firstWhere((a) => a.warningId == w.id);
      expect(
        alert.smsText,
        'DMC ALERT [HIGH]: Rising river / flood affecting Kelani river basin. '
        '${alert.body}',
      );
    });

    test('several areas are listed with commas', () async {
      final w = await issue(
        areas: const ['Kelani river basin', 'Kalu river basin'],
      );

      final alert = state.alerts.firstWhere((a) => a.warningId == w.id);
      expect(alert.body, contains('for Kelani river basin, Kalu river basin.'));
    });

    test('the seeded evacuation warning is worded for its level', () {
      final alert = state.alerts.firstWhere((a) => a.warningId == 'HW-1031');

      expect(alert.title, endsWith('Evacuate'));
      expect(alert.body, startsWith('EVACUATE: High severity'));
      expect(alert.body, contains('Leave immediately.'));
    });

    test('escalating re-words the alert for the new level', () async {
      final w = await issue(severity: WarningSeverity.moderate);

      await state.escalateWarning(w.id);
      await pumpEventQueue();

      final alert = state.alerts.firstWhere((a) => a.warningId == w.id);
      expect(alert.title, endsWith('Warning'));
      expect(alert.body, startsWith('WARNING:'));
    });
  });

  group('retryFailedDeliveries', () {
    test('recovers failures and stores the updated status', () async {
      final w = await issue();
      final failedBefore = w.failedCount;
      expect(failedBefore, greaterThan(0));

      await state.retryFailedDeliveries(w.id);
      await pumpEventQueue();

      final after = stored(w.id);
      expect(after.failedCount, lessThan(failedBefore));
      expect(after.deliveries.every((d) => d.fallback != null || d.failed == 0),
          isTrue);
      expect(after.deliveries.fold<int>(0, (s, d) => s + d.recovered),
          greaterThan(0));
    });

    test('does not change the level or recipient list', () async {
      final w = await issue();

      await state.retryFailedDeliveries(w.id);
      await pumpEventQueue();

      expect(stored(w.id).level, w.level);
      expect(stored(w.id).recipientCount, w.recipientCount);
      expect(stored(w.id).escalations, 0);
    });

    test('ignores an unknown warning id', () async {
      final before = state.warnings.map((w) => w.failedCount).toList();

      await state.retryFailedDeliveries('HW-NOPE');
      await pumpEventQueue();

      expect(state.warnings.map((w) => w.failedCount), before);
      expect(state.warnings.length, 2);
    });
  });

  group('escalateWarning', () {
    test('raises the level one step and counts the escalation', () async {
      final w = await issue(); // starts at Warning

      await state.escalateWarning(w.id);
      await pumpEventQueue();

      expect(stored(w.id).level, WarningLevel.evacuate);
      expect(stored(w.id).escalations, 1);
    });

    test('re-broadcasts to the same recipients with a fresh delivery result',
        () async {
      final w = await issue(recipients: 5000);
      await state.retryFailedDeliveries(w.id);
      await pumpEventQueue();

      await state.escalateWarning(w.id);
      await pumpEventQueue();

      final after = stored(w.id);
      expect(after.recipientCount, 5000);
      final fresh = gateway.dispatch(5000);
      expect(after.deliveries.map((d) => d.failed),
          fresh.map((d) => d.failed),
          reason: 'status reflects the new broadcast, not the old retry');
      expect(after.deliveries.every((d) => d.recovered == 0), isTrue);
    });

    test('keeps everything the officer originally decided', () async {
      final w = await issue(severity: WarningSeverity.moderate);

      await state.escalateWarning(w.id);
      await pumpEventQueue();

      final after = stored(w.id);
      expect(after.severity, WarningSeverity.moderate);
      expect(after.sourceReportId, 'GR-2481');
      expect(after.targetAreas, w.targetAreas);
    });

    test('walks the whole ladder one step at a time and then stops', () async {
      final w = await issue(severity: WarningSeverity.low); // Advisory
      final seen = <WarningLevel>[stored(w.id).level];

      for (var i = 0; i < 4; i++) {
        await state.escalateWarning(w.id);
        await pumpEventQueue();
        seen.add(stored(w.id).level);
      }

      expect(seen, [
        WarningLevel.advisory,
        WarningLevel.watch,
        WarningLevel.warning,
        WarningLevel.evacuate,
        WarningLevel.evacuate, // 4th escalation is refused
      ]);
      expect(stored(w.id).escalations, 3);
    });

    test('does nothing at the highest level', () async {
      final before = stored('HW-1031'); // Evacuate, escalated twice

      await state.escalateWarning('HW-1031');
      await pumpEventQueue();

      expect(stored('HW-1031').level, WarningLevel.evacuate);
      expect(stored('HW-1031').escalations, before.escalations);
    });

    test('ignores an unknown warning id', () async {
      await state.escalateWarning('HW-NOPE');
      await pumpEventQueue();

      expect(state.warnings.map((w) => w.id), ['HW-1042', 'HW-1031']);
    });
  });

  group('lifecycle', () {
    test('setRole stores the role and notifies', () {
      var notified = 0;
      state.addListener(() => notified++);

      state.setRole(UserRole.officer);

      expect(state.role, UserRole.officer);
      expect(notified, 1);
    });

    test('after dispose, repository changes no longer reach the state',
        () async {
      final separate = await createAppState(repository: repo);
      final warningsBefore = separate.warnings.length;
      separate.dispose();

      await repo.issueWarning(sampleWarning(id: 'HW-LATE'));
      await pumpEventQueue();

      expect(separate.warnings.length, warningsBefore);
    });
  });
}
