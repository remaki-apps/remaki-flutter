import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/export_data_modal.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Confirm Logout',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out? You will need to sign in again to access the admin portal.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: const Color(0xFF64748B),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ApiService.clearAuthToken();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(
              'Logout',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'More Options',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final totalBeds = provider.rooms.fold(0, (sum, r) => sum + r.capacity);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // 1. Property Overview Header Card (App Signature Purple Gradient)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF312E81), Color(0xFF4338CA), Color(0xFF5B32E4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5B32E4).withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
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
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: const Icon(
                                Icons.apartment_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.pgName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${provider.adminName} • Property Manager',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: const Color(0xFFE0E7FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Active',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMiniStat('${provider.rooms.length}', 'Rooms'),
                              Container(width: 1, height: 14, color: Colors.white24),
                              _buildMiniStat('$totalBeds', 'Total Beds'),
                              Container(width: 1, height: 14, color: Colors.white24),
                              _buildMiniStat('${provider.tenants.length}', 'Residents'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Individual Separate Containers using App Brand Theme Colors
                  _buildActionCard(
                    icon: Icons.cloud_download_outlined,
                    iconColor: AppTheme.primaryColor,
                    iconBg: const Color(0xFFF0EAFF),
                    title: 'Backup & Export Data',
                    subtitle: 'Export property records to Excel (.csv)',
                    badge: 'Excel',
                    onTap: () => ExportDataModal.show(context),
                  ),
                  const SizedBox(height: 8),

                  _buildActionCard(
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFF4338CA),
                    iconBg: const Color(0xFFEEF2FF),
                    title: 'Terms of Service',
                    subtitle: 'Usage rules & operating guidelines',
                    onTap: () => context.push('/terms'),
                  ),
                  const SizedBox(height: 8),

                  _buildActionCard(
                    icon: Icons.verified_user_outlined,
                    iconColor: const Color(0xFF00B074),
                    iconBg: const Color(0xFFE8F8F0),
                    title: 'Privacy Policy',
                    subtitle: 'Data security & zero-sharing policy',
                    onTap: () => context.push('/privacy'),
                  ),
                  const SizedBox(height: 8),

                  _buildActionCard(
                    icon: Icons.help_outline_rounded,
                    iconColor: const Color(0xFF0284C7),
                    iconBg: const Color(0xFFE0F2FE),
                    title: 'Help & Support',
                    subtitle: 'Contact Kishore & review FAQs',
                    badge: 'Helpdesk',
                    onTap: () => context.push('/help_support'),
                  ),
                  const SizedBox(height: 8),

                  _buildActionCard(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFFFF7A00),
                    iconBg: const Color(0xFFFFF2E8),
                    title: 'About Remaki',
                    subtitle: 'Smart PG & Hostel Operating System',
                    onTap: () => context.push('/about'),
                  ),
                  const SizedBox(height: 8),

                  // 3. Logout Separate Container
                  _buildActionCard(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    subtitle: 'Sign out of admin session',
                    isDestructive: true,
                    onTap: () => _showLogoutDialog(context),
                  ),

                  const Spacer(),

                  // 4. Subtle System Status Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 5),
                      Text(
                        'Encrypted Session • Remaki v1.0.0 (Build 1)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            color: const Color(0xFFE0E7FF),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
    Color? iconColor,
    Color? iconBg,
    bool isDestructive = false,
  }) {
    final effectiveIconColor = isDestructive
        ? const Color(0xFFEF4444)
        : (iconColor ?? AppTheme.primaryColor);
    final effectiveIconBg = isDestructive
        ? const Color(0xFFFEF2F2)
        : (iconBg ?? const Color(0xFFF0EAFF));
    final effectiveBorderColor = isDestructive
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFF1F5F9);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: effectiveBorderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDestructive
                ? const Color(0xFFEF4444).withValues(alpha: 0.04)
                : const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: effectiveIconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: effectiveIconColor,
            size: 19,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            color: isDestructive ? const Color(0xFFFCA5A5) : const Color(0xFF64748B),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: effectiveIconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: effectiveIconColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: isDestructive ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
