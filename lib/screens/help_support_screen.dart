import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/fancy_toast.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const String supportName = 'Kishore';
  static const String supportPhone = '9940328087';
  static const String supportEmail = 'remakiapps@gmail.com';

  final List<Map<String, dynamic>> _faqs = [
    {
      'question': 'How do I add a new resident and allocate a bed?',
      'answer':
          'Navigate to Rooms, choose an available room or bed, and tap "Allocate Tenant". Enter their basic details (name, phone, rent amount, security deposit, and move-in date) to immediately register them in the system.',
      'isExpanded': false,
    },
    {
      'question': 'How do tenants get their login credentials?',
      'answer':
          'Once a tenant is added, Remaki generates their unique login link. You can tap "Share on WhatsApp" to send their login phone number and auto-generated security PIN directly to their device.',
      'isExpanded': false,
    },
    {
      'question': 'How do I record offline cash or direct UPI payments?',
      'answer':
          'Open the Tenant profile or Pending Payments screen, tap "Record Payment", enter the paid amount, select the payment mode (Cash, UPI, GPay, Bank Transfer), and submit. The balance updates in real-time.',
      'isExpanded': false,
    },
    {
      'question': 'How does the Announcements board work?',
      'answer':
          'Go to Announcements from the main dashboard, enter your title, category, and message (with optional image attach), and tap "Post Now". The alert immediately broadcasts to all active tenant devices.',
      'isExpanded': false,
    },
    {
      'question': 'What happens when a tenant checks out or vacates?',
      'answer':
          'On the tenant profile, tap "Vacate / Checkout". The bed immediately returns to the "Available Beds" pool for new allocations, while past payment receipts and transaction records remain archived safely.',
      'isExpanded': false,
    },
  ];

  Future<void> _makePhoneCall() async {
    final uri = Uri.parse('tel:+91$supportPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(const ClipboardData(text: supportPhone));
      if (mounted) {
        FancyToast.showSuccess(context, 'Phone Copied', message: '+91 $supportPhone');
      }
    }
  }

  Future<void> _openWhatsApp() async {
    final msg = Uri.encodeComponent('Hi Kishore, I need help with the Remaki App.');
    final uri = Uri.parse('https://wa.me/91$supportPhone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(const ClipboardData(text: supportPhone));
      if (mounted) {
        FancyToast.showSuccess(context, 'Phone Copied', message: '+91 $supportPhone');
      }
    }
  }

  Future<void> _sendEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': 'Remaki App Support Request - $supportName'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
      if (mounted) {
        FancyToast.showSuccess(context, 'Email Copied', message: supportEmail);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: const BackButton(color: Color(0xFF0F172A)),
        title: Text(
          'Help & Support',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE9ECEF), height: 1),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        children: [
          // 1. Classic Minimalist Lead Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE9ECEF), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          supportName[0],
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
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
                                  color: const Color(0xFF0F172A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Active',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF475569),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Remaki Support & Operations',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: Color(0xFF64748B),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mon – Sat, 9:00 AM – 9:00 PM IST  •  Fast resolution',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF475569),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Classic Minimal "Get in Touch" Section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'GET IN TOUCH',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Unified Classic Contact Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE9ECEF), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Phone Row
                _buildClassicContactTile(
                  icon: Icons.phone_outlined,
                  title: 'Phone Call',
                  subtitle: '+91 $supportPhone',
                  actionText: 'Call',
                  isFirst: true,
                  onTap: _makePhoneCall,
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9), indent: 56),

                // WhatsApp Row
                _buildClassicContactTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'WhatsApp Chat',
                  subtitle: 'Direct messaging with Kishore',
                  actionText: 'Message',
                  onTap: _openWhatsApp,
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9), indent: 56),

                // Email Row
                _buildClassicContactTile(
                  icon: Icons.mail_outline_rounded,
                  title: 'Email Inquiries',
                  subtitle: supportEmail,
                  actionText: 'Email',
                  isLast: true,
                  onTap: _sendEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 3. Frequently Asked Questions
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE9ECEF), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: _faqs.asMap().entries.map((entry) {
                final index = entry.key;
                final faq = entry.value;
                final isExpanded = faq['isExpanded'] as bool;
                final isLast = index == _faqs.length - 1;

                return Column(
                  children: [
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: Key('faq_$index'),
                        initiallyExpanded: isExpanded,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        iconColor: const Color(0xFF0F172A),
                        collapsedIconColor: const Color(0xFF94A3B8),
                        title: Text(
                          faq['question'],
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        onExpansionChanged: (expanded) {
                          setState(() {
                            faq['isExpanded'] = expanded;
                          });
                        },
                        children: [
                          Text(
                            faq['answer'],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              height: 1.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 28),

          // Copyright
          Center(
            child: Column(
              children: [
                Text(
                  'Remaki Support Desk',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '© 2026 Remaki Technologies',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildClassicContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(20) : Radius.zero,
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF0F172A),
                size: 20,
              ),
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
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                actionText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
