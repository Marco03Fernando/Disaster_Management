import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:hazard_warning_app/core/models/models.dart';

/// Reports of the same hazard type within this distance and time window of
/// each other are flagged as possible duplicates for the officer.
const duplicateRadiusMeters = 500.0;
const duplicateWindow = Duration(hours: 6);

double distanceMeters(GeoCoordinate a, GeoCoordinate b) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(h.toDouble()));
}

/// Other reports that look like the same incident as [report]: same hazard
/// type, close by, and submitted around the same time. Dismissed reports are
/// ignored. Nearest first.
List<HazardReport> possibleDuplicates(
  HazardReport report,
  List<HazardReport> all,
) {
  final matches = all.where((other) {
    if (other.id == report.id) return false;
    if (other.category != report.category) return false;
    if (other.status == ReportStatus.rejected) return false;
    final gap = other.submittedAt.difference(report.submittedAt).abs();
    if (gap > duplicateWindow) return false;
    return distanceMeters(report.coordinates, other.coordinates) <=
        duplicateRadiusMeters;
  }).toList();
  matches.sort(
    (a, b) => distanceMeters(
      report.coordinates,
      a.coordinates,
    ).compareTo(distanceMeters(report.coordinates, b.coordinates)),
  );
  return matches;
}

/// Plain-language message for a failed submission or verification.
String describeReportError(Object error) {
  if (error is ReportAlreadyReviewedException) {
    return '${error.toString()} No changes were made.';
  }
  if (error is OfficerNotAuthorizedException) return error.toString();
  if (error is TimeoutException) {
    return 'No response from the server. Check the report status before '
        'trying again.';
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Permission denied. Your account is not allowed to make this change.',
      'unavailable' || 'deadline-exceeded' =>
        "Can't reach the server. Check your connection and try again.",
      'not-found' => 'This report no longer exists.',
      _ => 'Something went wrong (${error.code}). Please try again.',
    };
  }
  if (error is ArgumentError) {
    return 'Enter a reason of at least '
        '${ReportReviewRules.minDismissalReasonLength} characters.';
  }
  return 'Something went wrong. Please try again.';
}
