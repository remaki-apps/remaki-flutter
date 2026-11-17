import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/organization_models.dart';

class OrgAdminsScreen extends StatefulWidget {
  const OrgAdminsScreen({super.key});

  @override
  State<OrgAdminsScreen> createState() => _OrgAdminsScreenState();
}

class _OrgAdminsScreenState extends State<OrgAdminsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrganizationProvider>().loadFromAPI(showLoading: false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrganizationProvider>();
    final admins = orgProvider.filteredAdmins;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/org_create_admin'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'Create Admin',
            style: GoogleFonts.lato(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Management',
                          style: GoogleFonts.lato(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${orgProvider.admins.length} Admins registered under your organization',
                          style: GoogleFonts.lato(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
                    onPressed: () => orgProvider.loadFromAPI(showLoading: false),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => orgProvider.setSearchQuery(val),
                  style: GoogleFonts.lato(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name, admin code, phone, or PG...',
                    hintStyle: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              orgProvider.setSearchQuery('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filter Chips (All, Active, Inactive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  _buildFilterChip('All', 'ALL', orgProvider),
                  const SizedBox(width: 8),
                  _buildFilterChip('Active', 'ACTIVE', orgProvider),
                  const SizedBox(width: 8),
                  _buildFilterChip('Inactive', 'INACTIVE', orgProvider),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Admins List
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: () => orgProvider.loadFromAPI(showLoading: false),
                child: admins.isEmpty
                    ? _buildEmptyState(orgProvider.searchQuery.isNotEmpty)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                        itemCount: admins.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final admin = admins[index];
                          return _buildAdminCard(context, admin);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, OrganizationProvider provider) {
    final isSelected = provider.filterStatus == value;
    return GestureDetector(
      onTap: () => provider.setFilterStatus(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, OrganizationAdminSummary admin) {
    return GestureDetector(
      onTap: () => context.push('/org_admin_details/${admin.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: admin.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
            width: admin.isActive ? 1.0 : 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Avatar, Name, Code, and Status Pill
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: admin.isActive ? AppTheme.accentColor : const Color(0xFFF1F5F9),
                  child: Text(
                    admin.displayName.isNotEmpty ? admin.displayName[0].toUpperCase() : 'A',
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: admin.isActive ? AppTheme.primaryColor : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              admin.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              admin.adminCode,
                              style: GoogleFonts.lato(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        admin.phoneNumber,
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: admin.isActive ? AppTheme.successBg : AppTheme.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    admin.isActive ? 'Active' : 'Disabled',
                    style: GoogleFonts.lato(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: admin.isActive ? AppTheme.success : AppTheme.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Row 2: Assigned Property Details
            Row(
              children: [
                const Icon(Icons.apartment_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    admin.propertyNames.isNotEmpty
                        ? admin.propertyNames.join(', ')
                        : 'No property assigned yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: admin.propertyNames.isNotEmpty
                          ? AppTheme.primaryDark
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 3: Operational Breakdown Pills
            Row(
              children: [
                _buildMiniStat(Icons.door_front_door_outlined, '${admin.totalRooms} Rooms'),
                const SizedBox(width: 14),
                _buildMiniStat(Icons.bed_outlined, '${admin.occupiedBeds}/${admin.totalBeds} Beds'),
                const SizedBox(width: 14),
                _buildMiniStat(Icons.people_outline_rounded, '${admin.totalTenants} Tenants'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.lato(
            fontSize: 11.5,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isFiltered) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.search_off_rounded : Icons.badge_outlined,
              size: 54,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              isFiltered ? 'No Admins Found' : 'No Admins in Organization',
              style: GoogleFonts.lato(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Try adjusting your search query or filter.'
                  : 'Tap the button below to onboard your first PG branch admin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(fontSize: 13, color: AppTheme.textSecondary),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => context.push('/org_create_admin'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: Text('Create Admin', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

