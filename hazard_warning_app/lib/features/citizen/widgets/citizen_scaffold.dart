import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';

class CitizenScaffold extends StatelessWidget {
  const CitizenScaffold({
    super.key,
    required this.body,
    this.currentIndex = 0,
    this.showNav = true,
  });

  final Widget body;
  final int currentIndex;
  final bool showNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: body,
      bottomNavigationBar: showNav
          ? NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    context.go('/citizen/home');
                  case 1:
                    context.go('/citizen/reports');
                  case 2:
                    context.go('/citizen/home');
                }
              },
              indicatorColor: AppColors.lightBlueChip,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  label: 'Reports',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_outlined),
                  label: 'Alerts',
                ),
              ],
            )
          : null,
    );
  }
}
