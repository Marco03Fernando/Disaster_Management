import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/officer/widgets/officer_coordination_scaffold.dart';
import 'package:provider/provider.dart';

class CoordinationOverviewScreen extends StatefulWidget {
  const CoordinationOverviewScreen({super.key});

  @override
  State<CoordinationOverviewScreen> createState() =>
      _CoordinationOverviewScreenState();
}

class _CoordinationOverviewScreenState
    extends State<CoordinationOverviewScreen> {
  late Future<List<ReliefTeam>> _teamsFuture;
  late Future<List<ReliefStock>> _stockFuture;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _loadDashboardData() {
    _teamsFuture = AppServices.instance.repository.getReliefTeams();
    _stockFuture = AppServices.instance.repository.getReliefStock();
  }

  Future<void> _refresh() async {
    setState(_loadDashboardData);

    await Future.wait([
      _teamsFuture,
      _stockFuture,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final shelters = context.watch<AppState>().shelters;

    final overCapacity =
        shelters.where((shelter) => shelter.isOverCapacity).length;

    final totalOccupants = shelters.fold<int>(
      0,
      (sum, shelter) => sum + shelter.occupancy,
    );

    final totalCapacity = shelters.fold<int>(
      0,
      (sum, shelter) => sum + shelter.capacity,
    );

    final occupancyRatio = totalCapacity == 0
        ? 0.0
        : (totalOccupants / totalCapacity).clamp(0.0, 1.0).toDouble();

    final availableSpaces =
        (totalCapacity - totalOccupants).clamp(0, totalCapacity);

    return OfficerCoordinationScaffold(
      currentIndex: 0,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24,
            ),
            children: [
              ScreenHeader(
                title: 'Overview',
                subtitle: 'Shelters & relief snapshot',
                onBack: () => context.go('/officer/home'),
              ),

              const SizedBox(height: 8),

              // ------------------------------------------------------------
              // RESPONSE STATUS
              // ------------------------------------------------------------
              _DashboardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardHeader(
                      icon: Icons.dashboard_outlined,
                      title: 'Response status',
                      subtitle: 'Current operational picture',
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: _LargeMetric(
                            icon: Icons.home_work_outlined,
                            label: 'Active shelters',
                            value: '${shelters.length}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LargeMetric(
                            icon: Icons.people_outline,
                            label: 'Occupants',
                            value: '$totalOccupants',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _SmallMetric(
                            label: 'Over capacity',
                            value: '$overCapacity',
                            valueColor: overCapacity > 0
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF16A34A),
                            icon: overCapacity > 0
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SmallMetric(
                            label: 'Available spaces',
                            value: '$availableSpaces',
                            valueColor: const Color(0xFF16A34A),
                            icon: Icons.event_seat_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------------------
              // SHELTER CAPACITY
              // ------------------------------------------------------------
              _DashboardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardHeader(
                      icon: Icons.people_alt_outlined,
                      title: 'Shelter capacity',
                      subtitle: 'Occupancy across all registered shelters',
                    ),

                    const SizedBox(height: 18),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(occupancyRatio * 100).round()}%',
                          style:
                              Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'occupied',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$totalOccupants / $totalCapacity',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: occupancyRatio,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          overCapacity > 0
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF16A34A),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Icon(
                          overCapacity > 0
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          size: 17,
                          color: overCapacity > 0
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            overCapacity > 0
                                ? '$overCapacity shelter${overCapacity == 1 ? '' : 's'} need attention'
                                : 'All shelters are within capacity',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: overCapacity > 0
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF15803D),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------------------
              // TEAMS + RELIEF
              // ------------------------------------------------------------
              FutureBuilder<List<ReliefTeam>>(
                future: _teamsFuture,
                builder: (context, teamSnapshot) {
                  final teams = teamSnapshot.data ?? const <ReliefTeam>[];

                  final availableTeams = teams
                      .where(
                        (team) =>
                            team.status.toLowerCase() == 'available',
                      )
                      .length;

                  final activeTeams = teams
                      .where(
                        (team) =>
                            team.status.toLowerCase() != 'available' &&
                            team.status.toLowerCase() != 'completed',
                      )
                      .length;

                  return FutureBuilder<List<ReliefStock>>(
                    future: _stockFuture,
                    builder: (context, stockSnapshot) {
                      final stock =
                          stockSnapshot.data ?? const <ReliefStock>[];

                      final resourceCategories = <String>{};

                      for (final districtStock in stock) {
                        resourceCategories.addAll(
                          districtStock.items.keys,
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _DashboardCard(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const _CardHeader(
                                    icon: Icons.groups_outlined,
                                    title: 'Rescue teams',
                                    subtitle: 'Field response',
                                  ),

                                  const SizedBox(height: 18),

                                  Text(
                                    '${teams.length}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),

                                  const SizedBox(height: 3),

                                  Text(
                                    'total teams',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                  ),

                                  const SizedBox(height: 14),

                                  _MiniStatusRow(
                                    dotColor:
                                        const Color(0xFF16A34A),
                                    label: 'Available',
                                    value: '$availableTeams',
                                  ),

                                  const SizedBox(height: 7),

                                  _MiniStatusRow(
                                    dotColor:
                                        const Color(0xFF2563EB),
                                    label: 'Active',
                                    value: '$activeTeams',
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: _DashboardCard(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const _CardHeader(
                                    icon: Icons.inventory_2_outlined,
                                    title: 'Relief stock',
                                    subtitle: 'Resource coverage',
                                  ),

                                  const SizedBox(height: 18),

                                  Text(
                                    '${stock.length}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),

                                  const SizedBox(height: 3),

                                  Text(
                                    'districts covered',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                  ),

                                  const SizedBox(height: 14),

                                  _MiniStatusRow(
                                    dotColor:
                                        const Color(0xFFEAB308),
                                    label: 'Food',
                                    value: resourceCategories
                                            .contains('Food')
                                        ? 'Tracked'
                                        : '—',
                                  ),

                                  const SizedBox(height: 7),

                                  _MiniStatusRow(
                                    dotColor:
                                        const Color(0xFF2563EB),
                                    label: 'Water',
                                    value: resourceCategories
                                            .contains('Water')
                                        ? 'Tracked'
                                        : '—',
                                  ),

                                  const SizedBox(height: 7),

                                  _MiniStatusRow(
                                    dotColor:
                                        const Color(0xFF86EFAC),
                                    label: 'Medicine',
                                    value: resourceCategories
                                            .contains('Medicine')
                                        ? 'Tracked'
                                        : '—',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------------------
              // ATTENTION REQUIRED
              // ------------------------------------------------------------
              FutureBuilder<List<ReliefTeam>>(
                future: _teamsFuture,
                builder: (context, snapshot) {
                  final teams = snapshot.data ?? const <ReliefTeam>[];

                  final availableTeams = teams
                      .where(
                        (team) =>
                            team.status.toLowerCase() == 'available',
                      )
                      .length;

                  final attentionItems = <_AttentionItem>[];

                  if (overCapacity > 0) {
                    attentionItems.add(
                      _AttentionItem(
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFB91C1C),
                        text:
                            '$overCapacity shelter${overCapacity == 1 ? '' : 's'} over capacity',
                      ),
                    );
                  }

                  if (availableTeams == 0 && teams.isNotEmpty) {
                    attentionItems.add(
                      const _AttentionItem(
                        icon: Icons.groups_outlined,
                        color: Color(0xFFF59E0B),
                        text: 'No rescue teams currently available',
                      ),
                    );
                  }

                  if (attentionItems.isEmpty) {
                    attentionItems.add(
                      const _AttentionItem(
                        icon: Icons.check_circle_outline,
                        color: Color(0xFF16A34A),
                        text: 'No immediate coordination issues',
                      ),
                    );
                  }

                  return _DashboardCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CardHeader(
                          icon: Icons.notifications_none_rounded,
                          title: 'Attention required',
                          subtitle: 'Items that may need officer action',
                        ),

                        const SizedBox(height: 14),

                        ...attentionItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: item.color.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    size: 19,
                                    color: item.color,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ------------------------------------------------------------
              // REPORT BUTTON
              // ------------------------------------------------------------
              PrimaryActionButton(
                label: 'Open post-event report',
                onPressed: () =>
                    context.push('/officer/post-event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// DASHBOARD CARD
// ==========================================================================

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

// ==========================================================================
// CARD HEADER
// ==========================================================================

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF17366B),
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// LARGE METRIC
// ==========================================================================

class _LargeMetric extends StatelessWidget {
  const _LargeMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: const Color(0xFF17366B),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// SMALL METRIC
// ==========================================================================

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: valueColor,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// MINI STATUS ROW
// ==========================================================================

class _MiniStatusRow extends StatelessWidget {
  const _MiniStatusRow({
    required this.dotColor,
    required this.label,
    required this.value,
  });

  final Color dotColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

// ==========================================================================
// ATTENTION ITEM
// ==========================================================================

class _AttentionItem {
  const _AttentionItem({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;
}