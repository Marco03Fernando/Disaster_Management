import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/officer/widgets/officer_coordination_scaffold.dart';

const List<String> _responseAreas = [
  'Kelaniya',
  'Kolonnawa',
  'Kaduwela',
  'Dehiwala',
  'Moratuwa',
  'Sri Jayawardenepura Kotte',
];

class ReliefTeamsScreen extends StatefulWidget {
  const ReliefTeamsScreen({super.key});

  @override
  State<ReliefTeamsScreen> createState() => _ReliefTeamsScreenState();
}

class _ReliefTeamsScreenState extends State<ReliefTeamsScreen> {
  late Future<List<ReliefTeam>> _teamsFuture;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  void _loadTeams() {
    _teamsFuture = AppServices.instance.repository.getReliefTeams();
  }

  Future<void> _refresh() async {
    setState(_loadTeams);
    await _teamsFuture;
  }

  Future<void> _addTeam() async {
    final team = await showDialog<ReliefTeam>(
      context: context,
      builder: (_) => const _TeamDialog(),
    );

    if (team == null) return;

    try {
      await AppServices.instance.repository.addReliefTeam(team);

      if (!mounted) return;

      setState(_loadTeams);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Response team added successfully.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to add team: $e')));
    }
  }

  Future<void> _editTeam(ReliefTeam team) async {
    final updatedTeam = await showDialog<ReliefTeam>(
      context: context,
      builder: (_) => _TeamDialog(team: team),
    );

    if (updatedTeam == null) return;

    try {
      await AppServices.instance.repository.updateReliefTeam(updatedTeam);

      if (!mounted) return;

      setState(_loadTeams);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Response team updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update team: $e')));
    }
  }

  Future<void> _deleteTeam(ReliefTeam team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete response team?'),
          content: Text(
            'Are you sure you want to delete "${team.name}"? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await AppServices.instance.repository.deleteReliefTeam(team.id);

      if (!mounted) return;

      setState(_loadTeams);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Response team deleted.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete team: $e')));
    }
  }

  Future<void> _dispatchTeam(ReliefTeam team) async {
    final locationController = TextEditingController();

    final dispatchLocation = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Dispatch response team'),
          content: TextFormField(
            controller: locationController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Dispatch location',
              hintText: 'e.g. Sedawatta M.V.',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final location = locationController.text.trim();

                if (location.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Enter a dispatch location.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, location);
              },
              child: const Text('Dispatch'),
            ),
          ],
        );
      },
    );

    locationController.dispose();

    if (dispatchLocation == null || dispatchLocation.isEmpty) {
      return;
    }

    final updatedTeam = ReliefTeam(
      id: team.id,
      name: team.name,
      lead: team.lead,
      members: team.members,
      responseArea: team.responseArea,
      status: 'Dispatched',
      currentLocation: team.currentLocation,
      dispatchLocation: dispatchLocation,
    );

    try {
      await AppServices.instance.repository.updateReliefTeam(updatedTeam);

      if (!mounted) return;

      setState(_loadTeams);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${team.name} dispatched to $dispatchLocation.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to dispatch team: $e')));
    }
  }

  Future<void> _findAndDispatchTeam() async {
    String? selectedArea;
    String currentLocation = '';

    final currentLocationController = TextEditingController();

    final selectedTeam = await showDialog<ReliefTeam>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Find & Dispatch Team'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedArea,
                      decoration: const InputDecoration(
                        labelText: 'Response area',
                        hintText: 'Select a response area',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      items: _responseAreas
                          .map(
                            (area) => DropdownMenuItem<String>(
                              value: area,
                              child: Text(area),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedArea = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: currentLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Current location (optional)',
                        hintText: 'e.g. Kelaniya',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.my_location),
                      ),
                      onChanged: (value) {
                        currentLocation = value.trim();
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selectedArea == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Select a response area.'),
                        ),
                      );
                      return;
                    }

                    final teams = await AppServices.instance.repository
                        .getReliefTeams();

                    final availableTeams = teams.where((team) {
                      return team.status == 'Available' &&
                          team.responseArea == selectedArea;
                    }).toList();

                    if (availableTeams.isEmpty) {
                      if (!dialogContext.mounted) return;

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No available teams found in this response area.',
                          ),
                        ),
                      );
                      return;
                    }

                    List<ReliefTeam> matchingTeams = availableTeams;

                    if (currentLocation.isNotEmpty) {
                      final locationMatches = availableTeams.where((team) {
                        return team.currentLocation.toLowerCase() ==
                            currentLocation.toLowerCase();
                      }).toList();

                      if (locationMatches.isNotEmpty) {
                        matchingTeams = locationMatches;
                      }
                    }

                    if (!dialogContext.mounted) return;

                    final team = await showDialog<ReliefTeam>(
                      context: dialogContext,
                      builder: (teamDialogContext) {
                        return AlertDialog(
                          title: const Text('Select response team'),
                          content: SizedBox(
                            width: 500,
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: matchingTeams.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final team = matchingTeams[index];

                                return ListTile(
                                  leading: CircleAvatar(
                                    child: const Icon(Icons.groups_outlined),
                                  ),
                                  title: Text(
                                    team.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Lead: ${team.lead}\n'
                                    'Current location: '
                                    '${team.currentLocation.isEmpty ? 'Not provided' : team.currentLocation}',
                                  ),
                                  isThreeLine: true,
                                  onTap: () {
                                    Navigator.pop(teamDialogContext, team);
                                  },
                                );
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(teamDialogContext),
                              child: const Text('Cancel'),
                            ),
                          ],
                        );
                      },
                    );

                    if (team != null && dialogContext.mounted) {
                      Navigator.pop(dialogContext, team);
                    }
                  },
                  child: const Text('Find Team'),
                ),
              ],
            );
          },
        );
      },
    );

    currentLocationController.dispose();

    if (selectedTeam == null || !mounted) return;

    final dispatchLocationController = TextEditingController();

    final dispatchLocation = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Dispatch ${selectedTeam.name}'),
          content: TextFormField(
            controller: dispatchLocationController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Dispatch location',
              hintText: 'e.g. Sedawatta M.V.',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final location = dispatchLocationController.text.trim();

                if (location.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Enter a dispatch location.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, location);
              },
              child: const Text('Dispatch'),
            ),
          ],
        );
      },
    );

    dispatchLocationController.dispose();

    if (dispatchLocation == null || dispatchLocation.isEmpty || !mounted) {
      return;
    }

    final updatedTeam = ReliefTeam(
      id: selectedTeam.id,
      name: selectedTeam.name,
      lead: selectedTeam.lead,
      members: selectedTeam.members,
      responseArea: selectedTeam.responseArea,
      status: 'Dispatched',
      currentLocation: selectedTeam.currentLocation,
      dispatchLocation: dispatchLocation,
    );

    try {
      await AppServices.instance.repository.updateReliefTeam(updatedTeam);

      if (!mounted) return;

      setState(_loadTeams);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team notified of dispatch.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to dispatch team: $e')));
    }
  }

  Future<void> _changeTeamStatus(ReliefTeam team) async {
    const statuses = [
      'Available',
      'Dispatched',
      'En route',
      'On site',
      'Completed',
    ];

    final selectedStatus = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Change team status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              ...statuses.map((status) {
                return ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 14,
                    color: _statusColor(status),
                  ),
                  title: Text(status),
                  trailing: status == team.status
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext, status);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selectedStatus == null || selectedStatus == team.status) {
      return;
    }

    final updatedTeam = ReliefTeam(
      id: team.id,
      name: team.name,
      lead: team.lead,
      members: team.members,
      responseArea: team.responseArea,
      status: selectedStatus,
      currentLocation: team.currentLocation,

      // Clear the dispatch location when the team becomes available.
      dispatchLocation: selectedStatus == 'Available'
          ? ''
          : team.dispatchLocation,
    );

    try {
      await AppServices.instance.repository.updateReliefTeam(updatedTeam);

      if (!mounted) return;

      setState(_loadTeams);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${team.name} status changed to $selectedStatus.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update team status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OfficerCoordinationScaffold(
      currentIndex: 2,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _findAndDispatchTeam,
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('Find & Dispatch'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Response teams',
              subtitle: 'Field assignments',
              onBack: () => context.go('/officer/home'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _addTeam,
                  icon: const Icon(Icons.add),
                  label: const Text('Add response team'),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ReliefTeam>>(
                future: _teamsFuture,
                builder: (context, teamSnapshot) {
                  if (teamSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (teamSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'Unable to load response teams.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final teams = teamSnapshot.data ?? [];

                  if (teams.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        children: const [
                          SizedBox(height: 100),
                          Icon(Icons.groups_outlined, size: 56),
                          SizedBox(height: 12),
                          Center(
                            child: Text('No response teams registered yet.'),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: teams.length,
                      itemBuilder: (context, index) {
                        final team = teams[index];

                        return _TeamCard(
                          team: team,
                          onEdit: () => _editTeam(team),
                          onDelete: () => _deleteTeam(team),
                          onDispatch: () => _dispatchTeam(team),
                          onStatusChange: () => _changeTeamStatus(team),
                        );
                      },
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

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.onEdit,
    required this.onDelete,
    required this.onDispatch,
    required this.onStatusChange,
  });

  final ReliefTeam team;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDispatch;
  final VoidCallback onStatusChange;

  bool get isAvailable => team.status == 'Available';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    team.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit team',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete team',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Team ID: ${team.id}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Team lead',
              value: team.lead,
            ),
            _InfoRow(
              icon: Icons.groups_outlined,
              label: 'Members',
              value: '${team.members.length} members',
            ),
            _InfoRow(
              icon: Icons.location_city_outlined,
              label: 'Response area',
              value: team.responseArea.isEmpty
                  ? 'Not provided'
                  : team.responseArea,
            ),
            _InfoRow(
              icon: Icons.my_location,
              label: 'Current location',
              value: team.currentLocation.isEmpty
                  ? 'Not provided'
                  : team.currentLocation,
            ),
            if (!isAvailable && team.dispatchLocation.isNotEmpty)
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Dispatch location',
                value: team.dispatchLocation,
              ),
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(
                left: 4,
                right: 4,
                bottom: 8,
              ),
              title: Text(
                'Team members (${team.members.length})',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              children: [
                if (team.members.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('No members added.'),
                    ),
                  )
                else
                  ...team.members.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 17),
                          const SizedBox(width: 8),
                          Expanded(child: Text(member)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (isAvailable) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDispatch,
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Dispatch'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                const Text(
                  'Status:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onStatusChange,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(team.status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor(team.status)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _statusColor(team.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          team.status,
                          style: TextStyle(
                            color: _statusColor(team.status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: _statusColor(team.status),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 9),
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TeamDialog extends StatefulWidget {
  const _TeamDialog({this.team});

  final ReliefTeam? team;

  @override
  State<_TeamDialog> createState() => _TeamDialogState();
}

class _TeamDialogState extends State<_TeamDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _leadController;
  late final TextEditingController _currentLocationController;

  late List<TextEditingController> _memberControllers;

  String? _selectedResponseArea;
  String _status = 'Available';

  final List<String> _statuses = const [
    'Available',
    'Dispatched',
    'En route',
    'On site',
    'Completed',
  ];

  bool get _isEditing => widget.team != null;

  @override
  void initState() {
    super.initState();

    final team = widget.team;

    _idController = TextEditingController(text: team?.id ?? '');

    _nameController = TextEditingController(text: team?.name ?? '');

    _leadController = TextEditingController(text: team?.lead ?? '');

    _currentLocationController = TextEditingController(
      text: team?.currentLocation ?? '',
    );

    _selectedResponseArea = team?.responseArea.isEmpty == true
        ? null
        : team?.responseArea;

    _status = team?.status ?? 'Available';

    if (!_statuses.contains(_status)) {
      _status = 'Available';
    }

    _memberControllers = [
      for (final member in team?.members ?? const <String>[])
        TextEditingController(text: member),
    ];
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _leadController.dispose();
    _currentLocationController.dispose();

    for (final controller in _memberControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _addMember() {
    setState(() {
      _memberControllers.add(TextEditingController());
    });
  }

  void _removeMember(int index) {
    final controller = _memberControllers.removeAt(index);
    controller.dispose();

    setState(() {});
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final members = _memberControllers
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    final team = ReliefTeam(
      id: _idController.text.trim(),
      name: _nameController.text.trim(),
      lead: _leadController.text.trim(),
      members: members,
      responseArea: _selectedResponseArea ?? '',
      status: _status,
      currentLocation: _currentLocationController.text.trim(),
      dispatchLocation: widget.team?.dispatchLocation ?? '',
    );

    Navigator.of(context).pop(team);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit response team' : 'Add response team'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _idController,
                  enabled: !_isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Team ID',
                    hintText: 'e.g. RT-20',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a team ID';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Team name',
                    hintText: 'e.g. Colombo Response Unit',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a team name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _leadController,
                  decoration: const InputDecoration(
                    labelText: 'Team lead',
                    hintText: 'e.g. Officer Nimal',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter the team lead';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: _statuses
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _status = value;
                    });
                  },
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _selectedResponseArea,
                  decoration: const InputDecoration(
                    labelText: 'Response area',
                    hintText: 'Select a response area',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: _responseAreas
                      .map(
                        (area) => DropdownMenuItem<String>(
                          value: area,
                          child: Text(area),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedResponseArea = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Select a response area';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _currentLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Current location',
                    hintText: 'e.g. Kolonnawa',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.my_location),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Team members',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addMember,
                      icon: const Icon(Icons.add),
                      label: const Text('Add member'),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                if (_memberControllers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('No members added yet.'),
                  ),

                ...List.generate(_memberControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _memberControllers[index],
                            decoration: InputDecoration(
                              labelText: 'Member ${index + 1}',
                              hintText: 'Enter member name',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove member',
                          onPressed: () => _removeMember(index),
                          icon: const Icon(Icons.remove_circle_outline),
                          color: Colors.red,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Save changes' : 'Add team'),
        ),
      ],
    );
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'available':
      return const Color(0xFF16A34A);

    case 'dispatched':
      return const Color(0xFF2563EB);

    case 'en route':
      return const Color(0xFFF59E0B);

    case 'on site':
      return const Color(0xFF7C3AED);

    case 'completed':
      return const Color(0xFF64748B);

    default:
      return const Color(0xFF64748B);
  }
}
