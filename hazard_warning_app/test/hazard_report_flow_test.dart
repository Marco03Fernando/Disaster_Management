import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/services/officer_auth_service.dart';
import 'package:hazard_warning_app/features/report_verification/report_review_logic.dart';
import 'package:image_picker/image_picker.dart';

import 'support/hazard_report_fakes.dart';

/// End-to-end and edge-case tests for Submit and Verify Ground Hazard Report.
/// Complements submit_hazard_report_test.dart (rules, AppState submission)
/// and report_verification_test.dart (officer decisions).
void main() {
  group('Photo selection', () {
    testWidgets('a camera photo is attached and submitted with the report', (
      tester,
    ) async {
      final picker = FakeImagePicker()..pickResult = '/data/hazard.jpg';
      picker.install(tester);
      final state = buildState(ControlledRepository());
      await pumpApp(tester, state);

      await tapAndSettle(tester, find.text('Add photo'));
      await tapAndSettle(tester, find.text('Take a photo'));

      expect(picker.lastSource, ImageSource.camera.index);
      expect(find.text('Photo attached'), findsOneWidget);
      expect(find.text('Replace or remove photo'), findsOneWidget);

      await fillValidForm(tester);
      await tapSubmit(tester);
      expect(state.myReports.single.photoPath, '/data/hazard.jpg');
    });

    testWidgets('camera permission denied explains why and keeps the form', (
      tester,
    ) async {
      FakeImagePicker()
        ..pickResult = PlatformException(code: 'camera_access_denied')
        ..install(tester);
      final state = buildState(ControlledRepository());
      await pumpApp(tester, state);
      await tester.enterText(descriptionField(), 'Water over the road');

      await tapAndSettle(tester, find.text('Add photo'));
      await tapAndSettle(tester, find.text('Take a photo'));

      expect(find.textContaining('Camera permission is off'), findsOneWidget);
      expect(find.text('Water over the road'), findsOneWidget);
      expect(find.text('Add photo'), findsOneWidget);
    });

    testWidgets('a gallery failure shows the gallery message', (tester) async {
      final picker = FakeImagePicker()
        ..pickResult = PlatformException(code: 'unknown');
      picker.install(tester);
      await pumpApp(tester, buildState(ControlledRepository()));

      await tapAndSettle(tester, find.text('Add photo'));
      await tapAndSettle(tester, find.text('Choose from gallery'));

      expect(picker.lastSource, ImageSource.gallery.index);
      expect(
        find.textContaining('Could not open the photo gallery'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the picker leaves the report without a photo', (
      tester,
    ) async {
      FakeImagePicker()
        ..pickResult = null
        ..install(tester);
      await pumpApp(tester, buildState(ControlledRepository()));

      await tapAndSettle(tester, find.text('Add photo'));
      await tapAndSettle(tester, find.text('Take a photo'));

      expect(find.text('Photo attached'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a photo can be removed before submitting', (tester) async {
      FakeImagePicker()
        ..pickResult = '/data/hazard.jpg'
        ..install(tester);
      final state = buildState(ControlledRepository());
      await pumpApp(tester, state);

      await tapAndSettle(tester, find.text('Add photo'));
      await tapAndSettle(tester, find.text('Take a photo'));
      await tapAndSettle(tester, find.text('Replace or remove photo'));
      await tapAndSettle(tester, find.text('Remove photo'));

      expect(find.text('Add photo'), findsOneWidget);
      await fillValidForm(tester);
      await tapSubmit(tester);
      expect(state.myReports.single.photoPath, isNull);
    });

    testWidgets('a photo lost when Android closed the app is recovered', (
      tester,
    ) async {
      FakeImagePicker()
        ..lostData = {'type': 'image', 'path': '/data/lost.jpg'}
        ..install(tester);
      await pumpApp(tester, buildState(ControlledRepository()));

      expect(find.text('Photo attached'), findsOneWidget);
    });

    testWidgets('a lost-photo error is reported', (tester) async {
      FakeImagePicker()
        ..lostData = {
          'type': 'image',
          'errorCode': 'camera_access_denied',
          'errorMessage': 'denied',
        }
        ..install(tester);
      await pumpApp(tester, buildState(ControlledRepository()));

      expect(find.textContaining('Camera permission is off'), findsOneWidget);
      expect(find.text('Photo attached'), findsNothing);
    });

    testWidgets('a failed photo upload is shown and can be retried', (
      tester,
    ) async {
      final repo = ControlledRepository()..uploadFailures = 2;
      final state = buildState(repo, usesFirebase: true);
      final report = await submit(state, photoPath: '/data/missing.jpg');
      final router = await pumpApp(tester, state, start: '/citizen/reports');

      expect(find.textContaining('Photo not uploaded yet'), findsOneWidget);
      router.push('/citizen/reports/${report.id}');
      await tester.pumpAndSettle();
      expect(find.text('Photo not uploaded yet'), findsOneWidget);

      await tapAndSettle(tester, find.text('Retry photo upload'));
      expect(find.textContaining('Photo not uploaded. Check'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Retry photo upload'));
      expect(find.text('Photo uploaded.'), findsOneWidget);
      expect(repo.uploads, 3); // 1 automatic + 2 manual
    });
  });

  group('Location', () {
    Future<void> openManualLocation(WidgetTester tester) =>
        tapAndSettle(tester, find.text('Enter location manually'));

    Finder field(String label) => find.widgetWithText(TextFormField, label);

    testWidgets('manual location rejects a blank label or bad coordinates', (
      tester,
    ) async {
      await pumpApp(tester, buildState(ControlledRepository()));
      await openManualLocation(tester);

      await tester.enterText(find.byType(TextField).at(1), 'abc');
      await tapAndSettle(tester, find.text('Use this location'));
      expect(find.text('Enter a label and valid coordinates'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '');
      await tester.enterText(find.byType(TextField).at(1), '6.95');
      await tapAndSettle(tester, find.text('Use this location'));
      expect(find.text('Use this location'), findsOneWidget); // still here
    });

    testWidgets('a manual location is shown and submitted with the report', (
      tester,
    ) async {
      final state = buildState(ControlledRepository());
      await pumpApp(tester, state);
      expect(find.text('Approximate area location (not GPS)'), findsOneWidget);
      await openManualLocation(tester);

      await tester.enterText(
        find.byType(TextField).at(0),
        'Wellampitiya bridge',
      );
      await tester.enterText(find.byType(TextField).at(1), '6.95');
      await tester.enterText(find.byType(TextField).at(2), '79.92');
      await tapAndSettle(tester, find.text('Use this location'));

      expect(find.text('Location entered manually'), findsOneWidget);
      expect(find.textContaining('6.9500° N, 79.9200° E'), findsOneWidget);
      expect(find.text('Approximate area location (not GPS)'), findsNothing);

      await fillValidForm(tester);
      await tapSubmit(tester);
      final report = state.myReports.single;
      expect(report.locationLabel, 'Wellampitiya bridge');
      expect(report.coordinates.latitude, 6.95);
      expect(report.coordinates.longitude, 79.92);
      expect(field('Description (required)'), findsNothing); // left the form
    });
  });

  group('Offline submission and sync', () {
    testWidgets('offline: banner shown, report saved on device and Queued', (
      tester,
    ) async {
      final state = buildState(ControlledRepository(), online: false);
      final router = await pumpApp(tester, state);
      expect(find.text("You're offline"), findsOneWidget);

      await fillValidForm(tester);
      await tapSubmit(tester);
      expect(find.text('Report saved on device'), findsOneWidget);

      router.go('/citizen/reports');
      await tester.pumpAndSettle();
      expect(find.text('Queued'), findsOneWidget);
    });

    testWidgets('a slow server returns Queued; the report and photo sync '
        'when the write lands', (tester) async {
      final repo = ControlledRepository()..writeGate = Completer<void>();
      final state = buildState(repo, usesFirebase: true);
      await tester.pump();

      HazardReport? result;
      unawaited(
        submit(state, photoPath: '/data/p.jpg').then((r) => result = r),
      );
      await tester.pump(const Duration(seconds: 11));

      expect(result?.syncState, SyncState.queued);
      expect(repo.uploads, 0);

      repo.writeGate!.complete();
      await tester.pump();
      await tester.pump();

      expect(state.reports.any((r) => r.id == result!.id), isTrue);
      expect(repo.uploads, 1, reason: 'listener uploads the photo once');
    });

    testWidgets('a queued report the server refuses turns into Not sent', (
      tester,
    ) async {
      final repo = ControlledRepository()..failNextWriteWith = permissionDenied;
      final state = buildState(repo, online: false);
      await pumpApp(tester, state);

      await fillValidForm(tester);
      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Report not sent'), findsOneWidget);
      expect(find.textContaining('Open My reports to retry'), findsOneWidget);
    });
  });

  group('Duplicates and double submission', () {
    testWidgets('"View earlier report" opens it and sends nothing new', (
      tester,
    ) async {
      final repo = ControlledRepository();
      final state = buildState(repo);
      final earlier = await submit(state);
      await pumpApp(tester, state);

      await fillValidForm(tester);
      await tapSubmit(tester);
      await tapAndSettle(tester, find.text('View earlier report'));

      expect(find.text(earlier.id), findsOneWidget);
      expect(repo.writes, 1);
    });

    testWidgets('dismissing the duplicate prompt keeps the form unsent', (
      tester,
    ) async {
      final repo = ControlledRepository();
      final state = buildState(repo);
      await submit(state);
      await pumpApp(tester, state);

      await fillValidForm(tester);
      await tapSubmit(tester);
      await tester.tapAt(const Offset(5, 5)); // tap outside the dialog
      await tester.pumpAndSettle();

      expect(find.text('Already reported?'), findsNothing);
      expect(find.text('Tree across the road'), findsOneWidget);
      expect(repo.writes, 1);
    });

    testWidgets('tapping Submit again while sending does not send twice', (
      tester,
    ) async {
      final repo = ControlledRepository()..writeGate = Completer<void>();
      final state = buildState(repo);
      await pumpApp(tester, state);
      await fillValidForm(tester);

      final submitButton = find.text('Submit report');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();
      expect(find.text('Sending your report…'), findsOneWidget);
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();

      repo.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(find.text('Report submitted'), findsOneWidget);
    });
  });

  group('Confirmation and status tracking', () {
    testWidgets('confirmation leads to My reports with a Pending badge', (
      tester,
    ) async {
      final state = buildState(ControlledRepository());
      await pumpApp(tester, state);
      await fillValidForm(tester);
      await tapSubmit(tester);
      final id = state.myReports.single.id;

      expect(find.textContaining(id), findsOneWidget);
      await tapAndSettle(tester, find.text('View my reports'));

      expect(find.text('My reports'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.textContaining(id), findsOneWidget);
    });

    testWidgets('"Back to home" returns to the citizen home', (tester) async {
      final state = buildState(ControlledRepository());
      final report = await submit(state);
      await pumpApp(
        tester,
        state,
        start: '/citizen/report/submitted/${report.id}',
      );

      await tapAndSettle(tester, find.text('Back to home'));
      expect(find.text('Report ground hazard'), findsOneWidget);
    });

    testWidgets('empty history offers to report a hazard', (tester) async {
      await pumpApp(
        tester,
        buildState(ControlledRepository()),
        start: '/citizen/reports',
      );
      expect(find.text('No reports yet'), findsOneWidget);

      await tapAndSettle(tester, find.text('Report a hazard'));
      expect(find.text('What are you reporting?'), findsOneWidget);
    });

    testWidgets('a report history load error can be retried', (tester) async {
      final repo = ControlledRepository()..failNextWatchWith = permissionDenied;
      final state = buildState(repo);
      await submit(state);
      await pumpApp(tester, state, start: '/citizen/reports');

      expect(find.text('Reports unavailable'), findsOneWidget);
      expect(find.textContaining('Permission denied'), findsOneWidget);

      await tapAndSettle(tester, find.text('Retry'));
      expect(find.text('Reports unavailable'), findsNothing);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('an unknown report ID shows a way back', (tester) async {
      await pumpApp(
        tester,
        buildState(ControlledRepository()),
        start: '/citizen/reports/GR-DOES-NOT-EXIST',
      );
      await tapAndSettle(tester, find.text('Back'));
      expect(find.text('Report ground hazard'), findsOneWidget);
    });
  });

  group('Officer queue and verification', () {
    testWidgets('a citizen report reaches the officer queue and a CONFIRM '
        'is visible to the citizen', (tester) async {
      final auth = CitizenAuth();
      final state = buildState(ControlledRepository(), auth: auth);
      final report = await submit(state);
      auth.emit(officerSession);
      final router = await pumpApp(
        tester,
        state,
        start: '/officer/reports/pending',
      );

      await tapAndSettle(tester, find.textContaining(report.id).first);
      await tapAndSettle(tester, find.text('Confirm report').first);
      expect(find.text('Confirm this report?'), findsOneWidget);
      await tapAndSettle(tester, find.text('Confirm report').last);

      final saved = state.myReportById(report.id)!;
      expect(saved.status, ReportStatus.verified);
      expect(saved.verifiedByUid, officerSession.uid);

      router.go('/citizen/reports/${report.id}');
      await tester.pumpAndSettle();
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('OFFICER REVIEW'), findsOneWidget);
      expect(find.text('Reason'), findsNothing);
    });

    testWidgets('a DISMISSED report shows the officer reason to the citizen', (
      tester,
    ) async {
      const reason = 'Road was already cleared by the council';
      final auth = CitizenAuth(session: officerSession);
      final state = buildState(ControlledRepository(), auth: auth);
      final report = await submit(state);
      await tester.pump(); // deliver the officer session
      await state.rejectReport(report.id, reason: reason);
      final router = await pumpApp(tester, state, start: '/citizen/reports');

      expect(find.text('Dismissed'), findsOneWidget);
      expect(find.text('Reason: $reason'), findsNothing); // in subtitle text
      expect(find.textContaining('Reason: $reason'), findsOneWidget);

      router.push('/citizen/reports/${report.id}');
      await tester.pumpAndSettle();
      expect(find.text('OFFICER REVIEW'), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
    });

    testWidgets('the officer sees possible duplicates and the reporter '
        'contact, without either blocking the review', (tester) async {
      final state = buildState(
        ControlledRepository(),
        auth: CitizenAuth(session: officerSession),
      );
      final first = await submit(state);
      final second = await submit(
        state,
        contact: const ReporterContact(name: 'Nimal', phone: '0771234567'),
      );
      final router = await pumpApp(tester, state, start: '/officer/home');
      router.push('/officer/reports/${second.id}/verify');
      await tester.pumpAndSettle();

      expect(find.textContaining('Possible duplicates'), findsOneWidget);
      expect(find.textContaining('${first.id} · 0 m away'), findsOneWidget);
      expect(find.text('Nimal'), findsOneWidget);
      expect(find.text('0771234567'), findsOneWidget);
      expect(find.text('Confirm report'), findsOneWidget);

      // Following the duplicate opens the earlier report, which left no
      // contact details.
      await tapAndSettle(tester, find.textContaining('${first.id} · 0 m away'));
      expect(find.text('Not provided'), findsOneWidget);
    });

    test('only officers can read the reporter contact', () async {
      final auth = CitizenAuth();
      final state = buildState(ControlledRepository(), auth: auth);
      await settle();
      final report = await submit(
        state,
        contact: const ReporterContact(name: 'Nimal', phone: '0771234567'),
      );

      await expectLater(
        state.reporterContact(report.id),
        throwsA(isA<OfficerNotAuthorizedException>()),
      );
      auth.emit(officerSession);
      await settle();
      expect((await state.reporterContact(report.id))?.phone, '0771234567');
    });
  });

  group('Unauthorized access', () {
    testWidgets('a signed-in non-officer sees "Not authorized", not reports', (
      tester,
    ) async {
      final state = buildState(
        ControlledRepository(),
        auth: CitizenAuth(
          session: const OfficerSession(
            status: OfficerAccessStatus.unauthorized,
            uid: 'u-1',
            email: 'someone@example.com',
            message: 'This account is not a duty officer.',
          ),
        ),
      );
      final report = await submit(state);
      await pumpApp(tester, state, start: '/officer/reports/pending');

      expect(find.text('Not authorized'), findsOneWidget);
      expect(find.textContaining(report.id), findsNothing);
      await expectLater(
        state.verifyReport(report.id),
        throwsA(isA<OfficerNotAuthorizedException>()),
      );
      expect(state.myReportById(report.id)!.status, ReportStatus.pending);
    });
  });

  group('Errors and edge cases', () {
    test('error messages cover every failure type', () {
      expect(
        describeReportError(
          const ReportAlreadyReviewedException(
            ReportStatus.verified,
            reviewedBy: 'Officer Silva',
          ),
        ),
        'This report was already confirmed by Officer Silva. '
        'No changes were made.',
      );
      expect(
        describeReportError(const OfficerNotAuthorizedException()),
        contains('duty officers'),
      );
      expect(
        describeReportError(TimeoutException('slow')),
        contains('No response from the server'),
      );
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(
          describeReportError(
            FirebaseException(plugin: 'cloud_firestore', code: code),
          ),
          contains("Can't reach the server"),
        );
      }
      expect(
        describeReportError(
          FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
        ),
        'This report no longer exists.',
      );
      expect(
        describeReportError(
          FirebaseException(plugin: 'cloud_firestore', code: 'aborted'),
        ),
        contains('(aborted)'),
      );
      expect(
        describeReportError(ArgumentError('short')),
        contains('at least ${ReportReviewRules.minDismissalReasonLength}'),
      );
      expect(describeReportError(Exception('?')), contains('Something went'));
    });

    test('officer duplicate flags are ordered nearest first', () {
      final now = DateTime(2026, 10, 9, 12);
      const road = HazardCategory.blockedRoad;
      final base = reportAt('base', road, now);
      final far = reportAt(
        'far',
        road,
        now,
        coordinates: const GeoCoordinate(latitude: 6.933, longitude: 79.90),
      );
      final near = reportAt(
        'near',
        road,
        now,
        coordinates: const GeoCoordinate(latitude: 6.9301, longitude: 79.90),
      );
      expect(possibleDuplicates(base, [base, far, near]).map((r) => r.id), [
        'near',
        'far',
      ]);
    });

    test(
      'retrying an unknown report fails; a saved one is not resent',
      () async {
        final repo = ControlledRepository();
        final state = buildState(repo);
        await settle();
        await expectLater(
          state.retryFailedSubmission('GR-NOPE'),
          throwsA(isA<StateError>()),
        );

        final saved = await submit(state);
        await settle();
        final again = await state.retryFailedSubmission(saved.id);
        expect(again.id, saved.id);
        expect(repo.writes, 1);
      },
    );

    test(
      'a report stream error clears when the signed-in user changes',
      () async {
        final auth = CitizenAuth();
        final repo = ControlledRepository()
          ..failNextWatchWith = permissionDenied;
        final state = buildState(repo, auth: auth);
        await settle();
        expect(state.reportsError, permissionDenied);
        expect(state.reportsLoaded, isTrue);

        auth.emit(officerSession);
        await settle();
        await settle();
        expect(state.reportsError, isNull);
        expect(state.reports, isNotEmpty);
      },
    );

    testWidgets('a server error keeps the form and a retry sends once', (
      tester,
    ) async {
      final repo = ControlledRepository()..failNextWriteWith = permissionDenied;
      final state = buildState(repo);
      await pumpApp(tester, state);
      await fillValidForm(tester);

      await tapSubmit(tester);
      expect(
        find.textContaining('Report not sent. Permission denied'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Your details are still here'),
        findsOneWidget,
      );
      expect(find.text('Tree across the road'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tapSubmit(tester);
      expect(find.text('Report submitted'), findsOneWidget);
      expect(repo.writes, 2);
      expect(state.myReports, hasLength(1));
    });

    testWidgets('back on an empty form leaves without asking', (tester) async {
      await pumpApp(tester, buildState(ControlledRepository()));
      await tapAndSettle(tester, find.byIcon(Icons.arrow_back_rounded));
      expect(find.text('Discard this report?'), findsNothing);
      expect(find.text('Report ground hazard'), findsOneWidget);
    });

    testWidgets('system back with input asks, and Discard leaves the form', (
      tester,
    ) async {
      final repo = ControlledRepository();
      await pumpApp(tester, buildState(repo));
      await tester.enterText(descriptionField(), 'Half-typed');
      // Android system back button.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard this report?'), findsOneWidget);
      await tapAndSettle(tester, find.text('Discard'));

      expect(find.text('Report ground hazard'), findsOneWidget);
      expect(repo.writes, 0);
    });
  });
}
