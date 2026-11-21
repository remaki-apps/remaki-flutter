import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/organization_models.dart';
import '../../widgets/fancy_toast.dart';

class OrgAdminDetailsScreen extends StatefulWidget {
  final String adminId;
  const OrgAdminDetailsScreen({super.key, required this.adminId});

  @override
  State<OrgAdminDetailsScreen> createState() => _OrgAdminDetailsScreenState();
}

class _OrgAdminDetailsScreenState extends State<OrgAdminDetailsScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  bool _isTogglingStatus = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OrganizationProvider>();
      if (provider.admins.isEmpty) {
        provider.loadFromAPI(showLoading: false);
      }
    });
  }

  OrganizationAdminSummary? _getAdmin(OrganizationProvider provider) {
    try {
      return provider.admins.firstWhere((a) => a.id == widget.adminId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleStatus(OrganizationProvider provider, bool newStatus) async {
    final action = newStatus ? 'Activate' : 'Deactivate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$action Admin Account?',
          style: GoogleFonts.lato(fontWeight: FontWeight.w700),
        ),
        content: Text(
          newStatus
              ? 'Activating this account will allow the admin to log in and manage their assigned PG properties immediately.'
              : 'Deactivating this account will immediately revoke all access and terminate active sessions for this admin. Their data and properties will be preserved.',
          style: GoogleFonts.lato(fontSize: 13.5, color: const Color(0xFF64748B), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.lato(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppTheme.success : AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isTogglingStatus = true);
      try {
        await provider.toggleAdminStatus(widget.adminId, newStatus);
        if (mounted) {
          FancyToast.showSuccess(
            context,
            'Status Updated',
            message: 'Admin account successfully ${newStatus ? "activated" : "deactivated"}',
          );
        }
      } catch (e) {
        if (mounted) {
          FancyToast.showError(
            context,
            'Action Failed',
            message: e.toString().replaceAll('Exception: ', ''),
          );
        }
      } finally {
        if (mounted) setState(() => _isTogglingStatus = false);
      }
    }
  }

  Future<void> _deleteAdmin(OrganizationProvider provider, OrganizationAdminSummary admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
            const SizedBox(width: 8),
            Text('Delete Admin?', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete admin "${admin.displayName}"?\n\n'
          'Note: Admins with active tenants or historical payments cannot be deleted to protect tenant records. You may deactivate them instead.',
          style: GoogleFonts.lato(fontSize: 13.5, color: const Color(0xFF64748B), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.lato(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        await provider.deleteAdmin(widget.adminId);
        if (mounted) {
          FancyToast.showSuccess(context, 'Admin Deleted', message: 'Admin removed successfully');
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          FancyToast.showError(
            context,
            'Delete Failed',
            message: e.toString().replaceAll('Exception: ', ''),
          );
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrganizationProvider>();
    final admin = _getAdmin(orgProvider);

    if (admin == null) {
      if (orgProvider.isLoading) {
        return const Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Details')),
        body: const Center(child: Text('Admin not found.')),
      );
    }

    final String createdDate = admin.createdAt.isNotEmpty
        ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(admin.createdAt) ?? DateTime.now())
        : 'N/A';
    final trimmedName = admin.displayName.trim();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Admin Profile',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.primaryDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primaryDark, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
            tooltip: 'Edit Admin',
            onPressed: () async {
              final provider = context.read<OrganizationProvider>();
              await context.push('/org_edit_admin/${admin.id}');
              if (!mounted) return;
              provider.loadFromAPI(showLoading: false);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: admin.isActive ? AppTheme.accentColor : const Color(0xFFF1F5F9),
                      child: Text(
                        trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : 'A',
                        style: GoogleFonts.lato(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: admin.isActive ? AppTheme.primaryColor : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      admin.displayName,
                      style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        admin.adminCode,
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: admin.isActive ? AppTheme.successBg : AppTheme.dangerBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        admin.isActive ? 'Active Account' : 'Account Disabled',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: admin.isActive ? AppTheme.success : AppTheme.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Operational Stats
              Text(
                'Branch Operational Summary',
                style: GoogleFonts.lato(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem('Properties', '${admin.propertyCount}', Icons.apartment_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatItem('Rooms', '${admin.totalRooms}', Icons.door_front_door_outlined),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatItem(
                      'Beds',
                      '${admin.occupiedBeds}/${admin.totalBeds}',
                      Icons.bed_rounded,
                      subtitle: '${(admin.occupancyRate.clamp(0.0, 1.0) * 100).round()}% occupied',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem('Active Tenants', '${admin.totalTenants}', Icons.people_alt_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatItem(
                      'Rent Pending',
                      currencyFormat.format(admin.rentPending),
                      Icons.account_balance_wallet_outlined,
                      color: admin.rentPending > 0 ? AppTheme.danger : AppTheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Contact & Account Information
              Text(
                'Contact Information',
                style: GoogleFonts.lato(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.phone_outlined, 'Mobile Number', admin.phoneNumber),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _buildInfoRow(
                      Icons.email_outlined,
                      'Email Address',
                      admin.email != null && admin.email!.isNotEmpty ? admin.email! : 'Not provided',
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _buildInfoRow(Icons.calendar_today_outlined, 'Onboarded Date', createdDate),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _buildInfoRow(
                      Icons.apartment_rounded,
                      'Assigned PG(s)',
                      admin.propertyNames.isNotEmpty ? admin.propertyNames.join(', ') : 'None',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Account Controls
              Text(
                'Account Controls',
                style: GoogleFonts.lato(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Status Toggle Tile
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              admin.isActive ? 'Active Account' : 'Deactivated Account',
                              style: GoogleFonts.lato(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              admin.isActive ? 'Admin can log in and manage PGs' : 'Login and sessions are disabled',
                              style: GoogleFonts.lato(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        _isTogglingStatus
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Switch.adaptive(
                                value: admin.isActive,
                                activeColor: AppTheme.success,
                                onChanged: (val) => _toggleStatus(orgProvider, val),
                              ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),

                    // Edit Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/org_edit_admin/${admin.id}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text('Edit Admin Information', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Delete Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isDeleting ? null : () => _deleteAdmin(orgProvider, admin),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: Text('Delete Admin Account', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, {String? subtitle, Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? AppTheme.primaryColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color ?? AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.lato(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.lato(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.lato(fontSize: 11.5, color: const Color(0xFF64748B))),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.lato(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
