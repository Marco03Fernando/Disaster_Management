import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/data/seed_data.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/features/citizen/widgets/citizen_scaffold.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CitizenHomeScreen extends StatelessWidget {
  const CitizenHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final alerts = state.alerts;
    final fmt = DateFormat('d MMM, HH:mm');

    return CitizenScaffold(
      currentIndex: 0,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety alerts',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${SeedData.defaultArea} · registered address',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  tooltip: 'Switch role',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Material(
              color: AppColors.lightBlueBg,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/citizen/report/new'),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report ground hazard',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Photo, type, and GPS — works offline',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recent warnings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.lightBlueBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'No official warnings yet. After an officer issues a warning, it will appear here.',
                ),
              )
            else
              ...alerts.map((alert) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      alert.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      alert.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      fmt.format(alert.issuedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () =>
                        context.push('/citizen/alerts/${alert.warningId}'),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
