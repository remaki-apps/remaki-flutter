import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(context, 0, Icons.home_rounded, Icons.home_outlined, 'Dashboard', selectedIndex == 0),
                _buildNavItem(context, 1, Icons.bed_rounded, Icons.bed_outlined, 'Rooms', selectedIndex == 1),
                _buildNavItem(context, 2, Icons.people_rounded, Icons.people_outline_rounded, 'Tenants', selectedIndex == 2),
                _buildNavItem(context, 3, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Payments', selectedIndex == 3),
                _buildNavItem(context, 4, Icons.grid_view_rounded, Icons.grid_view_outlined, 'More', selectedIndex == 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData activeIcon, IconData inactiveIcon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => _onItemTapped(index, context),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
              size: 20,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/rooms')) {
      return 1;
    }
    if (location.startsWith('/tenants')) {
      return 2;
    }
    if (location.startsWith('/rent')) {
      return 3;
    }
    if (location.startsWith('/more')) {
      return 4;
    }
    return 0; // Default home
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/');
        break;
      case 1:
        GoRouter.of(context).go('/rooms');
        break;
      case 2:
        GoRouter.of(context).go('/tenants');
        break;
      case 3:
        GoRouter.of(context).go('/rent');
        break;
      case 4:
        GoRouter.of(context).go('/more');
        break;
    }
  }
}
