import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:provider/provider.dart';

class ReportSubmittedScreen extends StatelessWidget {
  const ReportSubmittedScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final report = state.myReportById(reportId);
    final failed = report?.syncState == SyncState.failed;
    // Also "saved on device" when online but the server has not confirmed yet.
    final online = state.online && report?.syncState != SyncState.queued;
    final title = failed
        ? 'Report not sent'
        : online
        ? 'Report submitted'
        : 'Report saved on device';
    final message = failed
        ? 'Report $reportId did not reach the DMC. Open My reports to retry.'
        : online
        ? 'Report $reportId is pending verification by a duty officer.'
        : 'Report $reportId will sync automatically when you are back online.';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: failed ? AppColors.dangerSoft : AppColors.lightBlueBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  failed ? Icons.error_outline_rounded : Icons.check_rounded,
                  size: 48,
                  color: failed
                      ? AppColors.severityHigh
                      : AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              PrimaryActionButton(
                label: 'View my reports',
                onPressed: () => context.go('/citizen/reports'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/citizen/home'),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
