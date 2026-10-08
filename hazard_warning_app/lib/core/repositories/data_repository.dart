import 'package:hazard_warning_app/core/models/models.dart';

abstract class DataRepository {
  Stream<List<HazardReport>> watchReports();
  Future<List<HazardReport>> getReports();
  Future<HazardReport?> getReport(String id);
  Future<String> submitReport(HazardReport draft);
  Future<void> verifyReport(String id);
  Future<void> rejectReport(String id);

  Stream<List<HazardWarning>> watchWarnings();
  Future<String> issueWarning(HazardWarning warning);
  Future<void> updateWarning(HazardWarning warning);
  
  Stream<List<Shelter>> watchShelters();
  Future<String> registerShelter(Shelter shelter);
  Future<void> updateShelter(Shelter shelter);
  Future<void> deleteShelter(String shelterId);
  Future<void> updateShelterOccupancy(String shelterId, int occupancy);

  Future<List<ReliefTeam>> getReliefTeams();

  Future<List<ReliefStock>> getReliefStock();
  Future<String> addReliefStock(ReliefStock stock);
  Future<void> updateReliefStock(ReliefStock stock);
  Future<void> deleteReliefStock(String district);

  Future<List<PostEventReport>> getPostEventReports();
  Future<PostEventReport?> getPostEventReport(String id);

  List<TargetAreaOption> areasForScope(BroadcastScope scope);
}
