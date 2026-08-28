import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final monthYear = DateFormat('MMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            const Text('Good Morning, Owner 👋', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Sunshine PG', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const Text('Koramangala, Bengaluru', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 24),

            // Top Stats Row
            Row(
              children: [
                _buildStatCard(context, 'Total Beds', '${appProvider.totalBeds}', Icons.bed_outlined, AppTheme.primaryColor.withValues(alpha: 0.1), AppTheme.primaryColor, null),
                const SizedBox(width: 12),
                _buildStatCard(context, 'Occupied Beds', '${appProvider.occupiedBeds}', Icons.airline_seat_individual_suite, AppTheme.brandOrange.withValues(alpha: 0.1), AppTheme.brandOrange, null),
                const SizedBox(width: 12),
                _buildStatCard(context, 'Available Beds', '${appProvider.availableBeds}', Icons.check_circle_outline, AppTheme.success.withValues(alpha: 0.1), AppTheme.success, () => context.push('/available_beds')),
              ],
            ),
            const SizedBox(height: 24),

            // Occupancy
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Occupancy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${appProvider.occupiedBeds}/${appProvider.totalBeds} Beds Occupied', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text('${(appProvider.occupancyRate * 100).toStringAsFixed(2)}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: appProvider.occupancyRate,
              backgroundColor: Colors.grey[200],
              color: AppTheme.primaryColor,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 32),

            // Rent Overview
            Text('Rent Overview ($monthYear)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildRentStat('Expected Rent', '₹${appProvider.expectedRent.toStringAsFixed(0)}', AppTheme.primaryColor),
                _buildRentStat('Collected Rent', '₹${appProvider.collectedRent.toStringAsFixed(0)}', AppTheme.success),
                _buildRentStat('Pending Rent', '₹${appProvider.pendingRent.toStringAsFixed(0)}', AppTheme.danger),
              ],
            ),
            const SizedBox(height: 32),

            // Quick Actions
            const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAction(context, 'Add Tenant', Icons.person_add_outlined, () => context.push('/add_tenant')),
                _buildQuickAction(context, 'Add Room', Icons.add_home_outlined, () => context.push('/add_room')),
                _buildQuickAction(context, 'Record Payment', Icons.payment_outlined, () => context.push('/tenants')),
                _buildQuickAction(context, 'View Reports', Icons.bar_chart_outlined, () => context.push('/rent')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color bgColor, Color iconColor, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: iconColor)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRentStat(String title, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

