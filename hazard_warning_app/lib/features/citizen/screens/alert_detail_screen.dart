import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key, required this.warningId});

  final String warningId;

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AppState>().alerts;
    final alert = alerts.where((a) => a.warningId == warningId).firstOrNull;
    final fmt = DateFormat('d MMM yyyy · HH:mm');

    if (alert == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: const Text('Back'),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ScreenHeader(
              title: 'Official warning',
              subtitle: fmt.format(alert.issuedAt),
              onBack: () => context.pop(),
            ),
            const SizedBox(height: 16),
            StatusBadge(
              label: alert.severity.label,
              color: alert.severity.color,
            ),
            const SizedBox(height: 20),
            Text(alert.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(alert.body),
            const SizedBox(height: 24),
            Text('SMS copy', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(alert.smsText),
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
