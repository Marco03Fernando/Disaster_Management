import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:provider/provider.dart';

class ShelterDetailScreen extends StatefulWidget {
  const ShelterDetailScreen({super.key, required this.shelterId});

  final String shelterId;

  @override
  State<ShelterDetailScreen> createState() => _ShelterDetailScreenState();
}

class _ShelterDetailScreenState extends State<ShelterDetailScreen> {
  late int _occupancy;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shelter = context.read<AppState>().shelterById(widget.shelterId);
      if (shelter != null && mounted) {
        setState(() => _occupancy = shelter.occupancy);
      }
    });
  }

  Shelter? get _shelter =>
      context.watch<AppState>().shelterById(widget.shelterId);

  Shelter? get _alternative {
    final id = _shelter?.nearestAlternativeId;
    if (id == null) return null;
    return context.read<AppState>().shelterById(id);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AppState>().saveShelterOccupancy(
      widget.shelterId,
      _occupancy,
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Occupancy saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shelter = _shelter;
    if (shelter == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: const Text('Back'),
          ),
        ),
      );
    }

    final over = _occupancy > shelter.capacity;
    final alt = _alternative;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                      ),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  shelter.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                              ),
                              if (over)
                                const StatusBadge(
                                  label: 'Over capacity',
                                  color: AppColors.severityHigh,
                                ),
                            ],
                          ),
                          Text(
                            shelter.district,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: AppColors.textGrey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  shelter.address,
                                  style: Theme.of(context).textTheme.bodySmall,
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$_occupancy',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: over
                                        ? AppColors.severityHigh
                                        : AppColors.textDark,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'capacity ${shelter.capacity}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _CapacityBar(
                              occupancy: _occupancy,
                              capacity: shelter.capacity,
                            ),
                            if (over)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${_occupancy - shelter.capacity} people over capacity',
                                  style: const TextStyle(
                                    color: AppColors.severityHigh,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionTitle('Current occupants'),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => setState(
                            () => _occupancy = (_occupancy - 1).clamp(0, 9999),
                          ),
                          icon: const Icon(Icons.remove),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$_occupancy',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => setState(() => _occupancy += 1),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    if (over) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.overCapacity,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.severityHigh,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Occupancy exceeds capacity',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Send new arrivals to the nearest shelter with space before saving.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (over && alt != null) ...[
                      const SizedBox(height: 24),
                      const SectionTitle('Nearest shelter with space'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      alt.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      '1.8 km',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.successGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${alt.id} · ${alt.occupancy} of ${alt.capacity} places used',
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: alt.fillRatio.clamp(0, 1),
                                backgroundColor: AppColors.borderGrey,
                                color: AppColors.successGreen,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 12),
                              PrimaryActionButton(
                                label: 'Redirect arrivals here',
                                icon: Icons.arrow_forward_rounded,
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Redirect note sent for ${alt.name}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    PrimaryActionButton(
                      label: 'Save occupancy',
                      icon: Icons.save_outlined,
                      busy: _saving,
                      onPressed: _save,
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

class _CapacityBar extends StatelessWidget {
  const _CapacityBar({required this.occupancy, required this.capacity});

  final int occupancy;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    final ratio = capacity == 0 ? 0.0 : (occupancy / capacity).clamp(0.0, 1.2);
    final fill = ratio.clamp(0.0, 1.0);
    final overflow = ratio > 1 ? (ratio - 1).clamp(0.0, 0.2) : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            Expanded(
              flex: (fill * 100).round().clamp(1, 100),
              child: ColoredBox(color: AppColors.successGreen),
            ),
            if (overflow > 0)
              Expanded(
                flex: (overflow * 100).round().clamp(1, 20),
                child: const ColoredBox(color: AppColors.severityHigh),
              ),
          ],
        ),
      ),
    );
  }
}
