import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/repositories/data_repository.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/services/notification_gateway.dart';

class AppState extends ChangeNotifier {
  AppState(this._services) {
    _listenReports();
    _listenWarnings();
    _listenShelters();
    _listenConnectivity();
  }

  final AppServices _services;
  final _gateway = const NotificationGateway();
  UserRole? _role;
  bool _online = true;
  List<HazardReport> _reports = [];
  List<HazardWarning> _warnings = [];
  List<Shelter> _shelters = [];
  List<CitizenAlert> _alerts = [];

  StreamSubscription<List<HazardReport>>? _reportsSub;
  StreamSubscription<List<HazardWarning>>? _warningsSub;
  StreamSubscription<List<Shelter>>? _sheltersSub;
  StreamSubscription<bool>? _onlineSub;

  UserRole? get role => _role;
  bool get online => _online;
  bool get usesFirebase => _services.usesFirebase;
  List<HazardReport> get reports => _reports;
  List<HazardReport> get pendingReports =>
      _reports.where((r) => r.status == ReportStatus.pending).toList();
  List<HazardWarning> get warnings => _warnings;
  List<Shelter> get shelters => _shelters;

  /// Verified reports that still need a warning issued.
  /// Reports that already have a warning are excluded.
  List<HazardReport> get verifiedAwaitingWarning {
    final warned = _warnings.map((w) => w.sourceReportId).toSet();
    return _reports
        .where(
          (r) => r.status == ReportStatus.verified && !warned.contains(r.id),
        )
        .toList();
  }

  List<CitizenAlert> get alerts => _alerts;

  DataRepository get repository => _services.repository;

  void setRole(UserRole role) {
    _role = role;
    notifyListeners();
  }

  void _listenReports() {
    _reportsSub = _services.repository.watchReports().listen((data) {
      _reports = data;
      notifyListeners();
    });
  }

  void _listenWarnings() {
    _warningsSub = _services.repository.watchWarnings().listen((data) {
      _warnings = data;
      _alerts = data.map(_alertFromWarning).toList();
      notifyListeners();
    });
  }

  void _listenShelters() {
    _sheltersSub = _services.repository.watchShelters().listen((data) {
      _shelters = data;
      notifyListeners();
    });
  }

  void _listenConnectivity() {
    _onlineSub = _services.watchOnline().listen((value) {
      _online = value;
      notifyListeners();
    });
    _services.isOnline().then((value) {
      _online = value;
      notifyListeners();
    });
  }

  CitizenAlert _alertFromWarning(HazardWarning warning) {
    final sev = warning.severity.label;
    final hazard = warning.category.label;
    final level = warning.level;
    final body =
        '${level.label.toUpperCase()}: $sev severity $hazard for ${warning.targetAreas.join(", ")}. ${level.action}. Follow DMC instructions and move to higher ground if advised.';
    return CitizenAlert(
      warningId: warning.id,
      title: '$hazard — ${level.label}',
      body: body,
      severity: warning.severity,
      issuedAt: warning.issuedAt,
      smsText:
          'DMC ALERT [${sev.toUpperCase()}]: $hazard affecting ${warning.targetAreas.join(", ")}. $body',
    );
  }

  Future<HazardReport> submitGroundReport({
    required HazardCategory category,
    required String areaLabel,
    required String locationLabel,
    required GeoCoordinate coordinates,
    String? photoPath,
    String? notes,
  }) async {
    final online = await _services.isOnline();
    final id = 'GR-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final report = HazardReport(
      id: id,
      category: category,
      areaLabel: areaLabel,
      locationLabel: locationLabel,
      coordinates: coordinates,
      status: ReportStatus.pending,
      submittedAt: DateTime.now(),
      photoPath: photoPath,
      notes: notes,
      syncState: online ? SyncState.synced : SyncState.queued,
    );
    await _services.repository.submitReport(report);
    return report;
  }

  Future<void> verifyReport(String id) => _services.repository.verifyReport(id);

  Future<void> rejectReport(String id) => _services.repository.rejectReport(id);

  /// Creates the warning record and hands the alert to the gateway for the
  /// determined recipients, recording the per-channel outcome.
  Future<HazardWarning> issueWarning({
    required HazardReport report,
    required HazardCategory category,
    required WarningSeverity severity,
    required BroadcastScope scope,
    required List<String> targetAreas,
    required int recipientCount,
  }) async {
    final warning = HazardWarning(
      id: 'HW-${DateTime.now().millisecondsSinceEpoch % 100000}',
      sourceReportId: report.id,
      category: category,
      severity: severity,
      scope: scope,
      targetAreas: targetAreas,
      recipientCount: recipientCount,
      issuedAt: DateTime.now(),
      level: WarningLevelX.initialFor(severity),
      deliveries: _gateway.dispatch(recipientCount),
    );
    await _services.repository.issueWarning(warning);
    return warning;
  }

  /// Resends failed deliveries on each channel's fallback channel.
  Future<void> retryFailedDeliveries(String warningId) async {
    final warning = _warningById(warningId);
    if (warning == null) return;
    await _services.repository.updateWarning(
      warning.copyWith(deliveries: _gateway.retryFailed(warning.deliveries)),
    );
  }

  /// Raises the warning level and re-broadcasts to the same recipient list.
  Future<void> escalateWarning(String warningId) async {
    final warning = _warningById(warningId);
    final next = warning?.level.next;
    if (warning == null || next == null) return;
    await _services.repository.updateWarning(
      warning.copyWith(
        level: next,
        escalations: warning.escalations + 1,
        deliveries: _gateway.dispatch(warning.recipientCount),
      ),
    );
  }

  HazardWarning? _warningById(String id) {
    for (final w in _warnings) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> saveShelterOccupancy(String shelterId, int occupancy) {
    return _services.repository.updateShelterOccupancy(shelterId, occupancy);
  }

  Future<String> registerShelter({
    required String name,
    required String district,
    required String address,
    required int capacity,
    String? nearestAlternativeId,
  }) async {
    final shelter = Shelter(
      id: 'SH-${DateTime.now().millisecondsSinceEpoch % 100000}',
      name: name,
      district: district,
      address: address,
      capacity: capacity,
      occupancy: 0,
      nearestAlternativeId: nearestAlternativeId,
    );

    return _services.repository.registerShelter(shelter);
  }

  Future<void> updateShelter(Shelter shelter) {
    return _services.repository.updateShelter(shelter);
  }

  Future<void> deleteShelter(String shelterId) {
    return _services.repository.deleteShelter(shelterId);
  }

  Shelter? shelterById(String id) {
    try {
      return _shelters.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    _warningsSub?.cancel();
    _sheltersSub?.cancel();
    _onlineSub?.cancel();
    super.dispose();
  }
}
