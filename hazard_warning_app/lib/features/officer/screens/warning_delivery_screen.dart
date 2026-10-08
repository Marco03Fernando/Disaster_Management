import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/officer/widgets/escalate_warning.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class WarningDeliveryScreen extends StatefulWidget {
  const WarningDeliveryScreen({super.key, required this.warningId});

  final String warningId;

  @override
  State<WarningDeliveryScreen> createState() => _WarningDeliveryScreenState();
}

class _WarningDeliveryScreenState extends State<WarningDeliveryScreen> {
  // Short pause so the demo gateway feels like a real round-trip.
  static const _gatewayDelay = Duration(milliseconds: 900);

  bool _retrying = false;
  bool _escalating = false;

  Future<void> _retry() async {
    final state = context.read<AppState>();
    setState(() => _retrying = true);
    await Future<void>.delayed(_gatewayDelay);
    await state.retryFailedDeliveries(widget.warningId);
    if (!mounted) return;
    setState(() => _retrying = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Resent on fallback channel · delivery status updated'),
        ),
      );
  }

  Future<void> _escalate(HazardWarning warning) {
    return escalateWithConfirmation(
      context,
      warning,
      onBusy: (busy) {
        if (mounted) setState(() => _escalating = busy);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final warning = context
        .watch<AppState>()
        .warnings
        .cast<HazardWarning?>()
        .firstWhere((w) => w!.id == widget.warningId, orElse: () => null);

    if (warning == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: const Text('Back'),
          ),
        ),
      );
    }

    final fmt = NumberFormat.decimalPattern();
    final retried = warning.deliveries.any((d) => d.fallback != null);
    final next = warning.level.next;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Warning dispatched',
              subtitle:
                  '${warning.id} · ${DateFormat('d MMM · HH:mm').format(warning.issuedAt)}',
              onBack: () => context.go('/officer/home'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                children: [
                  _LevelHero(warning: warning),
                  const SizedBox(height: 24),
                  FieldLabel(
                    'Delivery status by channel',
                    trailing: StatusBadge(
                      label: warning.hasFailures
                          ? '${fmt.format(warning.failedCount)} failed'
                          : 'All delivered',
                      color: warning.hasFailures
                          ? AppColors.severityHigh
                          : AppColors.successGreen,
                    ),
                  ),
                  for (final d in warning.deliveries) ...[
                    _ChannelCard(delivery: d),
                    const SizedBox(height: 12),
                  ],
                  if (warning.hasFailures && !retried)
                    _FailureBanner(
                      failed: warning.failedCount,
                      busy: _retrying,
                      onRetry: _retry,
                    )
                  else if (retried && warning.hasFailures)
                    _Note(
                      icon: Icons.info_outline_rounded,
                      color: AppColors.warningText,
                      background: AppColors.warningBanner,
                      text:
                          '${fmt.format(warning.failedCount)} citizens remain unreachable after the fallback retry (e.g. handsets off or out of coverage).',
                    )
                  else if (retried)
                    const _Note(
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.successGreen,
                      background: Color(0xFFF0FDF4),
                      text: 'Retry succeeded. Every recipient has now been reached.',
                    ),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 15,
                        color: AppColors.textGrey,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Delivery status is logged against this warning.',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderGrey)),
              ),
              child: Column(
                children: [
                  if (next != null) ...[
                    PrimaryActionButton(
                      label: 'Conditions worsen · Escalate to ${next.label}',
                      icon: Icons.trending_up_rounded,
                      backgroundColor: next.color,
                      busy: _escalating,
                      onPressed: () => _escalate(warning),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.go('/officer/home'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text(
                            'Dashboard',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.go('/citizen/home'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text(
                            'Citizen view',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                    ],
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

class _LevelHero extends StatelessWidget {
  const _LevelHero({required this.warning});

  final HazardWarning warning;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final level = warning.level;
    final targeted = warning.deliveries.fold<int>(0, (s, d) => s + d.targeted);
    final reached = warning.deliveries.fold<int>(
      0,
      (s, d) => s + d.totalDelivered,
    );
    final pct = targeted == 0 ? 100 : (reached / targeted * 100);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(level.color, Colors.black, 0.25)!, level.color],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: level.color.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'WARNING SENT',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (warning.escalations > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Escalated ×${warning.escalations}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${level.label} · ${level.action}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${warning.category.label} · ${warning.severity.label} severity\n${warning.targetArea}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final l in WarningLevel.values)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(
                      right: l == WarningLevel.values.last ? 0 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: l.index <= level.index ? 0.95 : 0.25,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  value: fmt.format(warning.recipientCount),
                  label: 'Recipients',
                ),
              ),
              Expanded(
                child: _HeroStat(
                  value: '${pct.toStringAsFixed(1)}%',
                  label: 'Reached',
                ),
              ),
              Expanded(
                child: _HeroStat(
                  value: fmt.format(warning.failedCount),
                  label: 'Failed',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

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
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
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

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.delivery});

  final ChannelDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final d = delivery;
    final healthy = d.failed == 0;
    final color = healthy ? AppColors.successGreen : AppColors.severityHigh;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: d.channel.icon,
                color: AppColors.primaryBlue,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.channel.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      d.channel == AlertChannel.audible
                          ? '${fmt.format(d.targeted)} with app in background'
                          : '${fmt.format(d.targeted)} targeted',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                healthy ? Icons.done_all_rounded : Icons.error_outline_rounded,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: d.successRatio),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.surfaceMuted,
                color: healthy
                    ? AppColors.successGreen
                    : AppColors.severityModerate,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _Metric(
                color: AppColors.successGreen,
                text: '${fmt.format(d.totalDelivered)} delivered',
              ),
              if (d.failed > 0)
                _Metric(
                  color: AppColors.severityHigh,
                  text: '${fmt.format(d.failed)} failed · network unavailable',
                ),
              if (d.recovered > 0)
                _Metric(
                  color: AppColors.accentBlue,
                  text:
                      '${fmt.format(d.recovered)} recovered via ${d.fallback!.shortLabel}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({
    required this.failed,
    required this.busy,
    required this.onRetry,
  });

  final int failed;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.severityHigh),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${NumberFormat.decimalPattern().format(failed)} deliveries failed',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.severityHigh,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Network was unavailable for some citizens. Resend on each channel\'s fallback (push ⇄ SMS).',
                      style: TextStyle(
                        color: AppColors.severityHigh,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryActionButton(
            label: 'Resend on fallback channel',
            icon: Icons.replay_rounded,
            backgroundColor: AppColors.severityHigh,
            busy: busy,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
