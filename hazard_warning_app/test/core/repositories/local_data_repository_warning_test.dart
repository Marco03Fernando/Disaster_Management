import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/data/seed_data.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/repositories/local_data_repository.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late LocalDataRepository repo;

  setUp(() => repo = LocalDataRepository());

  group('warnings', () {
    test('starts with the two seeded warnings, newest first', () async {
      final warnings = await repo.watchWarnings().first;

      expect(warnings.map((w) => w.id), ['HW-1042', 'HW-1031']);
    });

    test('issueWarning stores the warning at the top and returns its id',
        () async {
      final id = await repo.issueWarning(sampleWarning(id: 'HW-NEW'));

      final warnings = await repo.watchWarnings().first;
      expect(id, 'HW-NEW');
      expect(warnings.first.id, 'HW-NEW');
      expect(warnings.length, 3);
    });

    test('issueWarning notifies existing stream listeners', () async {
      final emissions = <List<HazardWarning>>[];
      final sub = repo.watchWarnings().listen(emissions.add);
      await pumpEventQueue();

      await repo.issueWarning(sampleWarning(id: 'HW-NEW'));
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 2, reason: 'initial snapshot + the new warning');
      expect(emissions.last.first.id, 'HW-NEW');
    });

    test('updateWarning replaces the warning in place', () async {
      final target = (await repo.watchWarnings().first)
          .firstWhere((w) => w.id == 'HW-1042');

      await repo.updateWarning(target.copyWith(level: WarningLevel.evacuate));

      final warnings = await repo.watchWarnings().first;
      expect(warnings.map((w) => w.id), ['HW-1042', 'HW-1031'],
          reason: 'order is preserved');
      expect(warnings.first.level, WarningLevel.evacuate);
    });

    test('updateWarning ignores a warning that does not exist', () async {
      await repo.updateWarning(sampleWarning(id: 'HW-MISSING'));

      final warnings = await repo.watchWarnings().first;
      expect(warnings.map((w) => w.id), ['HW-1042', 'HW-1031']);
    });

    test('snapshots handed out are read-only', () async {
      final warnings = await repo.watchWarnings().first;

      expect(() => warnings.add(sampleWarning()), throwsUnsupportedError);
    });
  });

  group('reports used by the issue flow', () {
    test('verifyReport marks the report verified with who and when', () async {
      await repo.verifyReport('GR-2476');

      final report = (await repo.getReport('GR-2476'))!;
      expect(report.status, ReportStatus.verified);
      expect(report.verifiedBy, 'Duty officer');
      expect(report.verifiedAt, isNotNull);
    });

    test('rejectReport marks the report rejected', () async {
      await repo.rejectReport('GR-2476');

      expect((await repo.getReport('GR-2476'))!.status, ReportStatus.rejected);
    });

    test('verify and reject ignore an unknown report id', () async {
      final before = (await repo.getReports()).length;

      await repo.verifyReport('NOPE');
      await repo.rejectReport('NOPE');

      expect((await repo.getReports()).length, before);
    });

    test('getReport returns null for an unknown id', () async {
      expect(await repo.getReport('NOPE'), isNull);
    });
  });

  group('areasForScope', () {
    test('every scope has areas', () {
      for (final scope in BroadcastScope.values) {
        expect(repo.areasForScope(scope), isNotEmpty, reason: scope.name);
      }
    });

    test('every area belongs to the scope it was requested for', () {
      for (final scope in BroadcastScope.values) {
        for (final area in repo.areasForScope(scope)) {
          expect(area.scope, scope, reason: area.label);
        }
      }
    });

    test('area ids are unique across all scopes', () {
      final ids = [
        for (final s in BroadcastScope.values)
          ...repo.areasForScope(s).map((a) => a.id),
      ];

      expect(ids.toSet().length, ids.length);
    });

    test('recipient counts are never negative', () {
      for (final scope in BroadcastScope.values) {
        for (final area in repo.areasForScope(scope)) {
          expect(area.recipientCount, greaterThanOrEqualTo(0));
        }
      }
    });

    test('the default (first) area of each scope is the Kelani scenario area',
        () {
      expect(repo.areasForScope(BroadcastScope.zone).first.label,
          'Kolonnawa zone');
      expect(repo.areasForScope(BroadcastScope.district).first.label,
          'Colombo district');
      final basin = repo.areasForScope(BroadcastScope.riverBasin).first;
      expect(basin.label, 'Kelani river basin');
      expect(basin.recipientCount, 12480);
    });

    test('exactly one zone has no registered citizens (empty-list demo case)',
        () {
      final empty = repo
          .areasForScope(BroadcastScope.zone)
          .where((a) => a.recipientCount == 0);

      expect(empty.map((a) => a.label), ['Mutwal harbour zone']);
    });

    test('districts and river basins all have registered citizens', () {
      for (final scope in [BroadcastScope.district, BroadcastScope.riverBasin]) {
        for (final area in repo.areasForScope(scope)) {
          expect(area.recipientCount, greaterThan(0), reason: area.label);
        }
      }
    });

    test('every hazard category has areas for each scope it allows', () {
      for (final category in HazardCategory.values) {
        for (final scope in category.allowedScopes) {
          expect(repo.areasForScope(scope), isNotEmpty,
              reason: '${category.name} / ${scope.name}');
        }
      }
    });
  });

  group('seed data consistency', () {
    test('every seeded warning refers to a verified seeded report', () {
      final reports = {for (final r in SeedData.initialReports()) r.id: r};

      for (final w in SeedData.initialWarnings()) {
        final source = reports[w.sourceReportId];
        expect(source, isNotNull, reason: w.id);
        expect(source!.status, ReportStatus.verified, reason: w.id);
        expect(source.category, w.category, reason: w.id);
      }
    });

    test('seeded warnings use only allowed scopes for their hazard', () {
      for (final w in SeedData.initialWarnings()) {
        expect(w.category.allowedScopes, contains(w.scope), reason: w.id);
      }
    });

    test('seeded warning levels and escalation counts agree', () {
      final byId = {for (final w in SeedData.initialWarnings()) w.id: w};

      expect(byId['HW-1042']!.level, WarningLevel.watch);
      expect(byId['HW-1042']!.escalations, 0);
      expect(byId['HW-1031']!.level, WarningLevel.evacuate);
      expect(byId['HW-1031']!.escalations, 2);
    });

    test('report ids are unique', () {
      final ids = SeedData.initialReports().map((r) => r.id).toList();

      expect(ids.toSet().length, ids.length);
    });

    test('there are verified reports still awaiting a warning', () {
      final warned =
          SeedData.initialWarnings().map((w) => w.sourceReportId).toSet();

      final awaiting = SeedData.initialReports().where(
          (r) => r.status == ReportStatus.verified && !warned.contains(r.id));

      expect(awaiting.map((r) => r.id),
          unorderedEquals(['GR-2481', 'GR-2488', 'GR-2495', 'GR-2491']));
    });
  });
}
