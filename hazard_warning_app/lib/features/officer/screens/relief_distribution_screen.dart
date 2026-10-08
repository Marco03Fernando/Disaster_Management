import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/officer/widgets/officer_coordination_scaffold.dart';
import 'package:intl/intl.dart';

class ReliefDistributionScreen extends StatelessWidget {
  const ReliefDistributionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();

    return OfficerCoordinationScaffold(
      currentIndex: 2,
      body: SafeArea(
        child: FutureBuilder<List<ReliefStock>>(
          future: AppServices.instance.repository.getReliefStock(),
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
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: stock.length,
                    itemBuilder: (context, index) {
                      final row = stock[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.district,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              _StockRow(
                                label: 'Food',
                                value: fmt.format(row.foodUnits),
                                color: const Color(0xFF166534),
                              ),
                              _StockRow(
                                label: 'Water',
                                value: fmt.format(row.waterUnits),
                                color: const Color(0xFF16A34A),
                              ),
                              _StockRow(
                                label: 'Medicine',
                                value: fmt.format(row.medicineUnits),
                                color: const Color(0xFF86EFAC),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
