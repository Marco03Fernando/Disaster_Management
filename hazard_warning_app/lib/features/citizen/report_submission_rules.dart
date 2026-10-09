import 'package:flutter/services.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/features/report_verification/report_review_logic.dart';

/// Field limits for the citizen report form. Kept within the Firestore rules
/// (notes <= 1000, name <= 80, phone <= 20).
class ReportFormRules {
  static const maxDescriptionLength = 500;
  static const maxNameLength = 80;
  static const maxPhoneLength = 20;

  /// A citizen's own report of the same hazard type within this window
  /// triggers a "you already reported this" confirmation (never a block).
  static const recentOwnReportWindow = Duration(minutes: 30);
}

String? validateHazardCategory(HazardCategory? category) =>
    category == null ? 'Choose the type of hazard you are reporting.' : null;

String? validateDescription(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Describe what you see.';
  if (text.length > ReportFormRules.maxDescriptionLength) {
    return 'Keep the description under '
        '${ReportFormRules.maxDescriptionLength} characters.';
  }
  return null;
}

final _phonePattern = RegExp(r'^\+?\d{7,15}$');

/// Phone is optional; if given it must be 7–15 digits, optionally with a
/// leading + (spaces and dashes are ignored).
String? validatePhone(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final compact = text.replaceAll(RegExp(r'[\s-]'), '');
  if (!_phonePattern.hasMatch(compact)) {
    return 'Enter a valid phone number, e.g. 0771234567, or leave it blank.';
  }
  return null;
}

/// The citizen's most recent report of [category] submitted within
/// [ReportFormRules.recentOwnReportWindow], or null.
///
/// Deliberately does NOT compare distance: report locations are a default
/// area or typed in by hand, not GPS, so distance would be misleading.
HazardReport? recentOwnReport({
  required HazardCategory category,
  required List<HazardReport> myReports,
  required DateTime now,
}) {
  HazardReport? latest;
  for (final r in myReports) {
    if (r.category != category || r.status == ReportStatus.rejected) continue;
    final age = now.difference(r.submittedAt);
    if (age.isNegative || age > ReportFormRules.recentOwnReportWindow) {
      continue;
    }
    if (latest == null || r.submittedAt.isAfter(latest.submittedAt)) {
      latest = r;
    }
  }
  return latest;
}

/// Plain-language message when the camera or gallery cannot be used.
String describePhotoError(Object error, {required bool fromCamera}) {
  final code = error is PlatformException ? error.code : '';
  if (code == 'camera_access_denied') {
    return 'Camera permission is off. Allow it in Settings, or choose a photo '
        'from the gallery. Your other details are kept.';
  }
  if (code == 'photo_access_denied') {
    return 'Photo library permission is off. Allow it in Settings, or take a '
        'photo instead. Your other details are kept.';
  }
  return fromCamera
      ? 'Camera unavailable. Try choosing from the gallery. Your other '
            'details are kept.'
      : 'Could not open the photo gallery. Your other details are kept.';
}

/// Plain-language message for a citizen submission that could not be saved.
String describeSubmissionError(Object error) =>
    error is CitizenSessionUnavailableException
    ? error.toString()
    : describeReportError(error);
