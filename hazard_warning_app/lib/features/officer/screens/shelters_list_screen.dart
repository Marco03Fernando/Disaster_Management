import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/officer/widgets/officer_coordination_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:hazard_warning_app/core/models/models.dart';

class SheltersListScreen extends StatelessWidget {
  const SheltersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shelters = context.watch<AppState>().shelters;

    return OfficerCoordinationScaffold(
      currentIndex: 1,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Shelters',
              subtitle: 'Occupancy and redirection',
              onBack: () => context.go('/officer/home'),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showRegisterShelterDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Register Shelter'),
                ),
              ),
            ),

            Expanded(
              child: shelters.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.home_work_outlined, size: 56),
                            SizedBox(height: 12),
                            Text(
                              'No shelters registered yet.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Register a shelter to start managing occupancy.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: shelters.length,
                      itemBuilder: (context, index) {
                        final shelter = shelters[index];

                        return _ShelterCard(
                          shelter: shelter,
                          onEdit: () {
                            _showEditShelterDialog(context, shelter);
                          },
                          onDelete: () {
                            _confirmDeleteShelter(context, shelter);
                          },
                          onTap: () {
                            context.push('/officer/shelters/${shelter.id}');
                          },
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

class _ShelterCard extends StatelessWidget {
  const _ShelterCard({
    required this.shelter,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  final Shelter shelter;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  double get fillRatio {
    if (shelter.capacity <= 0) return 0;

    return (shelter.occupancy / shelter.capacity).clamp(0.0, 1.0).toDouble();
  }

  Color get occupancyColor {
    if (shelter.isOverCapacity) {
      return AppColors.severityHigh;
    }

    if (fillRatio >= 0.8) {
      return const Color(0xFFF59E0B);
    }

    return const Color(0xFF16A34A);
  }

  String get occupancyLabel {
    if (shelter.isOverCapacity) {
      return 'Over capacity';
    }

    if (fillRatio >= 0.8) {
      return 'Nearly full';
    }

    return 'Available capacity';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.lightBlueChip,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.home_work_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shelter.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          shelter.district,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit shelter',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete shelter',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Occupancy section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: occupancyColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: occupancyColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 19,
                          color: occupancyColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Occupancy',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          '${shelter.occupancy} / ${shelter.capacity}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: occupancyColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 9),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: fillRatio,
                        minHeight: 8,
                        backgroundColor: occupancyColor.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          occupancyColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text(
                          occupancyLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: occupancyColor,
                          ),
                        ),
                        const Spacer(),
                        if (shelter.isOverCapacity)
                          StatusBadge(
                            label: 'Over capacity',
                            color: AppColors.severityHigh,
                          )
                        else
                          Text(
                            '${shelter.capacity - shelter.occupancy} spaces remaining',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 13),

              // Address
              _ShelterInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: shelter.address,
              ),

              // Alternative shelter
              if (shelter.nearestAlternativeId != null)
                _ShelterInfoRow(
                  icon: Icons.alt_route_outlined,
                  label: 'Alternative',
                  value: _getAlternativeShelterName(
                    context,
                    shelter.nearestAlternativeId!,
                  ),
                ),

              const SizedBox(height: 5),

              // Tap hint
              Row(
                children: [
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 13,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'View shelter details',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAlternativeShelterName(
    BuildContext context,
    String alternativeId,
  ) {
    final shelters = context.read<AppState>().shelters;

    final alternative = shelters.firstWhere(
      (shelter) => shelter.id == alternativeId,
      orElse: () => Shelter(
        id: '',
        name: 'Alternative shelter',
        district: '',
        address: '',
        capacity: 0,
        occupancy: 0,
      ),
    );

    return alternative.name.isEmpty ? 'Alternative shelter' : alternative.name;
  }
}

class _ShelterInfoRow extends StatelessWidget {
  const _ShelterInfoRow({
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
            width: 85,
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

Future<void> _showRegisterShelterDialog(BuildContext context) async {
  final nameController = TextEditingController();
  final districtController = TextEditingController();
  final addressController = TextEditingController();
  final capacityController = TextEditingController();

  String? nearestAlternativeId;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      bool saving = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Register Shelter'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Shelter name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: districtController,
                    decoration: const InputDecoration(labelText: 'District'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Location / address',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Capacity'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: nearestAlternativeId,
                    decoration: const InputDecoration(
                      labelText: 'Nearest alternative shelter',
                    ),
                    items: [
                      ...context.read<AppState>().shelters.map(
                        (shelter) => DropdownMenuItem<String>(
                          value: shelter.id,
                          child: Text(shelter.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        nearestAlternativeId = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final district = districtController.text.trim();
                        final address = addressController.text.trim();
                        final capacity = int.tryParse(
                          capacityController.text.trim(),
                        );

                        if (name.isEmpty ||
                            district.isEmpty ||
                            address.isEmpty ||
                            capacity == null ||
                            capacity <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter valid shelter details.',
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() => saving = true);

                        await context.read<AppState>().registerShelter(
                          name: name,
                          district: district,
                          address: address,
                          capacity: capacity,
                          nearestAlternativeId: nearestAlternativeId,
                        );

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Shelter registered successfully'),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Register'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  districtController.dispose();
  addressController.dispose();
  capacityController.dispose();
}

Future<void> _showEditShelterDialog(
  BuildContext context,
  Shelter shelter,
) async {
  final nameController = TextEditingController(text: shelter.name);
  final districtController = TextEditingController(text: shelter.district);
  final addressController = TextEditingController(text: shelter.address);
  final capacityController = TextEditingController(
    text: shelter.capacity.toString(),
  );

  String? nearestAlternativeId = shelter.nearestAlternativeId;

  final alternatives = context
      .read<AppState>()
      .shelters
      .where((s) => s.id != shelter.id)
      .toList();

  if (!alternatives.any((s) => s.id == nearestAlternativeId)) {
    nearestAlternativeId = null;
  }

  await showDialog(
    context: context,
    builder: (dialogContext) {
      bool saving = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Shelter'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Shelter name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: districtController,
                    decoration: const InputDecoration(labelText: 'District'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Capacity'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: nearestAlternativeId,
                    decoration: const InputDecoration(
                      labelText: 'Nearest alternative shelter',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...alternatives.map(
                        (s) => DropdownMenuItem<String>(
                          value: s.id,
                          child: Text(s.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        nearestAlternativeId = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final capacity = int.tryParse(
                          capacityController.text.trim(),
                        );

                        if (nameController.text.trim().isEmpty ||
                            districtController.text.trim().isEmpty ||
                            addressController.text.trim().isEmpty ||
                            capacity == null ||
                            capacity <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter valid shelter details.',
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() {
                          saving = true;
                        });

                        final updatedShelter = Shelter(
                          id: shelter.id,
                          name: nameController.text.trim(),
                          district: districtController.text.trim(),
                          address: addressController.text.trim(),
                          capacity: capacity,
                          occupancy: shelter.occupancy,
                          nearestAlternativeId: nearestAlternativeId,
                        );

                        await context.read<AppState>().updateShelter(
                          updatedShelter,
                        );

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Shelter updated')),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  districtController.dispose();
  addressController.dispose();
  capacityController.dispose();
}

Future<void> _confirmDeleteShelter(
  BuildContext context,
  Shelter shelter,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete shelter?'),
        content: Text('Are you sure you want to delete "${shelter.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  await context.read<AppState>().deleteShelter(shelter.id);

  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Shelter deleted')));
  }
}
