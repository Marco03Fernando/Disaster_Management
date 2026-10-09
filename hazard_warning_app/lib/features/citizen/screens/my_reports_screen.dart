import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/citizen/widgets/citizen_scaffold.dart';
import 'package:hazard_warning_app/features/report_verification/report_review_logic.dart';
import 'package:hazard_warning_app/features/report_verification/widgets/report_widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reports = state.myReports;
    final fmt = DateFormat('d MMM yyyy · HH:mm');

    final Widget content;
    if (!state.reportsLoaded) {
      content = const Center(child: CircularProgressIndicator());
    } else if (state.reportsError != null && reports.isEmpty) {
      content = ReviewStateView(
        icon: Icons.cloud_off_rounded,
        title: 'Reports unavailable',
        message: describeReportError(state.reportsError!),
        action: OutlinedButton(
          onPressed: state.reloadReports,
          child: const Text('Retry'),
        ),
      );
    } else if (reports.isEmpty) {
      content = ReviewStateView(
        icon: Icons.list_alt_outlined,
        title: 'No reports yet',
        message: 'Hazards you report will appear here with their status.',
        action: OutlinedButton.icon(
          onPressed: () => context.push('/citizen/report/new'),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Report a hazard'),
        ),
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          final queued = report.syncState == SyncState.queued;
          final failed = report.syncState == SyncState.failed;
          final note = failed
              ? 'Not sent — tap to retry'
              : report.dismissalReason != null
              ? 'Reason: ${report.dismissalReason}'
              : state.photoNeedsUpload(report)
              ? 'Photo not uploaded yet'
              : null;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(report.category.label),
              subtitle: Text(
                '${report.id} · ${fmt.format(report.submittedAt)}'
                '${note == null ? '' : '\n$note'}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: note != null,
              trailing: StatusBadge(
                label: failed
                    ? 'Not sent'
                    : queued
                    ? 'Queued'
                    : report.status.label,
                color: failed
                    ? AppColors.severityHigh
                    : queued
                    ? const Color(0xFF2563EB)
                    : report.status.color,
              ),
              onTap: () => context.push('/citizen/reports/${report.id}'),
            ),
          );
        },
      );
    }

    return CitizenScaffold(
      currentIndex: 1,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'My reports',
              subtitle: 'Track verification status',
              onBack: () => context.go('/citizen/home'),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
