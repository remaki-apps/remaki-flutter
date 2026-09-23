import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../widgets/tenant_avatar.dart';
import '../theme/app_theme.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, UPI, CASH, BANK

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatPaymentDate(DateTime date) {
    if (date.hour == 0 && date.minute == 0 && date.second == 0) {
      return DateFormat('dd MMM yyyy').format(date);
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  String _formatCurrency(num amount) {
    return NumberFormat('#,##,###').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final sortedPayments = [...appProvider.payments]..sort((a, b) => b.date.compareTo(a.date));

    // Calculate total amount collected from all payments
    final double totalCollected = sortedPayments.fold(0.0, (sum, p) => sum + p.amount);

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
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14.0),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ),
        title: Column(
          children: [
            Text(
              'Payment History',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${sortedPayments.length} Recorded Transactions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Total Collections Metric Card (Fintech Hero Card)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x180F172A),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL RECORDED PAYMENTS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '₹${_formatCurrency(totalCollected)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${sortedPayments.length} Transactions',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Modern Search Input Field
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x040F172A),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by tenant, room, mode, or notes...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Fintech Segmented Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All', sortedPayments.length),
                    const SizedBox(width: 8),
                    _buildFilterChip('UPI', 'UPI', upiCount),
                    const SizedBox(width: 8),
                    _buildFilterChip('CASH', 'Cash', cashCount),
                    const SizedBox(width: 8),
                    _buildFilterChip('BANK', 'Bank', bankCount),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Section Label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TRANSACTIONS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.9,
                    ),
                  ),
                  Text(
                    '${filteredPayments.length} results',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

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
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.receipt_long_outlined, size: 28, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No payment history yet',
                        style: GoogleFonts.plusJakartaSans(
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
                        style: GoogleFonts.plusJakartaSans(
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
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final payment = filteredPayments[index];
                    final paidDateStr = _formatPaymentDate(payment.date);
                    final isUPI = payment.method.toUpperCase().contains('UPI');
                    final isCash = payment.method.toUpperCase().contains('CASH');

                    // Find matched tenant for avatar photo
                    final tenant = appProvider.tenants
                        .where((t) => t.id == payment.tenantId)
                        .firstOrNull;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x040F172A),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                          BoxShadow(
                            color: Color(0x020F172A),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Tenant Profile Avatar with clean outline border & tap-to-preview
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            ),
                            child: TenantAvatar(
                              name: payment.tenantName ?? tenant?.name ?? 'Tenant',
                              imageUrl: tenant?.imageUrl,
                              radius: 20,
                              enablePreview: true,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Tenant Name, Room & Date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        payment.tenantName ?? tenant?.name ?? 'Tenant',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                          payment.roomNumber!,
                                          style: GoogleFonts.plusJakartaSans(
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
                                    Text(
                                      paidDateStr,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
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
                                '₹${_formatCurrency(payment.amount)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
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
                        ],
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

  Widget _buildFilterChip(String key, String label, int count) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x200F172A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
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
