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
    _reliefStock.addAll(SeedData.initialRelief());
    _reliefTeams.addAll(SeedData.initialTeams());
  }

  final _reports = <HazardReport>[];
  final _warnings = <HazardWarning>[];
  final _shelters = <Shelter>[];
  final _postEvents = <PostEventReport>[];
  final List<ReliefStock> _reliefStock = [];
  final List<ReliefTeam> _reliefTeams = [];

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
  Future<String> registerShelter(Shelter shelter) async {
    _shelters.add(shelter);
    _emitShelters();
    return shelter.id;
  }

  @override
  Future<void> updateShelter(Shelter shelter) async {
    final index = _shelters.indexWhere((s) => s.id == shelter.id);

    if (index < 0) return;

    _shelters[index] = shelter;
    _emitShelters();
  }

  @override
  Future<void> deleteShelter(String shelterId) async {
    _shelters.removeWhere((s) => s.id == shelterId);

    // Clear references to the deleted shelter.
    for (var i = 0; i < _shelters.length; i++) {
      final shelter = _shelters[i];

      if (shelter.nearestAlternativeId == shelterId) {
        _shelters[i] = Shelter(
          id: shelter.id,
          name: shelter.name,
          district: shelter.district,
          address: shelter.address,
          capacity: shelter.capacity,
          occupancy: shelter.occupancy,
          nearestAlternativeId: null,
        );
      }
    }

    _emitShelters();
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
  Future<List<ReliefTeam>> getReliefTeams() async {
    return List.unmodifiable(_reliefTeams);
  }

  @override
  Future<String> addReliefTeam(ReliefTeam team) async {
    _reliefTeams.add(team);
    return team.id;
  }

  @override
  Future<void> updateReliefTeam(ReliefTeam team) async {
    final index = _reliefTeams.indexWhere((item) => item.id == team.id);

    if (index < 0) return;

    _reliefTeams[index] = team;
  }

  @override
  Future<void> deleteReliefTeam(String teamId) async {
    _reliefTeams.removeWhere((item) => item.id == teamId);
  }

  @override
  Future<List<ReliefStock>> getReliefStock() async {
    return List.unmodifiable(_reliefStock);
  }

  @override
  Future<String> addReliefStock(ReliefStock stock) async {
    _reliefStock.add(stock);
    return stock.district;
  }

  @override
  Future<void> updateReliefStock(ReliefStock stock) async {
    final index = _reliefStock.indexWhere(
      (item) => item.district == stock.district,
    );

    if (index < 0) return;

    _reliefStock[index] = stock;
  }

  @override
  Future<void> deleteReliefStock(String district) async {
    _reliefStock.removeWhere((item) => item.district == district);
  }

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
