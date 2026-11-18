import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';
import '../widgets/app_shimmer.dart';
import '../utils/string_utils.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

enum TenantSortField { name, room, dueDate, amount }

class _TenantsScreenState extends State<TenantsScreen> {
  String _filter = 'All'; // All, Paid, Unpaid
  String _foodFilter = 'ALL'; // ALL, WITH_FOOD, WITHOUT_FOOD
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  TenantSortField _sortField = TenantSortField.name;
  bool _sortAscending = true;

  String get _sortLabel {
    switch (_sortField) {
      case TenantSortField.name:
        return _sortAscending ? 'Name A-Z' : 'Name Z-A';
      case TenantSortField.room:
        return _sortAscending ? 'Room ↑' : 'Room ↓';
      case TenantSortField.dueDate:
        return _sortAscending ? 'Due Earliest' : 'Due Latest';
      case TenantSortField.amount:
        return _sortAscending ? 'Amount Low' : 'Amount High';
    }
  }

  void _showSortModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sort Tenants',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() => _sortAscending = !_sortAscending);
                          setState(() {});
                        },
                        icon: Icon(
                          _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        label: Text(
                          _sortAscending ? 'Ascending' : 'Descending',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFEEF2FF),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SORT BY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSortChip(
                        field: TenantSortField.name,
                        label: 'Tenant Name',
                        icon: Icons.person_rounded,
                        setModalState: setModalState,
                      ),
                      _buildSortChip(
                        field: TenantSortField.room,
                        label: 'Room Number',
                        icon: Icons.meeting_room_rounded,
                        setModalState: setModalState,
                      ),
                      _buildSortChip(
                        field: TenantSortField.dueDate,
                        label: 'Due Date',
                        icon: Icons.calendar_today_rounded,
                        setModalState: setModalState,
                      ),
                      _buildSortChip(
                        field: TenantSortField.amount,
                        label: 'Pending Amount',
                        icon: Icons.currency_rupee_rounded,
                        setModalState: setModalState,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Apply Sort',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortChip({
    required TenantSortField field,
    required String label,
    required IconData icon,
    required StateSetter setModalState,
  }) {
    final isSelected = _sortField == field;
    return GestureDetector(
      onTap: () {
        setModalState(() => _sortField = field);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF334155),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(
                _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 14,
                color: AppTheme.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    bool isDueDateReached(DateTime? dueDate) {
      if (dueDate == null) return true;
      final dueStart = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final nowStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      return !nowStart.isBefore(dueStart);
    }

    final totalCount = appProvider.currentTenants.length;
    final paidCount = appProvider.currentTenants.where((t) => (t.isPaid || t.paymentStatus == 'PAID') && t.totalPendingBills <= 0).length;
    final unpaidCount = appProvider.currentTenants.where((t) {
      final bool hasPendingRent = (t.pendingRentAmount > 0 || !t.isPaid);
      final bool hasPendingBills = t.totalPendingBills > 0;
      if (hasPendingRent) {
        return isDueDateReached(t.rentDueDate);
      } else if (hasPendingBills) {
        return true;
      }
      return false;
    }).length;
    final withFoodCount = appProvider.currentTenants.where((t) => t.foodIncluded).length;
    final withoutFoodCount = appProvider.currentTenants.where((t) => !t.foodIncluded).length;

    var filteredTenants = appProvider.currentTenants.where((t) {
      final bool hasPendingRent = (t.pendingRentAmount > 0 || !t.isPaid);
      final bool hasPendingBills = t.totalPendingBills > 0;
      if (_filter == 'Paid') {
        if (hasPendingRent || hasPendingBills) return false;
      }
      if (_filter == 'Unpaid') {
        if (hasPendingRent) {
          if (!isDueDateReached(t.rentDueDate)) return false;
        } else if (hasPendingBills) {
          // Only bills: show immediately
        } else {
          return false;
        }
      }

      // Food Filter
      if (_foodFilter == 'WITH_FOOD' && !t.foodIncluded) return false;
      if (_foodFilter == 'WITHOUT_FOOD' && t.foodIncluded) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final roomIndex = appProvider.rooms.indexWhere((r) => r.id == t.roomId);
        final roomNumber = roomIndex != -1 ? appProvider.rooms[roomIndex].number.toLowerCase() : '';
        
        final matchesBasic = t.name.toLowerCase().contains(query) ||
            t.phone.toLowerCase().contains(query) ||
            roomNumber.contains(query);

        final foodPlanText = t.foodIncluded ? 'with food' : 'without food';
        final matchesFood = foodPlanText.contains(query);

        if (!matchesBasic && !matchesFood) return false;
      }
      return true;
    }).toList();

    filteredTenants.sort((a, b) {
      int cmp = 0;
      switch (_sortField) {
        case TenantSortField.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case TenantSortField.room:
          final roomA = appProvider.rooms.firstWhere(
            (r) => r.id == a.roomId,
            orElse: () => Room(id: '', propertyId: '', number: '', floor: '', capacity: 0, roomType: 'NON_AC', foodOption: 'WITH_FOOD', beds: []),
          ).number;
          final roomB = appProvider.rooms.firstWhere(
            (r) => r.id == b.roomId,
            orElse: () => Room(id: '', propertyId: '', number: '', floor: '', capacity: 0, roomType: 'NON_AC', foodOption: 'WITH_FOOD', beds: []),
          ).number;
          cmp = naturalCompare(roomA, roomB);
          break;
        case TenantSortField.dueDate:
          cmp = a.rentDueDate.compareTo(b.rentDueDate);
          break;
        case TenantSortField.amount:
          cmp = a.totalDue.compareTo(b.totalDue);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => appProvider.loadFromAPI(),
          color: AppTheme.primaryColor,
          child: appProvider.isLoading
              ? const TenantsListSkeleton()
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      children: [
                        // Top Header & Search Bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tenants',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalCount Total • $paidCount Paid • $unpaidCount Pending',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.push('/add_tenant'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Color(0x204F46E5), blurRadius: 8, offset: Offset(0, 3)),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Add Tenant',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search Bar & Sort Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search by name, room, phone, or "with food"...',
                              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showSortModal(context),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sortLabel,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Top KPI Cards Row (Interactive Filters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildKpiBox(
                      label: 'Total',
                      count: '$totalCount',
                      filterValue: 'All',
                      bgColor: const Color(0xFFEEF2FF),
                      borderColor: AppTheme.primaryColor,
                      textColor: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKpiBox(
                      label: 'Paid',
                      count: '$paidCount',
                      filterValue: 'Paid',
                      bgColor: const Color(0xFFF0FDF4),
                      borderColor: const Color(0xFFDCFCE7),
                      textColor: const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKpiBox(
                      label: 'Unpaid',
                      count: '$unpaidCount',
                      filterValue: 'Unpaid',
                      bgColor: const Color(0xFFFEF2F2),
                      borderColor: const Color(0xFFFCA5A5),
                      textColor: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),

            // Food Plan Filter Chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFoodFilterChip(
                      label: 'All Plans',
                      count: '$totalCount',
                      filterValue: 'ALL',
                      icon: Icons.all_inclusive_rounded,
                      activeColor: AppTheme.primaryColor,
                      activeBgColor: const Color(0xFFEEF2FF),
                    ),
                    const SizedBox(width: 8),
                    _buildFoodFilterChip(
                      label: 'With Food',
                      count: '$withFoodCount',
                      filterValue: 'WITH_FOOD',
                      icon: Icons.restaurant_rounded,
                      activeColor: const Color(0xFF16A34A),
                      activeBgColor: const Color(0xFFDCFCE7),
                    ),
                    const SizedBox(width: 8),
                    _buildFoodFilterChip(
                      label: 'Without Food',
                      count: '$withoutFoodCount',
                      filterValue: 'WITHOUT_FOOD',
                      icon: Icons.no_meals_rounded,
                      activeColor: const Color(0xFF475569),
                      activeBgColor: const Color(0xFFF1F5F9),
                    ),
                  ],
                ),
              ),
            ),

            // Tenants List View
            Expanded(
              child: filteredTenants.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.55,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/no_tenant1.png',
                                  height: 180,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No tenants matching "$_searchQuery"'
                                      : 'No Tenants Found',
                                  style: GoogleFonts.lato(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Try searching for another name, phone number, or room.'
                                      : 'Add tenants to track rent payments and bed allocations.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.lato(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : Scrollbar(
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          (MediaQuery.viewInsetsOf(context).bottom > 0 ? 32 : 120) + MediaQuery.paddingOf(context).bottom,
                        ),
                      itemCount: filteredTenants.length,
                      itemBuilder: (context, index) {
                        var tenant = filteredTenants[index];
                        var roomIndex = appProvider.rooms.indexWhere((r) => r.id == tenant.roomId);
                        var roomNumber = roomIndex != -1 ? appProvider.rooms[roomIndex].number : 'N/A';
                        var dueDateStr = DateFormat('dd MMM').format(tenant.rentDueDate);

                        return GestureDetector(
                          onTap: () => context.push('/tenant_profile/${tenant.id}'),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                              boxShadow: const [
                                BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              children: [
                                TenantAvatar(
                                  name: tenant.name,
                                  imageUrl: tenant.imageUrl,
                                  radius: 22,
                                ),
                                const SizedBox(width: 14),

                                // Tenant Info (Name & Room / Payment Status)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tenant.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 5),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEEF2FF),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              formatRoomName(roomNumber),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.primaryColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (tenant.statusBadgeLabel != 'UPCOMING' && !tenant.isUpcoming)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: tenant.statusBgColor,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                tenant.paymentStatusTitle,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: tenant.statusColor,
                                                ),
                                              ),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: tenant.foodIncluded ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: tenant.foodIncluded ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  tenant.foodIncluded ? Icons.restaurant_rounded : Icons.no_meals_rounded,
                                                  size: 10,
                                                  color: tenant.foodIncluded ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  tenant.foodIncluded ? 'With Food' : 'Without Food',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: tenant.foodIncluded ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                 // Financial Dues & Date
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${tenant.totalPayableWithPlatformFee.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Due $dueDateStr',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildKpiBox({
    required String label,
    required String count,
    required String filterValue,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    final isSelected = _filter == filterValue;
    return GestureDetector(
      onTap: () => setState(() => _filter = filterValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? textColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: textColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? textColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodFilterChip({
    required String label,
    required String count,
    required String filterValue,
    required IconData icon,
    required Color activeColor,
    required Color activeBgColor,
  }) {
    final isSelected = _foodFilter == filterValue;
    return GestureDetector(
      onTap: () => setState(() => _foodFilter = filterValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? activeColor : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

