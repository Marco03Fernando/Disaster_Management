import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/features/citizen/report_submission_rules.dart';

import 'support/hazard_report_fakes.dart';

void main() {
  group('Form validation', () {
    test('hazard type must be chosen', () {
      expect(validateHazardCategory(null), isNotNull);
      expect(validateHazardCategory(HazardCategory.blockedRoad), isNull);
    });

    test('description is required after trimming, with no minimum length', () {
      expect(validateDescription(null), 'Describe what you see.');
      expect(validateDescription(''), 'Describe what you see.');
      expect(validateDescription('  \n\t '), 'Describe what you see.');
      expect(validateDescription('Flooded'), isNull);
      expect(validateDescription('x'), isNull);
    });

    test('description over the limit is rejected', () {
      final max = ReportFormRules.maxDescriptionLength;
      expect(validateDescription('a' * max), isNull);
      expect(validateDescription('a' * (max + 1)), isNotNull);
    });

    test('phone is optional but must look like a phone number', () {
      expect(validatePhone(null), isNull);
      expect(validatePhone('   '), isNull);
      expect(validatePhone('0771234567'), isNull);
      expect(validatePhone('+94 77 123-4567'), isNull);
      expect(validatePhone('call me'), isNotNull);
      expect(validatePhone('12345'), isNotNull);
      expect(validatePhone('1234567890123456'), isNotNull);
    });
  });

  group('Report IDs', () {
    test('keep the GR- prefix and a parseable format', () {
      expect(newReportId(), matches(RegExp(r'^GR-[0-9A-Z]+-[A-Z2-9]{4}$')));
    });

    test('do not collide when the old scheme did', () {
      // Old IDs were `GR-{ms % 100000}`: these two times gave the same ID.
      final t1 = DateTime.fromMillisecondsSinceEpoch(1760000012345);
      final t2 = t1.add(const Duration(milliseconds: 100000));
      expect(
        t1.millisecondsSinceEpoch % 100000,
        t2.millisecondsSinceEpoch % 100000,
      );
      expect(newReportId(now: t1), isNot(newReportId(now: t2)));
    });

    test('differ within the same millisecond via the random suffix', () {
      final now = DateTime(2026, 10, 9, 12);
      final rng = math.Random(1);
      final ids = {
        for (var i = 0; i < 20; i++) newReportId(now: now, random: rng),
      };
      expect(ids.length, 20);
    });
  });

  group('Recent own report (soft duplicate check)', () {
    final now = DateTime(2026, 10, 9, 12);
    const road = HazardCategory.blockedRoad;

    test('finds the latest same-type report inside the window', () {
      final mine = [
        reportAt('a', road, now.subtract(const Duration(minutes: 25))),
        reportAt('b', road, now.subtract(const Duration(minutes: 5))),
      ];
      expect(
        recentOwnReport(category: road, myReports: mine, now: now)?.id,
        'b',
      );
    });

    test('ignores other types, old, dismissed and future reports', () {
      final mine = [
        reportAt('flood', HazardCategory.risingRiver, now),
        reportAt('old', road, now.subtract(const Duration(minutes: 31))),
        reportAt(
          'dismissed',
          road,
          now.subtract(const Duration(minutes: 1)),
          status: ReportStatus.rejected,
        ),
        reportAt('future', road, now.add(const Duration(minutes: 5))),
      ];
      expect(
        recentOwnReport(category: road, myReports: mine, now: now),
        isNull,
      );
    });

    test('does not use distance, since locations are not GPS', () {
      final far = reportAt(
        'far',
        road,
        now.subtract(const Duration(minutes: 2)),
        coordinates: const GeoCoordinate(latitude: 7.29, longitude: 80.63),
      );
      expect(
        recentOwnReport(category: road, myReports: [far], now: now)?.id,
        'far',
      );
    });
  });

  group('Error messages', () {
    test('photo permission and device failures are explained', () {
      expect(
        describePhotoError(
          PlatformException(code: 'camera_access_denied'),
          fromCamera: true,
        ),
        contains('Camera permission is off'),
      );
      expect(
        describePhotoError(
          PlatformException(code: 'photo_access_denied'),
          fromCamera: false,
        ),
        contains('Photo library permission is off'),
      );
      expect(
        describePhotoError(StateError('boom'), fromCamera: true),
        contains('Camera unavailable'),
      );
      expect(
        describePhotoError(StateError('boom'), fromCamera: false),
        contains('gallery'),
      );
    });

    test('missing citizen session is explained', () {
      expect(
        describeSubmissionError(const CitizenSessionUnavailableException()),
        contains('Connect to the internet'),
      );
    });
  });

  group('Submission (AppState)', () {
    test('generates a new-format ID and reaches the officer queue', () async {
      final repo = ControlledRepository();
      final state = buildState(repo);
      await settle();

      final report = await submit(state);
      await settle();

      expect(report.id, startsWith('GR-'));
      expect(report.id.split('-'), hasLength(3));
      expect(state.pendingReports.map((r) => r.id), contains(report.id));
      // A citizen (not an officer) cannot verify it.
      await expectLater(
        state.verifyReport(report.id),
        throwsA(isA<OfficerNotAuthorizedException>()),
      );
    });

    test('retrying with the same draft ID writes only once', () async {
      final repo = ControlledRepository();
      final state = buildState(repo);
      await settle();

      final first = await submit(state, id: 'GR-DRAFT-0001');
      await settle();
      final second = await submit(state, id: 'GR-DRAFT-0001');
      await settle();

      expect(repo.writes, 1);
      expect(second.id, first.id);
      expect(state.reports.where((r) => r.id == 'GR-DRAFT-0001'), hasLength(1));
    });

    test('an online failure is reported and a retry with the same ID saves '
        'exactly one report', () async {
      final repo = ControlledRepository()..failNextWriteWith = permissionDenied;
      final state = buildState(repo);
      await settle();

      await expectLater(
        submit(state, id: 'GR-DRAFT-0002'),
        throwsA(isA<FirebaseException>()),
      );
      expect(state.reports.any((r) => r.id == 'GR-DRAFT-0002'), isFalse);

      await submit(state, id: 'GR-DRAFT-0002');
      await settle();
      expect(state.reports.where((r) => r.id == 'GR-DRAFT-0002'), hasLength(1));
    });

    test(
      'a queued write the server refuses is kept as "failed", not lost',
      () async {
        final repo = ControlledRepository()
          ..failNextWriteWith = permissionDenied;
        final state = buildState(repo, online: false);
        await settle();

        final report = await submit(state);
        expect(report.syncState, SyncState.queued);
        await settle();

        final mine = state.myReportById(report.id);
        expect(mine?.syncState, SyncState.failed);
        expect(mine?.notes, 'Tree across both lanes');
        expect(state.myReports.first.id, report.id);
        expect(state.submissionError(report.id), permissionDenied);
        // Unsent reports never appear in the officer queue.
        expect(state.pendingReports.any((r) => r.id == report.id), isFalse);
      },
    );

    test(
      'a failed report can be resent with its original ID and time',
      () async {
        final repo = ControlledRepository()
          ..failNextWriteWith = permissionDenied;
        final state = buildState(repo, online: false);
        await settle();
        final report = await submit(state);
        await settle();

        final resent = await state.retryFailedSubmission(report.id);
        await settle();

        expect(resent.id, report.id);
        expect(resent.submittedAt, report.submittedAt);
        expect(state.submissionError(report.id), isNull);
        expect(state.myReports.where((r) => r.id == report.id), hasLength(1));
        expect(
          state.myReportById(report.id)?.syncState,
          isNot(SyncState.failed),
        );
      },
    );

    test('a retry that fails again stays in the Not sent list', () async {
      final repo = ControlledRepository()..failNextWriteWith = permissionDenied;
      final state = buildState(repo, online: false);
      await settle();
      final report = await submit(state);
      await settle();

      repo.failNextWriteWith = permissionDenied;
      final again = await state.retryFailedSubmission(report.id);
      expect(again.syncState, SyncState.queued);
      await settle();

      expect(state.myReportById(report.id)?.syncState, SyncState.failed);
      expect(state.submissionError(report.id), permissionDenied);
    });

    test('a retry refused up front keeps the report and rethrows', () async {
      final auth = CitizenAuth();
      final repo = ControlledRepository()..failNextWriteWith = permissionDenied;
      final state = buildState(repo, auth: auth, online: false);
      await settle();
      final report = await submit(state);
      await settle();

      auth.uid = null;
      await expectLater(
        state.retryFailedSubmission(report.id),
        throwsA(isA<CitizenSessionUnavailableException>()),
      );
      expect(state.myReportById(report.id)?.syncState, SyncState.failed);
      expect(
        state.submissionError(report.id),
        isA<CitizenSessionUnavailableException>(),
      );
    });

    test(
      'no citizen account: the report is refused up front, not queued',
      () async {
        final repo = ControlledRepository();
        final state = buildState(repo, auth: CitizenAuth(uid: null));
        await settle();

        await expectLater(
          submit(state),
          throwsA(isA<CitizenSessionUnavailableException>()),
        );
        expect(repo.writes, 0);
        expect(
          state.myReports.where((r) => r.syncState == SyncState.failed),
          isEmpty,
        );
      },
    );

    test('a photo upload that failed can be retried by the citizen', () async {
      final repo = ControlledRepository()..uploadFailures = 2;
      final state = buildState(repo, usesFirebase: true);
      await settle();

      final report = await submit(state, photoPath: '/tmp/photo.jpg');
      await settle();
      final saved = state.myReportById(report.id)!;
      expect(state.photoNeedsUpload(saved), isTrue);
      expect(repo.uploads, 1); // automatic attempt after the write

      await expectLater(
        state.retryPhotoUpload(report.id),
        throwsA(isA<FirebaseException>()),
      );
      expect(state.isUploadingPhoto(report.id), isFalse);

      await state.retryPhotoUpload(report.id);
      expect(repo.uploads, 3);
      expect(state.isUploadingPhoto(report.id), isFalse);
    });
  });

  group('Citizen screens', () {
    testWidgets('an empty form shows field errors and sends nothing', (
      tester,
    ) async {
      final repo = ControlledRepository();
      final state = buildState(repo);
      await pumpApp(tester, state);

      await tapSubmit(tester);

      expect(
        find.text('Choose the type of hazard you are reporting.'),
        findsOneWidget,
      );
      expect(find.text('Describe what you see.'), findsOneWidget);
      expect(
        find.text('Please complete the highlighted fields.'),
        findsOneWidget,
      );
      expect(repo.writes, 0);
    });

    testWidgets('whitespace-only description and bad phone are rejected', (
      tester,
    ) async {
      final repo = ControlledRepository();
      final state = buildState(repo);
      await pumpApp(tester, state);

      await tester.tap(find.text(HazardCategory.blockedRoad.label));
      await tester.enterText(descriptionField(), '    ');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone number'),
        'abc',
      );
      await tapSubmit(tester);

      expect(find.text('Describe what you see.'), findsOneWidget);
      expect(find.textContaining('Enter a valid phone number'), findsOneWidget);
      expect(repo.writes, 0);
    });

    testWidgets('a valid report is sent and confirmed', (tester) async {
      final repo = ControlledRepository();
      final state = buildState(repo);
      await pumpApp(tester, state);

      await tester.tap(find.text(HazardCategory.blockedRoad.label));
      await tester.enterText(descriptionField(), '  Tree across the road  ');
      await tapSubmit(tester);

      expect(find.text('Report submitted'), findsOneWidget);
      expect(repo.writes, 1);
      final mine = state.myReports.single;
      expect(mine.category, HazardCategory.blockedRoad);
      expect(mine.notes, 'Tree across the road');
      expect(mine.status, ReportStatus.pending);
    });

    testWidgets('location is labelled approximate, never as GPS', (
      tester,
    ) async {
      final state = buildState(ControlledRepository());
      await pumpApp(tester, state);

      expect(find.text('Approximate area location (not GPS)'), findsOneWidget);
      expect(find.textContaining('GPS location'), findsNothing);
    });

    testWidgets('category tiles expose their selected state to screen '
        'readers', (tester) async {
      final handle = tester.ensureSemantics();
      final state = buildState(ControlledRepository());
      await pumpApp(tester, state);

      final label = HazardCategory.landslideCrack.label;
      expect(
        tester.getSemantics(find.text(label)),
        isSemantics(isSelected: false, isButton: true),
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text(label)),
        isSemantics(isSelected: true, isButton: true),
      );
      handle.dispose();
    });

    testWidgets('leaving with unsaved input asks before discarding', (
      tester,
    ) async {
      final state = buildState(ControlledRepository());
      await pumpApp(tester, state);

      await tester.enterText(descriptionField(), 'Water rising');
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Discard this report?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Water rising'), findsOneWidget);
    });

    testWidgets('a recent report of the same type asks, but does not block', (
      tester,
    ) async {
      final repo = ControlledRepository();
      final state = buildState(repo);
      await submit(state, category: HazardCategory.blockedRoad);
      await pumpApp(tester, state);

      await tester.tap(find.text(HazardCategory.blockedRoad.label));
      await tester.enterText(descriptionField(), 'Second tree fell');
      await tapSubmit(tester);

      expect(find.text('Already reported?'), findsOneWidget);
      await tester.tap(find.text('Submit anyway'));
      await tester.pumpAndSettle();

      expect(find.text('Report submitted'), findsOneWidget);
      expect(repo.writes, 2);
    });

    testWidgets('a failed report shows Not sent and can be resent', (
      tester,
    ) async {
      final repo = ControlledRepository()..failNextWriteWith = permissionDenied;
      final state = buildState(repo, online: false);
      final report = await submit(state);
      await pumpApp(tester, state, start: '/citizen/reports');

      expect(find.text('Not sent'), findsOneWidget);
      expect(find.textContaining('Not sent — tap to retry'), findsOneWidget);

      await tester.tap(find.textContaining(report.id));
      await tester.pumpAndSettle();
      expect(find.text('Retry sending'), findsOneWidget);

      await tester.tap(find.text('Retry sending'));
      await tester.pumpAndSettle();

      expect(state.submissionError(report.id), isNull);
      expect(state.myReportById(report.id)?.syncState, SyncState.queued);
      expect(find.text('Retry sending'), findsNothing);
    });
  });
}
