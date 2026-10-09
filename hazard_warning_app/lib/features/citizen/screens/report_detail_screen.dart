import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/citizen/report_submission_rules.dart';
import 'package:hazard_warning_app/features/report_verification/widgets/report_widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _resending = false;

  /// What the officer's decision means for the citizen.
  static String _statusMessage(HazardReport report) => switch (report.status) {
    ReportStatus.verified =>
      'A duty officer confirmed this hazard. Official warnings, if needed, '
          'are sent separately.',
    ReportStatus.rejected =>
      'A duty officer reviewed this report and did not confirm it.',
    _ =>
      report.syncState == SyncState.queued
          ? 'Saved on this phone. It will be sent when you are back online.'
          : 'Waiting for a duty officer to verify it.',
  };

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _resend(AppState state) async {
    setState(() => _resending = true);
    try {
      final sent = await state.retryFailedSubmission(widget.reportId);
      if (!mounted) return;
      _showMessage(
        sent.syncState == SyncState.queued
            ? 'Saved on this phone. It will be sent when you are back online.'
            : 'Report sent. It is now waiting for a duty officer.',
      );
    } catch (e) {
      if (mounted) {
        _showMessage('Still not sent. ${describeSubmissionError(e)}');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _retryPhoto(AppState state) async {
    try {
      await state.retryPhotoUpload(widget.reportId);
      if (mounted) _showMessage('Photo uploaded.');
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Photo not uploaded. Check your connection and try again. '
          'It is still saved on this phone.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final report = state.myReportById(widget.reportId);
    final fmt = DateFormat('d MMM yyyy · HH:mm');

    if (report == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: const Text('Back'),
          ),
        ),
      );
    }

    final queued = report.syncState == SyncState.queued;
    final failed = report.syncState == SyncState.failed;
    final reviewed = report.status.isReviewed;
    final failure = state.submissionError(report.id);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          children: [
            ScreenHeader(
              title: report.id,
              subtitle: report.areaLabel,
              onBack: () => context.pop(),
            ),
            if (queued) ...[const SizedBox(height: 16), const OfflineBanner()],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (failed)
                    ReviewNotice.error(
                      title: 'Not sent',
                      message:
                          'This report did not reach the DMC. '
                          '${failure == null ? '' : describeSubmissionError(failure)} '
                          'It is kept on this phone until you close the app.',
                      action: PrimaryActionButton(
                        label: 'Retry sending',
                        icon: Icons.refresh_rounded,
                        busy: _resending,
                        backgroundColor: AppColors.severityHigh,
                        onPressed: () => _resend(state),
                      ),
                    )
                  else
                    ReviewNotice(
                      icon: report.status.icon,
                      title: queued ? 'Queued' : report.status.label,
                      message: _statusMessage(report),
                      background:
                          (queued ? AppColors.accentBlue : report.status.color)
                              .withValues(alpha: 0.1),
                      foreground: queued
                          ? AppColors.accentBlue
                          : report.status.color,
                    ),
                  const SizedBox(height: 16),
                  if (report.hasPhoto) ...[
                    ReportPhotoView(report: report, height: 180),
                    const SizedBox(height: 16),
                  ],
                  if (state.photoNeedsUpload(report)) ...[
                    ReviewNotice(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Photo not uploaded yet',
                      message:
                          'Officers can read your report, but not see the '
                          'photo until it uploads.',
                      background: AppColors.warningBanner,
                      foreground: AppColors.warningText,
                      action: OutlinedButton.icon(
                        onPressed: state.isUploadingPhoto(report.id)
                            ? null
                            : () => _retryPhoto(state),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          state.isUploadingPhoto(report.id)
                              ? 'Uploading…'
                              : 'Retry photo upload',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconBadge(
                              icon: report.category.icon,
                              color: AppColors.accentBlue,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                report.category.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32, color: AppColors.borderGrey),
                        ReportInfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Submitted',
                          value: fmt.format(report.submittedAt),
                        ),
                        ReportInfoRow(
                          icon: Icons.place_outlined,
                          label: 'Location',
                          value: report.locationLabel,
                        ),
                        ReportInfoRow(
                          icon: Icons.my_location_rounded,
                          label: 'Coordinates',
                          value: report.coordinates.formatted,
                          last: report.notes == null,
                        ),
                        if (report.notes != null)
                          ReportInfoRow(
                            icon: Icons.notes_rounded,
                            label: 'Your description',
                            value: report.notes!,
                            last: true,
                          ),
                      ],
                    ),
                  ),
                  if (reviewed) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Officer review'),
                          ReportInfoRow(
                            icon: Icons.event_available_rounded,
                            label: 'Reviewed',
                            value: report.verifiedAt == null
                                ? 'Just now'
                                : fmt.format(report.verifiedAt!),
                            last: report.dismissalReason == null,
                          ),
                          if (report.dismissalReason != null)
                            ReportInfoRow(
                              icon: Icons.comment_outlined,
                              label: 'Reason',
                              value: report.dismissalReason!,
                              last: true,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
