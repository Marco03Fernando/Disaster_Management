import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:provider/provider.dart';

class OfficerHomeScreen extends StatelessWidget {
  const OfficerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pending = state.pendingReports.length;
    final awaiting = state.verifiedAwaitingWarning.length;
    final activeWarnings = state.warnings.length;
    final latest = state.warnings.isEmpty ? null : state.warnings.first;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Field operations',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Duty officer console',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 19),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Switch role',
                  onPressed: () => context.go('/'),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.borderGrey),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _StatusHero(
              pending: pending,
              warnings: activeWarnings,
              latest: latest,
            ),
            const SizedBox(height: 26),
            const FieldLabel('Quick actions'),
            _ActionCard(
              title: 'Pending ground reports',
              subtitle: pending == 0
                  ? 'All caught up'
                  : '$pending awaiting verification',
              icon: Icons.fact_check_outlined,
              badge: pending > 0 ? '$pending' : null,
              onTap: () => context.push('/officer/reports/pending'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: 'Issue hazard warning',
              subtitle: awaiting == 0
                  ? 'No verified reports waiting'
                  : '$awaiting verified report${awaiting == 1 ? '' : 's'} awaiting a warning',
              icon: Icons.campaign_outlined,
              highlight: true,
              badge: awaiting > 0 ? '$awaiting' : null,
              onTap: () => context.push('/officer/warnings/select'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: 'Issued warnings',
              subtitle: activeWarnings == 0
                  ? 'No warnings issued yet'
                  : '$activeWarnings issued · statistics & escalation',
              icon: Icons.analytics_outlined,
              onTap: () => context.push('/officer/warnings'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: 'Coordinate shelters & relief',
              subtitle: 'Occupancy, teams, and stock levels',
              icon: Icons.home_work_outlined,
              onTap: () => context.push('/officer/overview'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: 'Post-event reports',
              subtitle: 'Analytics after an incident closes',
              icon: Icons.insights_outlined,
              onTap: () => context.push('/officer/post-event'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.pending,
    required this.warnings,
    required this.latest,
  });

  final int pending;
  final int warnings;
  final HazardWarning? latest;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SYSTEM ONLINE · MONITORING',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroStat(value: '$pending', label: 'Reports to verify'),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _HeroStat(value: '$warnings', label: 'Warnings issued'),
              ),
            ],
          ),
          if (latest != null) ...[
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () =>
                  context.push('/officer/warnings/delivery/${latest!.id}'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Latest: ${latest!.level.label} · ${latest!.targetArea}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.highlight = false,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? AppColors.severityHigh : AppColors.primaryBlue;
    return AppCard(
      onTap: onTap,
      color: highlight ? AppColors.dangerSoft : Colors.white,
      borderColor: highlight ? const Color(0xFFFECACA) : AppColors.borderGrey,
      child: Row(
        children: [
          IconBadge(icon: icon, color: accent, size: 52),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.severityModerate,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          Icon(
            Icons.chevron_right_rounded,
            color: accent.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
