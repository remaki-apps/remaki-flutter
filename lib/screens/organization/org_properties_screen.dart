import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/organization_models.dart';

class OrgPropertiesScreen extends StatelessWidget {
  const OrgPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrganizationProvider>();
    final properties = orgProvider.properties;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
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
                          'Properties Overview',
                          style: GoogleFonts.lato(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${properties.length} PG properties managed across all branch admins',
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
                    tooltip: 'Platform Fee & Settlements',
                    icon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryColor),
                    onPressed: () => context.push('/org_platform_fee'),
                  ),
                  IconButton(
                    tooltip: 'Add PG Property',
                    icon: const Icon(Icons.add_business_rounded, color: AppTheme.primaryColor),
                    onPressed: () => context.push('/org_property_form'),
                  ),
                ],
              ),
            ),

            // Properties List
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: () => orgProvider.loadFromAPI(showLoading: false),
                child: properties.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                        itemCount: properties.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final prop = properties[index];
                          return _buildPropertyCard(context, prop);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, OrganizationPropertyItem prop) {
    final double occupancyRate = prop.totalBeds > 0 ? (prop.occupiedBeds / prop.totalBeds).clamp(0.0, 1.0) : 0.0;
    final int percent = (occupancyRate * 100).round();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/org_property_details/${prop.id}'),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Title & Floor Pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.apartment_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prop.name,
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${prop.address}, ${prop.city}',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit PG',
                icon: const Icon(Icons.edit_outlined, size: 19, color: AppTheme.primaryColor),
                onPressed: () => context.push('/org_property_form?propertyId=${prop.id}'),
              ),
              IconButton(
                tooltip: 'Delete / Deactivate PG',
                icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.danger),
                onPressed: () => context.push('/org_stepwise_delete?targetId=${prop.id}&isAdmin=false&name=${Uri.encodeComponent(prop.name)}'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${prop.totalFloors} Floor${prop.totalFloors > 1 ? "s" : ""}',
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Managing Admin
          Row(
            children: [
              const Icon(Icons.person_pin_circle_rounded, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                'Managed by: ',
                style: GoogleFonts.lato(fontSize: 12.5, color: const Color(0xFF64748B)),
              ),
              Flexible(
                child: Text(
                  prop.adminName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prop.adminCode,
                  style: GoogleFonts.lato(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Statistics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile('Rooms', '${prop.totalRooms}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile('Total Beds', '${prop.totalBeds}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile('Occupied', '${prop.occupiedBeds} ($percent%)'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile('Available', '${prop.availableBeds}'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/org_property_details/${prop.id}?tab=0'),
                  icon: const Icon(Icons.meeting_room_outlined, size: 16),
                  label: Text('Rooms (${prop.totalRooms})', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryDark,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/org_property_details/${prop.id}?tab=1'),
                  icon: const Icon(Icons.group_add_outlined, size: 16),
                  label: Text('Co-Owners (${prop.coOwnersCount})', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          if (prop.electricityCalculatorEnabled) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 4),
                  Text(
                    'Electricity Calculator Enabled',
                    style: GoogleFonts.lato(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.lato(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apartment_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              'No Properties Found',
              style: GoogleFonts.lato(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Properties will appear here once branch admins are onboarded with assigned PGs.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

