import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/network_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// A modern, polished offline screen displayed whenever internet connectivity is lost.
class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  String? _statusFeedback;

  Future<void> _handleRetry() async {
    setState(() {
      _statusFeedback = null;
    });

    final isOnline = await NetworkProvider.instance.checkConnection();
    if (!mounted) return;

    if (isOnline) {
      NetworkProvider.instance.setOffline(false);
      if (ApiService.role == 'ADMIN') {
        try {
          context.read<AppProvider>().loadFromAPI(showLoading: false);
        } catch (_) {}
      }
    } else {
      setState(() {
        _statusFeedback = 'Still offline. Please check your Wi-Fi or mobile data.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NetworkProvider.instance,
      builder: (context, _) {
        final bool isChecking = NetworkProvider.instance.isChecking;

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Spacer(flex: 1),

                            // Hero Icon Illustration
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.accentColor.withValues(alpha: 0.6),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                    blurRadius: 32,
                                    spreadRadius: 8,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        AppTheme.accentColor,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.18),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.wifi_off_rounded,
                                    size: 42,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Title
                            Text(
                              "No Internet Connection",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lato(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryDark,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Subtitle
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Text(
                                "Please check your network connection and try again.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lato(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Quick Troubleshooting Tips Card
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 340),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.025),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _buildTipRow(Icons.wifi, "Check Wi-Fi or cellular data"),
                                  const Divider(height: 14, thickness: 0.7, color: Color(0xFFF1F5F9)),
                                  _buildTipRow(Icons.airplanemode_active, "Toggle airplane mode off & on"),
                                ],
                              ),
                            ),

                            if (_statusFeedback != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFECDD3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: Color(0xFFE11D48)),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _statusFeedback!,
                                        style: GoogleFonts.lato(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFBE123C),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),

                            // Highly Visible, Modern Retry Button
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 260),
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  colors: isChecking
                                      ? [
                                          AppTheme.primaryColor.withValues(alpha: 0.75),
                                          AppTheme.primaryColor.withValues(alpha: 0.85),
                                        ]
                                      : [
                                          AppTheme.primaryColor,
                                          const Color(0xFF7545FA),
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.32),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: isChecking ? null : _handleRetry,
                                  child: Center(
                                    child: isChecking
                                        ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                "Checking...",
                                                style: GoogleFonts.lato(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                                              const SizedBox(width: 8),
                                              Text(
                                                "Retry",
                                                style: GoogleFonts.lato(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),

                            const Spacer(flex: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.lato(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }
}
