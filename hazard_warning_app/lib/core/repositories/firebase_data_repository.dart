import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hazard_warning_app/core/data/seed_data.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/repositories/data_repository.dart';
import 'package:image_picker/image_picker.dart';

/// Firestore-backed repository. Collections are created on first write.
class FirebaseDataRepository implements DataRepository {
  FirebaseDataRepository({FirebaseFirestore? firestore, this._storage})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage? _storage;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('hazard_reports');
  CollectionReference<Map<String, dynamic>> get _warnings =>
      _db.collection('hazard_warnings');
  CollectionReference<Map<String, dynamic>> get _shelters =>
      _db.collection('shelters');
  CollectionReference<Map<String, dynamic>> get _postEvents =>
      _db.collection('post_event_reports');

  /// Includes metadata changes so a report written offline flips from
  /// "queued" to "synced" as soon as the server acknowledges it.
  @override
  Stream<List<HazardReport>> watchReports() {
    return _reports
        .orderBy('submittedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map(_reportFromDoc).toList());
  }

  @override
  Future<List<HazardReport>> getReports() async {
    final snap = await _reports.orderBy('submittedAt', descending: true).get();
    return snap.docs.map(_reportFromDoc).toList();
  }

  @override
  Future<HazardReport?> getReport(String id) async {
    final doc = await _reports.doc(id).get();
    if (!doc.exists) return null;
    return _reportFromDoc(doc);
  }

  /// Reporter contact details live in `hazard_reports/{id}/private/reporter`
  /// so security rules can hide them from everyone except duty officers.
  DocumentReference<Map<String, dynamic>> _contactDoc(String reportId) =>
      _reports.doc(reportId).collection('private').doc('reporter');

  @override
  Future<String> submitReport(
    HazardReport draft, {
    ReporterContact? contact,
  }) async {
    final batch = _db.batch()..set(_reports.doc(draft.id), _reportToMap(draft));
    if (contact != null && !contact.isEmpty) {
      batch.set(_contactDoc(draft.id), {
        'reporterUid': draft.reporterUid,
        'name': contact.name,
        'phone': contact.phone,
      });
    }
    await batch.commit();
    return draft.id;
  }

  @override
  Future<void> uploadReportPhoto(HazardReport report) async {
    final storage = _storage;
    final path = report.photoPath;
    final uid = report.reporterUid;
    if (storage == null || path == null || uid == null) return;
    final bytes = await XFile(path).readAsBytes();
    final ref = storage.ref('hazard_reports/$uid/${report.id}.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await _reports.doc(report.id).update({
      'photoUrl': url,
      'photoPending': false,
    });
  }

  @override
  Future<ReporterContact?> getReporterContact(String reportId) async {
    final doc = await _contactDoc(reportId).get();
    final d = doc.data();
    if (d == null) return null;
    return ReporterContact(
      name: d['name'] as String?,
      phone: d['phone'] as String?,
    );
  }

  @override
  Future<void> verifyReport(String id, {required ReportReviewer reviewer}) {
    return _review(id, ReportStatus.verified, reviewer);
  }

  @override
  Future<void> rejectReport(
    String id, {
    required ReportReviewer reviewer,
    required String reason,
  }) {
    return _review(id, ReportStatus.rejected, reviewer, reason: reason.trim());
  }

  /// Runs in a transaction so two officers cannot both decide the same
  /// report; the security rules enforce the same pending-only transition.
  Future<void> _review(
    String id,
    ReportStatus decision,
    ReportReviewer reviewer, {
    String? reason,
  }) async {
    final ref = _reports.doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final d = snap.data();
      if (d == null) throw StateError('Report $id not found');
      final current = ReportStatus.values.byName(d['status'] as String);
      if (current != ReportStatus.pending) {
        throw ReportAlreadyReviewedException(
          current,
          reviewedBy: d['verifiedBy'] as String?,
        );
      }
      tx.update(ref, {
        'status': decision.name,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': reviewer.displayName,
        'verifiedByUid': reviewer.uid,
        'dismissalReason': ?reason,
      });
    });
  }

  @override
  Stream<List<HazardWarning>> watchWarnings() {
    return _warnings
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_warningFromDoc).toList());
  }

  @override
  Future<String> issueWarning(HazardWarning warning) async {
    await _warnings.doc(warning.id).set({
      'sourceReportId': warning.sourceReportId,
      'category': warning.category.name,
      'severity': warning.severity.name,
      'scope': warning.scope.name,
      'targetArea': warning.targetArea,
      'targetAreas': warning.targetAreas,
      'recipientCount': warning.recipientCount,
      'issuedAt': Timestamp.fromDate(warning.issuedAt),
      'channels': warning.channels,
      ..._deliveryFields(warning),
    });
    return warning.id;
  }

  @override
  Future<void> updateWarning(HazardWarning warning) async {
    await _warnings.doc(warning.id).update(_deliveryFields(warning));
  }

  Map<String, dynamic> _deliveryFields(HazardWarning warning) => {
    'level': warning.level.name,
    'escalations': warning.escalations,
    'deliveries': [
      for (final d in warning.deliveries)
        {
          'channel': d.channel.name,
          'targeted': d.targeted,
          'delivered': d.delivered,
          'failed': d.failed,
          'recovered': d.recovered,
          'fallback': d.fallback?.name,
        },
    ],
  };

  @override
  Stream<List<Shelter>> watchShelters() {
    return _shelters
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(_shelterFromDoc).toList());
  }

  @override
  Future<String> registerShelter(Shelter shelter) async {
    await _shelters.doc(shelter.id).set({
      'name': shelter.name,
      'district': shelter.district,
      'address': shelter.address,
      'capacity': shelter.capacity,
      'occupancy': shelter.occupancy,
      'nearestAlternativeId': shelter.nearestAlternativeId,
    });

    return shelter.id;
  }

  @override
  Future<void> updateShelter(Shelter shelter) async {
    await _shelters.doc(shelter.id).update({
      'name': shelter.name,
      'district': shelter.district,
      'address': shelter.address,
      'capacity': shelter.capacity,
      'occupancy': shelter.occupancy,
      'nearestAlternativeId': shelter.nearestAlternativeId,
    });
  }

  @override
  Future<void> deleteShelter(String shelterId) async {
    final batch = _db.batch();

    batch.delete(_shelters.doc(shelterId));

    final references = await _shelters
        .where('nearestAlternativeId', isEqualTo: shelterId)
        .get();

    for (final doc in references.docs) {
      batch.update(doc.reference, {'nearestAlternativeId': null});
    }

    await batch.commit();
  }

  @override
  Future<void> updateShelterOccupancy(String shelterId, int occupancy) async {
    await _shelters.doc(shelterId).update({'occupancy': occupancy});
  }

  @override
  Future<List<ReliefTeam>> getReliefTeams() async {
    final snap = await _db.collection('relief_teams').orderBy('name').get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return ReliefTeam(
        id: doc.id,
        name: d['name'] as String,
        lead: d['lead'] as String,
        members: d['members'] as int,
        assignedShelterId: d['assignedShelterId'] as String,
        status: d['status'] as String,
      );
    }).toList();
  }

  @override
  Future<List<ReliefStock>> getReliefStock() async {
    final snap = await _db.collection('relief_stock').orderBy('district').get();
    return snap.docs.map((doc) => _stockFromMap(doc.data())).toList();
  }

  @override
  Future<String> addReliefStock(ReliefStock stock) async {
    await _db
        .collection('relief_stock')
        .doc(stock.district)
        .set(_stockToMap(stock));

    return stock.district;
  }

  @override
  Future<void> updateReliefStock(ReliefStock stock) async {
    await _db
        .collection('relief_stock')
        .doc(stock.district)
        .set(_stockToMap(stock));
  }

  @override
  Future<void> deleteReliefStock(String district) async {
    await _db.collection('relief_stock').doc(district).delete();
  }

  @override
  Future<List<PostEventReport>> getPostEventReports() async {
    final snap = await _postEvents.get();
    return snap.docs.map((doc) => _postEventFromDoc(doc)).toList();
  }

  @override
  Future<PostEventReport?> getPostEventReport(String id) async {
    final doc = await _postEvents.doc(id).get();
    return doc.exists ? _postEventFromDoc(doc) : null;
  }

  /// Target areas (with registered-citizen counts) are reference data loaded
  /// once at startup so the form can read them synchronously.
  final _areas = <BroadcastScope, List<TargetAreaOption>>{};

  @override
  List<TargetAreaOption> areasForScope(BroadcastScope scope) =>
      _areas[scope] ?? const [];

  /// Adds seed areas missing from the database and back-fills `order` on older
  /// documents. Existing documents (e.g. edited recipient counts) are kept.
  Future<void> _syncTargetAreas() async {
    final col = _db.collection('target_areas');
    final existing = {
      for (final doc in (await col.get()).docs) doc.id: doc.data(),
    };
    for (final scope in BroadcastScope.values) {
      final areas = SeedData.targetAreas(scope);
      for (var i = 0; i < areas.length; i++) {
        final a = areas[i];
        final current = existing[a.id];
        if (current == null) {
          await col.doc(a.id).set({
            'label': a.label,
            'scope': a.scope.name,
            'recipientCount': a.recipientCount,
            'order': i,
          });
        } else if (current['order'] == null) {
          await col.doc(a.id).update({'order': i});
        }
      }
    }
  }

  Future<void> _loadTargetAreas() async {
    final snap = await _db.collection('target_areas').get();
    _areas.clear();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final byOrder = ((a.data()['order'] as int?) ?? 9999).compareTo(
          (b.data()['order'] as int?) ?? 9999,
        );
        return byOrder != 0
            ? byOrder
            : (a.data()['label'] as String).compareTo(
                b.data()['label'] as String,
              );
      });
    for (final doc in docs) {
      final d = doc.data();
      final scope = BroadcastScope.values.byName(d['scope'] as String);
      _areas
          .putIfAbsent(scope, () => [])
          .add(
            TargetAreaOption(
              id: doc.id,
              label: d['label'] as String,
              recipientCount: d['recipientCount'] as int,
              scope: scope,
            ),
          );
    }
  }

  ReliefStock _stockFromMap(Map<String, dynamic> d) {
    // New dynamic format.
    if (d['items'] is Map) {
      final rawItems = Map<String, dynamic>.from(d['items'] as Map);

      return ReliefStock(
        district: d['district'] as String,
        items: rawItems.map(
          (key, value) => MapEntry(key, (value as num).toInt()),
        ),
      );
    }

    // Backward compatibility for existing Firebase documents.
    return ReliefStock(
      district: d['district'] as String,
      foodUnits: (d['foodUnits'] as num?)?.toInt() ?? 0,
      waterUnits: (d['waterUnits'] as num?)?.toInt() ?? 0,
      medicineUnits: (d['medicineUnits'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _stockToMap(ReliefStock s) => {
    'district': s.district,
    'items': s.items,
  };

  PostEventReport _postEventFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    DateTime ts(Object? v) => (v as Timestamp).toDate();
    return PostEventReport(
      id: doc.id,
      title: d['title'] as String,
      subtitle: d['subtitle'] as String,
      districtCount: d['districtCount'] as int,
      alertCount: d['alertCount'] as int,
      citizensReached: d['citizensReached'] as int,
      peakShelterOccupancy: d['peakShelterOccupancy'] as int,
      hasIncompleteData: d['hasIncompleteData'] as bool,
      incompleteRangeLabel: d['incompleteRangeLabel'] as String,
      alertTimeline: [for (final t in d['alertTimeline'] as List) ts(t)],
      reachByDay: [
        for (final r in d['reachByDay'] as List)
          ReachPoint(
            day: ts(r['day']),
            count: r['count'] as int,
            partial: r['partial'] as bool,
          ),
      ],
      shelterSeries: [
        for (final s in d['shelterSeries'] as List)
          ShelterPoint(
            day: ts(s['day']),
            occupancy: s['occupancy'] as int,
            incomplete: s['incomplete'] as bool,
          ),
      ],
      resourcesByDistrict: [
        for (final r in d['resourcesByDistrict'] as List)
          _stockFromMap(Map<String, dynamic>.from(r as Map)),
      ],
    );
  }

  Map<String, dynamic> _postEventToMap(PostEventReport r) => {
    'title': r.title,
    'subtitle': r.subtitle,
    'districtCount': r.districtCount,
    'alertCount': r.alertCount,
    'citizensReached': r.citizensReached,
    'peakShelterOccupancy': r.peakShelterOccupancy,
    'hasIncompleteData': r.hasIncompleteData,
    'incompleteRangeLabel': r.incompleteRangeLabel,
    'alertTimeline': [for (final t in r.alertTimeline) Timestamp.fromDate(t)],
    'reachByDay': [
      for (final p in r.reachByDay)
        {
          'day': Timestamp.fromDate(p.day),
          'count': p.count,
          'partial': p.partial,
        },
    ],
    'shelterSeries': [
      for (final p in r.shelterSeries)
        {
          'day': Timestamp.fromDate(p.day),
          'occupancy': p.occupancy,
          'incomplete': p.incomplete,
        },
    ],
    'resourcesByDistrict': [
      for (final s in r.resourcesByDistrict) _stockToMap(s),
    ],
  };

  HazardReport _reportFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return HazardReport(
      id: doc.id,
      category: HazardCategory.values.byName(d['category'] as String),
      areaLabel: d['areaLabel'] as String,
      locationLabel: d['locationLabel'] as String,
      coordinates: GeoCoordinate(
        latitude: (d['latitude'] as num).toDouble(),
        longitude: (d['longitude'] as num).toDouble(),
      ),
      status: ReportStatus.values.byName(d['status'] as String),
      submittedAt: (d['submittedAt'] as Timestamp).toDate(),
      photoPath: d['photoPath'] as String?,
      photoUrl: d['photoUrl'] as String?,
      photoPending: d['photoPending'] as bool? ?? false,
      notes: d['notes'] as String?,
      syncState: doc.metadata.hasPendingWrites
          ? SyncState.queued
          : SyncState.values.byName(d['syncState'] as String? ?? 'synced'),
      reporterUid: d['reporterUid'] as String?,
      verifiedAt: (d['verifiedAt'] as Timestamp?)?.toDate(),
      verifiedBy: d['verifiedBy'] as String?,
      verifiedByUid: d['verifiedByUid'] as String?,
      dismissalReason: d['dismissalReason'] as String?,
    );
  }

  Map<String, dynamic> _reportToMap(HazardReport report) => {
    'category': report.category.name,
    'areaLabel': report.areaLabel,
    'locationLabel': report.locationLabel,
    'latitude': report.coordinates.latitude,
    'longitude': report.coordinates.longitude,
    'status': report.status.name,
    'submittedAt': Timestamp.fromDate(report.submittedAt),
    'photoPath': report.photoPath,
    'photoUrl': report.photoUrl,
    'photoPending': report.photoPending,
    'notes': report.notes,
    // Stored copies are synced by definition; "queued" is derived from
    // pending local writes in [_reportFromDoc].
    'syncState': SyncState.synced.name,
    'reporterUid': report.reporterUid,
    'verifiedAt': report.verifiedAt != null
        ? Timestamp.fromDate(report.verifiedAt!)
        : null,
    'verifiedBy': report.verifiedBy,
  };

  HazardWarning _warningFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return HazardWarning(
      id: doc.id,
      sourceReportId: d['sourceReportId'] as String,
      category: HazardCategory.values.byName(d['category'] as String),
      severity: WarningSeverity.values.byName(d['severity'] as String),
      scope: BroadcastScope.values.byName(d['scope'] as String),
      targetAreas:
          (d['targetAreas'] as List?)?.cast<String>() ??
          [d['targetArea'] as String],
      recipientCount: d['recipientCount'] as int,
      issuedAt: (d['issuedAt'] as Timestamp).toDate(),
      channels: (d['channels'] as List).cast<String>(),
      level: WarningLevel.values.byName((d['level'] as String?) ?? 'warning'),
      escalations: (d['escalations'] as int?) ?? 0,
      deliveries: [
        for (final raw in (d['deliveries'] as List? ?? const []))
          ChannelDelivery(
            channel: AlertChannel.values.byName(raw['channel'] as String),
            targeted: raw['targeted'] as int,
            delivered: raw['delivered'] as int,
            failed: raw['failed'] as int,
            recovered: (raw['recovered'] as int?) ?? 0,
            fallback: raw['fallback'] == null
                ? null
                : AlertChannel.values.byName(raw['fallback'] as String),
          ),
      ],
    );
  }

  Shelter _shelterFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Shelter(
      id: doc.id,
      name: d['name'] as String,
      district: d['district'] as String,
      address: d['address'] as String,
      capacity: d['capacity'] as int,
      occupancy: d['occupancy'] as int,
      nearestAlternativeId: d['nearestAlternativeId'] as String?,
    );
  }

  /// Call once after Firebase project is connected to populate demo shelters.
  Future<void> seedSheltersIfEmpty() async {
    final snap = await _shelters.limit(1).get();
    if (snap.docs.isNotEmpty) return;
    for (final shelter in SeedData.initialShelters()) {
      await _shelters.doc(shelter.id).set({
        'name': shelter.name,
        'district': shelter.district,
        'address': shelter.address,
        'capacity': shelter.capacity,
        'occupancy': shelter.occupancy,
        'nearestAlternativeId': shelter.nearestAlternativeId,
      });
    }
  }

  /// Adds demo reports that are not in the database yet; existing documents
  /// (including ones an officer has since verified or rejected) are kept.
  Future<void> seedReportsIfEmpty() async {
    final existing = (await _reports.get()).docs.map((d) => d.id).toSet();
    for (final report in SeedData.initialReports()) {
      if (!existing.contains(report.id)) await submitReport(report);
    }
  }

  Future<bool> _isEmpty(CollectionReference<Map<String, dynamic>> c) async =>
      (await c.limit(1).get()).docs.isEmpty;

  /// Populates every empty collection with demo data (a collection that
  /// already has documents is left untouched), then loads reference data.
  Future<void> initialize() async {
    await seedSheltersIfEmpty();
    try {
      await seedReportsIfEmpty();
    } on FirebaseException catch (e) {
      // Report security rules only let citizens create PENDING reports, so
      // demo reports in other states cannot be seeded from the client.
      if (kDebugMode) debugPrint('Skipped seeding hazard reports: ${e.code}');
    }

    if (await _isEmpty(_warnings)) {
      for (final w in SeedData.initialWarnings()) {
        await _warnings.doc(w.id).set({
          'sourceReportId': w.sourceReportId,
          'category': w.category.name,
          'severity': w.severity.name,
          'scope': w.scope.name,
          'targetArea': w.targetArea,
          'targetAreas': w.targetAreas,
          'recipientCount': w.recipientCount,
          'issuedAt': Timestamp.fromDate(w.issuedAt),
          'channels': w.channels,
          ..._deliveryFields(w),
        });
      }
    }

    await _syncTargetAreas();

    final teams = _db.collection('relief_teams');
    if (await _isEmpty(teams)) {
      for (final t in SeedData.initialTeams()) {
        await teams.doc(t.id).set({
          'name': t.name,
          'lead': t.lead,
          'members': t.members,
          'assignedShelterId': t.assignedShelterId,
          'status': t.status,
        });
      }
    }

    final stock = _db.collection('relief_stock');
    if (await _isEmpty(stock)) {
      for (final s in SeedData.initialRelief()) {
        await stock.doc(s.district).set(_stockToMap(s));
      }
    }

    if (await _isEmpty(_postEvents)) {
      final report = SeedData.kelaniFloodReport();
      await _postEvents.doc(report.id).set(_postEventToMap(report));
    }

    await _loadTargetAreas();
  }
}
