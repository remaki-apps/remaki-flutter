import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: const BackButton(color: Color(0xFF0F172A)),
        title: Text(
          'Privacy Policy',
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
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        children: [
          // 1. Hero Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF047857).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Global Privacy Standard',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Your Data & Privacy Protected',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'At Remaki, we believe property and tenant information must remain confidential, securely encrypted, and never commercialized.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFFD1FAE5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 2. Trust Pillars
          Row(
            children: [
              Expanded(
                child: _buildTrustCard(
                  icon: Icons.lock_outline_rounded,
                  title: '256-Bit SSL',
                  subtitle: 'In-Transit Encryption',
                  color: const Color(0xFF00B074),
                  bg: const Color(0xFFE8F8F0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTrustCard(
                  icon: Icons.do_not_disturb_on_outlined,
                  title: 'Zero Ads',
                  subtitle: 'Never Sold or Shared',
                  color: const Color(0xFF5B32E4),
                  bg: const Color(0xFFF0EAFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTrustCard(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Role-Based',
                  subtitle: 'Owner-Only Access',
                  color: const Color(0xFF0284C7),
                  bg: const Color(0xFFE0F2FE),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section Title
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'INFORMATION PRACTICES',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Policy Cards
          _buildPolicyCard(
            number: '01',
            title: 'Information We Collect',
            icon: Icons.folder_shared_outlined,
            iconColor: const Color(0xFF5B32E4),
            iconBg: const Color(0xFFF0EAFF),
            bullets: const [
              'Manager identity details: Property name, manager contact, email credentials.',
              'Resident records: Full name, phone number, emergency contacts, room and bed number.',
              'Financial data: Rent amounts, security deposit logs, payment transaction modes, and receipt notes.',
              'Technical diagnostics: Device OS, app performance logs, and push notification tokens.',
            ],
          ),
          const SizedBox(height: 12),

          _buildPolicyCard(
            number: '02',
            title: 'How Your Information Is Used',
            icon: Icons.tune_rounded,
            iconColor: const Color(0xFF00B074),
            iconBg: const Color(0xFFE8F8F0),
            bullets: const [
              'To generate automated monthly rent invoices and digital PDF receipts.',
              'To calculate occupancy rates and display real-time bed inventory.',
              'To send broadcast notifications (maintenance alerts, food timing announcements).',
              'To authenticate residents securely into their personal self-service portal.',
            ],
          ),
          const SizedBox(height: 12),

          _buildPolicyCard(
            number: '03',
            title: 'Data Storage & Encryption Architecture',
            icon: Icons.storage_rounded,
            iconColor: const Color(0xFF0284C7),
            iconBg: const Color(0xFFE0F2FE),
            bullets: const [
              'All database communications use TLS 1.3 encryption with certificate validation.',
              'Sensitive resident authentication tokens and passwords utilize hashed cryptography.',
              'Automated off-site cloud backups ensure rapid disaster recovery without data loss.',
            ],
          ),
          const SizedBox(height: 12),

          _buildPolicyCard(
            number: '04',
            title: 'Strict Non-Disclosure Guarantee',
            icon: Icons.verified_user_rounded,
            iconColor: const Color(0xFFFF7A00),
            iconBg: const Color(0xFFFFF2E8),
            bullets: const [
              'Remaki does NOT sell, lease, or monetize resident or property data to third parties.',
              'We do NOT inject third-party ad trackers or behavioral telemetry software.',
              'Information is accessed solely by property management staff authorized by the owner.',
            ],
          ),
          const SizedBox(height: 12),

          _buildPolicyCard(
            number: '05',
            title: 'Tenant Rights & Record Deletion',
            icon: Icons.delete_sweep_outlined,
            iconColor: const Color(0xFFEF4444),
            iconBg: const Color(0xFFFEF2F2),
            bullets: const [
              'Residents can view all collected personal records directly within their profile screen.',
              'Upon vacating, residents or property owners can request archival or complete anonymization of personal identifiers.',
              'Data deletion requests can be sent directly to our support desk for processing within 48 hours.',
            ],
          ),
          const SizedBox(height: 24),

          // Data Inquiries Box
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF00B074),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy Inquiries or Data Removal',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Email privacy team: remakiapps@gmail.com',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Copyright
          Center(
            child: Text(
              '© 2026 Remaki Technologies. All rights reserved.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTrustCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard({
    required String number,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required List<String> bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  number,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        height: 1.45,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
