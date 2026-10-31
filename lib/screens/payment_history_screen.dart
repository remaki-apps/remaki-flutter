import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/tenant_avatar.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/payment_splitup_card.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, UPI, CASH, BANK
  final Set<String> _expandedPaymentIds = {};

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
    setState(() {
      final prev = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
      if (!prev.isBefore(earliestMonth)) {
        _selectedMonth = prev;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      if (!next.isAfter(_currentMonth)) {
        _selectedMonth = next;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatPaymentDate(DateTime date) {
    final local = date.toLocal();
    if (local.hour == 0 && local.minute == 0 && local.second == 0) {
      return DateFormat('dd MMM yyyy').format(local);
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(local);
  }

  String _formatCurrency(num amount) {
    return NumberFormat('#,##,###').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final allSortedPayments = [...appProvider.currentPayments]..sort((a, b) => b.date.compareTo(a.date));
    final earliestMonth = _getEarliestPaymentMonth(allSortedPayments);
    final bool canGoPrev = _selectedMonth.isAfter(earliestMonth);
    final bool canGoNext = _selectedMonth.isBefore(_currentMonth);

    // Filter by selected month
    final sortedPayments = allSortedPayments.where((p) {
      final targetMonthStr = DateFormat('yyyy-MM').format(_selectedMonth);
      if (p.billingMonth != null && p.billingMonth!.isNotEmpty) {
        if (p.billingMonth == targetMonthStr) return true;
      }
      final local = p.date.toLocal();
      return local.year == _selectedMonth.year && local.month == _selectedMonth.month;
    }).toList();

    // Counts for filter chips
    final int upiCount = sortedPayments.where((p) => p.method.toUpperCase().contains('UPI')).length;
    final int cashCount = sortedPayments.where((p) => p.method.toUpperCase().contains('CASH')).length;
    final int bankCount = sortedPayments.where((p) {
      final m = p.method.toUpperCase();
      return m.contains('BANK') || m.contains('TRANSFER') || m.contains('NEFT') || m.contains('IMPS');
    }).length;

    // Filter payments based on search and method
    final filteredPayments = sortedPayments.where((payment) {
      final matchesQuery = _searchQuery.isEmpty ||
          (payment.tenantName ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (payment.roomNumber ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          payment.method.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (payment.notes ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesQuery) return false;

      if (_selectedFilter == 'ALL') return true;
      final methodUpper = payment.method.toUpperCase();
      if (_selectedFilter == 'UPI') return methodUpper.contains('UPI');
      if (_selectedFilter == 'CASH') return methodUpper.contains('CASH');
      if (_selectedFilter == 'BANK') return methodUpper.contains('BANK') || methodUpper.contains('TRANSFER') || methodUpper.contains('NEFT') || methodUpper.contains('IMPS');
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 50,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14.0),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x060F172A),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.only(left: 2.0),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        titleSpacing: 8,
        title: Text(
          'Payment History',
          style: GoogleFonts.lato(
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: Center(
              child: _buildAppBarMonthChooser(context, allSortedPayments, earliestMonth, canGoPrev, canGoNext),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => appProvider.loadFromAPI(),
        color: AppTheme.primaryColor,
        child: appProvider.isLoading
            ? const PaymentHistorySkeleton()
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(14, 10, 14, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Compact Search Input Field
              Container(
                height: 38,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x040F172A),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: GoogleFonts.lato(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by tenant, room, mode, or notes...',
                    hintStyle: GoogleFonts.lato(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: Color(0xFF64748B),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFF94A3B8)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),

              // 2. Compact Segmented Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All', sortedPayments.length),
                    const SizedBox(width: 6),
                    _buildFilterChip('UPI', 'UPI', upiCount),
                    const SizedBox(width: 6),
                    _buildFilterChip('CASH', 'Cash', cashCount),
                    const SizedBox(width: 6),
                    _buildFilterChip('BANK', 'Bank', bankCount),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 3. Section Label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TRANSACTIONS',
                    style: GoogleFonts.lato(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '${filteredPayments.length} results',
                    style: GoogleFonts.lato(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 5. Payment Cards List
              if (sortedPayments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/no_payment_history.png',
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No payment history yet',
                        style: GoogleFonts.lato(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Payments recorded for tenants will be listed here chronologically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              else if (filteredPayments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 10),
                      Text(
                        'No matching payments found',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try searching with a different tenant name or room number.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredPayments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final payment = filteredPayments[index];
                    final paidDateStr = _formatPaymentDate(payment.date);
                    final isUPI = payment.method.toUpperCase().contains('UPI');
                    final isCash = payment.method.toUpperCase().contains('CASH');

                    // Find matched tenant for avatar photo
                    final tenant = appProvider.tenants
                        .where((t) => t.id == payment.tenantId)
                        .firstOrNull;

                    final isExpanded = _expandedPaymentIds.contains(payment.id);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x040F172A),
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedPaymentIds.remove(payment.id);
                            } else {
                              _expandedPaymentIds.add(payment.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8.5),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Tenant Profile Avatar with clean outline border & tap-to-preview
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                                    ),
                                    child: TenantAvatar(
                                      name: payment.tenantName ?? tenant?.name ?? 'Tenant',
                                      imageUrl: tenant?.imageUrl,
                                      radius: 17,
                                      enablePreview: true,
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Tenant Name, Room & Date
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: InkWell(
                                                onTap: () {
                                                  final targetId = tenant?.id ?? payment.tenantId;
                                                  if (targetId.isNotEmpty) {
                                                    context.push('/tenant_profile/$targetId', extra: tenant);
                                                  }
                                                },
                                                borderRadius: BorderRadius.circular(4),
                                                child: Text(
                                                  payment.tenantName ?? tenant?.name ?? 'Tenant',
                                                  style: GoogleFonts.lato(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            if (payment.roomNumber != null && payment.roomNumber!.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
                                                ),
                                                child: Text(
                                                  formatRoomName(payment.roomNumber),
                                                  style: GoogleFonts.lato(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time_rounded,
                                              size: 11.5,
                                              color: Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                paidDateStr,
                                                style: GoogleFonts.lato(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF64748B),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            payment.notes!,
                                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Amount & Badges
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${_formatCurrency(payment.calculateTotalPaid(tenant))}',
                                        style: GoogleFonts.lato(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (payment.platformFee > 0 || (tenant != null && tenant.platformFee > 0)) ...[
                                        const SizedBox(height: 1.5),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Rent: ₹${_formatCurrency(payment.rentAmount > 0 ? payment.rentAmount : payment.amount)}',
                                              style: GoogleFonts.lato(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '• Fee: ₹${(payment.platformFee > 0 ? payment.platformFee : tenant?.platformFee ?? 0).toStringAsFixed(0)}',
                                              style: GoogleFonts.lato(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF0284C7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: isUPI
                                                  ? const Color(0xFFEEF2FF)
                                                  : (isCash ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9)),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isUPI
                                                    ? const Color(0xFFE0E7FF)
                                                    : (isCash ? const Color(0xFFFEF3C7) : const Color(0xFFE2E8F0)),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              payment.method.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                                color: isUPI
                                                    ? const Color(0xFF4F46E5)
                                                    : (isCash ? const Color(0xFFD97706) : const Color(0xFF475569)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFBBF7D0), width: 0.6),
                                            ),
                                            child: const Text(
                                              'PAID',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                                color: Color(0xFF16A34A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 6),

                                  // Chevron icon
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.25 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              if (isExpanded)
                                PaymentSplitupCard(
                                  paymentAmount: payment.calculateTotalPaid(tenant),
                                  rentAmount: payment.rentAmount > 0 ? payment.rentAmount : (tenant?.rentAmount ?? payment.amount),
                                  platformFee: payment.platformFee > 0 ? payment.platformFee : (tenant?.platformFee ?? 0.0),
                                  bills: tenant?.additionalCharges,
                                  method: payment.method,
                                  notes: payment.notes,
                                  paymentDate: payment.date,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarMonthChooser(
    BuildContext context,
    List<Payment> allSortedPayments,
    DateTime earliestMonth,
    bool canGoPrev,
    bool canGoNext,
  ) {
    final isCurrent = _selectedMonth.year == _currentMonth.year && _selectedMonth.month == _currentMonth.month;
    final monthStr = DateFormat('MMM').format(_selectedMonth);
    final displayMonth = _selectedMonth.year == _currentMonth.year
        ? monthStr
        : "$monthStr '${_selectedMonth.year.toString().substring(2)}";

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFEEF2FF) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? const Color(0xFFC7D2FE) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canGoPrev ? () => _prevMonth(earliestMonth) : null,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.only(left: 6, right: 3, top: 4, bottom: 4),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: canGoPrev
                      ? (isCurrent ? const Color(0xFF4F46E5) : const Color(0xFF1E293B))
                      : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showMonthPickerSheet(context, allSortedPayments, earliestMonth),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayMonth,
                      style: GoogleFonts.lato(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isCurrent ? const Color(0xFF4F46E5) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: isCurrent ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canGoNext ? _nextMonth : null,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.only(left: 3, right: 6, top: 4, bottom: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: canGoNext
                      ? (isCurrent ? const Color(0xFF4F46E5) : const Color(0xFF1E293B))
                      : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthPickerSheet(
    BuildContext context,
    List<Payment> allSortedPayments,
    DateTime earliestMonth,
  ) {
    final List<DateTime> months = [];
    DateTime cursor = _currentMonth;
    final DateTime stop = DateTime(earliestMonth.year, earliestMonth.month, 1);
    while (!cursor.isBefore(stop)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month - 1, 1);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Month',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${months.length} ${months.length == 1 ? "Month" : "Months"}',
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: months.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (_, index) {
                    final m = months[index];
                    final isSelected = m.year == _selectedMonth.year && m.month == _selectedMonth.month;
                    final isCurrent = m.year == _currentMonth.year && m.month == _currentMonth.month;
                    final count = allSortedPayments.where((p) {
                      final targetMonthStr = DateFormat('yyyy-MM').format(m);
                      if (p.billingMonth != null && p.billingMonth!.isNotEmpty) {
                        return p.billingMonth == targetMonthStr;
                      }
                      final local = p.date.toLocal();
                      return local.year == m.year && local.month == m.month;
                    }).length;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      minLeadingWidth: 32,
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          size: 17,
                          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              DateFormat('MMMM yyyy').format(m),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lato(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFFC7D2FE), width: 0.6),
                              ),
                              child: Text(
                                'Current',
                                style: GoogleFonts.lato(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
                                width: 0.7,
                              ),
                            ),
                            child: Text(
                              '$count ${count == 1 ? "txn" : "txns"}',
                              style: GoogleFonts.lato(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5), size: 17),
                          ],
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _selectedMonth = m;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String key, String label, int count) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x180F172A),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.lato(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
