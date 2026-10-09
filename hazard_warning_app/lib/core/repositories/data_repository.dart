import 'package:hazard_warning_app/core/models/models.dart';

abstract class DataRepository {
  Stream<List<HazardReport>> watchReports();
  Future<List<HazardReport>> getReports();
  Future<HazardReport?> getReport(String id);
  Future<String> submitReport(HazardReport draft, {ReporterContact? contact});

  /// Uploads a report's on-device photo and records its download URL.
  Future<void> uploadReportPhoto(HazardReport report);

  /// Contact details left by the reporter; readable by duty officers only.
  Future<ReporterContact?> getReporterContact(String reportId);

  /// Marks a pending report CONFIRMED. Throws
  /// [ReportAlreadyReviewedException] if it is no longer pending.
  Future<void> verifyReport(String id, {required ReportReviewer reviewer});

  /// Marks a pending report DISMISSED with the officer's [reason].
  Future<void> rejectReport(
    String id, {
    required ReportReviewer reviewer,
    required String reason,
  });

  Stream<List<HazardWarning>> watchWarnings();
  Future<String> issueWarning(HazardWarning warning);
  Future<void> updateWarning(HazardWarning warning);
  
  Stream<List<Shelter>> watchShelters();
  Future<String> registerShelter(Shelter shelter);
  Future<void> updateShelter(Shelter shelter);
  Future<void> deleteShelter(String shelterId);
  Future<void> updateShelterOccupancy(String shelterId, int occupancy);

  Future<List<ReliefTeam>> getReliefTeams();
  Future<String> addReliefTeam(ReliefTeam team);
  Future<void> updateReliefTeam(ReliefTeam team);
  Future<void> deleteReliefTeam(String teamId); 

  Future<List<ReliefStock>> getReliefStock();
  Future<String> addReliefStock(ReliefStock stock);
  Future<void> updateReliefStock(ReliefStock stock);
  Future<void> deleteReliefStock(String district);

  Future<List<PostEventReport>> getPostEventReports();
  Future<PostEventReport?> getPostEventReport(String id);

  List<TargetAreaOption> areasForScope(BroadcastScope scope);
}
