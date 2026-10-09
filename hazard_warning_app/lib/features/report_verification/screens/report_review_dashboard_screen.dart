import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/report_verification/report_review_logic.dart';
import 'package:hazard_warning_app/features/report_verification/widgets/officer_access_gate.dart';
import 'package:hazard_warning_app/features/report_verification/widgets/report_widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Statuses an officer can filter the report queue by.
const reviewFilters = [
  ReportStatus.pending,
  ReportStatus.verified,
  ReportStatus.rejected,
];

/// UC-02 duty officer dashboard: live list of submitted hazard reports with
/// the pending count and PENDING / CONFIRMED / DISMISSED filters.
class ReportReviewDashboardScreen extends StatelessWidget {
  const ReportReviewDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OfficerAccessGate(child: _Dashboard());
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard();

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  ReportStatus _filter = ReportStatus.pending;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Hazard reports',
              subtitle: 'Verify ground reports before any warning',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/officer/home'),
            ),
            Expanded(child: _body(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppState state) {
    if (!state.reportsLoaded) {
      return const ReviewStateView(
        icon: Icons.fact_check_outlined,
        title: 'Loading reports…',
        message: 'Fetching the latest ground reports.',
        action: CircularProgressIndicator(),
      );
    }
    final all = state.reports;
    if (state.reportsError != null && all.isEmpty) {
      return ReviewStateView(
        icon: Icons.cloud_off_rounded,
        color: AppColors.severityHigh,
        title: 'Reports unavailable',
        message: describeReportError(state.reportsError!),
        action: PrimaryActionButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          onPressed: state.reloadReports,
        ),
      );
    }

    final counts = {
      for (final s in reviewFilters) s: all.where((r) => r.status == s).length,
    };
    final visible = all.where((r) => r.status == _filter).toList();
    if (_filter == ReportStatus.pending) {
      // Oldest first so nothing waits at the bottom of the queue.
      visible.sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    }
    final pending = all.where((r) => r.status == ReportStatus.pending);
    final duplicateFlags = pending
        .where((r) => possibleDuplicates(r, all).isNotEmpty)
        .length;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const OfficerIdentityBar(),
            if (!state.online) ...[
              const SizedBox(height: 12),
              const ReviewNotice.offline(
                message:
                    'Showing the last synced reports. Confirming or '
                    'dismissing needs a connection.',
              ),
            ],
            if (state.reportsError != null) ...[
              const SizedBox(height: 12),
              ReviewNotice.error(
                message:
                    'Live updates paused: ${describeReportError(state.reportsError!)}',
                action: TextButton(
                  onPressed: state.reloadReports,
                  child: const Text('Reconnect'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _QueueSummary(
              pending: counts[ReportStatus.pending]!,
              oldestPending: pending.isEmpty
                  ? null
                  : pending
                        .map((r) => r.submittedAt)
                        .reduce((a, b) => a.isBefore(b) ? a : b),
              duplicateFlags: duplicateFlags,
            ),
            const SizedBox(height: 24),
            const FieldLabel('Filter by status'),
            Semantics(
              container: true,
              label: 'Report status filter',
              child: SegmentedPills<ReportStatus>(
                values: reviewFilters,
                selected: _filter,
                labelBuilder: (s) => '${s.label} ${counts[s]}',
                selectedColor: (s) => s.color,
                onSelected: (s) => setState(() => _filter = s),
              ),
            ),
            const SizedBox(height: 20),
            if (visible.isEmpty)
              _EmptyFilter(status: _filter)
            else
              for (final report in visible) ...[
                ReviewReportTile(
                  report: report,
                  duplicates: report.status == ReportStatus.pending
                      ? possibleDuplicates(report, all).length
                      : 0,
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({
    required this.pending,
    required this.oldestPending,
    required this.duplicateFlags,
  });

  final int pending;
  final DateTime? oldestPending;
  final int duplicateFlags;

  String _age(DateTime since) {
    final d = DateTime.now().difference(since);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min';
    if (d.inDays < 1) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          '$pending reports awaiting verification'
          '${oldestPending == null ? '' : ', oldest waiting ${_age(oldestPending!)}'}'
          '${duplicateFlags == 0 ? '' : ', $duplicateFlags possible duplicates'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pending == 1 ? 'Report to verify' : 'Reports to verify',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryLine(
                      icon: Icons.schedule_rounded,
                      text: oldestPending == null
                          ? 'Queue is clear'
                          : 'Oldest ${_age(oldestPending!)}',
                    ),
                    const SizedBox(height: 8),
                    _SummaryLine(
                      icon: Icons.copy_all_rounded,
                      text: duplicateFlags == 0
                          ? 'No duplicates flagged'
                          : '$duplicateFlags possible duplicate${duplicateFlags == 1 ? '' : 's'}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// One report in the officer queue.
class ReviewReportTile extends StatelessWidget {
  const ReviewReportTile({
    super.key,
    required this.report,
    this.duplicates = 0,
  });

  final HazardReport report;
  final int duplicates;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM · HH:mm');
    return Semantics(
      button: true,
      label:
          '${report.category.label}, ${report.status.label}, '
          '${report.locationLabel}, report ${report.id}'
          '${duplicates > 0 ? ', $duplicates possible duplicates' : ''}',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: () => context.push('/officer/reports/${report.id}/verify'),
          child: Row(
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: report.status.label,
                          color: report.status.color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            report.locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          report.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          fmt.format(report.submittedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (report.hasPhoto)
                          const Icon(
                            Icons.photo_camera_outlined,
                            size: 15,
                            color: AppColors.textGrey,
                          ),
                        if (duplicates > 0)
                          StatusBadge(
                            label: '$duplicates similar',
                            color: AppColors.warningText,
                          ),
                      ],
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
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (status) {
      ReportStatus.pending => (
        Icons.task_alt_rounded,
        'Queue is clear',
        'No ground reports are waiting for verification.',
      ),
      ReportStatus.verified => (
        Icons.verified_outlined,
        'No confirmed reports',
        'Reports you confirm will appear here.',
      ),
      _ => (
        Icons.block_rounded,
        'No dismissed reports',
        'Reports you dismiss will appear here with their reason.',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ReviewStateView(
        icon: icon,
        color: status == ReportStatus.pending
            ? AppColors.successGreen
            : status.color,
        title: title,
        message: message,
      ),
    );
  }
}
