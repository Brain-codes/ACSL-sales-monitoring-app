import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/core/widgets/kpi_card.dart';
import 'package:stove_transaction/core/widgets/offline_banner.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/widgets/update_prompt_sheet.dart';
import 'package:stove_transaction/features/dashboard/models/dashboard_model.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(DashboardController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Obx(() => DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: c.selectedYear.value,
              dropdownColor: AppColors.brandHeader,
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.expand_more, color: Colors.white),
              items: c.years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
              onChanged: (y) {
                if (y != null) {
                  c.selectedYear.value = y;
                  c.fetchStats();
                }
              },
            ),
          )),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'dashboard_create_sale',
        onPressed: () => Get.toNamed(AppRoutes.salesCreate),
        icon: const Icon(Icons.add),
        label: const Text('Create Sale'),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value) return const Center(child: CircularProgressIndicator());
              final stats = c.stats.value;
              if (stats == null) {
                return EmptyState(
                  message: 'No data available for ${c.selectedYear.value}.',
                  icon: Icons.bar_chart_outlined,
                  actionLabel: 'Retry',
                  onAction: c.fetchStats,
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  await c.fetchStats();
                  showUpdatePromptIfNeeded();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overview', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.3,
                        children: [
                          KpiCard(title: 'Stoves Received', value: '${stats.stovesReceived}', icon: Icons.inventory_2_outlined, gradient: AppColors.gradientNavy),
                          KpiCard(title: 'Stoves Sold', value: '${stats.stovesSold}', icon: Icons.sell_outlined, gradient: AppColors.gradientTeal),
                          KpiCard(title: 'Available Stoves', value: '${stats.availableStoves}', icon: Icons.local_fire_department_outlined, gradient: AppColors.gradientPurple),
                          KpiCard(title: 'Expected Receivable', value: c.fmt(stats.expectedReceivable), icon: Icons.account_balance_outlined, gradient: AppColors.gradientGold),
                          KpiCard(title: 'Amount Received', value: c.fmt(stats.amountReceived), icon: Icons.payments_outlined, gradient: AppColors.gradientGreen),
                          KpiCard(title: 'Outstanding Balance', value: c.fmt(stats.outstandingBalance), icon: Icons.warning_amber_outlined, gradient: AppColors.gradientRed),
                        ],
                      ),
                      if (!Get.find<SessionManager>().isAcslAgent && stats.salesByState.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _ChartCard(title: 'Sales by State', child: _BarChart(data: stats.salesByState)),
                      ],
                      if (!Get.find<SessionManager>().isAcslAgent && stats.salesByModel.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ChartCard(title: 'Sales by Model', child: _PieChart(data: stats.salesByModel)),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<SalesByState> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.map((d) => d.count.toDouble()).fold(0.0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.2,
          barGroups: data.asMap().entries.map((e) => BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(toY: e.value.count.toDouble(), color: AppColors.brandPrimary, width: 16, borderRadius: BorderRadius.circular(4)),
            ],
          )).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  final label = data[i].state;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label.length > 6 ? label.substring(0, 6) : label, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  final List<SalesByModel> data;
  const _PieChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: PieChart(PieChartData(
              sections: data.asMap().entries.map((e) {
                final color = AppColors.chartColors[e.key % AppColors.chartColors.length];
                return PieChartSectionData(
                  value: e.value.count.toDouble(),
                  color: color,
                  radius: 60,
                  title: '${e.value.count}',
                  titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                );
              }).toList(),
              centerSpaceRadius: 0,
            )),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.asMap().entries.map((e) {
              final color = AppColors.chartColors[e.key % AppColors.chartColors.length];
              final label = e.value.modelName;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text(label.length > 14 ? '${label.substring(0, 14)}…' : label, style: const TextStyle(fontSize: 11)),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
