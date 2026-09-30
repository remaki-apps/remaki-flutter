import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fancy_toast.dart';

class SetupSecurityPinScreen extends StatefulWidget {
  const SetupSecurityPinScreen({super.key});

  @override
  State<SetupSecurityPinScreen> createState() => _SetupSecurityPinScreenState();
}

class _SetupSecurityPinScreenState extends State<SetupSecurityPinScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  final _pinFocus = FocusNode();
  final _confirmPinFocus = FocusNode();

  bool _obscurePin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _pinFocus.dispose();
    _confirmPinFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSavePin() async {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _errorMessage = 'Security PIN must be exactly 4 numeric digits');
      return;
    }

    if (confirmPin != pin) {
      setState(() => _errorMessage = 'PINs do not match. Please re-enter.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await ApiService.setupSecurityPin(pin);
      if (!mounted) return;

      if (success) {
        FancyToast.showSuccess(
          context,
          'Security Recovery PIN Created!',
          message: 'Your 4-digit MPIN has been safely activated.',
        );
        context.go('/tenant_home');
      } else {
        setState(() {
          _errorMessage = 'Failed to setup PIN. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = ApiService.cleanErrorMessage(e);
      setState(() {
        _errorMessage = cleanMsg;
        _isLoading = false;
      });
      FancyToast.showError(context, 'Setup Failed', message: cleanMsg);
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Sign Out?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'You need to set up a 4-digit Security Recovery PIN to access your tenant account. Do you want to sign out?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ApiService.clearAuthToken();
      if (mounted) context.go('/login');
    }
  }

  Widget _buildPinBoxes(String pinValue, {required bool isFocused}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final hasDigit = index < pinValue.length;
        final digitChar = hasDigit ? (_obscurePin ? '●' : pinValue[index]) : '';
        final isCurrentBox = index == pinValue.length && isFocused;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 52,
          height: 58,
          decoration: BoxDecoration(
            color: hasDigit ? const Color(0xFFEEF2FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrentBox
                  ? AppTheme.primaryColor
                  : hasDigit
                      ? AppTheme.primaryColor.withValues(alpha: 0.6)
                      : const Color(0xFFE2E8F0),
              width: isCurrentBox ? 2.2 : (hasDigit ? 1.8 : 1.2),
            ),
            boxShadow: isCurrentBox
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [
                    const BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    )
                  ],
          ),
          child: Center(
            child: Text(
              digitChar,
              style: GoogleFonts.outfit(
                fontSize: _obscurePin ? 20 : 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E1B4B),
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Compulsory - user cannot pop back
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleSignOut();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Hero Badge
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4338CA), AppTheme.primaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: 3,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Compulsory Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_clock_rounded, size: 14, color: Color(0xFFB45309)),
                          const SizedBox(width: 6),
                          Text(
                            'COMPULSORY FIRST TIME SETUP',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFB45309),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Create Security PIN',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Set a 4-digit Security Recovery PIN (like an ATM / UPI MPIN). You will need this PIN to reset your password if you ever forget it.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Main Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFB91C1C),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Visibility Toggle Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Enter 4-Digit MPIN',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _obscurePin = !_obscurePin),
                                child: Row(
                                  children: [
                                    Icon(
                                      _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 16,
                                      color: const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _obscurePin ? 'Show' : 'Hide',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Visual Boxes for PIN
                          GestureDetector(
                            onTap: () => FocusScope.of(context).requestFocus(_pinFocus),
                            child: _buildPinBoxes(_pinController.text, isFocused: _pinFocus.hasFocus),
                          ),

                          // Hidden text field for Pin 1
                          Opacity(
                            opacity: 0,
                            child: SizedBox(
                              height: 0,
                              child: TextField(
                                focusNode: _pinFocus,
                                controller: _pinController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (val) {
                                  setState(() {});
                                  if (val.length == 4) {
                                    FocusScope.of(context).requestFocus(_confirmPinFocus);
                                  }
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Confirm PIN Header
                          Text(
                            'Confirm 4-Digit MPIN',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Visual Boxes for Confirm PIN
                          GestureDetector(
                            onTap: () => FocusScope.of(context).requestFocus(_confirmPinFocus),
                            child: _buildPinBoxes(_confirmPinController.text, isFocused: _confirmPinFocus.hasFocus),
                          ),

                          // Hidden text field for Pin 2
                          Opacity(
                            opacity: 0,
                            child: SizedBox(
                              height: 0,
                              child: TextField(
                                focusNode: _confirmPinFocus,
                                controller: _confirmPinController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (val) {
                                  setState(() {});
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Security Notice Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Keep this MPIN safe and memorable. It verifies your identity if you ever forget your password.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSavePin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_outline, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Save & Secure Account',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Sign Out option if user wants to switch account
                    TextButton.icon(
                      onPressed: _isLoading ? null : _handleSignOut,
                      icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF94A3B8)),
                      label: Text(
                        'Sign Out / Switch Account',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
