import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';
import '../services/api_service.dart';
import '../widgets/fancy_toast.dart';
import 'edit_financials_dialog.dart';
import 'edit_personal_info_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/payment_splitup_card.dart';

class TenantProfileScreen extends StatefulWidget {
  final String tenantId;
  const TenantProfileScreen({super.key, required this.tenantId});

  @override
  State<TenantProfileScreen> createState() => _TenantProfileScreenState();
}

class _TenantProfileScreenState extends State<TenantProfileScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isHistoryExpanded = false;
  final Set<String> _expandedPaymentIds = {};

  DateTime get _currentMonth => DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _getEarliestPaymentMonth(List<Payment> payments, DateTime fallback) {
    if (payments.isEmpty) return DateTime(fallback.year, fallback.month, 1);
    DateTime earliest = payments.first.date;
    for (final p in payments) {
      if (p.date.isBefore(earliest)) {
        earliest = p.date;
      }
    }
    return DateTime(earliest.year, earliest.month, 1);
  }

  void _prevMonth(DateTime earliestMonth) {
    final prev = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    if (!prev.isBefore(earliestMonth)) {
      setState(() {
        _selectedMonth = prev;
      });
    }
  }

  void _nextMonth() {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    if (!next.isAfter(_currentMonth)) {
      setState(() {
        _selectedMonth = next;
      });
    }
  }

  void _resetToCurrentMonth() {
    setState(() {
      _selectedMonth = _currentMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final tenantIndex = appProvider.tenants.indexWhere((t) => t.id == widget.tenantId);

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
        ? (appProvider.rooms[roomIndex].beds.where((b) => b.id == tenant.bedId).isNotEmpty
            ? appProvider.rooms[roomIndex].beds.firstWhere((b) => b.id == tenant.bedId).name
            : 'N/A')
        : 'N/A';

    final tenantPayments = appProvider.payments.where((p) => p.tenantId == widget.tenantId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => appProvider.loadFromAPI(),
          color: AppTheme.primaryColor,
          child: appProvider.isLoading
              ? const ProfileSkeleton()
              : Column(
                  children: [
            // Top Header Bar
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'View and manage tenant details',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Change Room',
                    child: GestureDetector(
                      onTap: () => _showChangeRoomDialog(context, appProvider, tenant, roomNumber, bedName),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryColor, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Vacate Tenant',
                    child: GestureDetector(
                      onTap: () => _showVacateDialog(context, appProvider, tenant, roomNumber, bedName),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Icon(Icons.person_remove_outlined, color: Color(0xFFEF4444), size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

            // Scrollable Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => appProvider.loadFromAPI(),
                color: AppTheme.primaryColor,
                child: Scrollbar(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Column(
                          children: [
                    // Hero Profile Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TenantAvatar(
                                name: tenant.name,
                                imageUrl: tenant.imageUrl,
                                radius: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tenant.name,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.meeting_room_outlined, size: 12, color: AppTheme.primaryColor),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$roomNumber • $bedName',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

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

                    if (tenant.isPending) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFDE68A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Payment Request Pending Approval',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'This tenant submitted payment proof. Verify in Pending Approvals.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Financial Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: tenant.statusBgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: tenant.statusBorderColor,
                              ),
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
                                        color: tenant.statusBgColor,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: tenant.statusBorderColor, width: 0.5),
                                      ),
                                      child: Text(
                                        tenant.statusBadgeLabel,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: tenant.statusColor,
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
                                    color: tenant.statusColor,
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

                    // Personal Information Card
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
                                onTap: () => _showEditPersonalInfoDialog(context, appProvider, tenant),
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
                          _buildModernDetailItem(Icons.email_outlined, 'Email', tenant.email.isNotEmpty ? tenant.email : '-'),
                          _buildModernDetailItem(Icons.contact_phone_outlined, 'Emergency Contact', tenant.emergencyContact != null && tenant.emergencyContact!.isNotEmpty ? tenant.emergencyContact! : '-'),
                          if (tenant.dateOfBirth != null && tenant.dateOfBirth!.isNotEmpty) _buildModernDetailItem(Icons.cake_outlined, 'Date of Birth', tenant.dateOfBirth!),
                          if (tenant.maritalStatus != null && tenant.maritalStatus!.isNotEmpty) _buildModernDetailItem(Icons.favorite_border, 'Marital Status', tenant.maritalStatus!),
                          if (tenant.fatherName != null && tenant.fatherName!.isNotEmpty) _buildModernDetailItem(Icons.person_outline, 'Father\'s Name', tenant.fatherName!),
                          if (tenant.nationality != null && tenant.nationality!.isNotEmpty) _buildModernDetailItem(Icons.flag_outlined, 'Nationality', tenant.nationality!),
                          if (tenant.occupation != null && tenant.occupation!.isNotEmpty) _buildModernDetailItem(Icons.work_outline, 'Occupation', tenant.occupation!),
                          if (tenant.permanentAddress != null && tenant.permanentAddress!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 12),
                            const Text('Address Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            const SizedBox(height: 8),
                            _buildModernDetailItem(Icons.home_outlined, 'Permanent Address', tenant.permanentAddress!),
                            if (tenant.houseNo != null && tenant.houseNo!.isNotEmpty) _buildModernDetailItem(Icons.numbers, 'House No.', tenant.houseNo!),
                            if (tenant.wardNo != null && tenant.wardNo!.isNotEmpty) _buildModernDetailItem(Icons.map_outlined, 'Ward No.', tenant.wardNo!),
                            if (tenant.villageOrTown != null && tenant.villageOrTown!.isNotEmpty) _buildModernDetailItem(Icons.location_city_outlined, 'Village/Town', tenant.villageOrTown!),
                            if (tenant.district != null && tenant.district!.isNotEmpty) _buildModernDetailItem(Icons.map, 'District', tenant.district!),
                            if (tenant.state != null && tenant.state!.isNotEmpty) _buildModernDetailItem(Icons.public, 'State', tenant.state!),
                            if (tenant.pinCode != null && tenant.pinCode!.isNotEmpty) _buildModernDetailItem(Icons.pin_drop_outlined, 'PIN Code', tenant.pinCode!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Financial Information Card
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
                                'Financial Information',
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
                          _buildModernDetailItem(Icons.calendar_today_outlined, 'Move-in Date', DateFormat('dd/MM/yyyy').format(tenant.moveInDate)),
                          _buildModernDetailItem(Icons.payments_outlined, 'Monthly Rent', '₹${tenant.rentAmount.toStringAsFixed(0)}'),
                          _buildModernDetailItem(
                            Icons.event_outlined,
                            'Rent Due Date',
                            '${_formatOrdinalDay(tenant.rentDueDate.day)} of every month (${DateFormat('dd MMM yyyy').format(tenant.rentDueDate)})',
                          ),
                          if (!tenant.isPaid && tenant.pendingRentAmount > 0 && tenant.pendingRentAmount < tenant.rentAmount)
                            _buildModernDetailItem(Icons.account_balance_wallet_outlined, 'Rent Balance Due', '₹${tenant.pendingRentAmount.toStringAsFixed(0)}', isHighlight: true),
                          ...tenant.additionalCharges.where((c) => c.billType != 'RENT' && (c.status == 'PENDING' || c.status == 'UNPAID')).map(
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
                          if (tenant.totalPendingBills > 0 || !tenant.isPaid)
                            _buildModernDetailItem(Icons.account_balance_wallet_outlined, 'Total Due', '₹${tenant.totalDue.toStringAsFixed(0)}', isHighlight: true),
                          _buildModernDetailItem(Icons.local_atm_outlined, 'Platform Fee per Rent Payment', '₹${tenant.platformFee.toStringAsFixed(0)}'),
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
                            '${tenantPayments.length} Total Payments',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Month Navigation Bar with Previous and Next Arrows
                    Builder(
                      builder: (context) {
                        final earliestMonth = _getEarliestPaymentMonth(tenantPayments, tenant.moveInDate);
                        final bool isCurrentMonth = _selectedMonth.year == _currentMonth.year && _selectedMonth.month == _currentMonth.month;
                        final bool canGoPrev = _selectedMonth.isAfter(earliestMonth);
                        final bool canGoNext = _selectedMonth.isBefore(_currentMonth);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                            boxShadow: const [
                              BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.chevron_left_rounded,
                                  size: 22,
                                  color: canGoPrev ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                splashRadius: 18,
                                onPressed: canGoPrev ? () => _prevMonth(earliestMonth) : null,
                                tooltip: canGoPrev ? 'Previous Month' : 'First Recorded Month',
                              ),
                              GestureDetector(
                                onTap: isCurrentMonth ? null : _resetToCurrentMonth,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, size: 15, color: AppTheme.primaryColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('MMMM yyyy').format(_selectedMonth),
                                      style: GoogleFonts.lato(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (isCurrentMonth) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFC7D2FE), width: 0.6),
                                        ),
                                        child: Text(
                                          'Current',
                                          style: GoogleFonts.lato(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF4F46E5),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Reset',
                                          style: GoogleFonts.lato(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 22,
                                  color: canGoNext ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                splashRadius: 18,
                                onPressed: canGoNext ? _nextMonth : null,
                                tooltip: canGoNext ? 'Next Month' : 'Current Month',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Month Summary Metrics
                    Builder(
                      builder: (context) {
                        final targetMonthKey = DateFormat('yyyy-MM').format(_selectedMonth);
                        final monthPayments = tenantPayments.where((p) {
                          if (p.billingMonth != null && p.billingMonth!.isNotEmpty) {
                            return p.billingMonth == targetMonthKey;
                          }
                          return p.date.year == _selectedMonth.year && p.date.month == _selectedMonth.month;
                        }).toList();
                        final double monthTotalPaid = monthPayments.fold(0.0, (sum, p) => sum + p.amount);
                        final selectedMonthStr = DateFormat('MMMM yyyy').format(_selectedMonth);
                        final displayList = _isHistoryExpanded ? monthPayments : monthPayments.take(2).toList();

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$selectedMonthStr Paid',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${monthTotalPaid.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: monthPayments.isNotEmpty ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${monthPayments.length} ${monthPayments.length == 1 ? "Payment" : "Payments"}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: monthPayments.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (monthPayments.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: Column(
                                  children: [
                                    Image.asset(
                                      'assets/images/no_payment_history.png',
                                      height: 90,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No Payments for $selectedMonthStr',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Transactions recorded for this month will appear here.',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              ...displayList.map((payment) {
                                final localDate = payment.date.toLocal();
                                final dateStr = (localDate.hour == 0 && localDate.minute == 0 && localDate.second == 0)
                                    ? DateFormat('dd MMM yyyy').format(localDate)
                                    : DateFormat('dd MMM yyyy, hh:mm a').format(localDate);
                                final isExpanded = _expandedPaymentIds.contains(payment.id);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isExpanded ? const Color(0xFFC7D2FE) : const Color(0xFFF1F5F9)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0x04000000),
                                        blurRadius: isExpanded ? 8 : 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        setState(() {
                                          if (_expandedPaymentIds.contains(payment.id)) {
                                            _expandedPaymentIds.remove(payment.id);
                                          } else {
                                            _expandedPaymentIds.add(payment.id);
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF0FDF4),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: const Color(0xFFDCFCE7)),
                                                        ),
                                                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                const Icon(Icons.calendar_today_rounded, size: 11.5, color: Color(0xFF16A34A)),
                                                                const SizedBox(width: 4),
                                                                Expanded(
                                                                  child: Text(
                                                                    'Paid on $dateStr',
                                                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              (payment.notes != null && payment.notes!.isNotEmpty)
                                                                  ? '${payment.method} • ${payment.notes}'
                                                                  : payment.method,
                                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
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
                                                    const SizedBox(width: 6),
                                                    AnimatedRotation(
                                                      turns: isExpanded ? 0.25 : 0.0,
                                                      duration: const Duration(milliseconds: 200),
                                                      child: const Icon(
                                                        Icons.chevron_right_rounded,
                                                        color: Color(0xFF64748B),
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            if (isExpanded)
                                              PaymentSplitupCard(
                                                paymentAmount: payment.amount,
                                                rentAmount: tenant.rentAmount,
                                                platformFee: tenant.platformFee,
                                                bills: tenant.additionalCharges,
                                                method: payment.method,
                                                notes: payment.notes,
                                                paymentDate: payment.date,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),

                              if (monthPayments.length > 2) ...[
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isHistoryExpanded = !_isHistoryExpanded;
                                    });
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFC7D2FE), width: 0.8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isHistoryExpanded
                                              ? 'Show Summary'
                                              : 'Show More (${monthPayments.length - 2} more in $selectedMonthStr)',
                                          style: GoogleFonts.lato(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          _isHistoryExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
        ],
      ),
    ),
    ),
    );
  }

  String _formatOrdinalDay(int day) {
    String suffix = 'th';
    if (day < 11 || day > 13) {
      switch (day % 10) {
        case 1:
          suffix = 'st';
          break;
        case 2:
          suffix = 'nd';
          break;
        case 3:
          suffix = 'rd';
          break;
      }
    }
    return '$day$suffix';
  }

  Widget _buildModernDetailItem(IconData icon, String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
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
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isHighlight ? AppTheme.primaryColor : const Color(0xFF0F172A),
              ),
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
                      '$roomNumber • $bedName',
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
                      onPressed: () async {
                        try {
                          await appProvider.vacateTenant(tenant.id);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (context.mounted) {
                            context.pop();
                            FancyToast.showSuccess(
                              context,
                              'Tenant Vacated!',
                              message: '${tenant.name} has been vacated from $roomNumber - $bedName.',
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (context.mounted) {
                            FancyToast.showError(
                              context,
                              'Vacate Failed',
                              message: ApiService.cleanErrorMessage(e),
                            );
                          }
                        }
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

  void _showChangeRoomDialog(
    BuildContext context,
    AppProvider appProvider,
    dynamic tenant,
    String currentRoomNumber,
    String currentBedName,
  ) {
    String? selectedRoomId;
    String? selectedBedId;
    bool isSubmitting = false;

    // Filter rooms that have at least one available bed
    final availableRooms = appProvider.rooms.where((r) => r.beds.any((b) => b.isAvailable)).toList();

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final room = selectedRoomId != null
              ? appProvider.rooms.where((r) => r.id == selectedRoomId).firstOrNull
              : null;
          final availableBeds = room != null
              ? room.beds.where((b) => b.isAvailable).toList()
              : <Bed>[];

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Room',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Transfer tenant to a new room & bed',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Current Stay Info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current: Room $currentRoomNumber • $currentBedName',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (availableRooms.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No rooms with available beds found. Please create or free a bed first.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      // Select Target Room
                      const Text(
                        'Select Target Room',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedRoomId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Choose Room',
                          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        items: availableRooms.map((r) {
                          final avail = r.beds.where((b) => b.isAvailable).length;
                          return DropdownMenuItem<String>(
                            value: r.id,
                            child: Text(
                              'Room ${r.number} (${r.floor}) — $avail free',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedRoomId = val;
                            selectedBedId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      // Select Target Bed
                      const Text(
                        'Select Target Bed',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedBedId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: selectedRoomId == null ? 'Select room first' : 'Choose Bed',
                          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        items: availableBeds.map((b) {
                          return DropdownMenuItem<String>(
                            value: b.id,
                            child: Text(
                              b.name,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                          );
                        }).toList(),
                        onChanged: selectedRoomId == null
                            ? null
                            : (val) {
                                setDialogState(() {
                                  selectedBedId = val;
                                });
                              },
                      ),
                      const SizedBox(height: 22),
                    ],

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
                            onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
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
                              backgroundColor: AppTheme.primaryColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: (isSubmitting || selectedBedId == null)
                                ? null
                                : () async {
                                    setDialogState(() => isSubmitting = true);
                                    try {
                                      await ApiService.transferTenant(
                                        tenantId: tenant.id,
                                        fromBedId: tenant.bedId,
                                        toBedId: selectedBedId!,
                                        reason: 'Admin transfer via Tenant Profile',
                                      );
                                      await appProvider.loadFromAPI();
                                      if (ctx.mounted) Navigator.of(ctx).pop();
                                      if (context.mounted) {
                                        final targetRoom = appProvider.rooms.where((r) => r.id == selectedRoomId).firstOrNull;
                                        final targetBed = targetRoom?.beds.where((b) => b.id == selectedBedId).firstOrNull;
                                        FancyToast.showSuccess(
                                          context,
                                          'Room Changed!',
                                          message: '${tenant.name} transferred to Room ${targetRoom?.number ?? ""} - ${targetBed?.name ?? ""}.',
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(() => isSubmitting = false);
                                      if (context.mounted) {
                                        FancyToast.showError(
                                          context,
                                          'Transfer Failed',
                                          message: ApiService.cleanErrorMessage(e),
                                        );
                                      }
                                    }
                                  },
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Confirm Transfer',
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
        },
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

  void _showEditPersonalInfoDialog(BuildContext context, AppProvider appProvider, dynamic tenant) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => EditPersonalInfoDialog(
        tenant: tenant,
        isAdmin: true,
      ),
    );
    if (result == true) {
      // Refresh tenant list if needed, or appProvider already handles it if we call fetch inside.
      // We can trigger a refresh from the provider.
      appProvider.loadFromAPI();
    }
  }
}
