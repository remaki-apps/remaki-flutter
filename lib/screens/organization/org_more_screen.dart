import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/organization_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fancy_toast.dart';

class OrgMoreScreen extends StatelessWidget {
  const OrgMoreScreen({super.key});

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
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of the Organization portal?',
          style: GoogleFonts.lato(fontSize: 13.5, color: const Color(0xFF64748B)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.lato(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
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
              if (context.mounted) {
                try {
                  context.read<OrganizationProvider>().reset();
                } catch (_) {}
              }
              await ApiService.clearAuthToken();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text('Logout', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, OrganizationProvider provider) {
    final org = provider.currentOrganization;
    final nameController = TextEditingController(text: org?.name ?? '');
    final emailController = TextEditingController(text: org?.email ?? '');
    final phoneController = TextEditingController(text: org?.phoneNumber ?? '');
    final addressController = TextEditingController(text: org?.address ?? '');
    final cityController = TextEditingController(text: org?.city ?? '');

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Edit Organization Profile', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Organization Name *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email Address'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Contact Phone Number'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cityController,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.lato(color: const Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (nameController.text.trim().isEmpty) {
                          FancyToast.showError(context, 'Invalid Input', message: 'Organization name cannot be empty');
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          await provider.updateProfile({
                            'name': nameController.text.trim(),
                            'email': emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
                            'phoneNumber': phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                            'address': addressController.text.trim().isNotEmpty ? addressController.text.trim() : null,
                            'city': cityController.text.trim().isNotEmpty ? cityController.text.trim() : null,
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            FancyToast.showSuccess(context, 'Profile Updated', message: 'Organization profile updated successfully');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            FancyToast.showError(
                              context,
                              'Update Failed',
                              message: e.toString().replaceAll('Exception: ', ''),
                            );
                          }
                        }
                      },
                child: Text('Save', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrganizationProvider>();
    final org = orgProvider.currentOrganization;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organization Settings',
                style: GoogleFonts.lato(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 16),

              // Profile Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.accentColor,
                      child: Text(
                        org?.name.isNotEmpty == true ? org!.name[0].toUpperCase() : 'O',
                        style: GoogleFonts.lato(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  org?.name ?? 'Organization',
                                  style: GoogleFonts.lato(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                              ),
                              if (org?.code != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    org!.code,
                                    style: GoogleFonts.lato(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            org?.email ?? org?.phoneNumber ?? 'Master Account',
                            style: GoogleFonts.lato(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                      onPressed: () => _showEditProfileDialog(context, orgProvider),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Menu Options
              _buildSectionTitle('Preferences & Information'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Platform Fee & Settlements',
                      onTap: () => context.push('/org_platform_fee'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(
                      icon: Icons.business_outlined,
                      title: 'Edit Organization Details',
                      onTap: () => _showEditProfileDialog(context, orgProvider),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      onTap: () => context.push('/help_support'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About Remaki',
                      onTap: () => context.push('/about'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      onTap: () => context.push('/terms'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () => context.push('/privacy'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text('Logout from Organization', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.lato(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF64748B),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF64748B), size: 20),
      title: Text(
        title,
        style: GoogleFonts.lato(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryDark,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
