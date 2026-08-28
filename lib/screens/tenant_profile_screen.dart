import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class TenantProfileScreen extends StatelessWidget {
  final String tenantId;
  const TenantProfileScreen({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final tenantIndex = appProvider.tenants.indexWhere((t) => t.id == tenantId);
    if (tenantIndex == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tenant Profile')),
        body: const Center(child: Text('Tenant not found')),
      );
    }
    final tenant = appProvider.tenants[tenantIndex];
    final roomIndex = appProvider.rooms.indexWhere((r) => r.id == tenant.roomId);
    final roomNumber = roomIndex != -1 ? appProvider.rooms[roomIndex].number : 'N/A';
    final bedName = (roomIndex != -1)
        ? appProvider.rooms[roomIndex].beds.firstWhere((b) => b.id == tenant.bedId, orElse: () => appProvider.rooms[roomIndex].beds.first).name
        : 'N/A';

    final tenantPayments = appProvider.payments.where((p) => p.tenantId == tenantId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Tenant Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(tenant.name.isNotEmpty ? tenant.name.substring(0, 1).toUpperCase() : 'T', style: const TextStyle(fontSize: 32, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(tenant.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Room $roomNumber - $bedName', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Text('Active Tenant', style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),

            _buildDetailRow('Phone', tenant.phone, Icons.phone),
            _buildDetailRow('Email', tenant.email, Icons.email),
            _buildDetailRow('Move-in Date', DateFormat('dd/MM/yyyy').format(tenant.moveInDate), Icons.calendar_today),
            _buildDetailRow('Base Monthly Rent', '₹${tenant.rentAmount.toStringAsFixed(0)}', Icons.money),
            ...tenant.additionalCharges.map((c) => _buildDetailRow(c.description, '+ ₹${c.amount.toStringAsFixed(0)}', Icons.receipt_long)),
            if (tenant.additionalCharges.isNotEmpty)
              _buildDetailRow('Total Due', '₹${tenant.totalDue.toStringAsFixed(0)}', Icons.account_balance_wallet, isBold: true),
            _buildDetailRow('Security Deposit', '₹${tenant.securityDeposit.toStringAsFixed(0)}', Icons.security),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat, color: Colors.green),
                    label: const Text('WhatsApp'),
                    onPressed: () async {
                      final sanitizedPhone = tenant.phone.replaceAll(RegExp(r'\D'), '');
                      final phoneNum = sanitizedPhone.startsWith('91') ? sanitizedPhone : '91$sanitizedPhone';
                      final message = Uri.encodeComponent('Hi ${tenant.name}, a gentle reminder that your rent of ₹${tenant.totalDue.toStringAsFixed(0)} for Room $roomNumber is due.');
                      final url = Uri.parse('https://wa.me/$phoneNum?text=$message');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push('/record_payment/${tenant.id}'),
                    child: const Text('Record Payment'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            const Align(alignment: Alignment.centerLeft, child: Text('Rent Payment History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 16),
            
            if (tenantPayments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('No recorded payments yet.', style: TextStyle(color: AppTheme.textSecondary)),
              )
            else
              ...tenantPayments.map((payment) {
                final dateStr = DateFormat('dd MMM yyyy').format(payment.date);
                return Column(
                  children: [
                    _buildPaymentHistoryRow(dateStr, '₹${payment.amount.toStringAsFixed(0)}', true, method: payment.method),
                    const Divider(),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistoryRow(String title, String amount, bool isPaid, {String? method}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              if (method != null)
                Text(method, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          Row(
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(isPaid ? 'Paid' : 'Unpaid', style: TextStyle(color: isPaid ? AppTheme.success : AppTheme.danger, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isBold ? AppTheme.primaryColor : AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isBold ? AppTheme.primaryColor : AppTheme.textSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isBold ? 16 : 14, color: isBold ? AppTheme.primaryColor : Colors.black)),
        ],
      ),
    );
  }
}

