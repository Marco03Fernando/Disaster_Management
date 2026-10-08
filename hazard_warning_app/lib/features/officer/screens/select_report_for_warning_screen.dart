import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Lists verified reports that still need a warning, so the officer picks
/// which one to issue before the warning form.
class SelectReportForWarningScreen extends StatelessWidget {
  const SelectReportForWarningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = [...context.watch<AppState>().verifiedAwaitingWarning]
      ..sort(
        (a, b) => (b.verifiedAt ?? b.submittedAt).compareTo(
          a.verifiedAt ?? a.submittedAt,
        ),
      );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Issue hazard warning',
              subtitle: 'Select a verified report to warn about',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: reports.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      itemCount: reports.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return FieldLabel(
                            'Awaiting a warning',
                            trailing: StatusBadge(
                              label: '${reports.length} verified',
                              color: AppColors.accentBlue,
                            ),
                          );
                        }
                        return _ReportCard(report: reports[index - 1]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final HazardReport report;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM · HH:mm');
    final verified = report.verifiedAt ?? report.submittedAt;

    return AppCard(
      onTap: () => context.push('/officer/warnings/issue/${report.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: report.category.icon,
                color: AppColors.accentBlue,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.category.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textGrey,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                report.id,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.primaryBlue,
                ),
              ),
              const Text('  ·  ', style: TextStyle(color: AppColors.textGrey)),
              const Icon(
                Icons.verified_outlined,
                size: 14,
                color: AppColors.successGreen,
              ),
              const SizedBox(width: 4),
              Text(
                'Verified ${fmt.format(verified)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconBadge(
              icon: Icons.task_alt_rounded,
              color: AppColors.successGreen,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              'No reports need a warning',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Verify pending ground reports first, then come back to issue a warning.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () =>
                  context.pushReplacement('/officer/reports/pending'),
              child: const Text('Go to pending reports'),
            ),
          ],
        ),
      ),
    );
  }
}
