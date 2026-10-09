import 'dart:math' as math;

import 'package:flutter/material.dart';

enum UserRole { citizen, officer }

enum HazardCategory {
  risingRiver,
  blockedRoad,
  landslideCrack,
  damOverflow,
  coastalSurge,
  strongWinds,
}

enum ReportStatus { pending, verified, rejected, synced }

enum WarningSeverity { low, moderate, high }

enum BroadcastScope { zone, district, riverBasin }

enum WarningLevel { advisory, watch, warning, evacuate }

enum AlertChannel { push, sms, audible }

enum SyncState { synced, queued, failed }

extension HazardCategoryX on HazardCategory {
  String get label => switch (this) {
    HazardCategory.risingRiver => 'Rising river / flood',
    HazardCategory.blockedRoad => 'Blocked road',
    HazardCategory.landslideCrack => 'Landslide crack',
    HazardCategory.damOverflow => 'Dam / reservoir overflow',
    HazardCategory.coastalSurge => 'Coastal surge / tsunami',
    HazardCategory.strongWinds => 'Cyclone / strong winds',
  };

  IconData get icon => switch (this) {
    HazardCategory.risingRiver => Icons.waves_outlined,
    HazardCategory.blockedRoad => Icons.alt_route_rounded,
    HazardCategory.landslideCrack => Icons.landslide_outlined,
    HazardCategory.damOverflow => Icons.water_damage_outlined,
    HazardCategory.coastalSurge => Icons.tsunami_outlined,
    HazardCategory.strongWinds => Icons.air_rounded,
  };
}

extension HazardOnsetX on HazardCategory {
  /// Onset-speed profile used to validate the severity an officer selects.
  bool get isRapidOnset =>
      this == HazardCategory.landslideCrack ||
      this == HazardCategory.coastalSurge ||
      this == HazardCategory.damOverflow;

  String get onsetLabel => switch (this) {
    HazardCategory.risingRiver => 'Slow onset · hours of lead time',
    HazardCategory.blockedRoad => 'Immediate · localized impact',
    HazardCategory.landslideCrack => 'Rapid onset · minutes of lead time',
    HazardCategory.damOverflow => 'Rapid onset · spill gates, minutes to hours',
    HazardCategory.coastalSurge => 'Rapid onset · minutes of lead time',
    HazardCategory.strongWinds => 'Gradual onset · tracked hours ahead',
  };

  /// Broadcast scopes that make sense for this hazard. The first entry is
  /// the default. A flood follows a river, so it goes out by river basin.
  List<BroadcastScope> get allowedScopes => switch (this) {
    HazardCategory.risingRiver => const [BroadcastScope.riverBasin],
    HazardCategory.damOverflow => const [BroadcastScope.riverBasin],
    HazardCategory.landslideCrack => const [
      BroadcastScope.zone,
      BroadcastScope.district,
    ],
    HazardCategory.blockedRoad => const [
      BroadcastScope.zone,
      BroadcastScope.district,
    ],
    HazardCategory.coastalSurge => const [BroadcastScope.district],
    HazardCategory.strongWinds => const [
      BroadcastScope.district,
      BroadcastScope.zone,
    ],
  };

  String get scopeReason => switch (this) {
    HazardCategory.risingRiver =>
      'Floods follow the river, so the warning goes to the whole river basin.',
    HazardCategory.damOverflow =>
      'A dam spill affects everyone downstream, so it is sent by river basin.',
    HazardCategory.landslideCrack => 'Landslides are local; choose the zone, or the district if several slopes are at risk.',
    HazardCategory.blockedRoad => 'Road blockages are local; choose the zone, or the district for a major route.',
    HazardCategory.coastalSurge =>
      'Coastal hazards are sent to the affected coastal districts.',
    HazardCategory.strongWinds => 'Wind systems cover wide areas; choose the district, or a zone for a local gust front.',
  };
}

/// Officer-facing names for a report's verification state. The stored values
/// stay `pending` / `verified` / `rejected` because the warning flow (UC-01)
/// reads `verified`; the UI presents them as PENDING / CONFIRMED / DISMISSED.
extension ReportStatusX on ReportStatus {
  String get label => switch (this) {
    ReportStatus.pending => 'Pending',
    ReportStatus.verified => 'Confirmed',
    ReportStatus.rejected => 'Dismissed',
    ReportStatus.synced => 'Synced',
  };

  Color get color => switch (this) {
    ReportStatus.pending => const Color(0xFFF59E0B),
    ReportStatus.verified => const Color(0xFF16A34A),
    ReportStatus.rejected => const Color(0xFFB91C1C),
    ReportStatus.synced => const Color(0xFF2563EB),
  };

  IconData get icon => switch (this) {
    ReportStatus.pending => Icons.hourglass_top_rounded,
    ReportStatus.verified => Icons.verified_outlined,
    ReportStatus.rejected => Icons.block_rounded,
    ReportStatus.synced => Icons.cloud_done_outlined,
  };

  bool get isReviewed =>
      this == ReportStatus.verified || this == ReportStatus.rejected;
}

extension WarningLevelX on WarningLevel {
  String get label => switch (this) {
    WarningLevel.advisory => 'Advisory',
    WarningLevel.watch => 'Watch',
    WarningLevel.warning => 'Warning',
    WarningLevel.evacuate => 'Evacuate',
  };

  String get action => switch (this) {
    WarningLevel.advisory => 'Stay informed',
    WarningLevel.watch => 'Be prepared',
    WarningLevel.warning => 'Take action now',
    WarningLevel.evacuate => 'Leave immediately',
  };

  Color get color => switch (this) {
    WarningLevel.advisory => const Color(0xFF0EA5E9),
    WarningLevel.watch => const Color(0xFFF59E0B),
    WarningLevel.warning => const Color(0xFFEA580C),
    WarningLevel.evacuate => const Color(0xFFB91C1C),
  };

  WarningLevel? get next => index + 1 < WarningLevel.values.length
      ? WarningLevel.values[index + 1]
      : null;

  static WarningLevel initialFor(WarningSeverity severity) =>
      switch (severity) {
        WarningSeverity.low => WarningLevel.advisory,
        WarningSeverity.moderate => WarningLevel.watch,
        WarningSeverity.high => WarningLevel.warning,
      };
}

extension AlertChannelX on AlertChannel {
  String get label => switch (this) {
    AlertChannel.push => 'Push notification',
    AlertChannel.sms => 'SMS',
    AlertChannel.audible => 'Audible alert',
  };

  String get shortLabel => switch (this) {
    AlertChannel.push => 'Push',
    AlertChannel.sms => 'SMS',
    AlertChannel.audible => 'Audible',
  };

  IconData get icon => switch (this) {
    AlertChannel.push => Icons.notifications_active_outlined,
    AlertChannel.sms => Icons.sms_outlined,
    AlertChannel.audible => Icons.volume_up_outlined,
  };

  /// Channel used to resend when this one reports failures.
  AlertChannel get fallback => switch (this) {
    AlertChannel.push => AlertChannel.sms,
    AlertChannel.sms => AlertChannel.push,
    AlertChannel.audible => AlertChannel.sms,
  };
}

extension WarningSeverityX on WarningSeverity {
  String get label => switch (this) {
    WarningSeverity.low => 'Low',
    WarningSeverity.moderate => 'Moderate',
    WarningSeverity.high => 'High',
  };

  Color get color => switch (this) {
    WarningSeverity.low => const Color(0xFF059669),
    WarningSeverity.moderate => const Color(0xFFF59E0B),
    WarningSeverity.high => const Color(0xFFB91C1C),
  };
}

extension BroadcastScopeX on BroadcastScope {
  String get label => switch (this) {
    BroadcastScope.zone => 'Zone',
    BroadcastScope.district => 'District',
    BroadcastScope.riverBasin => 'River basin',
  };
}

class GeoCoordinate {
  const GeoCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  String get formatted =>
      '${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E';
}

class HazardReport {
  const HazardReport({
    required this.id,
    required this.category,
    required this.areaLabel,
    required this.locationLabel,
    required this.coordinates, // GeoCoordinate
    required this.status,
    required this.submittedAt,
    this.photoPath,
    this.photoUrl,
    this.photoPending = false,
    this.notes,
    this.syncState = SyncState.synced,
    this.reporterUid,
    this.verifiedAt,
    this.verifiedBy,
    this.verifiedByUid,
    this.dismissalReason,
  });

  final String id;
  final HazardCategory category;
  final String areaLabel;
  final String locationLabel;
  final GeoCoordinate coordinates;
  final ReportStatus status;
  final DateTime submittedAt;

  /// Path of the photo on the reporter's device.
  final String? photoPath;

  /// Download URL once the photo is uploaded to Firebase Storage.
  final String? photoUrl;

  /// True while a photo exists on the device but has not been uploaded yet.
  final bool photoPending;
  final String? notes;
  final SyncState syncState;

  /// Firebase Auth UID of the citizen who submitted the report.
  final String? reporterUid;

  /// When the report was confirmed or dismissed, and by whom.
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final String? verifiedByUid;

  /// Officer's reason, required when the report is dismissed.
  final String? dismissalReason;

  bool get hasPhoto => photoUrl != null || photoPath != null;

  HazardReport copyWith({
    ReportStatus? status,
    SyncState? syncState,
    DateTime? verifiedAt,
    String? verifiedBy,
    String? verifiedByUid,
    String? dismissalReason,
    String? photoUrl,
    bool? photoPending,
    String? reporterUid,
  }) {
    return HazardReport(
      id: id,
      category: category,
      areaLabel: areaLabel,
      locationLabel: locationLabel,
      coordinates: coordinates,
      status: status ?? this.status,
      submittedAt: submittedAt,
      photoPath: photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      photoPending: photoPending ?? this.photoPending,
      notes: notes,
      syncState: syncState ?? this.syncState,
      reporterUid: reporterUid ?? this.reporterUid,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedByUid: verifiedByUid ?? this.verifiedByUid,
      dismissalReason: dismissalReason ?? this.dismissalReason,
    );
  }
}

/// Optional contact details a citizen leaves with a report. Stored apart from
/// the report so only duty officers (and the reporter) can read them.
class ReporterContact {
  const ReporterContact({this.name, this.phone});

  final String? name;
  final String? phone;

  bool get isEmpty =>
      (name == null || name!.isEmpty) && (phone == null || phone!.isEmpty);
}

/// The signed-in duty officer recorded on a verification decision.
class ReportReviewer {
  const ReportReviewer({required this.uid, required this.displayName});

  final String uid;
  final String displayName;
}

/// Limits shared by the dismissal form, repositories and Firestore rules.
class ReportReviewRules {
  static const minDismissalReasonLength = 10;
  static const maxDismissalReasonLength = 500;
}

/// Thrown when an officer tries to review a report that is no longer pending
/// (for example, another officer decided it first).
class ReportAlreadyReviewedException implements Exception {
  const ReportAlreadyReviewedException(this.status, {this.reviewedBy});

  final ReportStatus status;
  final String? reviewedBy;

  @override
  String toString() =>
      'This report was already ${status.label.toLowerCase()}'
      '${reviewedBy == null ? '' : ' by $reviewedBy'}.';
}

/// Thrown when a citizen report cannot be stamped with the device's account
/// (e.g. first launch while offline), so the server would reject it.
class CitizenSessionUnavailableException implements Exception {
  const CitizenSessionUnavailableException();

  @override
  String toString() =>
      "Couldn't connect this phone to the reporting service yet. Connect to "
      'the internet and try again. Your report is still on this screen.';
}

const _reportIdAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Collision-resistant report ID, e.g. `GR-MG1X2ABC-K7QZ`. Keeps the `GR-`
/// prefix of existing reports; time first so IDs sort by creation.
String newReportId({DateTime? now, math.Random? random}) {
  final rng = random ?? math.Random.secure();
  final time = (now ?? DateTime.now()).millisecondsSinceEpoch
      .toRadixString(36)
      .toUpperCase();
  final suffix = List.generate(
    4,
    (_) => _reportIdAlphabet[rng.nextInt(_reportIdAlphabet.length)],
  ).join();
  return 'GR-$time-$suffix';
}

/// Thrown when a verification is attempted without an authorized officer.
class OfficerNotAuthorizedException implements Exception {
  const OfficerNotAuthorizedException();

  @override
  String toString() => 'Only signed-in duty officers can verify reports.';
}

/// Gateway outcome for one channel of one warning broadcast.
class ChannelDelivery {
  const ChannelDelivery({
    required this.channel,
    required this.targeted,
    required this.delivered,
    required this.failed,
    this.recovered = 0,
    this.fallback,
  });

  final AlertChannel channel;
  final int targeted;
  final int delivered;
  final int failed;

  /// Citizens reached by resending on [fallback] after a failure.
  final int recovered;
  final AlertChannel? fallback;

  int get totalDelivered => delivered + recovered;
  double get successRatio => targeted == 0 ? 1 : totalDelivered / targeted;

  ChannelDelivery copyWith({
    int? failed,
    int? recovered,
    AlertChannel? fallback,
  }) {
    return ChannelDelivery(
      channel: channel,
      targeted: targeted,
      delivered: delivered,
      failed: failed ?? this.failed,
      recovered: recovered ?? this.recovered,
      fallback: fallback ?? this.fallback,
    );
  }
}

class HazardWarning {
  const HazardWarning({
    required this.id,
    required this.sourceReportId,
    required this.category,
    required this.severity,
    required this.scope,
    required this.targetAreas,
    required this.recipientCount,
    required this.issuedAt,
    this.level = WarningLevel.warning,
    this.deliveries = const [],
    this.escalations = 0,
    this.channels = const ['Push', 'SMS', 'Audible'],
  });

  final String id;
  final String sourceReportId;
  final HazardCategory category;
  final WarningSeverity severity;
  final BroadcastScope scope;
  final List<String> targetAreas;

  /// Short display form: one name, two joined, or the first plus a count.
  String get targetArea => switch (targetAreas.length) {
        0 => '—',
        1 => targetAreas.first,
        2 => '${targetAreas[0]} & ${targetAreas[1]}',
        _ => '${targetAreas.first} +${targetAreas.length - 1} more areas',
      };
  final int recipientCount;
  final DateTime issuedAt;
  final WarningLevel level;
  final List<ChannelDelivery> deliveries;
  final int escalations;
  final List<String> channels;

  int get failedCount => deliveries.fold(0, (sum, d) => sum + d.failed);
  bool get hasFailures => failedCount > 0;

  HazardWarning copyWith({
    WarningLevel? level,
    List<ChannelDelivery>? deliveries,
    int? escalations,
  }) {
    return HazardWarning(
      id: id,
      sourceReportId: sourceReportId,
      category: category,
      severity: severity,
      scope: scope,
      targetAreas: targetAreas,
      recipientCount: recipientCount,
      issuedAt: issuedAt,
      level: level ?? this.level,
      deliveries: deliveries ?? this.deliveries,
      escalations: escalations ?? this.escalations,
      channels: channels,
    );
  }
}

class CitizenAlert {
  const CitizenAlert({
    required this.warningId,
    required this.title,
    required this.body,
    required this.severity,
    required this.issuedAt,
    required this.smsText,
  });

  final String warningId;
  final String title;
  final String body;
  final WarningSeverity severity;
  final DateTime issuedAt;
  final String smsText;
}

class Shelter {
  const Shelter({
    required this.id,
    required this.name,
    required this.district,
    required this.address,
    required this.capacity,
    required this.occupancy,
    this.nearestAlternativeId,
  });

  final String id;
  final String name;
  final String district;
  final String address;
  final int capacity;
  final int occupancy;
  final String? nearestAlternativeId;

  bool get isOverCapacity => occupancy > capacity;
  int get overflow => occupancy - capacity;
  double get fillRatio => capacity == 0 ? 0 : occupancy / capacity;
}

class ReliefTeam {
  const ReliefTeam({
    required this.id,
    required this.name,
    required this.lead,
    required this.members,
    required this.assignedShelterId,
    required this.status,
  });

  final String id;
  final String name;
  final String lead;
  final int members;
  final String assignedShelterId;
  final String status;
}

class ReliefStock {
  const ReliefStock({
    required this.district,
    Map<String, int>? items,
    int? foodUnits,
    int? waterUnits,
    int? medicineUnits,
  }) : items = items ??
            const {
              'Food': 0,
              'Water': 0,
              'Medicine': 0,
            };

  final String district;

  final Map<String, int> items;

  int get foodUnits => items['Food'] ?? 0;

  int get waterUnits => items['Water'] ?? 0;

  int get medicineUnits => items['Medicine'] ?? 0;
}

class PostEventReport {
  const PostEventReport({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.districtCount,
    required this.alertCount,
    required this.citizensReached,
    required this.peakShelterOccupancy,
    required this.hasIncompleteData,
    required this.incompleteRangeLabel,
    required this.alertTimeline,
    required this.reachByDay,
    required this.shelterSeries,
    required this.resourcesByDistrict,
  });

  final String id;
  final String title;
  final String subtitle;
  final int districtCount;
  final int alertCount;
  final int citizensReached;
  final int peakShelterOccupancy;
  final bool hasIncompleteData;
  final String incompleteRangeLabel;
  final List<DateTime> alertTimeline;
  final List<ReachPoint> reachByDay;
  final List<ShelterPoint> shelterSeries;
  final List<ReliefStock> resourcesByDistrict;
}

class ReachPoint {
  const ReachPoint({
    required this.day,
    required this.count,
    this.partial = false,
  });

  final DateTime day;
  final int count;
  final bool partial;
}

class ShelterPoint {
  const ShelterPoint({
    required this.day,
    required this.occupancy,
    this.incomplete = false,
  });

  final DateTime day;
  final int occupancy;
  final bool incomplete;
}

class TargetAreaOption {
  const TargetAreaOption({
    required this.id,
    required this.label,
    required this.recipientCount,
    required this.scope,
  });

  final String id;
  final String label;
  final int recipientCount;
  final BroadcastScope scope;
}
