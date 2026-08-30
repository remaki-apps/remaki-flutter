import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  String _filter = 'All'; // All, Paid, Unpaid
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    final totalCount = appProvider.tenants.length;
    final paidCount = appProvider.tenants.where((t) => t.totalDue == 0).length;
    final unpaidCount = appProvider.tenants.where((t) => t.totalDue > 0).length;

    var filteredTenants = appProvider.tenants.where((t) {
      if (_filter == 'Paid' && t.totalDue > 0) return false;
      if (_filter == 'Unpaid' && t.totalDue == 0) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final roomIndex = appProvider.rooms.indexWhere((r) => r.id == t.roomId);
        final roomNumber = roomIndex != -1 ? appProvider.rooms[roomIndex].number.toLowerCase() : '';
        return t.name.toLowerCase().contains(query) ||
            t.phone.toLowerCase().contains(query) ||
            roomNumber.contains(query);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
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
                      Column(
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
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

                  // Search Bar Input
                  Container(
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
                        hintText: 'Search tenant by name, room, or phone...',
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

            // Tenants List View
            Expanded(
              child: filteredTenants.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty ? 'No tenants matching "$_searchQuery"' : 'No tenants found.',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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

                                // Tenant Info (Name, Status & Room/Bed)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              tenant.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: tenant.totalDue == 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: tenant.totalDue == 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFCA5A5),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 5,
                                                  height: 5,
                                                  decoration: BoxDecoration(
                                                    color: tenant.totalDue == 0 ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  tenant.totalDue == 0 ? 'Paid' : 'Unpaid',
                                                  style: TextStyle(
                                                    color: tenant.totalDue == 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Room $roomNumber',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
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
                                      '₹${tenant.totalDue.toStringAsFixed(0)}',
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
          ],
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
}

