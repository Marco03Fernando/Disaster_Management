import 'dart:async';

import 'package:hazard_warning_app/core/data/seed_data.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/repositories/data_repository.dart';

class LocalDataRepository implements DataRepository {
  LocalDataRepository() {
    _reports.addAll(SeedData.initialReports());
    _shelters.addAll(SeedData.initialShelters());
    _warnings.addAll(SeedData.initialWarnings());
    _postEvents.add(SeedData.kelaniFloodReport());
  }

  final _reports = <HazardReport>[];
  final _warnings = <HazardWarning>[];
  final _shelters = <Shelter>[];
  final _postEvents = <PostEventReport>[];

  final _reportsCtrl = StreamController<List<HazardReport>>.broadcast();
  final _warningsCtrl = StreamController<List<HazardWarning>>.broadcast();
  final _sheltersCtrl = StreamController<List<Shelter>>.broadcast();

  void _emitReports() => _reportsCtrl.add(List.unmodifiable(_reports));
  void _emitWarnings() => _warningsCtrl.add(List.unmodifiable(_warnings));
  void _emitShelters() => _sheltersCtrl.add(List.unmodifiable(_shelters));

  @override
  Stream<List<HazardReport>> watchReports() async* {
    yield List.unmodifiable(_reports);
    yield* _reportsCtrl.stream;
  }

  @override
  Future<List<HazardReport>> getReports() async => List.unmodifiable(_reports);

  @override
  Future<HazardReport?> getReport(String id) async {
    try {
      return _reports.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> submitReport(HazardReport draft) async {
    _reports.insert(0, draft);
    _emitReports();
    return draft.id;
  }

  @override
  Future<void> verifyReport(String id) async {
    final index = _reports.indexWhere((r) => r.id == id);
    if (index < 0) return;
    _reports[index] = _reports[index].copyWith(
      status: ReportStatus.verified,
      verifiedAt: DateTime.now(),
      verifiedBy: 'Duty officer',
      syncState: SyncState.synced,
    );
    _emitReports();
  }

  @override
  Future<void> rejectReport(String id) async {
    final index = _reports.indexWhere((r) => r.id == id);
    if (index < 0) return;
    _reports[index] = _reports[index].copyWith(status: ReportStatus.rejected);
    _emitReports();
  }

  @override
  Stream<List<HazardWarning>> watchWarnings() async* {
    yield List.unmodifiable(_warnings);
    yield* _warningsCtrl.stream;
  }

  @override
  Future<String> issueWarning(HazardWarning warning) async {
    _warnings.insert(0, warning);
    _emitWarnings();
    return warning.id;
  }

  @override
  Future<void> updateWarning(HazardWarning warning) async {
    final index = _warnings.indexWhere((w) => w.id == warning.id);
    if (index < 0) return;
    _warnings[index] = warning;
    _emitWarnings();
  }

  @override
  Stream<List<Shelter>> watchShelters() async* {
    yield List.unmodifiable(_shelters);
    yield* _sheltersCtrl.stream;
  }

  @override
  Future<void> updateShelterOccupancy(String shelterId, int occupancy) async {
    final index = _shelters.indexWhere((s) => s.id == shelterId);
    if (index < 0) return;
    final current = _shelters[index];
    _shelters[index] = Shelter(
      id: current.id,
      name: current.name,
      district: current.district,
      address: current.address,
      capacity: current.capacity,
      occupancy: occupancy,
      nearestAlternativeId: current.nearestAlternativeId,
    );
    _emitShelters();
  }

  @override
  Future<List<ReliefTeam>> getReliefTeams() async => SeedData.initialTeams();

  @override
  Future<List<ReliefStock>> getReliefStock() async => SeedData.initialRelief();

  @override
  Future<List<PostEventReport>> getPostEventReports() async =>
      List.unmodifiable(_postEvents);

  @override
  Future<PostEventReport?> getPostEventReport(String id) async {
    try {
      return _postEvents.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  List<TargetAreaOption> areasForScope(BroadcastScope scope) =>
      SeedData.targetAreas(scope);
}
