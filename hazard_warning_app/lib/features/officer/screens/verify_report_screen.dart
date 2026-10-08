import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class VerifyReportScreen extends StatelessWidget {
  const VerifyReportScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<AppState>().reports;
    final report = reports.cast<HazardReport?>().firstWhere(
      (r) => r!.id == reportId,
      orElse: () => null,
    );

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

    final fmt = DateFormat('d MMM yyyy · HH:mm');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Verify report',
              subtitle: 'Confirm the hazard before a warning is issued',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconBadge(
                              icon: report.category.icon,
                              color: AppColors.accentBlue,
                              size: 56,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report.category.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    report.id,
                                    style: const TextStyle(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const StatusBadge(
                              label: 'Unverified',
                              color: AppColors.severityModerate,
                            ),
                          ],
                        ),
                        const Divider(height: 32, color: AppColors.borderGrey),
                        _InfoRow(
                          icon: Icons.place_outlined,
                          label: 'Location',
                          value: report.locationLabel,
                        ),
                        _InfoRow(
                          icon: Icons.my_location_rounded,
                          label: 'Coordinates',
                          value: report.coordinates.formatted,
                        ),
                        _InfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Reported',
                          value: fmt.format(report.submittedAt),
                        ),
                        _InfoRow(
                          icon: Icons.speed_rounded,
                          label: 'Hazard profile',
                          value: report.category.onsetLabel,
                          last: report.notes == null,
                        ),
                        if (report.notes != null)
                          _InfoRow(
                            icon: Icons.notes_rounded,
                            label: 'Field notes',
                            value: report.notes!,
                            last: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  PrimaryActionButton(
                    label: 'Mark verified & continue',
                    icon: Icons.verified_outlined,
                    onPressed: () async {
                      await context.read<AppState>().verifyReport(report.id);
                      if (context.mounted) {
                        context.pushReplacement(
                          '/officer/warnings/issue/${report.id}',
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await context.read<AppState>().rejectReport(report.id);
                      if (context.mounted) context.pop();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      foregroundColor: AppColors.severityHigh,
                      side: const BorderSide(
                        color: Color(0xFFFECACA),
                        width: 1.5,
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject report'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
