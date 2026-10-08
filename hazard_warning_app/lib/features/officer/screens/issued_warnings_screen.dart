import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/officer/widgets/escalate_warning.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// All warnings issued so far, with delivery statistics and quick escalation.
class IssuedWarningsScreen extends StatefulWidget {
  const IssuedWarningsScreen({super.key});

  @override
  State<IssuedWarningsScreen> createState() => _IssuedWarningsScreenState();
}

class _IssuedWarningsScreenState extends State<IssuedWarningsScreen> {
  final _escalating = <String>{};

  Future<void> _escalate(HazardWarning warning) {
    return escalateWithConfirmation(
      context,
      warning,
      onBusy: (busy) {
        if (!mounted) return;
        setState(
          () => busy
              ? _escalating.add(warning.id)
              : _escalating.remove(warning.id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final warnings = [...context.watch<AppState>().warnings]
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Issued warnings',
              subtitle: 'Delivery statistics and escalation',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: warnings.isEmpty
                  ? const _EmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      children: [
                        _SummaryPanel(warnings: warnings),
                        const SizedBox(height: 24),
                        FieldLabel(
                          'All warnings',
                          trailing: Text(
                            '${warnings.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        for (final w in warnings) ...[
                          _WarningCard(
                            warning: w,
                            escalating: _escalating.contains(w.id),
                            onEscalate: () => _escalate(w),
                          ),
                          const SizedBox(height: 12),
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

double _reachRatio(HazardWarning w) {
  final targeted = w.deliveries.fold<int>(0, (s, d) => s + d.targeted);
  final reached = w.deliveries.fold<int>(0, (s, d) => s + d.totalDelivered);
  return targeted == 0 ? 1 : reached / targeted;
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.warnings});

  final List<HazardWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact();
    final recipients = warnings.fold<int>(0, (s, w) => s + w.recipientCount);
    final failed = warnings.fold<int>(0, (s, w) => s + w.failedCount);
    final targeted = warnings.fold<int>(
      0,
      (s, w) => s + w.deliveries.fold<int>(0, (a, d) => a + d.targeted),
    );
    final reached = warnings.fold<int>(
      0,
      (s, w) => s + w.deliveries.fold<int>(0, (a, d) => a + d.totalDelivered),
    );
    final rate = targeted == 0 ? 100.0 : reached / targeted * 100;
    final escalated = warnings.where((w) => w.escalations > 0).length;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALL-TIME OVERVIEW',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(value: '${warnings.length}', label: 'Warnings'),
              ),
              Expanded(
                child: _Stat(
                  value: fmt.format(recipients),
                  label: 'Citizens alerted',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '${rate.toStringAsFixed(1)}%',
                  label: 'Delivery rate',
                ),
              ),
              Expanded(
                child: _Stat(
                  value: NumberFormat.decimalPattern().format(failed),
                  label: 'Failed deliveries',
                ),
              ),
              Expanded(
                child: _Stat(value: '$escalated', label: 'Escalated'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.warning,
    required this.escalating,
    required this.onEscalate,
  });

  final HazardWarning warning;
  final bool escalating;
  final VoidCallback onEscalate;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final w = warning;
    final next = w.level.next;
    final ratio = _reachRatio(w);

    return AppCard(
      onTap: () => context.push('/officer/warnings/delivery/${w.id}'),
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: w.level.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBadge(
                          icon: w.category.icon,
                          color: w.level.color,
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.category.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                w.targetArea,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(label: w.level.label, color: w.level.color),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 7,
                        backgroundColor: AppColors.surfaceMuted,
                        color: w.hasFailures
                            ? AppColors.severityModerate
                            : AppColors.successGreen,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _Mini(
                            label: 'Recipients',
                            value: fmt.format(w.recipientCount),
                          ),
                        ),
                        Expanded(
                          child: _Mini(
                            label: 'Reached',
                            value: '${(ratio * 100).toStringAsFixed(1)}%',
                          ),
                        ),
                        Expanded(
                          child: _Mini(
                            label: 'Failed',
                            value: fmt.format(w.failedCount),
                            color: w.hasFailures
                                ? AppColors.severityHigh
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${w.id} · ${DateFormat('d MMM · HH:mm').format(w.issuedAt)}'
                            '${w.escalations > 0 ? ' · escalated ×${w.escalations}' : ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (next != null)
                          FilledButton.icon(
                            onPressed: escalating ? null : onEscalate,
                            style: FilledButton.styleFrom(
                              backgroundColor: next.color,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              minimumSize: Size.zero,
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            icon: escalating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.trending_up_rounded,
                                    size: 16,
                                  ),
                            label: Text('Escalate to ${next.label}'),
                          )
                        else
                          const StatusBadge(
                            label: 'Highest level',
                            color: AppColors.textGrey,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: color ?? AppColors.textDark,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
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
              icon: Icons.campaign_outlined,
              color: AppColors.accentBlue,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              'No warnings issued yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Warnings you send will appear here with their delivery statistics.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () =>
                  context.pushReplacement('/officer/warnings/select'),
              child: const Text('Issue a warning'),
            ),
          ],
        ),
      ),
    );
  }
}
