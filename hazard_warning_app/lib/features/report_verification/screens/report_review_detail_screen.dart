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

/// UC-02 report details with CONFIRM / DISMISS actions for duty officers.
class ReportReviewDetailScreen extends StatelessWidget {
  const ReportReviewDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    return OfficerAccessGate(child: _ReviewDetail(reportId: reportId));
  }
}

void _back(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/officer/reports/pending');
  }
}

class _ReviewDetail extends StatefulWidget {
  const _ReviewDetail({required this.reportId});

  final String reportId;

  @override
  State<_ReviewDetail> createState() => _ReviewDetailState();
}

class _ReviewDetailState extends State<_ReviewDetail> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm(HazardReport report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.verified_outlined,
          color: AppColors.successGreen,
          size: 32,
        ),
        title: const Text('Confirm this report?'),
        content: Text(
          '${report.id} will be marked CONFIRMED and become eligible for a '
          'hazard warning. No warning is sent and no warning level changes '
          'automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm report'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => context.read<AppState>().verifyReport(report.id),
      success: '${report.id} confirmed · now eligible for a warning',
    );
  }

  Future<void> _dismiss(HazardReport report) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DismissSheet(reportId: report.id),
    );
    if (reason == null || !mounted) return;
    await _run(
      () => context.read<AppState>().rejectReport(report.id, reason: reason),
      success: '${report.id} dismissed',
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String success,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(success)),
            ],
          ),
        ),
      );
      _back(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describeReportError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final report = state.reports.cast<HazardReport?>().firstWhere(
      (r) => r!.id == widget.reportId,
      orElse: () => null,
    );

    final Widget body;
    if (!state.reportsLoaded) {
      body = const ReviewStateView(
        icon: Icons.fact_check_outlined,
        title: 'Loading report…',
        message: 'Fetching the latest details.',
        action: CircularProgressIndicator(),
      );
    } else if (report == null) {
      body = ReviewStateView(
        icon: Icons.search_off_rounded,
        title: 'Report not found',
        message: state.reportsError != null
            ? describeReportError(state.reportsError!)
            : 'Report ${widget.reportId} does not exist or was removed.',
        action: OutlinedButton(
          onPressed: () => _back(context),
          child: const Text('Back to reports'),
        ),
      );
    } else {
      body = _content(context, state, report);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Review report',
              subtitle: report == null
                  ? widget.reportId
                  : '${report.id} · ${report.areaLabel}',
              onBack: () => _back(context),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppState state, HazardReport report) {
    final fmt = DateFormat('d MMM yyyy · HH:mm');
    final duplicates = possibleDuplicates(report, state.reports);
    final pending = report.status == ReportStatus.pending;
    final warned = state.warnings.any((w) => w.sourceReportId == report.id);

    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                children: [
                  ReportPhotoView(report: report),
                  const SizedBox(height: 16),
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
                            StatusBadge(
                              label: report.status.label,
                              color: report.status.color,
                            ),
                          ],
                        ),
                        const Divider(height: 32, color: AppColors.borderGrey),
                        ReportInfoRow(
                          icon: Icons.place_outlined,
                          label: 'Location',
                          value: report.locationLabel,
                        ),
                        ReportInfoRow(
                          icon: Icons.my_location_rounded,
                          label: 'GPS coordinates',
                          value: report.coordinates.formatted,
                        ),
                        ReportInfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Submitted',
                          value: fmt.format(report.submittedAt),
                        ),
                        ReportInfoRow(
                          icon: Icons.speed_rounded,
                          label: 'Hazard profile',
                          value: report.category.onsetLabel,
                        ),
                        ReportInfoRow(
                          icon: Icons.notes_rounded,
                          label: 'Description',
                          value: (report.notes?.trim().isNotEmpty ?? false)
                              ? report.notes!
                              : 'No description provided',
                          valueColor: (report.notes?.trim().isNotEmpty ?? false)
                              ? null
                              : AppColors.textGrey,
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  if (duplicates.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _DuplicatesCard(report: report, duplicates: duplicates),
                  ],
                  const SizedBox(height: 16),
                  _ReporterCard(report: report),
                  if (report.status.isReviewed) ...[
                    const SizedBox(height: 16),
                    _DecisionCard(report: report, warned: warned),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (pending)
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null) ...[
                      ReviewNotice.error(message: _error!),
                      const SizedBox(height: 12),
                    ] else if (!state.online) ...[
                      const ReviewNotice.offline(
                        message: 'Reconnect to confirm or dismiss this report.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    PrimaryActionButton(
                      label: 'Confirm report',
                      icon: Icons.verified_outlined,
                      busy: _busy,
                      onPressed: state.online ? () => _confirm(report) : null,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy || !state.online
                          ? null
                          : () => _dismiss(report),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        foregroundColor: AppColors.severityHigh,
                        side: const BorderSide(
                          color: Color(0xFFFECACA),
                          width: 1.5,
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Dismiss report'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DuplicatesCard extends StatelessWidget {
  const _DuplicatesCard({required this.report, required this.duplicates});

  final HazardReport report;
  final List<HazardReport> duplicates;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM · HH:mm');
    return AppCard(
      color: AppColors.warningBanner,
      borderColor: const Color(0xFFFDE68A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.copy_all_rounded, color: AppColors.warningText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Possible duplicates (${duplicates.length})',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppColors.warningText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Same hazard type within ${duplicateRadiusMeters.round()} m and '
            '${duplicateWindow.inHours} h of this report.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.warningText),
          ),
          const SizedBox(height: 8),
          for (final d in duplicates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              onTap: () => context.push('/officer/reports/${d.id}/verify'),
              title: Text(
                '${d.id} · ${distanceMeters(report.coordinates, d.coordinates).round()} m away',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(fmt.format(d.submittedAt)),
              trailing: StatusBadge(
                label: d.status.label,
                color: d.status.color,
              ),
            ),
        ],
      ),
    );
  }
}

/// Reporter details; contact info is only readable by duty officers.
class _ReporterCard extends StatefulWidget {
  const _ReporterCard({required this.report});

  final HazardReport report;

  @override
  State<_ReporterCard> createState() => _ReporterCardState();
}

class _ReporterCardState extends State<_ReporterCard> {
  late Future<ReporterContact?> _contact;

  @override
  void initState() {
    super.initState();
    _contact = context.read<AppState>().reporterContact(widget.report.id);
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.report.reporterUid;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel(
            'Reporter',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: AppColors.textGrey,
                ),
                SizedBox(width: 4),
                Text(
                  'Officers only',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          FutureBuilder<ReporterContact?>(
            future: _contact,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                );
              }
              if (snap.hasError) {
                return ReportInfoRow(
                  icon: Icons.error_outline_rounded,
                  label: 'Contact details',
                  value: describeReportError(snap.error!),
                  valueColor: AppColors.severityHigh,
                  last: uid == null,
                );
              }
              final c = snap.data;
              if (c == null || c.isEmpty) {
                return ReportInfoRow(
                  icon: Icons.person_off_outlined,
                  label: 'Contact details',
                  value: 'Not provided',
                  valueColor: AppColors.textGrey,
                  last: uid == null,
                );
              }
              return Column(
                children: [
                  if (c.name?.isNotEmpty ?? false)
                    ReportInfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Name',
                      value: c.name!,
                    ),
                  if (c.phone?.isNotEmpty ?? false)
                    ReportInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: c.phone!,
                      last: uid == null,
                    ),
                ],
              );
            },
          ),
          if (uid != null)
            ReportInfoRow(
              icon: Icons.fingerprint_rounded,
              label: 'Reporter account',
              value: uid.length > 10 ? '${uid.substring(0, 10)}…' : uid,
              last: true,
            ),
        ],
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.report, required this.warned});

  final HazardReport report;
  final bool warned;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy · HH:mm');
    final confirmed = report.status == ReportStatus.verified;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Verification record'),
          ReportInfoRow(
            icon: report.status.icon,
            label: 'Decision',
            value: report.status.label.toUpperCase(),
            valueColor: report.status.color,
          ),
          ReportInfoRow(
            icon: Icons.badge_outlined,
            label: 'Reviewed by',
            value: report.verifiedBy ?? 'Unknown officer',
          ),
          ReportInfoRow(
            icon: Icons.event_available_rounded,
            label: 'Reviewed at',
            value: report.verifiedAt == null
                ? 'Syncing…'
                : fmt.format(report.verifiedAt!),
            last: confirmed || report.dismissalReason == null,
          ),
          if (!confirmed && report.dismissalReason != null)
            ReportInfoRow(
              icon: Icons.comment_outlined,
              label: 'Reason for dismissal',
              value: report.dismissalReason!,
              last: true,
            ),
          if (confirmed) ...[
            const SizedBox(height: 16),
            ReviewNotice(
              icon: warned
                  ? Icons.campaign_rounded
                  : Icons.outlined_flag_rounded,
              message: warned
                  ? 'A hazard warning has been issued from this report.'
                  : 'Eligible for a hazard warning. Nothing is published '
                        'until an officer issues one.',
              action: warned
                  ? null
                  : TextButton.icon(
                      onPressed: () =>
                          context.push('/officer/warnings/issue/${report.id}'),
                      icon: const Icon(Icons.campaign_outlined, size: 18),
                      label: const Text('Go to issue warning'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet collecting the mandatory dismissal reason.
class _DismissSheet extends StatefulWidget {
  const _DismissSheet({required this.reportId});

  final String reportId;

  @override
  State<_DismissSheet> createState() => _DismissSheetState();
}

class _DismissSheetState extends State<_DismissSheet> {
  static const _quickReasons = [
    'Duplicate of an existing report',
    'Photo does not show a hazard',
    'Location could not be verified',
    'Hazard already resolved on site',
  ];

  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.length < ReportReviewRules.minDismissalReasonLength) {
      setState(
        () => _error =
            'Enter a reason of at least '
            '${ReportReviewRules.minDismissalReasonLength} characters.',
      );
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dismiss ${widget.reportId}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'The reason is saved with the report and shown to the reporter.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            const FieldLabel('Common reasons'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _quickReasons)
                  ActionChip(
                    label: Text(r),
                    onPressed: () => setState(() {
                      _ctrl.text = r;
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: ReportReviewRules.maxDismissalReasonLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: 'Reason for dismissal (required)',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            PrimaryActionButton(
              label: 'Dismiss report',
              icon: Icons.block_rounded,
              backgroundColor: AppColors.severityHigh,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
