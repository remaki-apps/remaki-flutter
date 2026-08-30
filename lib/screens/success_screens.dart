import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.success,
              child: Icon(Icons.check, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: details,
            ),
            const SizedBox(height: 48),
            if (secondaryButtonText != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSecondaryPressed,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(secondaryButtonText!),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPrimaryPressed,
                child: Text(primaryButtonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TenantAddedSuccessScreen extends StatelessWidget {
  final String name;
  final String roomBed;
  final String rent;
  final String moveIn;

  const TenantAddedSuccessScreen({super.key, required this.name, required this.roomBed, required this.rent, required this.moveIn});

  @override
  Widget build(BuildContext context) {
    return SuccessScreen(
      title: 'Tenant Added Successfully!',
      subtitle: '',
      details: Row(
        children: [
          TenantAvatar(
            name: name,
            radius: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(roomBed, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text('₹$rent / month', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text('Move-in: $moveIn', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      secondaryButtonText: 'Add Another Tenant',
      onSecondaryPressed: () => context.go('/add_tenant'),
      primaryButtonText: 'Go to Tenants List',
      onPrimaryPressed: () => context.go('/tenants'),
    );
  }
}

class PaymentSuccessScreen extends StatelessWidget {
  final String amount;
  final String name;
  final String roomBed;
  final String dateMethod;

  const PaymentSuccessScreen({super.key, required this.amount, required this.name, required this.roomBed, required this.dateMethod});

  @override
  Widget build(BuildContext context) {
    return SuccessScreen(
      title: 'Payment Recorded Successfully!',
      subtitle: '',
      details: Column(
        children: [
          Text('₹$amount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              TenantAvatar(
                name: name,
                radius: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(roomBed, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    Text(dateMethod, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      primaryButtonText: 'Go to Tenants List',
      onPrimaryPressed: () => context.go('/tenants'),
      secondaryButtonText: 'Back to Dashboard',
      onSecondaryPressed: () => context.go('/'),
    );
  }
}
