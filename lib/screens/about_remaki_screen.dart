import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutRemakiScreen extends StatelessWidget {
  const AboutRemakiScreen({super.key});

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
          'About Remaki',
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
          // 1. Hero Brand Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo
                Image.asset(
                  'assets/logo/logo_word.png',
                  height: 38,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B32E4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'REMAKI',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Version 1.0.0 (Build 1)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Smart Hostel & PG Operating System',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Remaki is an end-to-end management platform designed for modern paying guest accommodations, student hostels, and co-living properties. It automates rent collections, tenant onboarding, inventory allocation, and resident communications.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 2. Core Capabilities
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'PLATFORM CAPABILITIES',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ),
          _buildFeatureCard(
            icon: Icons.hotel_rounded,
            iconColor: const Color(0xFF5B32E4),
            iconBg: const Color(0xFFF0EAFF),
            title: 'Real-Time Inventory & Bed Mapping',
            description:
                'Floor-by-floor room configuration, instant bed availability status, and automated occupancy tracking across all property rooms.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.payments_rounded,
            iconColor: const Color(0xFF00B074),
            iconBg: const Color(0xFFE8F8F0),
            title: 'Automated Rent & Billing Cycle',
            description:
                'Track monthly rents, calculate pending balances, log manual cash payments, and verify resident UPI payment screenshots effortlessly.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.groups_rounded,
            iconColor: const Color(0xFFFF7A00),
            iconBg: const Color(0xFFFFF2E8),
            title: 'Tenant Directory & Digital KYC',
            description:
                'Store resident records, track move-in and due dates, issue one-click WhatsApp credentials, and manage tenant lifecycles seamlessly.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.campaign_rounded,
            iconColor: const Color(0xFF4F46E5),
            iconBg: const Color(0xFFEEF2FF),
            title: 'Live Notice Board & Broadcasts',
            description:
                'Broadcast emergency maintenance alerts, food timing changes, and PG notices instantly with optional photo attachments.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.phone_android_rounded,
            iconColor: const Color(0xFF0284C7),
            iconBg: const Color(0xFFE0F2FE),
            title: 'Resident Self-Service Portal',
            description:
                'Residents log in with their phone and secure PIN to view rent breakdowns, download receipts, and upload payment proof anytime.',
          ),
          const SizedBox(height: 28),

          // 3. Footer
          Center(
            child: Column(
              children: [
                Text(
                  '© 2026 Remaki Technologies. All rights reserved.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Empowering modern co-living communities.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    height: 1.45,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
