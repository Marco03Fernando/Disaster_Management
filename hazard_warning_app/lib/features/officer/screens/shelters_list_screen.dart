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
      currentIndex: 0,
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: shelters.length,
                itemBuilder: (context, index) {
                  final shelter = shelters[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(shelter.name),
                      subtitle: Text(
                        '${shelter.occupancy} / ${shelter.capacity} occupants',
                      ),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (shelter.isOverCapacity)
                            const StatusBadge(
                              label: 'Over capacity',
                              color: AppColors.severityHigh,
                            ),

                          IconButton(
                            tooltip: 'Edit shelter',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              _showEditShelterDialog(context, shelter);
                            },
                          ),

                          IconButton(
                            tooltip: 'Delete shelter',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              _confirmDeleteShelter(context, shelter);
                            },
                          ),
                        ],
                      ),

                      onTap: () =>
                          context.push('/officer/shelters/${shelter.id}'),
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

  // Prevent an invalid self-reference.
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
                    decoration: const InputDecoration(
                      labelText: 'District',
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacity',
                    ),
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
                onPressed: saving
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),

              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final capacity =
                            int.tryParse(capacityController.text.trim());

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

                        await context
                            .read<AppState>()
                            .updateShelter(updatedShelter);

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Shelter updated'),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
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
        content: Text(
          'Are you sure you want to delete "${shelter.name}"?',
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shelter deleted'),
      ),
    );
  }
}