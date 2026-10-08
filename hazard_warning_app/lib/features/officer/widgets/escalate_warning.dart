import 'package:flutter/material.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// Short pause so the demo gateway feels like a real round-trip.
const _gatewayDelay = Duration(milliseconds: 900);

/// Confirms, then raises the warning to the next level and re-broadcasts to
/// the same recipients. [onBusy] reports when the gateway call starts/ends.
/// Returns true if the warning was escalated.
Future<bool> escalateWithConfirmation(
  BuildContext context,
  HazardWarning warning, {
  ValueChanged<bool>? onBusy,
}) async {
  final next = warning.level.next;
  if (next == null) return false;
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.trending_up_rounded, color: next.color, size: 32),
      title: Text('Escalate to ${next.label}?'),
      content: Text(
        'The warning level will be raised from ${warning.level.label} to ${next.label} and re-broadcast to the same ${NumberFormat.decimalPattern().format(warning.recipientCount)} recipients.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: next.color),
          child: const Text('Escalate & resend'),
        ),
      ],
    ),
  );
  if (ok != true) return false;

  onBusy?.call(true);
  try {
    await Future<void>.delayed(_gatewayDelay);
    await state.escalateWarning(warning.id);
  } finally {
    onBusy?.call(false);
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Escalated to ${next.label} · alert re-broadcast'),
      ),
    );
  return true;
}
