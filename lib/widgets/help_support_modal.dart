import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'fancy_toast.dart';

class HelpSupportModal {
  static const String supportName = 'Kishore';
  static const String supportPhone = '9940328087';
  static const String supportEmail = 'remakiapps@gmail.com';

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 30,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Representative Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4338CA).withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: const Center(
                      child: Text(
                        'K',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
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
                            Text(
                              supportName,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'ONLINE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Remaki Help & Support Lead',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Text(
              'REACH OUT VIA',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            // Call Action
            _buildContactTile(
              icon: Icons.phone_rounded,
              iconColor: const Color(0xFF00B074),
              iconBg: const Color(0xFFE8F8F0),
              title: 'Direct Phone Call',
              subtitle: '+91 $supportPhone',
              actionLabel: 'Call Now',
              onTap: () async {
                final uri = Uri.parse('tel:+91$supportPhone');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  await Clipboard.setData(const ClipboardData(text: supportPhone));
                  if (ctx.mounted) {
                    FancyToast.showSuccess(ctx, 'Phone Copied', message: supportPhone);
                  }
                }
              },
            ),
            const SizedBox(height: 10),

            // WhatsApp Action
            _buildContactTile(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              iconBg: const Color(0xFFE8F8EE),
              title: 'WhatsApp Chat',
              subtitle: 'Quick response & live assistance',
              actionLabel: 'Message',
              onTap: () async {
                final msg = Uri.encodeComponent('Hi Kishore, I need help with the Remaki App.');
                final uri = Uri.parse('https://wa.me/91$supportPhone?text=$msg');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  await Clipboard.setData(const ClipboardData(text: supportPhone));
                  if (ctx.mounted) {
                    FancyToast.showSuccess(ctx, 'Phone Copied', message: supportPhone);
                  }
                }
              },
            ),
            const SizedBox(height: 10),

            // Email Action
            _buildContactTile(
              icon: Icons.mail_rounded,
              iconColor: const Color(0xFF5B32E4),
              iconBg: const Color(0xFFF0EAFF),
              title: 'Email Support',
              subtitle: supportEmail,
              actionLabel: 'Send Mail',
              onTap: () async {
                final uri = Uri(
                  scheme: 'mailto',
                  path: supportEmail,
                  queryParameters: {'subject': 'Remaki App Support Request - $supportName'},
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  await Clipboard.setData(const ClipboardData(text: supportEmail));
                  if (ctx.mounted) {
                    FancyToast.showSuccess(ctx, 'Email Copied', message: supportEmail);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildContactTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            actionLabel,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: iconColor),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
