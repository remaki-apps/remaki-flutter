import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';
import '../widgets/fancy_toast.dart';
import 'edit_financials_dialog.dart';

class TenantProfileScreen extends StatelessWidget {
  final String tenantId;
  const TenantProfileScreen({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final tenantIndex = appProvider.tenants.indexWhere((t) => t.id == tenantId);

    if (tenantIndex == -1) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Tenant not found', style: TextStyle(color: Color(0xFF64748B))),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tenant = appProvider.tenants[tenantIndex];
    final roomIndex = appProvider.rooms.indexWhere((r) => r.id == tenant.roomId);
    final roomNumber = roomIndex != -1 ? appProvider.rooms[roomIndex].number : 'N/A';
    final floorName = roomIndex != -1 ? appProvider.rooms[roomIndex].floor : 'N/A';
    final bedName = (roomIndex != -1)
        ? appProvider.rooms[roomIndex].beds.firstWhere((b) => b.id == tenant.bedId, orElse: () => appProvider.rooms[roomIndex].beds.first).name
        : 'N/A';

    final tenantPayments = appProvider.payments.where((p) => p.tenantId == tenantId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tenant Profile',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'View and manage tenant details',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showVacateDialog(context, appProvider, tenant, roomNumber, bedName),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_remove_outlined, color: Color(0xFFEF4444), size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Hero Profile Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        children: [
                          TenantAvatar(
                            name: tenant.name,
                            imageUrl: tenant.imageUrl,
                            radius: 42,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tenant.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Room $roomNumber • $bedName',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Action Buttons (WhatsApp, Call, Collect Rent)
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final sanitizedPhone = tenant.phone.replaceAll(RegExp(r'\D'), '');
                                    final phoneNum = sanitizedPhone.startsWith('91') ? sanitizedPhone : '91$sanitizedPhone';
                                    final message = tenant.buildDetailedRentBillMessage(roomNumber: roomNumber, floorName: floorName, pgName: appProvider.pgName);
                                    final url = Uri.parse('https://wa.me/$phoneNum?text=$message');
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/icons/whatsapp.png',
                                          width: 16,
                                          height: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        const Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'WhatsApp',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF15803D),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final cleanPhone = tenant.phone.replaceAll(RegExp(r'[^\d+]'), '');
                                    final url = Uri.parse('tel:$cleanPhone');
                                    try {
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url);
                                      } else {
                                        await launchUrl(url, mode: LaunchMode.externalApplication);
                                      }
                                    } catch (e) {
                                      debugPrint('Could not launch phone dialer: $e');
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.phone_outlined, color: Color(0xFF475569), size: 16),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Call',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => context.push('/record_payment/${tenant.id}'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFC7D2FE)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.payments_outlined, color: AppTheme.primaryColor, size: 16),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Collect Rent',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!tenant.credentialsSent) ...[
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () async {
                                final sanitizedPhone = tenant.phone.replaceAll(RegExp(r'\D'), '');
                                final phoneNum = sanitizedPhone.startsWith('91') ? sanitizedPhone : '91$sanitizedPhone';
                                final message = Uri.encodeComponent(
                                  '🌟 *Welcome to ${appProvider.pgName}!* 🌟\n\n'
                                  'Dear ${tenant.name},\n\n'
                                  'Your tenant portal account is ready on the *Remaki* app. You can now use the app to track your rent payments, view payment receipts, and manage your stay.\n\n'
                                  '🏠 *Stay Details:*\n'
                                  '• *Room:* Room $roomNumber\n'
                                  '• *Floor:* $floorName\n\n'
                                  '🔐 *Your Remaki App Login Credentials:*\n'
                                  '────────────────────────────\n'
                                  '📱 *Mobile Number:* ${tenant.phone}\n'
                                  '🔑 *Password:* ${tenant.password}\n'
                                  '────────────────────────────\n\n'
                                  '📲 *Next Steps:*\n'
                                  '1️⃣ Download & open the *Remaki* app.\n'
                                  '2️⃣ Log in using your registered mobile number and password above.\n\n'
                                  'If you have any questions, please reach out to the management.\n\n'
                                  'Best regards,\n'
                                  '*${appProvider.pgName} Management*'
                                );
                                final url = Uri.parse('https://wa.me/$phoneNum?text=$message');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                  appProvider.markCredentialsSent(tenant.id);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/icons/whatsapp.png',
                                      width: 18,
                                      height: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Send Remaki Credentials via WhatsApp',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Financial Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: tenant.totalDue == 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: tenant.totalDue == 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Due', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: tenant.totalDue == 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tenant.totalDue == 0 ? 'PAID' : (tenant.pendingRentAmount < tenant.rentAmount && tenant.pendingRentAmount > 0 ? 'PARTIAL' : 'DUE'),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: tenant.totalDue == 0 ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tenant.totalDue == 0 ? '₹0' : '₹${tenant.totalDue.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: tenant.totalDue == 0 ? const Color(0xFF15803D) : const Color(0xFFC2410C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Deposit', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${tenant.securityDeposit.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Personal Information',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              GestureDetector(
                                onTap: () => _showEditFinancialsDialog(context, appProvider, tenant),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 14, color: AppTheme.primaryColor),
                                      SizedBox(width: 4),
                                      Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildModernDetailItem(Icons.phone_outlined, 'Phone', tenant.phone),
                          _buildModernDetailItem(Icons.email_outlined, 'Email', tenant.email),
                          _buildModernDetailItem(Icons.calendar_today_outlined, 'Move-in Date', DateFormat('dd/MM/yyyy').format(tenant.moveInDate)),
                          _buildModernDetailItem(Icons.payments_outlined, 'Monthly Rent', '₹${tenant.rentAmount.toStringAsFixed(0)}'),
                          if (!tenant.isPaid && tenant.pendingRentAmount > 0 && tenant.pendingRentAmount < tenant.rentAmount)
                            _buildModernDetailItem(Icons.account_balance_wallet_outlined, 'Rent Balance Due', '₹${tenant.pendingRentAmount.toStringAsFixed(0)}', isHighlight: true),
                          ...tenant.additionalCharges.where((c) => c.billType != 'RENT').map(
                            (c) {
                              final dueDateStr = c.billDueDate != null
                                  ? ' (due ${DateFormat('dd/MM').format(c.billDueDate!)})'  
                                  : '';
                              return _buildModernDetailItem(
                                Icons.receipt_long_outlined,
                                '${c.description}$dueDateStr',
                                '+ ₹${c.amount.toStringAsFixed(0)}',
                              );
                            },
                          ),
                          if (tenant.additionalCharges.where((c) => c.billType != 'RENT').isNotEmpty)
                            _buildModernDetailItem(Icons.account_balance_wallet_outlined, 'Total Due', '₹${tenant.totalDue.toStringAsFixed(0)}', isHighlight: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Payment History Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Payment History',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '${tenantPayments.length} Payments',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (tenantPayments.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: const Center(
                          child: Text('No recorded payments yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        ),
                      )
                    else
                      ...tenantPayments.map((payment) {
                        final dateStr = DateFormat('dd MMM yyyy').format(payment.date);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Icon(Icons.receipt_outlined, color: Color(0xFF475569), size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dateStr,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        payment.method,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '₹${payment.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('PAID', style: TextStyle(color: Color(0xFF16A34A), fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDetailItem(IconData icon, String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isHighlight ? AppTheme.primaryColor : const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isHighlight ? AppTheme.primaryColor : const Color(0xFF64748B),
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppTheme.primaryColor : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  void _showVacateDialog(BuildContext context, AppProvider appProvider, dynamic tenant, String roomNumber, String bedName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon Circle
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 28),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Vacate Tenant?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),

              Text(
                'Are you sure you want to vacate ${tenant.name}?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Room & Bed Info Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.meeting_room_outlined, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Text(
                      'Room $roomNumber • $bedName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),

              // Pending Dues Warning Alert
              if (tenant.totalDue > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tenant has pending dues of ₹${tenant.totalDue.toStringAsFixed(0)}.',
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        appProvider.vacateTenant(tenant.id);
                        Navigator.of(ctx).pop();
                        context.pop();
                        FancyToast.showSuccess(
                          context,
                          'Tenant Vacated!',
                          message: '${tenant.name} has been vacated from Room $roomNumber - $bedName.',
                        );
                      },
                      child: const Text(
                        'Vacate Tenant',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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

  void _showEditFinancialsDialog(BuildContext context, AppProvider appProvider, dynamic tenant) {
    showDialog(
      context: context,
      builder: (ctx) => EditFinancialsDialog(
        provider: appProvider,
        tenant: tenant,
      ),
    );
  }
}
