import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/repositories/data_repository.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/services/notification_gateway.dart';
import 'package:hazard_warning_app/core/services/officer_auth_service.dart';

class AppState extends ChangeNotifier {
  AppState(this._services) {
    _listenReports();
    _listenWarnings();
    _listenShelters();
    _listenConnectivity();
    _listenOfficerSession();
  }

  /// How long to wait for the server before treating a report as queued.
  static const _submitTimeout = Duration(seconds: 10);
  static const _reviewTimeout = Duration(seconds: 20);
  static const _photoUploadTimeout = Duration(seconds: 60);

  final AppServices _services;
  final _gateway = const NotificationGateway();
  UserRole? _role;
  bool _online = true;
  List<HazardReport> _reports = [];
  List<HazardWarning> _warnings = [];
  List<Shelter> _shelters = [];
  List<CitizenAlert> _alerts = [];
  bool _reportsLoaded = false;
  Object? _reportsError;
  OfficerSession _officerSession = OfficerSession.checking;
  final _photoUploadsTried = <String>{};
  final _photoUploading = <String>{};

  /// Citizen reports the server refused (or could not be stamped with an
  /// account), kept so they are shown as "Not sent" and can be retried
  /// instead of silently disappearing. In memory only.
  final _failedSubmissions = <String, _FailedSubmission>{};
  bool _disposed = false;

  StreamSubscription<List<HazardReport>>? _reportsSub;
  StreamSubscription<List<HazardWarning>>? _warningsSub;
  StreamSubscription<List<Shelter>>? _sheltersSub;
  StreamSubscription<bool>? _onlineSub;
  StreamSubscription<OfficerSession>? _sessionSub;

  UserRole? get role => _role;
  bool get online => _online;
  bool get usesFirebase => _services.usesFirebase;
  List<HazardReport> get reports => _reports;

  /// False until the first report snapshot arrives.
  bool get reportsLoaded => _reportsLoaded;

  /// Last error from the report stream (e.g. permission denied), if any.
  Object? get reportsError => _reportsError;

  /// Reports submitted from this device's account. Demo mode has no
  /// accounts, so every report is shown.
  List<HazardReport> get myReports {
    final uid = _services.auth.currentUid;
    final mine = (!_services.auth.enforcesAccess || uid == null)
        ? _reports
        : _reports.where((r) => r.reporterUid == uid).toList();
    final failed = _unsentFailures();
    return failed.isEmpty ? mine : [...failed, ...mine];
  }

  List<HazardReport> _unsentFailures() {
    final saved = _reports.map((r) => r.id).toSet();
    return [
      for (final f in _failedSubmissions.values)
        if (!saved.contains(f.report.id)) f.report,
    ];
  }

  /// A report as the citizen should see it, including ones that failed to
  /// send. Saved copies win over a stale failure record.
  HazardReport? myReportById(String id) =>
      _savedReport(id) ?? _failedSubmissions[id]?.report;

  /// Why [id] could not be sent, if it is a failed submission.
  Object? submissionError(String id) => _failedSubmissions[id]?.error;

  /// True when [report]'s photo is on this phone but not in cloud storage.
  bool photoNeedsUpload(HazardReport report) =>
      usesFirebase &&
      report.photoPending &&
      report.photoUrl == null &&
      report.photoPath != null &&
      report.syncState == SyncState.synced;

  bool isUploadingPhoto(String id) => _photoUploading.contains(id);

  OfficerSession get officerSession => _officerSession;
  bool get enforcesOfficerAccess => _services.auth.enforcesAccess;
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
    _reportsSub?.cancel();
    _reportsSub = _services.repository.watchReports().listen(
      (data) {
        _reports = data;
        _reportsLoaded = true;
        _reportsError = null;
        notifyListeners();
        _retryPendingPhotos();
      },
      onError: (Object error) {
        _reportsLoaded = true;
        _reportsError = error;
        notifyListeners();
      },
    );
  }

  /// Re-subscribes to reports after a stream error (e.g. after signing in).
  void reloadReports() {
    _reportsLoaded = false;
    _reportsError = null;
    notifyListeners();
    _listenReports();
  }

  void _listenOfficerSession() {
    _sessionSub = _services.auth.watchSession().listen((session) {
      final previous = _officerSession;
      _officerSession = session;
      notifyListeners();
      // The report stream may have failed under a previous identity.
      if (_reportsError != null && previous.uid != session.uid) {
        reloadReports();
      }
    });
  }

  Future<void> signInOfficer({
    required String email,
    required String password,
  }) {
    return _services.auth.signIn(email: email, password: password);
  }

  Future<void> signOutOfficer() => _services.auth.signOut();

  Future<void> refreshOfficerAccess() => _services.auth.refresh();

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
      final cameOnline = value && !_online;
      _online = value;
      notifyListeners();
      if (cameOnline) {
        _photoUploadsTried.clear();
        _retryPendingPhotos();
      }
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

  /// Saves a citizen report as PENDING. Offline (or when the server is slow)
  /// the write stays in Firestore's local cache and syncs on reconnect, so the
  /// citizen is never left waiting on a spinner.
  ///
  /// Pass the same [id] when retrying a form so a report that was already
  /// saved is not written twice.
  Future<HazardReport> submitGroundReport({
    String? id,
    required HazardCategory category,
    required String areaLabel,
    required String locationLabel,
    required GeoCoordinate coordinates,
    String? photoPath,
    String? notes,
    ReporterContact? contact,
  }) async {
    final reportId = id ?? newReportId();
    final existing = _savedReport(reportId);
    if (existing != null) return existing;
    return _send(
      HazardReport(
        id: reportId,
        category: category,
        areaLabel: areaLabel,
        locationLabel: locationLabel,
        coordinates: coordinates,
        status: ReportStatus.pending,
        submittedAt: DateTime.now(),
        photoPath: photoPath,
        photoPending: photoPath != null && usesFirebase,
        notes: notes,
      ),
      contact,
    );
  }

  /// Sends a report that previously failed again, keeping its ID and time.
  /// If it fails again it stays in the "Not sent" list.
  Future<HazardReport> retryFailedSubmission(String id) async {
    final saved = _savedReport(id);
    if (saved != null) return saved;
    final failed = _failedSubmissions[id];
    if (failed == null) {
      throw StateError('Report $id is not waiting to be resent');
    }
    try {
      return await _send(failed.report, failed.contact);
    } catch (e) {
      _markFailed(failed.report, failed.contact, e);
      rethrow;
    }
  }

  HazardReport? _savedReport(String id) {
    for (final r in _reports) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<HazardReport> _send(
    HazardReport draft,
    ReporterContact? contact,
  ) async {
    final uid = await _citizenUid();
    if (_services.auth.enforcesAccess && uid == null) {
      throw const CitizenSessionUnavailableException();
    }
    final online = await _services.isOnline();
    final report = draft.copyWith(
      reporterUid: uid,
      syncState: online ? SyncState.synced : SyncState.queued,
    );
    _failedSubmissions.remove(report.id);
    // Online, the photo is uploaded below once the write lands; mark it first
    // so the report snapshot listener does not start a second upload.
    if (online && report.photoPending) _photoUploadsTried.add(report.id);
    final write = _services.repository.submitReport(report, contact: contact);
    if (!online) {
      _watchBackgroundWrite(report, contact, write);
      return report;
    }
    try {
      await write.timeout(_submitTimeout);
    } on TimeoutException {
      // Let the listener upload the photo once the queued write syncs.
      _photoUploadsTried.remove(report.id);
      _watchBackgroundWrite(report, contact, write);
      return report.copyWith(syncState: SyncState.queued);
    }
    if (report.photoPending) {
      unawaited(
        _services.repository
            .uploadReportPhoto(report)
            .catchError((Object e) => _logBackgroundError(e)),
      );
    }
    return report;
  }

  /// The anonymous citizen account is normally created at start-up; if that
  /// did not happen (e.g. launched offline) try once more before sending.
  Future<String?> _citizenUid() async {
    final auth = _services.auth;
    if (auth.currentUid == null && auth is FirebaseOfficerAuthService) {
      await auth.ensureCitizenSession().timeout(
        _submitTimeout,
        onTimeout: () {},
      );
    }
    return auth.currentUid;
  }

  /// A queued write that the server later refuses is rolled back by
  /// Firestore; keep the report so the citizen can see it and retry.
  void _watchBackgroundWrite(
    HazardReport report,
    ReporterContact? contact,
    Future<String> write,
  ) {
    unawaited(
      write.then<void>(
        (_) {},
        onError: (Object e) {
          _logBackgroundError(e);
          _markFailed(report, contact, e);
        },
      ),
    );
  }

  void _markFailed(HazardReport report, ReporterContact? contact, Object e) {
    if (_disposed) return;
    _failedSubmissions[report.id] = _FailedSubmission(
      report.copyWith(syncState: SyncState.failed),
      contact,
      e,
    );
    notifyListeners();
  }

  /// Citizen-triggered retry of a photo that has not reached cloud storage.
  /// Errors are rethrown so the screen can explain them.
  Future<void> retryPhotoUpload(String id) async {
    final report = myReportById(id);
    if (report == null || !photoNeedsUpload(report)) return;
    if (!_photoUploading.add(id)) return;
    notifyListeners();
    try {
      await _services.repository
          .uploadReportPhoto(report)
          .timeout(_photoUploadTimeout);
    } finally {
      _photoUploading.remove(id);
      if (!_disposed) notifyListeners();
    }
  }

  String _logBackgroundError(Object error) {
    if (kDebugMode) debugPrint('Background report sync failed: $error');
    return '';
  }

  /// Uploads photos of this device's reports that were saved while offline.
  void _retryPendingPhotos() {
    if (!_online || !usesFirebase) return;
    for (final r in myReports) {
      final needsUpload =
          r.photoPending && r.photoUrl == null && r.photoPath != null;
      if (!needsUpload || r.syncState != SyncState.synced) continue;
      if (!_photoUploadsTried.add(r.id)) continue;
      unawaited(
        _services.repository
            .uploadReportPhoto(r)
            .catchError((Object e) => _logBackgroundError(e)),
      );
    }
  }

  ReportReviewer _requireReviewer() {
    final session = _officerSession;
    if (!session.isAuthorized || session.uid == null) {
      throw const OfficerNotAuthorizedException();
    }
    return ReportReviewer(
      uid: session.uid!,
      displayName: session.displayName ?? 'Duty officer',
    );
  }

  /// CONFIRMS a pending report. This only makes it eligible for a warning
  /// (UC-01); it never issues a warning or changes a warning level.
  Future<void> verifyReport(String id) async {
    final reviewer = _requireReviewer();
    await _services.repository
        .verifyReport(id, reviewer: reviewer)
        .timeout(_reviewTimeout);
  }

  /// DISMISSES a pending report; [reason] is required and stored.
  Future<void> rejectReport(String id, {required String reason}) async {
    final reviewer = _requireReviewer();
    final trimmed = reason.trim();
    if (trimmed.length < ReportReviewRules.minDismissalReasonLength) {
      throw ArgumentError.value(reason, 'reason', 'Dismissal reason too short');
    }
    await _services.repository
        .rejectReport(id, reviewer: reviewer, reason: trimmed)
        .timeout(_reviewTimeout);
  }

  Future<ReporterContact?> reporterContact(String reportId) async {
    _requireReviewer();
    return _services.repository.getReporterContact(reportId);
  }

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
    _disposed = true;
    _reportsSub?.cancel();
    _warningsSub?.cancel();
    _sheltersSub?.cancel();
    _onlineSub?.cancel();
    _sessionSub?.cancel();
    super.dispose();
  }
}

class _FailedSubmission {
  const _FailedSubmission(this.report, this.contact, this.error);

  final HazardReport report;
  final ReporterContact? contact;
  final Object error;
}
