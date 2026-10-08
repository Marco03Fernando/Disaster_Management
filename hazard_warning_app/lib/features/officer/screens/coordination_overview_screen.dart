import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/officer/widgets/officer_coordination_scaffold.dart';
import 'package:provider/provider.dart';

class CoordinationOverviewScreen extends StatelessWidget {
  const CoordinationOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shelters = context.watch<AppState>().shelters;
    final over = shelters.where((s) => s.isOverCapacity).length;
    final totalOcc = shelters.fold<int>(0, (sum, s) => sum + s.occupancy);

    return OfficerCoordinationScaffold(
      currentIndex: 3,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ScreenHeader(
              title: 'Overview',
              subtitle: 'Shelters & relief snapshot',
              onBack: () => context.go('/officer/home'),
            ),
            const SizedBox(height: 16),
            _MetricCard(title: 'Active shelters', value: '${shelters.length}'),
            _MetricCard(title: 'Total occupants', value: '$totalOcc'),
            _MetricCard(title: 'Over capacity', value: '$over'),
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: 'Open post-event report',
              onPressed: () => context.push('/officer/post-event'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
