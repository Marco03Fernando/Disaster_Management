import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/app.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/repositories/local_data_repository.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/services/officer_auth_service.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:provider/provider.dart';

/// Test doubles for the Submit and Verify Ground Hazard Report use case.
/// Firebase is never touched: the repository is the in-memory
/// [LocalDataRepository] and auth is a settable fake.

/// Auth that enforces access like Firebase. A citizen by default; pass
/// [officerSession] (or call [emit]) to act as a duty officer.
class CitizenAuth implements OfficerAuthService {
  CitizenAuth({this.uid = 'citizen-1', OfficerSession? session})
    : _session = session ?? OfficerSession.signedOut;

  String? uid;
  OfficerSession _session;
  final _ctrl = StreamController<OfficerSession>.broadcast();

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
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async => emit(OfficerSession.signedOut);

  @override
  Future<void> refresh() async {}
}

const officerSession = OfficerSession(
  status: OfficerAccessStatus.authorized,
  uid: 'officer-7',
  displayName: 'Officer Perera',
  email: 'perera@dmc.lk',
);

/// In-memory repository whose report stream, writes and photo uploads can be
/// delayed or made to fail.
class ControlledRepository extends LocalDataRepository {
  int writes = 0;
  int uploads = 0;
  int uploadFailures = 0;
  Object? failNextWriteWith;
  Object? failNextWatchWith;

  /// When set, writes wait for it (simulates a slow server).
  Completer<void>? writeGate;

  @override
  Stream<List<HazardReport>> watchReports() {
    final error = failNextWatchWith;
    if (error != null) {
      failNextWatchWith = null;
      return Stream.error(error);
    }
    return super.watchReports();
  }

  @override
  Future<String> submitReport(
    HazardReport draft, {
    ReporterContact? contact,
  }) async {
    writes++;
    final gate = writeGate;
    if (gate != null) await gate.future;
    final error = failNextWriteWith;
    if (error != null) {
      failNextWriteWith = null;
      throw error;
    }
    return super.submitReport(draft, contact: contact);
  }

  @override
  Future<void> uploadReportPhoto(HazardReport report) async {
    uploads++;
    if (uploadFailures > 0) {
      uploadFailures--;
      throw FirebaseException(plugin: 'firebase_storage', code: 'unknown');
    }
  }
}

final permissionDenied = FirebaseException(
  plugin: 'cloud_firestore',
  code: 'permission-denied',
);

const here = GeoCoordinate(latitude: 6.93, longitude: 79.90);

AppState buildState(
  ControlledRepository repo, {
  OfficerAuthService? auth,
  bool online = true,
  bool usesFirebase = false,
}) => AppState(
  AppServices.test(
    repository: repo,
    auth: auth ?? CitizenAuth(),
    online: online,
    usesFirebase: usesFirebase,
  ),
);

Future<HazardReport> submit(
  AppState state, {
  String? id,
  HazardCategory category = HazardCategory.blockedRoad,
  String? photoPath,
  ReporterContact? contact,
}) => state.submitGroundReport(
  id: id,
  category: category,
  areaLabel: 'Kolonnawa',
  locationLabel: 'Main road',
  coordinates: here,
  photoPath: photoPath,
  notes: 'Tree across both lanes',
  contact: contact,
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

HazardReport reportAt(
  String id,
  HazardCategory category,
  DateTime submittedAt, {
  ReportStatus status = ReportStatus.pending,
  GeoCoordinate coordinates = here,
}) => HazardReport(
  id: id,
  category: category,
  areaLabel: 'Kolonnawa',
  locationLabel: 'x',
  coordinates: coordinates,
  status: status,
  submittedAt: submittedAt,
);

/// Pumps the real app and router, opening [start] on top of the citizen
/// home screen so back navigation behaves as on a device.
Future<GoRouter> pumpApp(
  WidgetTester tester,
  AppState state, {
  String start = '/citizen/report/new',
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final router = buildRouter();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: HazardWarningApp(router: router),
    ),
  );
  router.go('/citizen/home');
  await tester.pumpAndSettle();
  if (start != '/citizen/home') {
    router.push(start);
    await tester.pumpAndSettle();
  }
  return router;
}

/// Stands in for the device camera/gallery on image_picker's platform
/// channel, so photo flows run without a real device.
class FakeImagePicker {
  static const channel = MethodChannel('plugins.flutter.io/image_picker');

  /// What `pickImage` returns: a file path, null (cancelled), or a
  /// [PlatformException] to throw.
  Object? pickResult;

  /// What `retrieve` (Android lost-data recovery) returns.
  Map<String, Object?>? lostData;

  final calls = <MethodCall>[];

  void install(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'retrieve':
          return lostData;
        case 'pickImage':
          final result = pickResult;
          if (result is PlatformException) throw result;
          return result;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  /// `source` argument of the last pick: 0 = camera, 1 = gallery.
  int? get lastSource =>
      calls.lastWhere((c) => c.method == 'pickImage').arguments['source']
          as int?;
}

Finder descriptionField() =>
    find.widgetWithText(TextFormField, 'Description (required)');

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapSubmit(WidgetTester tester) =>
    tapAndSettle(tester, find.text('Submit report'));

/// Fills the required fields with valid values.
Future<void> fillValidForm(
  WidgetTester tester, {
  HazardCategory category = HazardCategory.blockedRoad,
  String description = 'Tree across the road',
}) async {
  await tapAndSettle(tester, find.text(category.label));
  await tester.enterText(descriptionField(), description);
  await tester.pump();
}
