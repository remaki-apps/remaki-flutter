import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        children: [
          _buildMenuItem(Icons.people_outline, 'Staff Management'),
          _buildMenuItem(Icons.description_outlined, 'Documents'),
          _buildMenuItem(Icons.build_outlined, 'Maintenance Requests'),
          _buildMenuItem(Icons.book_outlined, 'Visitors Log'),
          _buildMenuItem(Icons.campaign_outlined, 'Notices'),
          _buildMenuItem(Icons.bar_chart_outlined, 'Reports & Analytics'),
          const Divider(),
          _buildMenuItem(Icons.cloud_upload_outlined, 'Backup & Export'),
          _buildMenuItem(Icons.settings_outlined, 'Settings'),
          _buildMenuItem(Icons.help_outline, 'Help & Support'),
          _buildMenuItem(Icons.info_outline, 'About App'),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: () {},
    );
  }
}
