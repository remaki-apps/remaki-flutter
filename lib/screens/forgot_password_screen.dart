import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/fancy_toast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePin = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showOrganizationSupportModal() async {
    final supportInfo = await ApiService.fetchOrganizationSupportInfo();
    final email = supportInfo['email'] ?? 'support@remaki.in';
    final phone = supportInfo['phone'] ?? '+91 98765 43210';
    final message = supportInfo['message'] ?? 'Please contact organization support to recover your Security Recovery PIN (MPIN).';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Icon Badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 2),
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: AppTheme.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Forgot Security PIN?',
              style: GoogleFonts.lato(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),

            // Contact Email Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.email_outlined, color: AppTheme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Organization Support Email',
                              style: GoogleFonts.lato(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: GoogleFonts.lato(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy Email',
                        icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: email));
                          FancyToast.showSuccess(context, 'Email Copied!', message: email);
                        },
                      ),
                    ],
                  ),
                  if (phone.isNotEmpty) ...[
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.phone_outlined, color: Color(0xFF475569), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Support Helpline',
                                style: GoogleFonts.lato(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                phone,
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Email Support Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  'Email Organization Support',
                  style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final userEnteredPhone = _phoneController.text.trim();
                  final subject = Uri.encodeComponent('Security PIN Reset Request - Remaki');
                  final body = Uri.encodeComponent(
                    'Hello Remaki Organization Support Team,\n\n'
                    'I am unable to remember my 4-digit Security Recovery PIN (MPIN).\n'
                    'Please assist me with verifying my identity and resetting my Security PIN.\n\n'
                    'Registered Phone Number: ${userEnteredPhone.isNotEmpty ? userEnteredPhone : "[Enter your phone number]"}\n\n'
                    'Thank you.',
                  );
                  final mailtoUri = Uri.parse('mailto:$email?subject=$subject&body=$body');
                  try {
                    await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    if (mounted) {
                      Clipboard.setData(ClipboardData(text: email));
                      FancyToast.showSuccess(
                        context,
                        'Email Copied to Clipboard',
                        message: 'Write to $email to reset your Security PIN.',
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Close',
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }

    if (pin.isEmpty || pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _errorMessage = 'Please enter your 4-digit Security Recovery PIN');
      return;
    }

    if (newPassword.isEmpty) {
      setState(() => _errorMessage = 'Please enter a new password');
      return;
    }

    if (newPassword.length < 4) {
      setState(() => _errorMessage = 'Password must be at least 4 characters');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'New password and confirm password do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    String cleanPhone = phone.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '');
    if (cleanPhone.startsWith('+91')) {
      cleanPhone = cleanPhone.substring(3);
    } else if (cleanPhone.startsWith('91') && cleanPhone.length == 12) {
      cleanPhone = cleanPhone.substring(2);
    } else if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = cleanPhone.substring(1);
    }

    try {
      await ApiService.resetPasswordWithPin(
        phoneNumber: cleanPhone,
        securityPin: pin,
        newPassword: newPassword,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
                const SizedBox(width: 8),
                Text('Password Reset', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Text(
              'Your password has been reset successfully! You can now log in using your new password.',
              style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF475569)),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  context.pop(); // close dialog
                  context.pop(); // go back to login screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = ApiService.cleanErrorMessage(e);
        setState(() {
          _errorMessage = cleanMsg;
        });
        FancyToast.showError(context, 'Reset Failed', message: cleanMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          'Forgot Password',
          style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: AppTheme.primaryColor,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: Text(
                        'Reset Password',
                        style: GoogleFonts.lato(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Enter your registered phone number, 4-digit Security Recovery PIN, and create a new password.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lato(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Inline Error Banner
                    if (_errorMessage.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: GoogleFonts.lato(
                                      color: const Color(0xFFB91C1C),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_errorMessage.toLowerCase().contains('pin') || _errorMessage.toLowerCase().contains('mpin') || _errorMessage.toLowerCase().contains('support')) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _showOrganizationSupportModal,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFF87171)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.mail_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Contact Organization Support for PIN Reset',
                                        style: GoogleFonts.lato(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Phone Number
                    Text(
                      'Phone Number',
                      style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        hintText: 'Enter registered phone number',
                        hintStyle: GoogleFonts.lato(color: const Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF64748B)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // 4-Digit Security Recovery PIN (ATM / UPI MPIN)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 16, color: AppTheme.primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              '4-Digit Security Recovery PIN (MPIN)',
                              style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _obscurePin = !_obscurePin),
                          child: Text(
                            _obscurePin ? 'Show' : 'Hide',
                            style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _pinController,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Enter 4-digit MPIN',
                        hintStyle: GoogleFonts.lato(color: const Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.pin_outlined, size: 20, color: Color(0xFF64748B)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Forgot PIN Help Link
                    GestureDetector(
                      onTap: _showOrganizationSupportModal,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.help_outline_rounded, size: 15, color: AppTheme.primaryColor),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                "Don't remember your Security PIN? Contact Organization Support",
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // New Password
                    Text(
                      'Enter New Password',
                      style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      decoration: InputDecoration(
                        hintText: 'Minimum 4 characters',
                        hintStyle: GoogleFonts.lato(color: const Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF64748B)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility, size: 20, color: const Color(0xFF64748B)),
                          onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm New Password
                    Text(
                      'Confirm New Password',
                      style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        hintText: 'Re-enter new password',
                        hintStyle: GoogleFonts.lato(color: const Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF64748B)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, size: 20, color: const Color(0xFF64748B)),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('Reset Password', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold)),
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
