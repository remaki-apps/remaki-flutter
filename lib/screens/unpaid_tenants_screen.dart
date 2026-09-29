import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';
import '../widgets/fancy_toast.dart';
import '../widgets/app_shimmer.dart';

class UnpaidTenantsScreen extends StatelessWidget {
  final String? filter;
  const UnpaidTenantsScreen({super.key, this.filter});

  Future<void> _sendWhatsAppReminder(
    BuildContext context,
    Tenant tenant,
    String roomNumber, {
    String floorName = '',
    String pgName = '',
  }) async {
    try {
      final sanitizedPhone = tenant.phone.replaceAll(RegExp(r'\D'), '');
      final phoneNum = sanitizedPhone.startsWith('91') ? sanitizedPhone : '91$sanitizedPhone';
      final message = tenant.buildDetailedRentBillMessage(
        roomNumber: roomNumber,
        floorName: floorName,
        pgName: pgName,
      );
      final url = Uri.parse('https://wa.me/$phoneNum?text=$message');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          FancyToast.showError(
            context,
            'WhatsApp Unavailable',
            message: 'Could not open WhatsApp. Please check if WhatsApp is installed.',
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        FancyToast.showError(
          context,
          'WhatsApp Error',
          message: 'Unable to open WhatsApp on this device.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    final List<Tenant> unpaidTenants = filter == 'bills'
        ? appProvider.unpaidBillsTenants
        : filter == 'rent'
            ? appProvider.unpaidRentTenants
            : appProvider.unpaidTenants;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Unpaid Tenants',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => appProvider.loadFromAPI(),
        color: AppTheme.primaryColor,
        child: appProvider.isLoading
            ? const SimpleListSkeleton()
            : unpaidTenants.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/no_tenant1.png',
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Unpaid Tenants!',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'All dues are clear for this month.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 30 + MediaQuery.of(context).padding.bottom),
              physics: const BouncingScrollPhysics(),
              itemCount: unpaidTenants.length,
              itemBuilder: (context, index) {
                final tenant = unpaidTenants[index];
                final roomIndex = appProvider.rooms.indexWhere((r) => r.id == tenant.roomId);
                final room = roomIndex != -1 ? appProvider.rooms[roomIndex] : null;
                final roomNumber = room != null ? room.number : 'N/A';
                final floorName = room != null ? room.floor : '';
                final bedName = (room != null)
                    ? room.beds.firstWhere(
                        (b) => b.id == tenant.bedId,
                        orElse: () => room.beds.isNotEmpty
                            ? room.beds.first
                            : Bed(id: '', name: ''),
                      ).name
                    : 'N/A';

                // If bill is there, it is combined with rent and shown as total pending
                final totalPending = tenant.totalDue;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x040F172A),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/tenant_profile/${tenant.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Avatar + Tenant Name & Room + WhatsApp Action
                          Row(
                            children: [
                              TenantAvatar(
                                name: tenant.name,
                                imageUrl: tenant.imageUrl,
                                radius: 20,
                                backgroundColor: AppTheme.danger.withValues(alpha: 0.1),
                                textColor: AppTheme.danger,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tenant.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Room $roomNumber${bedName.isNotEmpty ? ' - $bedName' : ''}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // WhatsApp Button
                              Tooltip(
                                message: 'Send WhatsApp Reminder',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _sendWhatsAppReminder(
                                    context,
                                    tenant,
                                    roomNumber,
                                    floorName: floorName,
                                    pgName: appProvider.pgName,
                                  ),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Image.asset(
                                      'assets/icons/whatsapp.png',
                                      width: 18,
                                      height: 18,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.chat,
                                        color: Color(0xFF16A34A),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 10),
                          // Bottom Row: Dues & Badges on left, Mark as Paid Button on right
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Pending: ',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '₹${totalPending.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.danger,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (tenant.isPartiallyPaid)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFFDE68A)),
                                            ),
                                            child: const Text(
                                              'Partial',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                        if (tenant.totalPendingBills > 0 && tenant.pendingRentAmount == 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFDBEAFE)),
                                            ),
                                            child: const Text(
                                              'Bills Only',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (tenant.totalPendingBills > 0 && tenant.pendingRentAmount > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Rent: ₹${tenant.pendingRentAmount.toStringAsFixed(0)} • Bills: ₹${tenant.totalPendingBills.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Mark as Paid Button
                              ElevatedButton(
                                onPressed: () => context.push('/record_payment/${tenant.id}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: const Size(0, 34),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text(
                                  'Mark as Paid',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
