import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/repositories/local_data_repository.dart';
import 'package:hazard_warning_app/core/services/notification_gateway.dart';

void main() {
  test('Local repository seeds Kelani scenario data', () async {
    final repo = LocalDataRepository();
    final reports = await repo.getReports();
    expect(reports.any((r) => r.id == 'GR-2481'), isTrue);
    expect(reports.firstWhere((r) => r.id == 'GR-2481').status, ReportStatus.verified);

    final shelters = await repo.watchShelters().first;
    expect(shelters.any((s) => s.id == 'SH-042' && s.isOverCapacity), isTrue);
  });

  group('Issue hazard warning', () {
    const gateway = NotificationGateway();

    test('gateway reports per-channel outcome; audible targets background users only', () {
      final result = gateway.dispatch(10000);
      expect(result.map((d) => d.channel), AlertChannel.values);
      for (final d in result) {
        expect(d.delivered + d.failed, d.targeted);
      }
      final audible = result.firstWhere((d) => d.channel == AlertChannel.audible);
      expect(audible.targeted, lessThan(10000));
    });

    test('retry on fallback recovers failures and updates status', () {
      final before = gateway.dispatch(10000);
      final after = gateway.retryFailed(before);
      for (var i = 0; i < before.length; i++) {
        expect(after[i].failed, lessThan(before[i].failed));
        expect(after[i].totalDelivered, greaterThan(before[i].totalDelivered));
        expect(after[i].fallback, before[i].channel.fallback);
      }
    });

    test('escalation moves up levels and stops at evacuate', () {
      expect(WarningLevel.warning.next, WarningLevel.evacuate);
      expect(WarningLevel.evacuate.next, isNull);
    });

    test('empty target area exists for the empty-recipient flow', () {
      final repo = LocalDataRepository();
      final zones = repo.areasForScope(BroadcastScope.zone);
      expect(zones.any((a) => a.recipientCount == 0), isTrue);
    });

    test('warning record is stored and updatable', () async {
      final repo = LocalDataRepository();
      final warning = HazardWarning(
        id: 'HW-1',
        sourceReportId: 'GR-2481',
        category: HazardCategory.risingRiver,
        severity: WarningSeverity.high,
        scope: BroadcastScope.riverBasin,
        targetAreas: const ['Kelani river basin'],
        recipientCount: 12480,
        issuedAt: DateTime(2026, 6, 12),
        level: WarningLevel.warning,
        deliveries: gateway.dispatch(12480),
      );
      await repo.issueWarning(warning);
      await repo.updateWarning(warning.copyWith(level: WarningLevel.evacuate, escalations: 1));
      final stored = (await repo.watchWarnings().first).firstWhere((w) => w.id == 'HW-1');
      expect(stored.level, WarningLevel.evacuate);
      expect(stored.escalations, 1);
    });
  });
}
