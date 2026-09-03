import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';

class UnpaidTenantsScreen extends StatelessWidget {
  final String? filter;
  const UnpaidTenantsScreen({super.key, this.filter});

  Future<void> _sendWhatsAppReminder(BuildContext context, Tenant tenant, String roomNumber) async {
    try {
      final sanitizedPhone = tenant.phone.replaceAll(RegExp(r'\D'), '');
      final phoneNum = sanitizedPhone.startsWith('91') ? sanitizedPhone : '91$sanitizedPhone';
      final message = tenant.buildDetailedRentBillMessage(roomNumber: roomNumber);
      final url = Uri.parse('https://wa.me/$phoneNum?text=$message');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching WhatsApp: $e')),
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
      body: unpaidTenants.isEmpty
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              physics: const BouncingScrollPhysics(),
              itemCount: unpaidTenants.length,
              itemBuilder: (context, index) {
                final tenant = unpaidTenants[index];
                final roomIndex = appProvider.rooms.indexWhere((r) => r.id == tenant.roomId);
                final roomNumber = roomIndex != -1 ? appProvider.rooms[roomIndex].number : 'N/A';
                final bedName = (roomIndex != -1)
                    ? appProvider.rooms[roomIndex].beds.firstWhere(
                        (b) => b.id == tenant.bedId,
                        orElse: () => appProvider.rooms[roomIndex].beds.isNotEmpty
                            ? appProvider.rooms[roomIndex].beds.first
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
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/tenant_profile/${tenant.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
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
                                ),
                                const SizedBox(height: 3),
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
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // WhatsApp Button with Background Container
                          Tooltip(
                            message: 'Send WhatsApp Reminder',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _sendWhatsAppReminder(context, tenant, roomNumber),
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
                          const SizedBox(width: 6),
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
                    ),
                  ),
                );
              },
            ),
    );
  }
}
