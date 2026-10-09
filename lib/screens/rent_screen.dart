import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/app_shimmer.dart';

class RentScreen extends StatefulWidget {
  const RentScreen({super.key});

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  bool _showBills = false;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime get _currentMonth => DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _getEarliestPaymentMonth(List<Payment> payments) {
    if (payments.isEmpty) return _currentMonth;
    DateTime earliest = payments.first.date;
    for (final p in payments) {
      if (p.date.isBefore(earliest)) {
        earliest = p.date;
      }
    }
    return DateTime(earliest.year, earliest.month, 1);
  }

  void _prevMonth(DateTime earliestMonth) {
    final prev = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    if (!prev.isBefore(earliestMonth)) {
      setState(() {
        _selectedMonth = prev;
      });
    }
  }

  void _nextMonth() {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    if (!next.isAfter(_currentMonth)) {
      setState(() {
        _selectedMonth = next;
      });
    }
  }

  void _resetToCurrentMonth() {
    setState(() {
      _selectedMonth = _currentMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final earliestMonth = _getEarliestPaymentMonth(appProvider.currentPayments);
    final bool canGoPrev = _selectedMonth.isAfter(earliestMonth);
    final bool canGoNext = _selectedMonth.isBefore(_currentMonth);
    final bool isCurrentMonth = _selectedMonth.year == _currentMonth.year && _selectedMonth.month == _currentMonth.month;
    final selectedMonthStr = DateFormat('MMMM yyyy').format(_selectedMonth);
    final targetMonthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    // Filter payments for the selected month
    final monthPayments = appProvider.currentPayments.where((p) {
      if (p.billingMonth != null && p.billingMonth!.isNotEmpty) {
        return p.billingMonth == targetMonthKey;
      }
      return p.date.year == _selectedMonth.year && p.date.month == _selectedMonth.month;
    }).toList();

    final monthRentPayments = monthPayments.where((p) {
      final isBill = p.notes != null && p.notes!.toLowerCase().contains('bill');
      return !isBill;
    }).toList();

    final monthBillPayments = monthPayments.where((p) {
      final isBill = p.notes != null && p.notes!.toLowerCase().contains('bill');
      return isBill;
    }).toList();

    // Filter charges for the selected month
    final allMonthCharges = <Map<String, dynamic>>[];
    for (final tenant in appProvider.currentTenants) {
      for (final charge in tenant.additionalCharges) {
        if (charge.billType == 'RENT') continue;
        final chargeDate = charge.billDueDate ?? charge.date;
        if (chargeDate.year == _selectedMonth.year && chargeDate.month == _selectedMonth.month) {
          allMonthCharges.add({
            'charge': charge,
            'tenant': tenant,
          });
        }
      }
    }

    // Compute Metrics for Selected Month
    final double expectedAmount;
    final double collectedAmount;
    final double pendingAmount;
    final int paidCount;
    final int unpaidCount;

    if (!_showBills) {
      if (isCurrentMonth) {
        expectedAmount = appProvider.expectedRentOnly;
        collectedAmount = appProvider.collectedRentOnly;
        pendingAmount = appProvider.pendingRentOnly;
        paidCount = appProvider.currentTenants.where((t) => t.pendingRentAmount == 0 && t.rentAmount > 0).length;
        unpaidCount = appProvider.currentTenants.where((t) => t.pendingRentAmount > 0).length;
      } else {
        final rentExpectedRaw = appProvider.currentTenants.fold(0.0, (sum, t) {
          if (t.moveInDate.isAfter(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1))) return sum;
          return sum + t.rentAmount;
        });
        collectedAmount = monthRentPayments.fold(0.0, (sum, p) => sum + p.amount);
        expectedAmount = math.max(rentExpectedRaw, collectedAmount);
        pendingAmount = math.max(0.0, expectedAmount - collectedAmount);
        paidCount = monthRentPayments.map((p) => p.tenantId).toSet().length;
        unpaidCount = math.max(0, appProvider.currentTenants.length - paidCount);
      }
    } else {
      if (isCurrentMonth) {
        expectedAmount = appProvider.expectedBillsOnly;
        collectedAmount = appProvider.collectedBillsOnly;
        pendingAmount = appProvider.pendingBillsOnly;
        paidCount = appProvider.currentTenants.where((t) => t.totalPendingBills == 0 && t.additionalCharges.any((c) => c.billType != 'RENT')).length;
        unpaidCount = appProvider.currentTenants.where((t) => t.totalPendingBills > 0).length;
      } else {
        final billsExpectedFromCharges = allMonthCharges.fold(0.0, (sum, item) => sum + (item['charge'] as AdditionalCharge).amount);
        final billsCollectedFromPayments = monthBillPayments.fold(0.0, (sum, p) => sum + p.amount);
        final billsCollectedFromCharges = allMonthCharges.where((item) => (item['charge'] as AdditionalCharge).status == 'PAID').fold(0.0, (sum, item) => sum + (item['charge'] as AdditionalCharge).amount);
        collectedAmount = math.max(billsCollectedFromPayments, billsCollectedFromCharges);
        expectedAmount = math.max(billsExpectedFromCharges, collectedAmount);
        pendingAmount = math.max(0.0, expectedAmount - collectedAmount);
        paidCount = allMonthCharges.where((item) => (item['charge'] as AdditionalCharge).status == 'PAID').map((item) => (item['tenant'] as Tenant).id).toSet().length;
        unpaidCount = allMonthCharges.where((item) => (item['charge'] as AdditionalCharge).status == 'PENDING').map((item) => (item['tenant'] as Tenant).id).toSet().length;
      }
    }

    final double collectionRate = expectedAmount > 0
        ? ((collectedAmount / expectedAmount) * 100).clamp(0.0, 100.0)
        : 0.0;

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
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              selectedMonthStr,
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
      body: RefreshIndicator(
        onRefresh: () => appProvider.loadFromAPI(),
        color: AppTheme.primaryColor,
        child: appProvider.isLoading
            ? const RentOverviewSkeleton()
            : Scrollbar(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 120 + MediaQuery.paddingOf(context).bottom),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
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
              const SizedBox(height: 12),

              // 1.5. Month-Wise Payment History Navigation Bar
              _buildMonthNavigationBar(
                selectedMonthStr: selectedMonthStr,
                isCurrentMonth: isCurrentMonth,
                canGoPrev: canGoPrev,
                canGoNext: canGoNext,
                onPrev: () => _prevMonth(earliestMonth),
                onNext: _nextMonth,
              ),
              const SizedBox(height: 16),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: KeyedSubtree(
                  key: ValueKey<bool>(_showBills),
                  child: Column(
                    children: [
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
                          style: GoogleFonts.lato(
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
                          Builder(
                            builder: (context) {
                              final hasCollected = collectedAmount > 0;
                              final hasPending = pendingAmount > 0;
                              final List<PieChartSectionData> chartSections;

                              if (hasCollected && hasPending) {
                                chartSections = [
                                  PieChartSectionData(
                                    color: const Color(0xFF16A34A),
                                    value: collectedAmount,
                                    title: '',
                                    radius: 22,
                                  ),
                                  PieChartSectionData(
                                    color: AppTheme.danger,
                                    value: pendingAmount,
                                    title: '',
                                    radius: 22,
                                  ),
                                ];
                              } else if (hasCollected) {
                                chartSections = [
                                  PieChartSectionData(
                                    color: const Color(0xFF16A34A),
                                    value: collectedAmount,
                                    title: '',
                                    radius: 22,
                                  ),
                                ];
                              } else if (hasPending) {
                                chartSections = [
                                  PieChartSectionData(
                                    color: AppTheme.danger,
                                    value: pendingAmount,
                                    title: '',
                                    radius: 22,
                                  ),
                                ];
                              } else {
                                chartSections = [
                                  PieChartSectionData(
                                    color: const Color(0xFFE2E8F0),
                                    value: 1,
                                    title: '',
                                    radius: 18,
                                  ),
                                ];
                              }

                              return PieChart(
                                PieChartData(
                                  sectionsSpace: (hasCollected && hasPending) ? 3 : 0,
                                  centerSpaceRadius: 55,
                                  startDegreeOffset: -90,
                                  sections: chartSections,
                                ),
                              );
                            },
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
                                style: GoogleFonts.lato(
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
            const SizedBox(height: 16),

            // 5. Month Payment Records / Payment History Section
            _buildMonthPaymentHistorySection(
              selectedMonthStr: selectedMonthStr,
              payments: _showBills ? monthBillPayments : monthRentPayments,
              charges: allMonthCharges,
              isBillsTab: _showBills,
              appProvider: appProvider,
            ),
          ],
        ),
      ),
    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavigationBar({
    required String selectedMonthStr,
    required bool isCurrentMonth,
    required bool canGoPrev,
    required bool canGoNext,
    required VoidCallback? onPrev,
    required VoidCallback? onNext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: canGoPrev ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            splashRadius: 18,
            onPressed: canGoPrev ? onPrev : null,
            tooltip: canGoPrev ? 'Previous Month' : 'First Recorded Month',
          ),
          GestureDetector(
            onTap: isCurrentMonth ? null : _resetToCurrentMonth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(
                  selectedMonthStr,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isCurrentMonth ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCurrentMonth ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    isCurrentMonth ? 'Current' : 'Reset',
                    style: GoogleFonts.lato(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isCurrentMonth ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: canGoNext ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            splashRadius: 18,
            onPressed: canGoNext ? onNext : null,
            tooltip: canGoNext ? 'Next Month' : 'Current Month',
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPaymentHistorySection({
    required String selectedMonthStr,
    required List<Payment> payments,
    required List<Map<String, dynamic>> charges,
    required bool isBillsTab,
    required AppProvider appProvider,
  }) {
    final tenantMap = {for (final t in appProvider.currentTenants) t.id: t};

    return Container(
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
          // Section Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded, color: AppTheme.primaryColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment History',
                          style: GoogleFonts.lato(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          selectedMonthStr,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${payments.length} Records',
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      isBillsTab ? Icons.receipt_long_outlined : Icons.account_balance_wallet_outlined,
                      size: 38,
                      color: const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No ${isBillsTab ? "bill" : "rent"} payments recorded for $selectedMonthStr',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Collected payments in this month will appear here',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final p = payments[index];
                final tenant = tenantMap[p.tenantId];
                final tenantDisplayName = p.tenantName ?? tenant?.name ?? 'Tenant';
                final roomIdx = tenant != null ? appProvider.rooms.indexWhere((r) => r.id == tenant.roomId) : -1;
                final tenantRoomNum = roomIdx != -1 ? appProvider.rooms[roomIdx].number : '';
                final roomInfo = (p.roomNumber != null && p.roomNumber!.isNotEmpty)
                    ? 'Room ${p.roomNumber}'
                    : (tenantRoomNum.isNotEmpty ? 'Room $tenantRoomNum' : 'PG Tenant');
                final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(p.date);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                  ),
                  title: Text(
                    tenantDisplayName,
                    style: GoogleFonts.lato(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    '$roomInfo • $dateStr',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+₹${p.amount.toStringAsFixed(0)}',
                        style: GoogleFonts.lato(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.method.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: (tenant != null || p.tenantId.isNotEmpty)
                      ? () {
                          final targetId = p.tenantId.isNotEmpty ? p.tenantId : (tenant?.id ?? '');
                          if (targetId.isNotEmpty) {
                            context.push('/tenant_profile/$targetId', extra: tenant);
                          }
                        }
                      : null,
                );
              },
            ),
        ],
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '₹${amount.toStringAsFixed(0)}',
                style: GoogleFonts.lato(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
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
