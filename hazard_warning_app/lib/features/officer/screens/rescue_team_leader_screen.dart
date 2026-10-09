import 'package:flutter/material.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:go_router/go_router.dart';

class RescueTeamLeaderScreen extends StatefulWidget {
  const RescueTeamLeaderScreen({super.key});

  @override
  State<RescueTeamLeaderScreen> createState() => _RescueTeamLeaderScreenState();
}

class _RescueTeamLeaderScreenState extends State<RescueTeamLeaderScreen> {
  // CHANGE THIS to the document ID of the team in Firebase.
  static const String assignedTeamId = 'RB-26';

  late Future<ReliefTeam?> _teamFuture;
  bool _updatingStatus = false;

  static const List<String> _statuses = [
    'Dispatched',
    'En route',
    'On site',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _teamFuture = _loadAssignedTeam();
  }

  Future<ReliefTeam?> _loadAssignedTeam() async {
    final teams = await AppServices.instance.repository.getReliefTeams();

    for (final team in teams) {
      if (team.id == assignedTeamId) {
        return team;
      }
    }

    return null;
  }

  Future<void> _refreshTeam() async {
    setState(() {
      _teamFuture = _loadAssignedTeam();
    });

    await _teamFuture;
  }

  Future<void> _changeStatus(ReliefTeam team) async {
    final selectedStatus = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Update Team Status',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
            ..._statuses.map(
              (status) => ListTile(
                leading: Icon(
                  Icons.circle,
                  size: 14,
                  color: _statusColor(status),
                ),
                title: Text(status),
                trailing: status == team.status
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheetContext, status),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selectedStatus == null || selectedStatus == team.status || !mounted) {
      return;
    }

    setState(() => _updatingStatus = true);

    final updatedTeam = ReliefTeam(
      id: team.id,
      name: team.name,
      lead: team.lead,
      members: team.members,
      responseArea: team.responseArea,
      status: selectedStatus,
      currentLocation: team.currentLocation,
      dispatchLocation: team.dispatchLocation,
    );

    try {
      await AppServices.instance.repository.updateReliefTeam(updatedTeam);

      if (!mounted) return;

      setState(() {
        _teamFuture = Future.value(updatedTeam);
        _updatingStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Team status updated to $selectedStatus.')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _updatingStatus = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not update status: $e')));
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
        return Colors.grey;
    }
  }

  Widget _detail(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeam(ReliefTeam team) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (['Dispatched', 'En route', 'On site'].contains(team.status))
          Card(
            color: const Color(0xFFFEE2E2),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notification_important,
                    color: Color(0xFFDC2626),
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTIVE RESCUE ASSIGNMENT',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your team is ${team.status.toLowerCase()}.',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          team.dispatchLocation.isEmpty
                              ? 'Check with the duty officer for the dispatch location.'
                              : 'Dispatch location: ${team.dispatchLocation}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.groups, size: 30),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'My Assigned Rescue Team',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  team.name,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Team ID: ${team.id}'),
                const Divider(height: 28),
                _detail('Team Leader', team.lead, Icons.person),
                _detail(
                  'Response Area',
                  team.responseArea,
                  Icons.location_on_outlined,
                ),
                _detail(
                  'Current Location',
                  team.currentLocation,
                  Icons.my_location,
                ),
                _detail(
                  'Dispatch Location',
                  team.dispatchLocation,
                  Icons.flag_outlined,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Team Members',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (team.members.isEmpty)
                  const Text('No team members listed.')
                else
                  ...team.members.map(
                    (member) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(member),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operational Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(team.status).withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    team.status,
                    style: TextStyle(
                      color: _statusColor(team.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _updatingStatus
                        ? null
                        : () => _changeStatus(team),
                    icon: const Icon(Icons.sync),
                    label: Text(
                      _updatingStatus ? 'Updating...' : 'Update Team Status',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Update the team status as the rescue operation progresses.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to role selection',
          onPressed: () => context.go('/'),
        ),
        title: const Text('Rescue Team Leader'),
        actions: [
          IconButton(
            onPressed: _refreshTeam,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh team',
          ),
        ],
      ),
      body: FutureBuilder<ReliefTeam?>(
        future: _teamFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text('Failed to load the assigned team.'),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refreshTeam,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final team = snapshot.data;

          if (team == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_outlined, size: 50),
                    const SizedBox(height: 12),
                    const Text(
                      'Team not found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check assignedTeamId in the code and make sure it '
                      'matches a document ID in the relief_teams collection.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refreshTeam,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _buildTeam(team);
        },
      ),
    );
  }
}
