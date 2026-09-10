import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          'Terms of Service',
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
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E1B4B).withValues(alpha: 0.22),
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
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
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
                        color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Effective Jan 2026',
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
                  'Remaki Terms of Service',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'These terms outline the rules and guidelines for using the Remaki PG & Hostel Management Platform by property owners, managers, staff, and residents.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 2. Summary Badges Row
          Row(
            children: [
              Expanded(
                child: _buildBadge(
                  icon: Icons.verified_outlined,
                  title: 'Binding Agreement',
                  color: const Color(0xFF5B32E4),
                  bg: const Color(0xFFF0EAFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBadge(
                  icon: Icons.security_rounded,
                  title: 'Fair Use Standards',
                  color: const Color(0xFF00B074),
                  bg: const Color(0xFFE8F8F0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBadge(
                  icon: Icons.cloud_done_rounded,
                  title: '99.9% Uptime SLA',
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
              'PLATFORM POLICIES & GUIDELINES',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Clauses Cards
          _buildClauseCard(
            number: '01',
            title: 'Acceptance & Account Eligibility',
            icon: Icons.badge_outlined,
            iconColor: const Color(0xFF5B32E4),
            iconBg: const Color(0xFFF0EAFF),
            content:
                'By accessing or using Remaki (via mobile application, tablet interface, or web dashboard), property managers and residents agree to be bound by these terms. You confirm that all business entity details and identity information provided are genuine, current, and legally accurate.',
          ),
          const SizedBox(height: 12),

          _buildClauseCard(
            number: '02',
            title: 'Property Manager Responsibilities',
            icon: Icons.manage_accounts_outlined,
            iconColor: const Color(0xFF00B074),
            iconBg: const Color(0xFFE8F8F0),
            content:
                'Property managers are solely responsible for ensuring tenant rent amounts, due dates, security deposit records, and room allocations conform to physical rental agreements. Managers must not use the platform to harass residents, record fraudulent dues, or misrepresent bed inventory.',
          ),
          const SizedBox(height: 12),

          _buildClauseCard(
            number: '03',
            title: 'Resident Portal & Access Standards',
            icon: Icons.person_pin_circle_outlined,
            iconColor: const Color(0xFFFF7A00),
            iconBg: const Color(0xFFFFF2E8),
            content:
                'Residents accessing the tenant self-service portal must keep their mobile credentials and security PIN confidential. Rent payment proof uploads (UPI transaction IDs, receipts, and screenshots) must be legitimate. Misleading financial submissions may result in account restriction.',
          ),
          const SizedBox(height: 12),

          _buildClauseCard(
            number: '04',
            title: 'Financial Records & Payment Disclaimers',
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF4F46E5),
            iconBg: const Color(0xFFEEF2FF),
            content:
                'Remaki is a software ledger and operations management utility. Unless explicitly configured via third-party integrated payment gateways, cash payments and direct UPI transactions occur directly between tenants and property bank accounts. Remaki does not custody tenant deposit funds.',
          ),
          const SizedBox(height: 12),

          _buildClauseCard(
            number: '05',
            title: 'Service Availability & Modifications',
            icon: Icons.sync_problem_rounded,
            iconColor: const Color(0xFF0284C7),
            iconBg: const Color(0xFFE0F2FE),
            content:
                'We continuously maintain high service reliability, automated data backups, and low-latency cloud synchronization. Remaki reserves the right to introduce feature upgrades, improve algorithms, or conduct scheduled maintenance with advance notice to administrators.',
          ),
          const SizedBox(height: 12),

          _buildClauseCard(
            number: '06',
            title: 'Account Closure & Data Retention',
            icon: Icons.archive_outlined,
            iconColor: const Color(0xFFEF4444),
            iconBg: const Color(0xFFFEF2F2),
            content:
                'Property managers may request workspace offboarding or archive resident stays upon contract expiration. Historical payment entries may be retained as necessary to fulfill statutory tax, billing reconciliation, and accounting audits.',
          ),
          const SizedBox(height: 24),

          // Contact & Questions Box
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
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.contact_support_rounded,
                    color: Color(0xFF475569),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Questions about Terms?',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Contact legal & operations: remakiapps@gmail.com',
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

  Widget _buildBadge({
    required IconData icon,
    required String title,
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
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClauseCard({
    required String number,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String content,
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
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.5,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
