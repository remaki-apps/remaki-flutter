import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class OrgShell extends StatelessWidget {
  final Widget child;
  const OrgShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _calculateSelectedIndex(context);
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Page Content
          Positioned.fill(
            child: child,
          ),

          // 2. Translucent Frosted Glass Floating Navigation Bar Dock
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: isKeyboardOpen,
              child: AnimatedSlide(
                offset: isKeyboardOpen ? const Offset(0, 2) : Offset.zero,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: isKeyboardOpen ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: SafeArea(
                    maintainBottomViewPadding: true,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x180F172A),
                                blurRadius: 24,
                                spreadRadius: 0,
                                offset: Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Color(0x0A4F46E5),
                                blurRadius: 10,
                                spreadRadius: 0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                height: 66,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                color: Colors.white.withValues(alpha: 0.85),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildNavItem(
                                      context,
                                      0,
                                      Icons.dashboard_rounded,
                                      Icons.dashboard_outlined,
                                      'Dashboard',
                                      selectedIndex == 0,
                                    ),
                                    _buildNavItem(
                                      context,
                                      1,
                                      Icons.badge_rounded,
                                      Icons.badge_outlined,
                                      'Admins',
                                      selectedIndex == 1,
                                    ),
                                    _buildNavItem(
                                      context,
                                      2,
                                      Icons.apartment_rounded,
                                      Icons.apartment_outlined,
                                      'Properties',
                                      selectedIndex == 2,
                                    ),
                                    _buildNavItem(
                                      context,
                                      3,
                                      Icons.grid_view_rounded,
                                      Icons.grid_view_outlined,
                                      'More',
                                      selectedIndex == 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    bool isSelected,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index, context),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/org_admins')) {
      return 1;
    }
    if (location.startsWith('/org_properties')) {
      return 2;
    }
    if (location.startsWith('/org_more')) {
      return 3;
    }
    return 0; // Default dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/org_dashboard');
        break;
      case 1:
        GoRouter.of(context).go('/org_admins');
        break;
      case 2:
        GoRouter.of(context).go('/org_properties');
        break;
      case 3:
        GoRouter.of(context).go('/org_more');
        break;
    }
  }
}

