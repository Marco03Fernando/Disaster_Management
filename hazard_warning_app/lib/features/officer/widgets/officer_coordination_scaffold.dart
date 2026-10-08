import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';

class OfficerCoordinationScaffold extends StatelessWidget {
  const OfficerCoordinationScaffold({
    super.key,
    required this.body,
    this.currentIndex = 0,
  });

  final Widget body;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/officer/shelters');
            case 1:
              context.go('/officer/teams');
            case 2:
              context.go('/officer/relief');
            case 3:
              context.go('/officer/overview');
          }
        },
        indicatorColor: AppColors.lightBlueChip,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Shelters',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Teams',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Relief',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Overview',
          ),
        ],
      ),
    );
  }
}
