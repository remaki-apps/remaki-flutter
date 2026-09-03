import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final monthYear = DateFormat('MMMM yyyy').format(DateTime.now());

    final expectedAmount = _showBills ? appProvider.expectedBillsOnly : appProvider.expectedRentOnly;
    final collectedAmount = _showBills ? appProvider.collectedBillsOnly : appProvider.collectedRentOnly;
    final pendingAmount = _showBills ? appProvider.pendingBillsOnly : appProvider.pendingRentOnly;

    final double collectionRate = expectedAmount > 0
        ? ((collectedAmount / expectedAmount) * 100).clamp(0.0, 100.0)
        : 0.0;

    final int paidCount = _showBills
        ? appProvider.tenants.where((t) => t.totalPendingBills == 0 && t.additionalCharges.any((c) => c.billType != 'RENT')).length
        : appProvider.tenants.where((t) => t.pendingRentAmount == 0 && t.rentAmount > 0).length;

    final int unpaidCount = _showBills
        ? appProvider.tenants.where((t) => t.totalPendingBills > 0).length
        : appProvider.tenants.where((t) => t.pendingRentAmount > 0).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
            Text(
              _showBills ? 'Bills Overview' : 'Rent Overview',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              monthYear,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Classic Segmented Switcher (Rent vs Bills)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildSegmentButton(
                    title: 'Monthly Rent',
                    icon: Icons.home_rounded,
                    isSelected: !_showBills,
                    onTap: () {
                      if (_showBills) setState(() => _showBills = false);
                    },
                  ),
                  _buildSegmentButton(
                    title: 'Utility Bills',
                    icon: Icons.bolt_rounded,
                    isSelected: _showBills,
                    onTap: () {
                      if (!_showBills) setState(() => _showBills = true);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Three Metric Cards (Expected, Collected, Pending)
            Row(
              children: [
                _buildMetricCard(
                  title: 'Expected',
                  amount: expectedAmount,
                  color: AppTheme.primaryColor,
                  bgColor: const Color(0xFFEEF2FF),
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  title: 'Collected',
                  amount: collectedAmount,
                  color: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFF0FDF4),
                  icon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  title: 'Pending',
                  amount: pendingAmount,
                  color: AppTheme.danger,
                  bgColor: const Color(0xFFFEF2F2),
                  icon: Icons.pending_actions_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Collection Progress & Donut Chart Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'COLLECTION PERFORMANCE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: collectionRate >= 80
                              ? const Color(0xFFDCFCE7)
                              : (collectionRate >= 50 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${collectionRate.toStringAsFixed(1)}% Collected',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: collectionRate >= 80
                                ? const Color(0xFF15803D)
                                : (collectionRate >= 50 ? const Color(0xFFB45309) : const Color(0xFFB91C1C)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Linear Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: expectedAmount > 0 ? (collectedAmount / expectedAmount).clamp(0.0, 1.0) : 0.0,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Donut Pie Chart
                  SizedBox(
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 55,
                            startDegreeOffset: -90,
                            sections: expectedAmount > 0
                                ? [
                                    PieChartSectionData(
                                      color: const Color(0xFF16A34A),
                                      value: collectedAmount > 0 ? collectedAmount : 0.001,
                                      title: '',
                                      radius: 22,
                                    ),
                                    PieChartSectionData(
                                      color: AppTheme.danger,
                                      value: pendingAmount > 0 ? pendingAmount : 0.001,
                                      title: '',
                                      radius: 22,
                                    ),
                                  ]
                                : [
                                    PieChartSectionData(
                                      color: const Color(0xFFE2E8F0),
                                      value: 1,
                                      title: '',
                                      radius: 18,
                                    ),
                                  ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _showBills ? 'Total Bills' : 'Total Rent',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${expectedAmount.toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Chart Legend Strip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildChartLegend(
                        color: const Color(0xFF16A34A),
                        label: 'Collected',
                        amount: collectedAmount,
                      ),
                      const SizedBox(width: 24),
                      _buildChartLegend(
                        color: AppTheme.danger,
                        label: 'Pending',
                        amount: pendingAmount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Breakdown Cards (Paid vs Unpaid Tenants)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Fully Paid Tile
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fully Cleared',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$paidCount tenant(s) with no pending dues',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${collectedAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // Pending Dues Tile (Clickable to jump to unpaid tenants)
                  InkWell(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    onTap: () => context.push('/unpaid_tenants?filter=${_showBills ? 'bills' : 'rent'}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pending Collection',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$unpaidCount tenant(s) pending payment',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '₹${pendingAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.danger,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. Direct Action Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.push('/unpaid_tenants?filter=${_showBills ? 'bills' : 'rent'}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _showBills ? 'View Tenants with Unpaid Bills' : 'View Tenants with Unpaid Rent',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend({
    required Color color,
    required String label,
    required double amount,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }
}
