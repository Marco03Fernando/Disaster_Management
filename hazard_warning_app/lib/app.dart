import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/features/citizen/screens/alert_detail_screen.dart';
import 'package:hazard_warning_app/features/citizen/screens/citizen_home_screen.dart';
import 'package:hazard_warning_app/features/citizen/screens/manual_location_screen.dart';
import 'package:hazard_warning_app/features/citizen/screens/my_reports_screen.dart';
import 'package:hazard_warning_app/features/citizen/screens/report_detail_screen.dart';
import 'package:hazard_warning_app/features/citizen/screens/report_submitted_screen.dart';
import 'package:hazard_warning_app/features/citizen/screens/submit_hazard_report_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/coordination_overview_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/issue_warning_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/issued_warnings_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/officer_home_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/pending_reports_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/post_event_report_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/post_event_reports_list_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/relief_distribution_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/relief_teams_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/select_report_for_warning_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/shelter_detail_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/shelters_list_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/verify_report_screen.dart';
import 'package:hazard_warning_app/features/officer/screens/warning_delivery_screen.dart';
import 'package:hazard_warning_app/features/role_selection/role_selection_screen.dart';

class HazardWarningApp extends StatelessWidget {
  const HazardWarningApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DMC Hazard Warning',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
      builder: (context, child) {
        if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();
        return ColoredBox(
          color: const Color(0xFF0F172A),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Material(
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(28),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/citizen/home',
        builder: (context, state) => const CitizenHomeScreen(),
      ),
      GoRoute(
        path: '/citizen/report/new',
        builder: (context, state) => const SubmitHazardReportScreen(),
      ),
      GoRoute(
        path: '/citizen/report/manual-location',
        builder: (context, state) => const ManualLocationScreen(),
      ),
      GoRoute(
        path: '/citizen/report/submitted/:id',
        builder: (context, state) =>
            ReportSubmittedScreen(reportId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/citizen/reports',
        builder: (context, state) => const MyReportsScreen(),
      ),
      GoRoute(
        path: '/citizen/reports/:id',
        builder: (context, state) =>
            ReportDetailScreen(reportId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/citizen/alerts/:warningId',
        builder: (context, state) =>
            AlertDetailScreen(warningId: state.pathParameters['warningId']!),
      ),
      GoRoute(
        path: '/officer/home',
        builder: (context, state) => const OfficerHomeScreen(),
      ),
      GoRoute(
        path: '/officer/reports/pending',
        builder: (context, state) => const PendingReportsScreen(),
      ),
      GoRoute(
        path: '/officer/reports/:id/verify',
        builder: (context, state) =>
            VerifyReportScreen(reportId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/officer/warnings',
        builder: (context, state) => const IssuedWarningsScreen(),
      ),
      GoRoute(
        path: '/officer/warnings/select',
        builder: (context, state) => const SelectReportForWarningScreen(),
      ),
      GoRoute(
        path: '/officer/warnings/issue/:reportId',
        builder: (context, state) =>
            IssueWarningScreen(reportId: state.pathParameters['reportId']!),
      ),
      GoRoute(
        path: '/officer/warnings/delivery/:warningId',
        builder: (context, state) => WarningDeliveryScreen(
          warningId: state.pathParameters['warningId']!,
        ),
      ),
      GoRoute(
        path: '/officer/shelters',
        builder: (context, state) => const SheltersListScreen(),
      ),
      GoRoute(
        path: '/officer/shelters/:id',
        builder: (context, state) =>
            ShelterDetailScreen(shelterId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/officer/teams',
        builder: (context, state) => const ReliefTeamsScreen(),
      ),
      GoRoute(
        path: '/officer/relief',
        builder: (context, state) => const ReliefDistributionScreen(),
      ),
      GoRoute(
        path: '/officer/overview',
        builder: (context, state) => const CoordinationOverviewScreen(),
      ),
      GoRoute(
        path: '/officer/post-event',
        builder: (context, state) => const PostEventReportsListScreen(),
      ),
      GoRoute(
        path: '/officer/post-event/:id',
        builder: (context, state) =>
            PostEventReportScreen(reportId: state.pathParameters['id']!),
      ),
    ],
  );
}
