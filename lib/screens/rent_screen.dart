import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class RentScreen extends StatelessWidget {
  const RentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final hasRentData = appProvider.expectedRent > 0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent Overview'),
        actions: [
          IconButton(icon: const Icon(Icons.swap_horiz), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Stats
            Row(
              children: [
                _buildStatBox('Expected Rent', '₹${appProvider.expectedRent.toStringAsFixed(0)}', AppTheme.primaryColor),
                const SizedBox(width: 8),
                _buildStatBox('Collected Rent', '₹${appProvider.collectedRent.toStringAsFixed(0)}', AppTheme.success),
                const SizedBox(width: 8),
                _buildStatBox('Pending Rent', '₹${appProvider.pendingRent.toStringAsFixed(0)}', AppTheme.danger),
              ],
            ),
            const SizedBox(height: 48),

            // Pie Chart
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 70,
                      sections: hasRentData
                          ? [
                              PieChartSectionData(
                                color: AppTheme.success,
                                value: appProvider.collectedRent > 0 ? appProvider.collectedRent : 0,
                                title: '',
                                radius: 30,
                              ),
                              PieChartSectionData(
                                color: AppTheme.danger,
                                value: appProvider.pendingRent > 0 ? appProvider.pendingRent : 0,
                                title: '',
                                radius: 30,
                              ),
                            ]
                          : [
                              PieChartSectionData(
                                color: Colors.grey.shade300,
                                value: 1,
                                title: '',
                                radius: 30,
                              )
                            ],
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Total Expected', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        Text('₹${appProvider.expectedRent.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Legend
            _buildLegendItem('Paid', appProvider.tenants.where((t) => t.totalDue == 0).length, appProvider.collectedRent, AppTheme.success),
            _buildLegendItem('Unpaid', appProvider.tenants.where((t) => t.totalDue > 0).length, appProvider.pendingRent, AppTheme.danger),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/unpaid_tenants'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: const Text('View Unpaid Tenants'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('$label ($count)'),
            ],
          ),
          Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
