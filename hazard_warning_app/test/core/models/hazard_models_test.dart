import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/models/models.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('HazardCategory', () {
    const rapidOnset = {
      HazardCategory.landslideCrack,
      HazardCategory.damOverflow,
      HazardCategory.coastalSurge,
    };

    test('every category has a distinct, non-empty label', () {
      final labels = HazardCategory.values.map((c) => c.label).toList();

      expect(labels.every((l) => l.isNotEmpty), isTrue);
      expect(labels.toSet().length, HazardCategory.values.length);
    });

    for (final category in HazardCategory.values) {
      final expectedRapid = rapidOnset.contains(category);

      test('${category.name}: isRapidOnset is $expectedRapid', () {
        expect(category.isRapidOnset, expectedRapid);
      });

      test('${category.name}: onset label matches the onset profile', () {
        expect(
          category.onsetLabel.startsWith('Rapid onset'),
          expectedRapid,
          reason: category.onsetLabel,
        );
      });

      test('${category.name}: offers at least one scope and a reason', () {
        expect(category.allowedScopes, isNotEmpty);
        expect(category.allowedScopes.toSet().length,
            category.allowedScopes.length,
            reason: 'no duplicate scopes');
        expect(category.scopeReason, isNotEmpty);
      });
    }

    test('floods and dam spills can only be broadcast by river basin', () {
      expect(HazardCategory.risingRiver.allowedScopes,
          [BroadcastScope.riverBasin]);
      expect(HazardCategory.damOverflow.allowedScopes,
          [BroadcastScope.riverBasin]);
    });

    test('coastal surge is only broadcast by district', () {
      expect(
          HazardCategory.coastalSurge.allowedScopes, [BroadcastScope.district]);
    });

    test('local hazards default to the narrowest scope (zone)', () {
      expect(HazardCategory.blockedRoad.allowedScopes.first,
          BroadcastScope.zone);
      expect(HazardCategory.landslideCrack.allowedScopes.first,
          BroadcastScope.zone);
    });

    test('wind systems default to the wider district scope', () {
      expect(HazardCategory.strongWinds.allowedScopes.first,
          BroadcastScope.district);
      expect(HazardCategory.strongWinds.allowedScopes,
          contains(BroadcastScope.zone));
    });
  });

  group('WarningLevel', () {
    test('escalation ladder runs advisory > watch > warning > evacuate', () {
      expect(WarningLevel.advisory.next, WarningLevel.watch);
      expect(WarningLevel.watch.next, WarningLevel.warning);
      expect(WarningLevel.warning.next, WarningLevel.evacuate);
    });

    test('the top level has no next level', () {
      expect(WarningLevel.evacuate.next, isNull);
    });

    test('severity maps to the documented initial level', () {
      expect(WarningLevelX.initialFor(WarningSeverity.low),
          WarningLevel.advisory);
      expect(WarningLevelX.initialFor(WarningSeverity.moderate),
          WarningLevel.watch);
      expect(
          WarningLevelX.initialFor(WarningSeverity.high), WarningLevel.warning);
    });

    test('evacuate can never be an initial level', () {
      final initial = WarningSeverity.values.map(WarningLevelX.initialFor);

      expect(initial, isNot(contains(WarningLevel.evacuate)));
    });

    test('labels and actions are distinct and match the wording shown to users',
        () {
      expect(WarningLevel.values.map((l) => l.label),
          ['Advisory', 'Watch', 'Warning', 'Evacuate']);
      expect(WarningLevel.values.map((l) => l.action), [
        'Stay informed',
        'Be prepared',
        'Take action now',
        'Leave immediately',
      ]);
      expect(WarningLevel.values.map((l) => l.color).toSet().length,
          WarningLevel.values.length);
    });
  });

  group('AlertChannel', () {
    test('fallback pairs push with SMS and audible with SMS', () {
      expect(AlertChannel.push.fallback, AlertChannel.sms);
      expect(AlertChannel.sms.fallback, AlertChannel.push);
      expect(AlertChannel.audible.fallback, AlertChannel.sms);
    });

    test('a channel is never its own fallback', () {
      for (final c in AlertChannel.values) {
        expect(c.fallback, isNot(c));
      }
    });

    test('labels', () {
      expect(AlertChannel.values.map((c) => c.label),
          ['Push notification', 'SMS', 'Audible alert']);
      expect(AlertChannel.values.map((c) => c.shortLabel),
          ['Push', 'SMS', 'Audible']);
    });
  });

  group('WarningSeverity and BroadcastScope labels', () {
    test('severity labels', () {
      expect(WarningSeverity.values.map((s) => s.label),
          ['Low', 'Moderate', 'High']);
      expect(WarningSeverity.values.map((s) => s.color).toSet().length, 3);
    });

    test('scope labels', () {
      expect(BroadcastScope.values.map((s) => s.label),
          ['Zone', 'District', 'River basin']);
    });
  });

  group('ChannelDelivery', () {
    test('totalDelivered adds recovered citizens to first-attempt deliveries',
        () {
      final d = delivery(AlertChannel.push, targeted: 100, failed: 10)
          .copyWith(failed: 4, recovered: 6);

      expect(d.totalDelivered, 96);
    });

    test('successRatio is the share of targeted citizens reached', () {
      final d = delivery(AlertChannel.sms, targeted: 200, failed: 50);

      expect(d.successRatio, closeTo(0.75, 1e-9));
    });

    test('successRatio is 1 when nobody was targeted (no division by zero)',
        () {
      final d = delivery(AlertChannel.audible, targeted: 0);

      expect(d.successRatio, 1);
    });

    test('copyWith overrides only the given fields', () {
      final original = delivery(AlertChannel.push, targeted: 100, failed: 10);

      final changed =
          original.copyWith(recovered: 7, fallback: AlertChannel.sms);

      expect(changed.channel, AlertChannel.push);
      expect(changed.targeted, 100);
      expect(changed.delivered, 90);
      expect(changed.failed, 10);
      expect(changed.recovered, 7);
      expect(changed.fallback, AlertChannel.sms);
    });

    test('copyWith with no arguments keeps every field', () {
      final original = delivery(AlertChannel.push,
          targeted: 100, failed: 10, recovered: 3, fallback: AlertChannel.sms);

      final copy = original.copyWith();

      expect(copy.failed, original.failed);
      expect(copy.recovered, original.recovered);
      expect(copy.fallback, original.fallback);
    });
  });

  group('HazardWarning', () {
    test('targetArea shows a dash when there are no areas', () {
      expect(sampleWarning(targetAreas: const []).targetArea, '—');
    });

    test('targetArea shows the single area name', () {
      expect(sampleWarning(targetAreas: const ['Kelani river basin']).targetArea,
          'Kelani river basin');
    });

    test('targetArea joins two areas with an ampersand', () {
      expect(sampleWarning(targetAreas: const ['A', 'B']).targetArea, 'A & B');
    });

    test('targetArea summarises three or more areas', () {
      expect(sampleWarning(targetAreas: const ['A', 'B', 'C']).targetArea,
          'A +2 more areas');
      expect(sampleWarning(targetAreas: const ['A', 'B', 'C', 'D', 'E'])
              .targetArea,
          'A +4 more areas');
    });

    test('failedCount sums failures across channels', () {
      final w = sampleWarning(deliveries: [
        delivery(AlertChannel.push, targeted: 100, failed: 3),
        delivery(AlertChannel.sms, targeted: 100, failed: 1),
        delivery(AlertChannel.audible, targeted: 40, failed: 2),
      ]);

      expect(w.failedCount, 6);
      expect(w.hasFailures, isTrue);
    });

    test('hasFailures is false when every channel delivered everything', () {
      final w = sampleWarning(deliveries: [
        delivery(AlertChannel.push, targeted: 100),
      ]);

      expect(w.failedCount, 0);
      expect(w.hasFailures, isFalse);
    });

    test('a warning without deliveries has no failures', () {
      final w = sampleWarning(deliveries: const []);

      expect(w.failedCount, 0);
      expect(w.hasFailures, isFalse);
    });

    test('copyWith changes level, deliveries and escalations only', () {
      final original = sampleWarning();

      final updated = original.copyWith(
        level: WarningLevel.evacuate,
        escalations: 2,
        deliveries: const [],
      );

      expect(updated.level, WarningLevel.evacuate);
      expect(updated.escalations, 2);
      expect(updated.deliveries, isEmpty);
      // Identity and what the officer decided stay the same.
      expect(updated.id, original.id);
      expect(updated.sourceReportId, original.sourceReportId);
      expect(updated.category, original.category);
      expect(updated.severity, original.severity);
      expect(updated.scope, original.scope);
      expect(updated.targetAreas, original.targetAreas);
      expect(updated.recipientCount, original.recipientCount);
      expect(updated.issuedAt, original.issuedAt);
      expect(updated.channels, original.channels);
    });

    test('defaults: warning level, no escalations, three channels', () {
      final w = HazardWarning(
        id: 'HW-D',
        sourceReportId: 'GR-1',
        category: HazardCategory.blockedRoad,
        severity: WarningSeverity.low,
        scope: BroadcastScope.zone,
        targetAreas: const ['Z'],
        recipientCount: 1,
        issuedAt: DateTime(2026),
      );

      expect(w.level, WarningLevel.warning);
      expect(w.escalations, 0);
      expect(w.deliveries, isEmpty);
      expect(w.channels, ['Push', 'SMS', 'Audible']);
    });
  });

  group('HazardReport', () {
    HazardReport report() => HazardReport(
          id: 'GR-1',
          category: HazardCategory.risingRiver,
          areaLabel: 'Area',
          locationLabel: 'Place',
          coordinates: const GeoCoordinate(latitude: 6.9382, longitude: 79.9012),
          status: ReportStatus.pending,
          submittedAt: DateTime(2026, 6, 1),
          notes: 'note',
        );

    test('copyWith marks the report verified without losing its details', () {
      final verified = report().copyWith(
        status: ReportStatus.verified,
        verifiedAt: DateTime(2026, 6, 2),
        verifiedBy: 'Duty officer',
      );

      expect(verified.status, ReportStatus.verified);
      expect(verified.verifiedBy, 'Duty officer');
      expect(verified.id, 'GR-1');
      expect(verified.notes, 'note');
      expect(verified.category, HazardCategory.risingRiver);
    });

    test('copyWith with no arguments keeps the status', () {
      expect(report().copyWith().status, ReportStatus.pending);
    });

    test('coordinates are formatted to four decimals', () {
      expect(report().coordinates.formatted, '6.9382° N, 79.9012° E');
    });
  });

  group('CitizenAlert and TargetAreaOption', () {
    test('hold the values they are created with', () {
      final alert = CitizenAlert(
        warningId: 'HW-1',
        title: 't',
        body: 'b',
        severity: WarningSeverity.moderate,
        issuedAt: DateTime(2026),
        smsText: 's',
      );
      const area = TargetAreaOption(
        id: 'a',
        label: 'Area',
        recipientCount: 5,
        scope: BroadcastScope.zone,
      );

      expect(alert.warningId, 'HW-1');
      expect(alert.severity, WarningSeverity.moderate);
      expect(area.recipientCount, 5);
      expect(area.scope, BroadcastScope.zone);
    });
  });
}
