import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';

class UnpaidTenantsScreen extends StatelessWidget {
  final String? filter;
  const UnpaidTenantsScreen({super.key, this.filter});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final unpaidTenants = filter == 'bills' 
        ? appProvider.unpaidBillsTenants 
        : filter == 'rent' 
            ? appProvider.unpaidRentTenants 
            : appProvider.unpaidTenants;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Unpaid Tenants'),
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
                      height: 180,
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
              padding: const EdgeInsets.all(16),
              itemCount: unpaidTenants.length,
              itemBuilder: (context, index) {
                final tenant = unpaidTenants[index];
                final roomIndex = appProvider.rooms.indexWhere((r) => r.id == tenant.roomId);
                final roomNumber = roomIndex != -1 ? appProvider.rooms[roomIndex].number : 'N/A';
                final bedName = roomIndex != -1
                    ? appProvider.rooms[roomIndex].beds.firstWhere((b) => b.id == tenant.bedId, orElse: () => appProvider.rooms[roomIndex].beds.first).name
                    : 'N/A';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: TenantAvatar(
                      name: tenant.name,
                      imageUrl: tenant.imageUrl,
                      radius: 20,
                      backgroundColor: AppTheme.danger.withValues(alpha: 0.1),
                      textColor: AppTheme.danger,
                    ),
                    title: Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Room $roomNumber - $bedName\nPending: ₹${(filter == 'bills' ? tenant.totalPendingBills : filter == 'rent' ? tenant.pendingRentAmount : tenant.totalDue).toStringAsFixed(0)}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat, color: Colors.green),
                          tooltip: 'Send WhatsApp Reminder',
                          onPressed: () async {
                            final sanitizedPhone = tenant.phone.replaceAll(RegExp(r'\D'), '');
                            final phoneNum = sanitizedPhone.startsWith('91') ? sanitizedPhone : '91$sanitizedPhone';
                            final message = tenant.buildDetailedRentBillMessage(roomNumber: roomNumber);
                            final url = Uri.parse('https://wa.me/$phoneNum?text=$message');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        ElevatedButton(
                          onPressed: () => context.push('/record_payment/${tenant.id}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('Pay'),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/tenant_profile/${tenant.id}'),
                  ),
                );
              },
            ),
    );
  }
}
