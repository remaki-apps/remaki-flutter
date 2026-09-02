import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';

class SuccessScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget details;
  final String primaryButtonText;
  final VoidCallback onPrimaryPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;

  const SuccessScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => context.go('/tenants'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      
                      // Success Badge Graphic
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Title & Subtitle
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Details Card
                      details,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom Action Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: onPrimaryPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              primaryButtonText,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (secondaryButtonText != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onSecondaryPressed,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          secondaryButtonText!,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TenantAddedSuccessScreen extends StatefulWidget {
  final String? tenantId;
  final String? password;
  final String name;
  final String phone;
  final String? roomNumber;
  final String? floor;
  final String roomBed;
  final String rent;
  final String moveIn;

  const TenantAddedSuccessScreen({
    super.key,
    this.tenantId,
    this.password,
    required this.name,
    this.phone = '',
    this.roomNumber,
    this.floor,
    required this.roomBed,
    required this.rent,
    required this.moveIn,
  });

  @override
  State<TenantAddedSuccessScreen> createState() => _TenantAddedSuccessScreenState();
}

class _TenantAddedSuccessScreenState extends State<TenantAddedSuccessScreen> {
  bool _isSentLocally = false;

  Future<void> _sendWhatsAppCredentials() async {
    final cleanPhone = widget.phone.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    String currentRoom = widget.roomNumber ?? '';
    String currentFloor = widget.floor ?? '';
    String currentPassword = widget.password ?? '';
    
    final tenantIndex = provider.tenants.indexWhere((t) => (widget.tenantId != null && t.id == widget.tenantId) || (t.phone.isNotEmpty && cleanPhone.isNotEmpty && cleanPhone.endsWith(t.phone.replaceAll(RegExp(r'\D'), ''))));
    if (tenantIndex != -1) {
      final t = provider.tenants[tenantIndex];
      if (currentPassword.isEmpty) currentPassword = t.password;
      final rIndex = provider.rooms.indexWhere((r) => r.id == t.roomId);
      if (rIndex != -1) {
        if (currentRoom.isEmpty) currentRoom = provider.rooms[rIndex].number;
        if (currentFloor.isEmpty) currentFloor = provider.rooms[rIndex].floor;
      }
    }
    if (currentPassword.isEmpty) currentPassword = 'hi123';

    final stayDetailsText = (currentRoom.isNotEmpty || currentFloor.isNotEmpty)
      ? '🏠 *Stay Details:*\n'
        '${currentRoom.isNotEmpty ? '• *Room:* Room $currentRoom\n' : ''}'
        '${currentFloor.isNotEmpty ? '• *Floor:* $currentFloor\n' : ''}\n'
      : '';

    final message = Uri.encodeComponent(
      '🌟 *Welcome to Sunshine PG!* 🌟\n\n'
      'Dear ${widget.name},\n\n'
      'Your tenant portal account is ready on the *Remaki* app. You can now use the app to track your rent payments, view payment receipts, and manage your stay.\n\n'
      '$stayDetailsText'
      '🔐 *Your Remaki App Login Credentials:*\n'
      '────────────────────────────\n'
      '📱 *Mobile Number:* ${widget.phone}\n'
      '🔑 *Password:* $currentPassword\n'
      '────────────────────────────\n\n'
      '📲 *Next Steps:*\n'
      '1️⃣ Download & open the *Remaki* app.\n'
      '2️⃣ Log in using your registered mobile number and password above.\n\n'
      'If you have any questions, please reach out to the management.\n\n'
      'Best regards,\n'
      '*Sunshine PG Management*'
    );
    final url = Uri.parse('https://wa.me/$formattedPhone?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (mounted) {
        setState(() {
          _isSentLocally = true;
        });
        final provider = Provider.of<AppProvider>(context, listen: false);
        if (widget.tenantId != null && widget.tenantId!.isNotEmpty) {
          provider.markCredentialsSent(widget.tenantId!);
        } else if (widget.phone.isNotEmpty) {
          provider.markCredentialsSentByPhone(widget.phone);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final tenantSentInStore = provider.tenants.any((t) {
      if (widget.tenantId != null && widget.tenantId!.isNotEmpty && t.id == widget.tenantId) {
        return t.credentialsSent;
      }
      final cleanPhone = widget.phone.replaceAll(RegExp(r'\D'), '');
      final tPhone = t.phone.replaceAll(RegExp(r'\D'), '');
      return tPhone.isNotEmpty && cleanPhone.isNotEmpty && (tPhone.endsWith(cleanPhone) || cleanPhone.endsWith(tPhone)) && t.credentialsSent;
    });

    final isCredentialsSent = _isSentLocally || tenantSentInStore;

    String displayPassword = widget.password ?? '';
    String currentRoom = widget.roomNumber ?? '';
    String currentFloor = widget.floor ?? '';

    final tIndex = provider.tenants.indexWhere((t) {
      if (widget.tenantId != null && widget.tenantId!.isNotEmpty && t.id == widget.tenantId) return true;
      final cleanPhone = widget.phone.replaceAll(RegExp(r'\D'), '');
      final tPhone = t.phone.replaceAll(RegExp(r'\D'), '');
      return tPhone.isNotEmpty && cleanPhone.isNotEmpty && (tPhone.endsWith(cleanPhone) || cleanPhone.endsWith(tPhone));
    });

    if (tIndex != -1) {
      final t = provider.tenants[tIndex];
      if (displayPassword.isEmpty) displayPassword = t.password;
      final rIndex = provider.rooms.indexWhere((r) => r.id == t.roomId);
      if (rIndex != -1) {
        if (currentRoom.isEmpty) currentRoom = provider.rooms[rIndex].number;
        if (currentFloor.isEmpty) currentFloor = provider.rooms[rIndex].floor;
      }
    }
    if (displayPassword.isEmpty) displayPassword = 'hi123';

    return SuccessScreen(
      title: 'Tenant Onboarded Successfully!',
      subtitle: 'Tenant profile and room allocation are active',
      details: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Tags
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.stars_rounded, size: 14, color: AppTheme.primaryColor),
                      SizedBox(width: 5),
                      Text(
                        'NEW TENANT PROFILE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                      SizedBox(width: 5),
                      Text(
                        'Active Stay',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 18),

            // Tenant Main Hero Info Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                  ),
                  child: TenantAvatar(name: widget.name, radius: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.meeting_room_outlined, size: 12, color: Color(0xFF475569)),
                                const SizedBox(width: 4),
                                Text(
                                  (currentRoom.isNotEmpty) ? 'Room $currentRoom' : widget.roomBed,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                          if (widget.phone.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.phone,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Remaki App Credentials Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.vpn_key_rounded, size: 15, color: AppTheme.primaryColor),
                          SizedBox(width: 6),
                          Text(
                            'REMAKI APP CREDENTIALS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: const Text(
                          'DEFAULT',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.smartphone_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            widget.phone.isNotEmpty ? widget.phone : 'Registered Mobile',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              displayPassword,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // WhatsApp Share Button or Sent Banner
            if (!isCredentialsSent)
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF25D366), Color(0xFF16A34A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D366).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _sendWhatsAppCredentials,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Image.asset(
                      'assets/icons/whatsapp.png',
                      width: 22,
                      height: 22,
                    ),
                    label: const Text(
                      'Send Credentials via WhatsApp',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Credentials Sent via WhatsApp',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 18),

            // 2x2 Details Grid
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    label: 'MONTHLY RENT',
                    value: '₹${widget.rent}',
                    icon: Icons.payments_outlined,
                    accentColor: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDetailCard(
                    label: 'MOVE-IN DATE',
                    value: widget.moveIn.isEmpty ? 'Today' : widget.moveIn,
                    icon: Icons.calendar_month_outlined,
                    accentColor: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    label: 'ROOM & FLOOR',
                    value: currentRoom.isNotEmpty ? 'Room $currentRoom${currentFloor.isNotEmpty ? ' ($currentFloor)' : ''}' : widget.roomBed,
                    icon: Icons.apartment_rounded,
                    accentColor: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDetailCard(
                    label: 'TENANT PORTAL',
                    value: 'Remaki App',
                    icon: Icons.verified_user_outlined,
                    accentColor: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      secondaryButtonText: 'Add Another Tenant',
      onSecondaryPressed: () => context.go('/add_tenant'),
      primaryButtonText: 'Go to Tenants List',
      onPrimaryPressed: () => context.go('/tenants'),
    );
  }

  static Widget _buildDetailCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: accentColor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class PaymentSuccessScreen extends StatelessWidget {
  final String amount;
  final String name;
  final String roomBed;
  final String dateMethod;

  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    required this.name,
    required this.roomBed,
    required this.dateMethod,
  });

  @override
  Widget build(BuildContext context) {
    return SuccessScreen(
      title: 'Payment Recorded Successfully!',
      subtitle: 'Rent payment has been credited',
      details: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Amount Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Column(
                children: [
                  const Text(
                    'AMOUNT RECEIVED',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹$amount',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tenant Row
            Row(
              children: [
                TenantAvatar(name: name, radius: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roomBed,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      Text(
                        dateMethod,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      primaryButtonText: 'Go to Tenants List',
      onPrimaryPressed: () => context.go('/tenants'),
      secondaryButtonText: 'Back to Dashboard',
      onSecondaryPressed: () => context.go('/'),
    );
  }
}
