import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/app.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/repositories/data_repository.dart';
import 'package:hazard_warning_app/core/repositories/local_data_repository.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:provider/provider.dart';

/// In-memory stand-in for [AppServices] so tests never touch Firebase or
/// the connectivity plugin.
class FakeAppServices implements AppServices {
  FakeAppServices(this.repository, {this.online = true});

  @override
  final DataRepository repository;

  final bool online;

  @override
  bool get usesFirebase => false;

  @override
  Connectivity get connectivity => throw UnimplementedError('not used in tests');

  @override
  Stream<bool> watchOnline() => const Stream<bool>.empty();

  @override
  Future<bool> isOnline() async => online;
}

/// Repository with no warnings at all, to exercise the "nothing issued yet"
/// states ([LocalDataRepository] always seeds two warnings).
class NoWarningsRepository extends LocalDataRepository {
  @override
  Stream<List<HazardWarning>> watchWarnings() => Stream.value(const []);
}

/// Channel result with explicit numbers, for deterministic UI assertions.
ChannelDelivery delivery(
  AlertChannel channel, {
  required int targeted,
  int failed = 0,
  int recovered = 0,
  AlertChannel? fallback,
}) {
  return ChannelDelivery(
    channel: channel,
    targeted: targeted,
    delivered: targeted - failed,
    failed: failed,
    recovered: recovered,
    fallback: fallback,
  );
}

HazardWarning sampleWarning({
  String id = 'HW-T1',
  String sourceReportId = 'GR-2481',
  HazardCategory category = HazardCategory.risingRiver,
  WarningSeverity severity = WarningSeverity.high,
  BroadcastScope scope = BroadcastScope.riverBasin,
  List<String> targetAreas = const ['Kelani river basin'],
  int recipientCount = 12480,
  WarningLevel level = WarningLevel.warning,
  int escalations = 0,
  List<ChannelDelivery>? deliveries,
}) {
  return HazardWarning(
    id: id,
    sourceReportId: sourceReportId,
    category: category,
    severity: severity,
    scope: scope,
    targetAreas: targetAreas,
    recipientCount: recipientCount,
    issuedAt: DateTime(2026, 6, 12, 9, 30),
    level: level,
    escalations: escalations,
    deliveries:
        deliveries ??
        [
          delivery(AlertChannel.push, targeted: 100),
          delivery(AlertChannel.sms, targeted: 100),
          delivery(AlertChannel.audible, targeted: 40),
        ],
  );
}

/// Plain-Dart [AppState] backed by the seeded local repository. Waits for the
/// repository streams to deliver their first event.
Future<AppState> createAppState({DataRepository? repository}) async {
  final state = AppState(FakeAppServices(repository ?? LocalDataRepository()));
  await pumpEventQueue();
  return state;
}

/// Same, for use inside `testWidgets` where time is controlled by the tester.
Future<AppState> createAppStateInWidgetTest(
  WidgetTester tester, {
  DataRepository? repository,
}) async {
  final state = AppState(FakeAppServices(repository ?? LocalDataRepository()));
  await tester.pump();
  return state;
}

/// Pumps the real app router at [location] with [state] provided.
Future<GoRouter> pumpApp(
  WidgetTester tester,
  AppState state,
  String location,
) async {
  // 800 x 1200 logical pixels. The default test font (Ahem) is wider than the
  // real app font, so a phone-width viewport would report false overflows.
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: HazardWarningApp(router: router),
    ),
  );
  router.go(location);
  await tester.pumpAndSettle();
  return router;
}

/// Adds [warning] to the repository and lets the state pick it up.
Future<void> addWarning(
  WidgetTester tester,
  AppState state,
  HazardWarning warning,
) async {
  await state.repository.issueWarning(warning);
  await tester.pump();
}
