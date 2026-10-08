import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<AppState>().reports;
    final report = reports.cast<HazardReport?>().firstWhere(
      (r) => r!.id == reportId,
      orElse: () => null,
    );
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

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ScreenHeader(
              title: report.id,
              subtitle: report.areaLabel,
              onBack: () => context.pop(),
            ),
            const SizedBox(height: 16),
            StatusBadge(
              label: report.status.name.toUpperCase(),
              color: report.status == ReportStatus.verified
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 20),
            Text(
              report.category.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Submitted ${fmt.format(report.submittedAt)}'),
            const SizedBox(height: 16),
            Text('Location: ${report.locationLabel}'),
            Text(report.coordinates.formatted),
            if (report.notes != null) ...[
              const SizedBox(height: 16),
              Text(report.notes!),
            ],
            if (report.syncState == SyncState.queued) ...[
              const SizedBox(height: 24),
              const OfflineBanner(),
            ],
          ],
        ),
      ),
    );
  }
}
