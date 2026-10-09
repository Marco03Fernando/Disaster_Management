import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/app.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/repositories/local_data_repository.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/services/officer_auth_service.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/features/report_verification/report_review_logic.dart';
import 'package:provider/provider.dart';

/// Auth stand-in that enforces access like Firebase, with a settable session.
class FakeOfficerAuth implements OfficerAuthService {
  FakeOfficerAuth(this._session, {this.uid = 'citizen-1'});

  final _ctrl = StreamController<OfficerSession>.broadcast();
  OfficerSession _session;
  String? uid;

  void emit(OfficerSession session) {
    _session = session;
    _ctrl.add(session);
  }

  @override
  bool get enforcesAccess => true;

  @override
  String? get currentUid => uid;

  @override
  Stream<OfficerSession> watchSession() async* {
    yield _session;
    yield* _ctrl.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (password != 'correct') {
      throw StateError('bad credentials');
    }
    emit(officer);
  }

  @override
  Future<void> signOut() async => emit(OfficerSession.signedOut);

  @override
  Future<void> refresh() async {}
}

const officer = OfficerSession(
  status: OfficerAccessStatus.authorized,
  uid: 'officer-7',
  displayName: 'Officer Perera',
  email: 'perera@dmc.lk',
);

AppState createState(OfficerAuthService auth, {bool online = true}) => AppState(
  AppServices.test(
    repository: LocalDataRepository(),
    auth: auth,
    online: online,
  ),
);

/// For plain tests: lets the repository and session streams deliver.
Future<AppState> makeState(
  OfficerAuthService auth, {
  bool online = true,
}) async {
  final state = createState(auth, online: online);
  await Future<void>.delayed(Duration.zero);
  return state;
}

HazardReport firstPending(AppState state) =>
    state.reports.firstWhere((r) => r.status == ReportStatus.pending);

void main() {
  group('Citizen submission', () {
    test(
      'is saved as PENDING with description, reporter and contact',
      () async {
        final state = await makeState(FakeOfficerAuth(officer));
        final report = await state.submitGroundReport(
          category: HazardCategory.blockedRoad,
          areaLabel: 'Kolonnawa',
          locationLabel: 'Main road',
          coordinates: const GeoCoordinate(latitude: 6.93, longitude: 79.89),
          notes: 'Tree across both lanes',
          contact: const ReporterContact(name: 'Nimal', phone: '0771234567'),
        );
        await Future<void>.delayed(Duration.zero);

        final stored = state.reports.firstWhere((r) => r.id == report.id);
        expect(stored.status, ReportStatus.pending);
        expect(stored.notes, 'Tree across both lanes');
        expect(stored.reporterUid, 'citizen-1');
        expect(stored.verifiedByUid, isNull);
        expect(state.myReports.map((r) => r.id), [report.id]);
        expect((await state.reporterContact(report.id))?.phone, '0771234567');
      },
    );

    test('offline submission is queued instead of blocking', () async {
      final state = await makeState(FakeOfficerAuth(officer), online: false);
      final report = await state.submitGroundReport(
        category: HazardCategory.risingRiver,
        areaLabel: 'Kolonnawa',
        locationLabel: 'River bank',
        coordinates: const GeoCoordinate(latitude: 6.93, longitude: 79.90),
      );
      expect(report.syncState, SyncState.queued);
      expect(report.status, ReportStatus.pending);
    });
  });

  group('Authorization', () {
    for (final session in [
      OfficerSession.signedOut,
      const OfficerSession(
        status: OfficerAccessStatus.unauthorized,
        uid: 'someone',
      ),
    ]) {
      test(
        '${session.status.name} user cannot verify or read contacts',
        () async {
          final state = await makeState(FakeOfficerAuth(session));
          final id = firstPending(state).id;
          await expectLater(
            state.verifyReport(id),
            throwsA(isA<OfficerNotAuthorizedException>()),
          );
          await expectLater(
            state.rejectReport(id, reason: 'Not a real hazard at all'),
            throwsA(isA<OfficerNotAuthorizedException>()),
          );
          await expectLater(
            state.reporterContact(id),
            throwsA(isA<OfficerNotAuthorizedException>()),
          );
          expect(firstPending(state).id, id);
        },
      );
    }
  });

  group('Officer verification', () {
    test('CONFIRM records officer UID and time, and only makes the report '
        'eligible for a warning', () async {
      final state = await makeState(FakeOfficerAuth(officer));
      final id = firstPending(state).id;
      final warningsBefore = state.warnings.length;

      await state.verifyReport(id);
      await Future<void>.delayed(Duration.zero);

      final r = state.reports.firstWhere((r) => r.id == id);
      expect(r.status, ReportStatus.verified);
      expect(r.status.label, 'Confirmed');
      expect(r.verifiedByUid, 'officer-7');
      expect(r.verifiedBy, 'Officer Perera');
      expect(r.verifiedAt, isNotNull);
      expect(state.verifiedAwaitingWarning.map((r) => r.id), contains(id));
      expect(state.warnings.length, warningsBefore, reason: 'no auto-publish');
    });

    test('DISMISS requires a reason and stores it', () async {
      final state = await makeState(FakeOfficerAuth(officer));
      final id = firstPending(state).id;

      await expectLater(
        state.rejectReport(id, reason: '  short '),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        state.reports.firstWhere((r) => r.id == id).status,
        ReportStatus.pending,
      );

      await state.rejectReport(id, reason: 'Photo does not show a hazard');
      await Future<void>.delayed(Duration.zero);
      final r = state.reports.firstWhere((r) => r.id == id);
      expect(r.status, ReportStatus.rejected);
      expect(r.dismissalReason, 'Photo does not show a hazard');
      expect(r.verifiedByUid, 'officer-7');
    });

    test('a report cannot be reviewed twice', () async {
      final state = await makeState(FakeOfficerAuth(officer));
      final id = firstPending(state).id;
      await state.verifyReport(id);

      await expectLater(
        state.rejectReport(id, reason: 'Changed my mind on this'),
        throwsA(
          isA<ReportAlreadyReviewedException>().having(
            (e) => e.status,
            'status',
            ReportStatus.verified,
          ),
        ),
      );
      expect(
        state.reports.firstWhere((r) => r.id == id).status,
        ReportStatus.verified,
      );
    });
  });

  group('Duplicate detection', () {
    HazardReport report(
      String id,
      double lat, {
      int minutes = 0,
      HazardCategory category = HazardCategory.risingRiver,
    }) => HazardReport(
      id: id,
      category: category,
      areaLabel: 'A',
      locationLabel: 'L',
      coordinates: GeoCoordinate(latitude: lat, longitude: 79.9),
      status: ReportStatus.pending,
      submittedAt: DateTime(2026, 10, 1, 12).add(Duration(minutes: minutes)),
    );

    test('flags same hazard nearby within the time window only', () {
      final base = report('A', 6.9300);
      final all = [
        base,
        report('near', 6.9320), // ~220 m
        report('far', 6.9500), // ~2.2 km
        report('late', 6.9301, minutes: 60 * 7),
        report('other-type', 6.9301, category: HazardCategory.blockedRoad),
      ];
      expect(possibleDuplicates(base, all).map((r) => r.id), ['near']);
    });
  });

  group('Officer screens', () {
    Future<void> pumpAt(
      WidgetTester tester,
      AppState state,
      String location,
    ) async {
      final router = buildRouter();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: HazardWarningApp(router: router),
        ),
      );
      router.go(location);
      await tester.pumpAndSettle();
    }

    testWidgets('signed-out users get the sign-in form, not the reports', (
      tester,
    ) async {
      final auth = FakeOfficerAuth(OfficerSession.signedOut);
      final state = createState(auth);
      await pumpAt(tester, state, '/officer/reports/pending');

      expect(find.text('Officer sign-in'), findsOneWidget);
      expect(find.text('Hazard reports'), findsNothing);

      await tester.enterText(find.byType(TextFormField).at(0), 'perera@dmc.lk');
      await tester.enterText(find.byType(TextFormField).at(1), 'correct');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Hazard reports'), findsOneWidget);
      expect(find.text('Officer Perera'), findsOneWidget);
    });

    testWidgets('dashboard shows pending count and filters by status', (
      tester,
    ) async {
      final state = createState(FakeOfficerAuth(officer));
      await pumpAt(tester, state, '/officer/reports/pending');
      final pending = state.pendingReports.length;
      final confirmed = state.reports
          .where((r) => r.status == ReportStatus.verified)
          .length;
      expect(pending, greaterThan(0));

      expect(find.text('Pending $pending'), findsOneWidget);
      expect(find.text('$pending'), findsOneWidget);

      await tester.tap(find.text('Confirmed $confirmed'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmed'), findsWidgets);
      expect(find.text('Pending'), findsNothing);
    });

    testWidgets('dismissal flow requires a reason and updates the report', (
      tester,
    ) async {
      final state = createState(FakeOfficerAuth(officer));
      await pumpAt(tester, state, '/officer/reports/pending');
      final id = firstPending(state).id;
      await tester.tap(find.textContaining(id).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Dismiss report'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'nope');
      await tester.tap(find.text('Dismiss report').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 10 characters'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).last,
        'Location could not be verified',
      );
      await tester.tap(find.text('Dismiss report').last);
      await tester.pumpAndSettle();

      final r = state.reports.firstWhere((r) => r.id == id);
      expect(r.status, ReportStatus.rejected);
      expect(r.dismissalReason, 'Location could not be verified');
      expect(find.text('$id dismissed'), findsOneWidget);
    });
  });
}
