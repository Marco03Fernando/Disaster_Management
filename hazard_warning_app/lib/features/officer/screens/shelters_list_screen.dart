import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/officer/widgets/officer_coordination_scaffold.dart';
import 'package:provider/provider.dart';

class SheltersListScreen extends StatelessWidget {
  const SheltersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shelters = context.watch<AppState>().shelters;

    return OfficerCoordinationScaffold(
      currentIndex: 0,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Shelters',
              subtitle: 'Occupancy and redirection',
              onBack: () => context.go('/officer/home'),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: shelters.length,
                itemBuilder: (context, index) {
                  final shelter = shelters[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(shelter.name),
                      subtitle: Text(
                        '${shelter.occupancy} / ${shelter.capacity} occupants',
                      ),
                      trailing: shelter.isOverCapacity
                          ? const StatusBadge(
                              label: 'Over capacity',
                              color: AppColors.severityHigh,
                            )
                          : null,
                      onTap: () =>
                          context.push('/officer/shelters/${shelter.id}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
