import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/models/models.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class PostEventReportScreen extends StatelessWidget {
  const PostEventReportScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PostEventReport?>(
      future: AppServices.instance.repository.getPostEventReport(reportId),
      builder: (context, snapshot) {
        final report = snapshot.data;
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
        return _PostEventBody(report: report);
      },
    );
  }
}

class _PostEventBody extends StatelessWidget {
  const _PostEventBody({required this.report});

  final PostEventReport report;

  @override
  Widget build(BuildContext context) {
    final dayFmt = DateFormat('d MMM');
    final countFmt = NumberFormat.decimalPattern();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  ScreenHeader(
                    title: 'Post-event report',
                    subtitle: report.subtitle,
                    onBack: () => context.pop(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        _FilterChip(label: 'All hazards'),
                        _FilterChip(label: '${report.districtCount} districts'),
                      ],
                    ),
                  ),
                  if (report.hasIncompleteData) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warningBanner,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.warningText,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${report.incompleteRangeLabel}: incomplete data. Field records did not sync for that period. Figures below are partial, not omitted.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.warningText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: 'Alert timeline',
                    trailing: '${report.alertCount} alerts',
                    child: SizedBox(
                      height: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (final date in report.alertTimeline)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: date.day == 13
                                        ? AppColors.severityHigh
                                        : AppColors.accentBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  dayFmt.format(date),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  _ChartCard(
                    title: 'Citizens reached',
                    trailing: countFmt.format(report.citizensReached),
                    child: SizedBox(
                      height: 160,
                      child: BarChart(
                        BarChartData(
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          barGroups: [
                            for (var i = 0; i < report.reachByDay.length; i++)
                              BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: report.reachByDay[i].count / 1000,
                                    width: 10,
                                    color: report.reachByDay[i].partial
                                        ? AppColors.lightBlueChip
                                        : AppColors.accentBlue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _ChartCard(
                    title: 'Shelter occupancy over time',
                    trailing:
                        'peak ${countFmt.format(report.peakShelterOccupancy)}',
                    child: SizedBox(
                      height: 160,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              color: AppColors.successGreen,
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              spots: [
                                for (
                                  var i = 0;
                                  i < report.shelterSeries.length;
                                  i++
                                )
                                  FlSpot(
                                    i.toDouble(),
                                    report.shelterSeries[i].occupancy / 100,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _ChartCard(
                    title: 'Resource distribution',
                    trailing: '${report.districtCount} districts',
                    child: SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 ||
                                      idx >=
                                          report.resourcesByDistrict.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      report.resourcesByDistrict[idx].district,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          barGroups: [
                            for (
                              var i = 0;
                              i < report.resourcesByDistrict.length;
                              i++
                            )
                              BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY:
                                        report
                                            .resourcesByDistrict[i]
                                            .foodUnits /
                                        1000,
                                    width: 8,
                                    color: const Color(0xFF166534),
                                  ),
                                  BarChartRodData(
                                    toY:
                                        report
                                            .resourcesByDistrict[i]
                                            .waterUnits /
                                        1000,
                                    width: 8,
                                    color: const Color(0xFF16A34A),
                                  ),
                                  BarChartRodData(
                                    toY:
                                        report
                                            .resourcesByDistrict[i]
                                            .medicineUnits /
                                        1000,
                                    width: 8,
                                    color: const Color(0xFF86EFAC),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Export prepared (demo)'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Share.share(
                        '${report.title}\n${report.subtitle}\nCitizens reached: ${report.citizensReached}',
                      ),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.trailing,
    required this.child,
  });

  final String title;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(trailing, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderGrey),
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Icon(Icons.expand_more, size: 18),
        ],
      ),
    );
  }
}
