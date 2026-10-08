import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/citizen/widgets/citizen_scaffold.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<AppState>().reports;
    final fmt = DateFormat('d MMM yyyy · HH:mm');

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
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(report.category.label),
                      subtitle: Text(
                        '${report.id} · ${fmt.format(report.submittedAt)}',
                      ),
                      trailing: StatusBadge(
                        label: _statusLabel(report),
                        color: _statusColor(report.status),
                      ),
                      onTap: () =>
                          context.push('/citizen/reports/${report.id}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(HazardReport report) {
    if (report.syncState == SyncState.queued) return 'Queued';
    return switch (report.status) {
      ReportStatus.pending => 'Pending',
      ReportStatus.verified => 'Verified',
      ReportStatus.rejected => 'Rejected',
      ReportStatus.synced => 'Synced',
    };
  }

  Color _statusColor(ReportStatus status) => switch (status) {
    ReportStatus.pending => const Color(0xFFF59E0B),
    ReportStatus.verified => const Color(0xFF16A34A),
    ReportStatus.rejected => const Color(0xFFB91C1C),
    ReportStatus.synced => const Color(0xFF2563EB),
  };
}
