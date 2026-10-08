import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class IssueWarningScreen extends StatefulWidget {
  const IssueWarningScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<IssueWarningScreen> createState() => _IssueWarningScreenState();
}

class _IssueWarningScreenState extends State<IssueWarningScreen> {
  WarningSeverity _severity = WarningSeverity.high;
  late BroadcastScope _scope;
  late List<TargetAreaOption> _areas; // affected areas, at least one
  bool _busy = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final report = state.reports.cast<HazardReport?>().firstWhere(
      (r) => r!.id == widget.reportId,
      orElse: () => null,
    );
    // The hazard type comes from the verified report and decides the scope.
    _scope = (report?.category.allowedScopes ?? BroadcastScope.values).first;
    _areas = [state.repository.areasForScope(_scope).first];
  }

  void _applyScope(BroadcastScope scope) {
    _scope = scope;
    _areas = [context.read<AppState>().repository.areasForScope(scope).first];
  }

  int get _totalRecipients =>
      _areas.fold(0, (sum, a) => sum + a.recipientCount);

  String get _areaSummary => _areas.length == 1
      ? _areas.first.label
      : '${_areas.length} selected areas';

  /// Step 3: validate the warning details. Returns an error message or null.
  String? _validate(HazardCategory category) {
    if (category.isRapidOnset && _severity == WarningSeverity.low) {
      return '${category.label} is a rapid-onset hazard. Choose at least Moderate severity.';
    }
    return null;
  }

  Future<void> _review(HazardReport report) async {
    final category = report.category;
    setState(() => _attempted = true);
    if (_validate(category) != null) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RecipientSummarySheet(
        category: category,
        severity: _severity,
        areas: _areas,
      ),
    );
    if (confirmed == true) await _send(report, category);
  }

  Future<void> _send(HazardReport report, HazardCategory category) async {
    setState(() => _busy = true);
    final warning = await context.read<AppState>().issueWarning(
      report: report,
      category: category,
      severity: _severity,
      scope: _scope,
      targetAreas: [for (final a in _areas) a.label],
      recipientCount: _totalRecipients,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    context.go('/officer/warnings/delivery/${warning.id}');
  }

  Future<void> _pickAreas() async {
    final available = context.read<AppState>().repository.areasForScope(_scope);
    final picked = await showModalBottomSheet<List<TargetAreaOption>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AreaMultiSelectSheet(
        scope: _scope,
        options: available,
        initiallySelected: {for (final a in _areas) a.id},
      ),
    );
    if (picked != null && picked.isNotEmpty) setState(() => _areas = picked);
  }

  void _removeArea(TargetAreaOption area) {
    if (_areas.length > 1) {
      setState(() => _areas = _areas.where((a) => a.id != area.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = context
        .watch<AppState>()
        .reports
        .cast<HazardReport?>()
        .firstWhere((r) => r!.id == widget.reportId, orElse: () => null);

    if (report == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: const Text('Back'),
          ),
        ),
      );
    }

    final category = report.category;
    final error = _attempted ? _validate(category) : null;
    final empty = _totalRecipients == 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Issue warning',
              subtitle: 'From verified report ${report.id}',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  LockedFieldTile(
                    label: 'Hazard type',
                    value: category.label,
                    icon: category.icon,
                    reason:
                        'Set by verified report ${report.id} · ${category.onsetLabel}',
                  ),
                  const SizedBox(height: 24),
                  const FieldLabel('Severity'),
                  SegmentedPills<WarningSeverity>(
                    values: WarningSeverity.values,
                    labelBuilder: (v) => v.label,
                    selected: _severity,
                    selectedColor: (v) => v.color,
                    onSelected: (v) => setState(() => _severity = v),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    _InlineError(message: error),
                  ],
                  const SizedBox(height: 24),
                  const FieldLabel('Broadcast scope'),
                  SegmentedPills<BroadcastScope>(
                    values: BroadcastScope.values,
                    labelBuilder: (v) => v.label,
                    selected: _scope,
                    isEnabled: category.allowedScopes.contains,
                    showLockOnSelected: category.allowedScopes.length == 1,
                    onSelected: (scope) => setState(() => _applyScope(scope)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.scopeReason,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FieldLabel(
                    'Affected areas',
                    trailing: StatusBadge(
                      label: '${_areas.length} selected',
                      color: AppColors.accentBlue,
                    ),
                  ),
                  _AreaPickerTile(
                    scope: _scope,
                    areas: _areas,
                    onTap: _pickAreas,
                    onRemove: _areas.length > 1 ? _removeArea : null,
                  ),
                  const SizedBox(height: 24),
                  empty
                      ? _EmptyRecipientsCard(area: _areaSummary)
                      : _RecipientPreview(
                          count: _totalRecipients,
                          area: _areaSummary,
                        ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderGrey)),
              ),
              child: PrimaryActionButton(
                label: 'Review recipients',
                icon: Icons.fact_check_outlined,
                backgroundColor: AppColors.severityHigh,
                busy: _busy,
                onPressed: () => _review(report),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.severityHigh,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.severityHigh,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientPreview extends StatelessWidget {
  const _RecipientPreview({required this.count, required this.area});

  final int count;
  final String area;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESTIMATED RECIPIENTS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fmt.format(count),
            style: const TextStyle(
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'citizens registered in $area',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in AlertChannel.values) _ChannelChip(channel: c),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyRecipientsCard extends StatelessWidget {
  const _EmptyRecipientsCard({required this.area});

  final String area;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.warningBanner,
      borderColor: const Color(0xFFFDE68A),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(
            icon: Icons.person_off_outlined,
            color: AppColors.warningText,
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No citizens in this area',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.warningText,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No registered citizens were found in $area. Choose a wider scope or another area — no alert will be sent.',
                  style: const TextStyle(
                    color: AppColors.warningText,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({required this.channel});

  final AlertChannel channel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(channel.icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            channel.shortLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile showing the selected affected areas as removable chips; tapping the
/// header opens the multi-select sheet.
class _AreaPickerTile extends StatelessWidget {
  const _AreaPickerTile({
    required this.scope,
    required this.areas,
    required this.onTap,
    required this.onRemove,
  });

  final BroadcastScope scope;
  final List<TargetAreaOption> areas;
  final VoidCallback onTap;
  final ValueChanged<TargetAreaOption>? onRemove;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const IconBadge(
                    icon: Icons.map_outlined,
                    color: AppColors.accentBlue,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add or remove ${scope.label.toLowerCase()} areas',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.accentBlue,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.borderGrey),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in areas)
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      7,
                      onRemove == null ? 12 : 6,
                      7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlueBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.lightBlueChip),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          a.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          a.recipientCount == 0
                              ? 'none'
                              : NumberFormat.compact().format(a.recipientCount),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                        if (onRemove != null) ...[
                          const SizedBox(width: 2),
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => onRemove!(a),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (areas.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                '${areas.length} areas · ${fmt.format(areas.fold<int>(0, (s, a) => s + a.recipientCount))} registered citizens in total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet for choosing one or more affected areas of the current scope.
class _AreaMultiSelectSheet extends StatefulWidget {
  const _AreaMultiSelectSheet({
    required this.scope,
    required this.options,
    required this.initiallySelected,
  });

  final BroadcastScope scope;
  final List<TargetAreaOption> options;
  final Set<String> initiallySelected;

  @override
  State<_AreaMultiSelectSheet> createState() => _AreaMultiSelectSheetState();
}

class _AreaMultiSelectSheetState extends State<_AreaMultiSelectSheet> {
  late final Set<String> _selected = {...widget.initiallySelected};

  List<TargetAreaOption> get _chosen =>
      widget.options.where((a) => _selected.contains(a.id)).toList();

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final allSelected = _selected.length == widget.options.length;
    final total = _chosen.fold<int>(0, (s, a) => s + a.recipientCount);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Affected ${widget.scope.label.toLowerCase()} areas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      if (allSelected) {
                        // Keep the first one: at least one area is required.
                        _selected
                          ..clear()
                          ..add(widget.options.first.id);
                      } else {
                        _selected.addAll(widget.options.map((a) => a.id));
                      }
                    }),
                    child: Text(allSelected ? 'Clear' : 'Select all'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final a in widget.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: _selected.contains(a.id)
                              ? AppColors.lightBlueBg
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: _selected.contains(a.id)
                                  ? AppColors.accentBlue
                                  : AppColors.borderGrey,
                              width: _selected.contains(a.id) ? 1.5 : 1,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: _selected.contains(a.id),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _selected.add(a.id);
                              } else if (_selected.length > 1) {
                                _selected.remove(a.id);
                              }
                            }),
                            controlAffinity: ListTileControlAffinity.trailing,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(
                              a.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              a.recipientCount == 0
                                  ? 'No registered citizens'
                                  : '${fmt.format(a.recipientCount)} registered citizens',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              PrimaryActionButton(
                label:
                    '${_selected.length} selected · ${fmt.format(total)} citizens',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.pop(context, _chosen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Step 5: recipient summary and confirmation. Also reports an empty list.
class _RecipientSummarySheet extends StatelessWidget {
  const _RecipientSummarySheet({
    required this.category,
    required this.severity,
    required this.areas,
  });

  final HazardCategory category;
  final WarningSeverity severity;
  final List<TargetAreaOption> areas;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final total = areas.fold<int>(0, (s, a) => s + a.recipientCount);
    final empty = total == 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (empty) ...[
              const Center(
                child: IconBadge(
                  icon: Icons.person_off_outlined,
                  color: AppColors.severityModerate,
                  size: 72,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Empty recipient list',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'There are no registered citizens in ${areas.map((a) => a.label).join(', ')}, so no alert has been dispatched.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryActionButton(
                label: 'Change target area',
                onPressed: () => Navigator.pop(context, false),
              ),
            ] else ...[
              Text(
                'Confirm warning',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Review who will be alerted before sending.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              AppCard(
                color: AppColors.scaffoldBg,
                child: Column(
                  children: [
                    _SummaryRow(label: 'Hazard', value: category.label),
                    _SummaryRow(
                      label: 'Severity',
                      valueWidget: StatusBadge(
                        label: severity.label,
                        color: severity.color,
                      ),
                    ),
                    for (final a in areas)
                      _SummaryRow(
                        label: areas.length == 1
                            ? 'Target area'
                            : '• ${a.label}',
                        value: areas.length == 1
                            ? a.label
                            : '${fmt.format(a.recipientCount)} citizens',
                      ),
                    _SummaryRow(
                      label: areas.length == 1
                          ? 'Recipients'
                          : 'Total recipients',
                      value: '${fmt.format(total)} citizens',
                      strong: true,
                    ),
                    _SummaryRow(
                      label: 'Channels',
                      value: 'Push · SMS · Audible',
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Audible alerts reach only recipients whose app is in the background.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryActionButton(
                label: 'Confirm & send warning',
                icon: Icons.send_rounded,
                backgroundColor: AppColors.severityHigh,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Go back'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.strong = false,
    this.last = false,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool strong;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 16),
          Flexible(
            child:
                valueWidget ??
                Text(
                  value!,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                    fontSize: strong ? 16 : 14,
                    color: strong ? AppColors.primaryBlue : AppColors.textDark,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
