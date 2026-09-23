import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/tenant_avatar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _pendingApprovalsCount = 0;
  bool _isLoadingApprovals = false;

  @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    if (_isLoadingApprovals) return;
    _isLoadingApprovals = true;
    try {
      final reqs = await ApiService.fetchPendingPaymentRequests();
      if (mounted) {
        setState(() {
          _pendingApprovalsCount = reqs.length;
        });
      }
    } catch (_) {
      // Gracefully ignore if offline or error
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingApprovals = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await Future.wait([
      appProvider.loadFromAPI(),
      _loadPendingApprovals(),
    ]);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatPaymentDate(DateTime date) {
    if (date.hour == 0 && date.minute == 0 && date.second == 0) {
      return DateFormat('dd MMM yyyy').format(date);
    }
    return DateFormat('dd MMM, hh:mm a').format(date);
  }

  String _formatCurrency(num amount) {
    return NumberFormat('#,##,###').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final monthYear = DateFormat('MMMM yyyy').format(DateTime.now());

    final expectedRent = appProvider.expectedRentOnly;
    final collectedRent = appProvider.collectedRentOnly;
    final pendingRent = appProvider.pendingRentOnly;

    final sortedPayments = [...appProvider.payments]..sort((a, b) => b.date.compareTo(a.date));
    final recentPayments = sortedPayments.take(5).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Sleek PG & Owner Identity Banner
                _buildPGIdentityCard(appProvider),
                const SizedBox(height: 16),

                // 2. Modern Quick Actions Hub (Add Tenant, Notice, Unpaid Rent, Approvals)
                _buildQuickActionsSection(context, appProvider),
                const SizedBox(height: 16),

                // 3. Bed Occupancy & Capacity Bento Card
                _buildOccupancyCard(context, appProvider),
                const SizedBox(height: 16),

                // 4. Rent Collection Overview Card
                _buildRentOverviewCard(
                  context: context,
                  monthYear: monthYear,
                  expectedRent: expectedRent,
                  collectedRent: collectedRent,
                  pendingRent: pendingRent,
                  unpaidCount: appProvider.unpaidRentTenants.length,
                ),
                const SizedBox(height: 16),

                // 5. Payment History (Recent Transactions with Tenant Profile Photos)
                _buildPaymentHistorySection(
                  context: context,
                  appProvider: appProvider,
                  payments: recentPayments,
                  totalCount: appProvider.payments.length,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPGIdentityCard(AppProvider appProvider) {
    final greeting = _getGreeting();
    final ownerName = appProvider.adminName.isNotEmpty ? appProvider.adminName : 'Owner';
    final pgName = appProvider.pgName.isNotEmpty ? appProvider.pgName : 'Your PG';
    final pgAddress = appProvider.pgAddress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x020F172A),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x254F46E5),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$greeting, $ownerName',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('👋', style: TextStyle(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  pgName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (pgAddress.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          pgAddress,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context, AppProvider appProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'QUICK ACTIONS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.9,
              ),
            ),
            if (_pendingApprovalsCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_pendingApprovalsCount Pending Approval',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildQuickActionButton(
              label: 'Add Tenant',
              icon: Icons.person_add_alt_1_rounded,
              bgColor: const Color(0xFFEEF2FF),
              iconColor: const Color(0xFF4F46E5),
              onTap: () => context.push('/add_tenant'),
            ),
            const SizedBox(width: 10),
            // Notice action
            _buildQuickActionButton(
              label: 'Notice',
              icon: Icons.campaign_rounded,
              bgColor: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              onTap: () => context.push('/announcements'),
            ),
            const SizedBox(width: 10),
            _buildQuickActionButton(
              label: 'Unpaid Rent',
              icon: Icons.pending_actions_rounded,
              bgColor: const Color(0xFFFFF1F2),
              iconColor: const Color(0xFFE11D48),
              badgeCount: appProvider.unpaidRentTenants.length,
              onTap: () => context.push('/unpaid_tenants?filter=rent'),
            ),
            const SizedBox(width: 10),
            _buildQuickActionButton(
              label: 'Approvals',
              icon: Icons.fact_check_outlined,
              bgColor: const Color(0xFFF0FDF4),
              iconColor: const Color(0xFF16A34A),
              badgeCount: _pendingApprovalsCount,
              onTap: () async {
                await context.push('/approvals');
                _loadPendingApprovals();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x040F172A),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33DC2626),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOccupancyCard(BuildContext context, AppProvider appProvider) {
    final occupancyPct = (appProvider.occupancyRate * 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x020F172A),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bed_rounded, size: 17, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bed Occupancy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E7FF), width: 1),
                ),
                child: Text(
                  '$occupancyPct% Occupied',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF4F46E5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildOccupancyStat(
                title: 'Total Beds',
                value: '${appProvider.totalBeds}',
                color: const Color(0xFF0F172A),
                icon: Icons.hotel_rounded,
                iconColor: const Color(0xFF64748B),
                bgColor: const Color(0xFFF8FAFC),
                borderColor: const Color(0xFFE2E8F0),
              ),
              const SizedBox(width: 8),
              _buildOccupancyStat(
                title: 'Occupied',
                value: '${appProvider.occupiedBeds}',
                color: const Color(0xFF2563EB),
                icon: Icons.person_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFFDBEAFE),
              ),
              const SizedBox(width: 8),
              _buildOccupancyStat(
                title: 'Available',
                value: '${appProvider.availableBeds}',
                color: const Color(0xFF16A34A),
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF16A34A),
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFDCFCE7),
                onTap: () => context.push('/available_beds'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancyStat({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 15, color: iconColor),
                  if (onTap != null)
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: Color(0xFF16A34A),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRentOverviewCard({
    required BuildContext context,
    required String monthYear,
    required double expectedRent,
    required double collectedRent,
    required double pendingRent,
    required int unpaidCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x020F172A),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 17,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rent Overview',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: Color(0xFF475569),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      monthYear,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF475569),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildRentStatColumn(
                title: 'Expected Rent',
                value: '₹${_formatCurrency(expectedRent)}',
                color: const Color(0xFF0F172A),
                icon: Icons.receipt_outlined,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF475569),
              ),
              Container(width: 1, height: 38, color: const Color(0xFFF1F5F9)),
              _buildRentStatColumn(
                title: 'Collected',
                value: '₹${_formatCurrency(collectedRent)}',
                color: const Color(0xFF16A34A),
                icon: Icons.check_circle_rounded,
                iconBg: const Color(0xFFF0FDF4),
                iconColor: const Color(0xFF16A34A),
              ),
              Container(width: 1, height: 38, color: const Color(0xFFF1F5F9)),
              _buildRentStatColumn(
                title: 'Pending',
                value: '₹${_formatCurrency(pendingRent)}',
                color: const Color(0xFFE11D48),
                icon: Icons.schedule_rounded,
                iconBg: const Color(0xFFFFF1F2),
                iconColor: const Color(0xFFE11D48),
              ),
            ],
          ),
          if (unpaidCount > 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push('/unpaid_tenants?filter=rent'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECDD3), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$unpaidCount tenants with pending rent',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFBE123C),
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: Color(0xFFBE123C),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRentStatColumn({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 12, color: iconColor),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistorySection({
    required BuildContext context,
    required AppProvider appProvider,
    required List<Payment> payments,
    required int totalCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x020F172A),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 17,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Payment History',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (totalCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Text(
                        '$totalCount',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: () => context.push('/payment_history'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (payments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: Color(0xFF64748B),
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No payment history yet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Payments recorded for tenants will appear here.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              separatorBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),
              itemBuilder: (context, index) {
                final payment = payments[index];
                return _buildPaymentRow(payment, appProvider);
              },
            ),
          if (totalCount > 5) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push('/payment_history'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View all $totalCount transactions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentRow(Payment payment, AppProvider appProvider) {
    final paidDateStr = _formatPaymentDate(payment.date);
    final isUPI = payment.method.toUpperCase().contains('UPI');
    final isCash = payment.method.toUpperCase().contains('CASH');

    // Find matched tenant for avatar photo
    final tenant = appProvider.tenants
        .where((t) => t.id == payment.tenantId)
        .firstOrNull;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tenant Profile Avatar with clean border
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: TenantAvatar(
            name: payment.tenantName ?? tenant?.name ?? 'Tenant',
            imageUrl: tenant?.imageUrl,
            radius: 19,
            enablePreview: true,
          ),
        ),
        const SizedBox(width: 10),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (payment.roomNumber != null && payment.roomNumber!.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    paidDateStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        payment.notes!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${_formatCurrency(payment.amount)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUPI
                        ? const Color(0xFFEEF2FF)
                        : (isCash ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(5),
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
                      fontSize: 9,
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
                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFBBF7D0), width: 0.6),
                  ),
                  child: const Text(
                    'PAID',
                    style: TextStyle(
                      fontSize: 9,
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
    );
  }
}
