import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/officer/widgets/officer_coordination_scaffold.dart';
import 'package:intl/intl.dart';

class ReliefDistributionScreen extends StatefulWidget {
  const ReliefDistributionScreen({super.key});

  @override
  State<ReliefDistributionScreen> createState() =>
      _ReliefDistributionScreenState();
}

class _ReliefDistributionScreenState
    extends State<ReliefDistributionScreen> {
  late Future<List<ReliefStock>> _stockFuture;

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  void _loadStock() {
    _stockFuture = AppServices.instance.repository.getReliefStock();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadStock();
    });

    await _stockFuture;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();

    return OfficerCoordinationScaffold(
      currentIndex: 3,
      body: SafeArea(
        child: FutureBuilder<List<ReliefStock>>(
          future: _stockFuture,
          builder: (context, snapshot) {
            final stock = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(
                  title: 'Relief stock',
                  subtitle: 'Distribution by district',
                  onBack: () => context.go('/officer/home'),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showAddStockDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Relief Stock'),
                    ),
                  ),
                ),

                Expanded(
                  child: stock.isEmpty
                      ? const Center(
                          child: Text('No relief stock records'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: stock.length,
                          itemBuilder: (context, index) {
                            final row = stock[index];

                            return Card(
                              margin:
                                  const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            row.district,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),

                                        IconButton(
                                          tooltip: 'Edit stock',
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                          ),
                                          onPressed: () {
                                            _showEditStockDialog(
                                              context,
                                              row,
                                            );
                                          },
                                        ),

                                        IconButton(
                                          tooltip: 'Delete stock',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () {
                                            _confirmDeleteStock(
                                              context,
                                              row,
                                            );
                                          },
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    ...row.items.entries.map(
                                      (item) => _StockRow(
                                        label: item.key,
                                        value: fmt.format(item.value),
                                        color: _stockColor(item.key),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddStockDialog(BuildContext context) async {
    final districtController = TextEditingController();

    final itemControllers = <String, TextEditingController>{
      'Food': TextEditingController(),
      'Water': TextEditingController(),
      'Medicine': TextEditingController(),
    };

    await _showStockDialog(
      context: context,
      title: 'Add Relief Stock',
      districtController: districtController,
      itemControllers: itemControllers,
      isEditing: false,
    );

    districtController.dispose();

    for (final controller in itemControllers.values) {
      controller.dispose();
    }

    await _refresh();
  }

  Future<void> _showEditStockDialog(
    BuildContext context,
    ReliefStock stock,
  ) async {
    final districtController =
        TextEditingController(text: stock.district);

    final itemControllers = <String, TextEditingController>{
      for (final entry in stock.items.entries)
        entry.key: TextEditingController(
          text: entry.value.toString(),
        ),
    };

    await _showStockDialog(
      context: context,
      title: 'Edit Relief Stock',
      districtController: districtController,
      itemControllers: itemControllers,
      isEditing: true,
    );

    districtController.dispose();

    for (final controller in itemControllers.values) {
      controller.dispose();
    }

    await _refresh();
  }

  Future<void> _showStockDialog({
    required BuildContext context,
    required String title,
    required TextEditingController districtController,
    required Map<String, TextEditingController> itemControllers,
    required bool isEditing,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> save() async {
              final district =
                  districtController.text.trim();

              if (district.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a district.'),
                  ),
                );
                return;
              }

              final items = <String, int>{};

              for (final entry in itemControllers.entries) {
                final name = entry.key.trim();
                final quantity =
                    int.tryParse(entry.value.text.trim());

                if (name.isEmpty || quantity == null || quantity < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter valid stock quantities.',
                      ),
                    ),
                  );
                  return;
                }

                items[name] = quantity;
              }

              if (items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Add at least one stock type.',
                    ),
                  ),
                );
                return;
              }

              final repository =
                  AppServices.instance.repository;

              final stock = ReliefStock(
                district: district,
                items: items,
              );

              setState(() {
                saving = true;
              });

              try {
                if (isEditing) {
                  await repository.updateReliefStock(stock);
                } else {
                  final existing =
                      await repository.getReliefStock();

                  final alreadyExists = existing.any(
                    (item) =>
                        item.district.toLowerCase() ==
                        district.toLowerCase(),
                  );

                  if (alreadyExists) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'A stock record for this district already exists.',
                          ),
                        ),
                      );
                    }

                    setState(() {
                      saving = false;
                    });

                    return;
                  }

                  await repository.addReliefStock(stock);
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (e) {
                setState(() {
                  saving = false;
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not save stock: $e',
                      ),
                    ),
                  );
                }
              }
            }

            void addCustomItem() {
              String itemName = '';
              final nameController = TextEditingController();
              final quantityController = TextEditingController();

              showDialog(
                context: context,
                builder: (customDialogContext) {
                  return AlertDialog(
                    title: const Text('Add stock type'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Stock type',
                            hintText: 'e.g. Blankets',
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(customDialogContext);
                        },
                        child: const Text('Cancel'),
                      ),

                      FilledButton(
                        onPressed: () {
                          itemName =
                              nameController.text.trim();

                          final quantity = int.tryParse(
                            quantityController.text.trim(),
                          );

                          if (itemName.isEmpty ||
                              quantity == null ||
                              quantity < 0) {
                            return;
                          }

                          if (itemControllers.containsKey(
                            itemName,
                          )) {
                            return;
                          }

                          setState(() {
                            itemControllers[itemName] =
                                TextEditingController(
                              text: quantity.toString(),
                            );
                          });

                          Navigator.pop(customDialogContext);
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  );
                },
              ).then((_) {
                nameController.dispose();
                quantityController.dispose();
              });
            }

            void removeItem(String name) {
              if (itemControllers.length <= 1) {
                return;
              }

              final controller =
                  itemControllers.remove(name);

              controller?.dispose();

              setState(() {});
            }

            return AlertDialog(
              title: Text(title),

              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: districtController,
                        enabled: !isEditing,
                        decoration: InputDecoration(
                          labelText: 'District',
                          helperText: isEditing
                              ? 'District cannot be changed'
                              : null,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Stock items',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall,
                        ),
                      ),

                      const SizedBox(height: 8),

                      ...itemControllers.entries.map(
                        (entry) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry.key,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: TextField(
                                  controller: entry.value,
                                  keyboardType:
                                      TextInputType.number,
                                  decoration:
                                      const InputDecoration(
                                    labelText: 'Quantity',
                                  ),
                                ),
                              ),

                              if (![
                                'Food',
                                'Water',
                                'Medicine',
                              ].contains(entry.key))
                                IconButton(
                                  tooltip: 'Remove stock type',
                                  icon: const Icon(
                                    Icons.close,
                                  ),
                                  onPressed: () {
                                    removeItem(entry.key);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      OutlinedButton.icon(
                        onPressed: addCustomItem,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Add another stock type',
                        ),
                      ),
                    ],
                  ),
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
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEditing ? 'Save changes' : 'Add stock',
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteStock(
    BuildContext context,
    ReliefStock stock,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete stock record?'),
          content: Text(
            'Are you sure you want to delete the relief stock record for ${stock.district}?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await AppServices.instance.repository
          .deleteReliefStock(stock.district);

      await _refresh();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Relief stock deleted'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not delete stock: $e',
            ),
          ),
        );
      }
    }
  }
}

Color _stockColor(String itemName) {
  switch (itemName.toLowerCase()) {
    case 'food':
      return const Color.fromARGB(255, 245, 76, 3);

    case 'water':
      return const Color.fromARGB(255, 2, 144, 253);

    case 'medicine':
      return const Color(0xFF86EFAC);

    default:
      return const Color(0xFF64748B);
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(width: 8),

          Text(label),

          const Spacer(),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}