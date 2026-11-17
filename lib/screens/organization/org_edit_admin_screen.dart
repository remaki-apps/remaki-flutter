import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fancy_toast.dart';

class OrgEditAdminScreen extends StatefulWidget {
  final String adminId;
  const OrgEditAdminScreen({super.key, required this.adminId});

  @override
  State<OrgEditAdminScreen> createState() => _OrgEditAdminScreenState();
}

class _OrgEditAdminScreenState extends State<OrgEditAdminScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  bool _isActive = true;
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final orgProvider = context.read<OrganizationProvider>();
      try {
        final admin = orgProvider.admins.firstWhere((a) => a.id == widget.adminId);
        _nameController = TextEditingController(text: admin.displayName);
        _phoneController = TextEditingController(text: admin.phoneNumber);
        _emailController = TextEditingController(text: admin.email ?? '');
        _isActive = admin.isActive;
        _initialized = true;
      } catch (_) {
        _nameController = TextEditingController();
        _phoneController = TextEditingController();
        _emailController = TextEditingController();
        _initialized = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final orgProvider = context.read<OrganizationProvider>();
    setState(() => _isLoading = true);

    try {
      final input = <String, dynamic>{
        'adminId': widget.adminId,
        'displayName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'isActive': _isActive,
      };

      await orgProvider.updateAdmin(input);

      if (mounted) {
        FancyToast.showSuccess(context, 'Admin Updated', message: 'Admin information updated successfully');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        FancyToast.showError(
          context,
          'Update Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Edit Admin Details',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.primaryDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primaryDark, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.lato(fontSize: 14),
                        decoration: _buildInputDecoration(
                          label: 'Full Name *',
                          hint: 'Enter full name',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 2) {
                            return 'Please enter a valid name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: GoogleFonts.lato(fontSize: 14),
                        decoration: _buildInputDecoration(
                          label: 'Mobile Number *',
                          hint: '10-digit mobile number',
                          icon: Icons.phone_outlined,
                          prefixText: '+91 ',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length != 10) {
                            return 'Please enter a valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.lato(fontSize: 14),
                        decoration: _buildInputDecoration(
                          label: 'Email Address (Optional)',
                          hint: 'e.g. admin@example.com',
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Account Status (Active)',
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                          Switch.adaptive(
                            value: _isActive,
                            activeColor: AppTheme.success,
                            onChanged: (val) => setState(() => _isActive = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    IconData? icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF64748B)),
      hintText: hint,
      hintStyle: GoogleFonts.lato(fontSize: 13, color: const Color(0xFFCBD5E1)),
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF94A3B8), size: 18) : null,
      prefixText: prefixText,
      prefixStyle: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }
}
