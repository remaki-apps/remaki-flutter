import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/organization_models.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fancy_toast.dart';

class OrgAdminSuccessScreen extends StatelessWidget {
  final AdminCreatedPayload payload;
  final String propertyName;

  const OrgAdminSuccessScreen({
    super.key,
    required this.payload,
    this.propertyName = '',
  });

  Future<void> _shareOnWhatsApp(BuildContext context, String orgName) async {
    final message = buildAdminCredentialsMessage(
      orgName: orgName,
      adminName: payload.admin.displayName,
      adminCode: payload.admin.adminCode,
      phone: payload.admin.phoneNumber,
      password: payload.tempPassword,
      propertyName: propertyName,
    );

    final cleanPhone = payload.admin.phoneNumber.replaceAll(RegExp(r'\D'), '');
    final fullPhone = cleanPhone.startsWith('91') && cleanPhone.length == 12
        ? cleanPhone
        : (cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone);

    final whatsappUrl = Uri.parse('whatsapp://send?phone=$fullPhone&text=$message');
    final webWhatsappUrl = Uri.parse('https://wa.me/$fullPhone?text=$message');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webWhatsappUrl)) {
        await launchUrl(webWhatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          FancyToast.showError(context, 'WhatsApp not installed', message: 'WhatsApp is not installed on this device');
        }
      }
    } catch (_) {
      if (context.mounted) {
        FancyToast.showError(context, 'Unable to open WhatsApp');
      }
    }
  }

  void _copyCredentials(BuildContext context) {
    final text = 'Remaki Admin Credentials:\n'
        '• Admin Name: ${payload.admin.displayName}\n'
        '• Admin Code: ${payload.admin.adminCode}\n'
        '• Mobile: ${payload.admin.phoneNumber}\n'
        '• Password: ${payload.tempPassword}\n'
        '${propertyName.isNotEmpty ? "• PG Property: $propertyName\n" : ""}'
        'Login: https://remaki-flutter.vercel.app';

    Clipboard.setData(ClipboardData(text: text));
    FancyToast.showSuccess(context, 'Credentials Copied', message: 'Admin login credentials copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final org = context.read<OrganizationProvider>().currentOrganization;
    final orgName = org?.name ?? 'Organization';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/org_admins');
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Success Badge Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.successBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.success.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.success,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Admin Onboarded Successfully!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The new branch admin account is ready. Share the login credentials below.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // Credentials Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF9FE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildCredentialRow('Admin Name', payload.admin.displayName),
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                      _buildCredentialRow('Admin Code', payload.admin.adminCode, isHighlight: true),
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                      _buildCredentialRow('Mobile Number', payload.admin.phoneNumber),
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                      _buildCredentialRow(
                        'Temporary Password',
                        payload.tempPassword,
                        isSecret: true,
                        onCopy: () {
                          Clipboard.setData(ClipboardData(text: payload.tempPassword));
                          FancyToast.showSuccess(context, 'Password Copied');
                        },
                      ),
                      if (propertyName.isNotEmpty) ...[
                        const Divider(height: 20, color: Color(0xFFE2E8F0)),
                        _buildCredentialRow('Assigned PG', propertyName),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // WhatsApp Share Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareOnWhatsApp(context, orgName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: Text(
                      'Share Credentials via WhatsApp',
                      style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Copy to Clipboard Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _copyCredentials(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(
                      'Copy All Details',
                      style: GoogleFonts.lato(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Return to Admins
                TextButton(
                  onPressed: () => context.go('/org_admins'),
                  child: Text(
                    'Return to Admin Management',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isSecret = false,
    VoidCallback? onCopy,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 13,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: isHighlight
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
                  : EdgeInsets.zero,
              decoration: isHighlight
                  ? BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Text(
                value,
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isHighlight
                      ? AppTheme.primaryColor
                      : (isSecret ? const Color(0xFF0F172A) : AppTheme.primaryDark),
                  letterSpacing: isSecret ? 0.5 : 0,
                ),
              ),
            ),
            if (onCopy != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onCopy,
                child: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryColor),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
