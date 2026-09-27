import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String? primaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;
  final VoidCallback? onBackPressed;
  final Widget? bottomContent;

  const SuccessScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.details,
    this.primaryButtonText,
    this.onPrimaryPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
    this.onBackPressed,
    this.bottomContent,
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
          onPressed: onBackPressed ?? () => context.go('/tenants'),
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

              if (bottomContent != null) ...[
                const SizedBox(height: 12),
                bottomContent!,
              ] else if (primaryButtonText != null && onPrimaryPressed != null) ...[
                const SizedBox(height: 12),
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
                                primaryButtonText!,
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
      '🌟 *Welcome to ${provider.pgName}!* 🌟\n\n'
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
      '*${provider.pgName} Management*'
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

  void _copyPasswordToClipboard(String pwd) {
    Clipboard.setData(ClipboardData(text: pwd));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Password copied to clipboard', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
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

    final String roomDisplay = currentRoom.isNotEmpty
        ? 'Room $currentRoom${currentFloor.isNotEmpty ? ' ($currentFloor)' : ''}'
        : widget.roomBed;

    return SuccessScreen(
      title: 'Tenant Onboarded Successfully!',
      subtitle: 'Profile created & room allocation active',
      details: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tenant Avatar & Header Row
            Row(
              children: [
                TenantAvatar(name: widget.name, radius: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.phone,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // Classic Key-Value List
            _buildDetailRow(
              label: 'Room & Floor',
              value: roomDisplay,
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              label: 'Monthly Rent',
              value: '₹${widget.rent}',
              valueColor: const Color(0xFF047857),
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              label: 'Move-in Date',
              value: widget.moveIn.isEmpty ? 'Today' : widget.moveIn,
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // Remaki App Credentials Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Remaki App Password',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayPassword,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primaryColor),
                    onPressed: () => _copyPasswordToClipboard(displayPassword),
                    tooltip: 'Copy password',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // WhatsApp Share Button or Sent Banner
            if (!isCredentialsSent)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendWhatsAppCredentials,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Image.asset(
                    'assets/icons/whatsapp.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  ),
                  label: const Text(
                    'Send Credentials via WhatsApp',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                    ),
                  ],
                ),
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

  static Widget _buildDetailRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class PaymentSuccessScreen extends StatefulWidget {
  final String amount;
  final String name;
  final String roomBed;
  final String dateMethod;
  final String? tenantId;

  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    required this.name,
    required this.roomBed,
    required this.dateMethod,
    this.tenantId,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Auto-navigate to previous screen after brief confirmation
    _timer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _navigateBack();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _navigateBack() {
    _timer?.cancel();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else if (widget.tenantId != null && widget.tenantId!.isNotEmpty) {
      context.go('/tenant_profile/${widget.tenantId}');
    } else {
      context.go('/tenants');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _timer?.cancel();
      },
      child: SuccessScreen(
        title: 'Payment Recorded Successfully!',
        subtitle: 'Rent payment has been credited',
        onBackPressed: _navigateBack,
        bottomContent: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64748B)),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Returning to previous screen...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
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
                      '₹${widget.amount}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tenant Row
              Row(
                children: [
                  TenantAvatar(name: widget.name, radius: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.roomBed,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          widget.dateMethod,
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
      ),
    );
  }
}
