import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/officer/widgets/officer_coordination_scaffold.dart';

class ReliefTeamsScreen extends StatelessWidget {
  const ReliefTeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OfficerCoordinationScaffold(
      currentIndex: 1,
      body: SafeArea(
        child: FutureBuilder<List<ReliefTeam>>(
          future: AppServices.instance.repository.getReliefTeams(),
          builder: (context, snapshot) {
            final teams = snapshot.data ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(
                  title: 'Response teams',
                  subtitle: 'Field assignments',
                  onBack: () => context.go('/officer/home'),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: teams.length,
                    itemBuilder: (context, index) {
                      final team = teams[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(team.name),
                          subtitle: Text(
                            'Lead ${team.lead} · ${team.members} members · ${team.status}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
