import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class RentScreen extends StatefulWidget {
  const RentScreen({super.key});

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  bool _showBills = false;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    final expectedAmount = _showBills ? appProvider.expectedBillsOnly : appProvider.expectedRentOnly;
    final collectedAmount = _showBills ? appProvider.collectedBillsOnly : appProvider.collectedRentOnly;
    final pendingAmount = _showBills ? appProvider.pendingBillsOnly : appProvider.pendingRentOnly;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_showBills ? 'Bills Overview' : 'Rent Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: _showBills ? 'Switch to Rent' : 'Switch to Bills',
            onPressed: () {
              setState(() {
                _showBills = !_showBills;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Stats
            Row(
              children: [
                _buildStatBox(
                  _showBills ? 'Expected Bills' : 'Expected Rent', 
                  '₹${expectedAmount.toStringAsFixed(0)}', 
                  AppTheme.primaryColor
                ),
                const SizedBox(width: 8),
                _buildStatBox(
                  _showBills ? 'Collected Bills' : 'Collected Rent', 
                  '₹${collectedAmount.toStringAsFixed(0)}', 
                  AppTheme.success
                ),
                const SizedBox(width: 8),
                _buildStatBox(
                  _showBills ? 'Pending Bills' : 'Pending Rent', 
                  '₹${pendingAmount.toStringAsFixed(0)}', 
                  AppTheme.danger
                ),
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
                      sections: expectedAmount > 0
                          ? [
                              PieChartSectionData(
                                color: AppTheme.success,
                                value: collectedAmount > 0 ? collectedAmount : 0,
                                title: collectedAmount > 0 ? '₹${collectedAmount.toStringAsFixed(0)}' : '',
                                radius: 40,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              PieChartSectionData(
                                color: AppTheme.danger,
                                value: pendingAmount > 0 ? pendingAmount : 0,
                                title: pendingAmount > 0 ? '₹${pendingAmount.toStringAsFixed(0)}' : '',
                                radius: 40,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
                        Text(_showBills ? 'Expected Bills' : 'Expected Rent', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        Text('₹${expectedAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Tenants Breakdown
            if (!_showBills) ...[
              _buildLegendItem('Fully Paid', appProvider.tenants.where((t) => t.pendingRentAmount == 0 && t.rentAmount > 0).length, collectedAmount, AppTheme.success),
              _buildLegendItem('Unpaid / Partial', appProvider.tenants.where((t) => t.pendingRentAmount > 0).length, pendingAmount, AppTheme.danger),
            ] else ...[
              _buildLegendItem('Fully Paid Bills', appProvider.tenants.where((t) => t.totalPendingBills == 0 && t.additionalCharges.any((c) => c.billType != 'RENT')).length, collectedAmount, AppTheme.success),
              _buildLegendItem('Unpaid Bills', appProvider.tenants.where((t) => t.totalPendingBills > 0).length, pendingAmount, AppTheme.danger),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/unpaid_tenants?filter=${_showBills ? 'bills' : 'rent'}'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: Text(_showBills ? 'View Tenants with Unpaid Bills' : 'View Tenants with Unpaid Rent'),
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
              Text('$label ($count tenants)'),
            ],
          ),
          Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
