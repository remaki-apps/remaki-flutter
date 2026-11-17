import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fancy_toast.dart';

class OrgCreateAdminScreen extends StatefulWidget {
  const OrgCreateAdminScreen({super.key});

  @override
  State<OrgCreateAdminScreen> createState() => _OrgCreateAdminScreenState();
}

class _OrgCreateAdminScreenState extends State<OrgCreateAdminScreen> {
  final _formKey = GlobalKey<FormState>();

  // Admin details
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Initial Property details (optional)
  bool _includeInitialProperty = true;
  final _propertyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _floorsController = TextEditingController(text: '1');

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _propertyNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _floorsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final orgProvider = context.read<OrganizationProvider>();

    setState(() => _isLoading = true);

    try {
      final input = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        if (_emailController.text.trim().isNotEmpty)
          'email': _emailController.text.trim(),
        if (_passwordController.text.trim().isNotEmpty)
          'password': _passwordController.text.trim(),
        if (_includeInitialProperty && _propertyNameController.text.trim().isNotEmpty) ...{
          'initialPropertyName': _propertyNameController.text.trim(),
          if (_addressController.text.trim().isNotEmpty)
            'propertyAddress': _addressController.text.trim(),
          if (_cityController.text.trim().isNotEmpty)
            'city': _cityController.text.trim(),
          if (_stateController.text.trim().isNotEmpty)
            'state': _stateController.text.trim(),
          if (_pincodeController.text.trim().isNotEmpty)
            'pincode': _pincodeController.text.trim(),
          'totalFloors': int.tryParse(_floorsController.text.trim()) ?? 1,
        },
      };

      final payload = await orgProvider.createAdmin(input);

      if (mounted) {
        context.pushReplacement(
          '/org_admin_success',
          extra: {
            'payload': payload,
            'propertyName': _includeInitialProperty ? _propertyNameController.text.trim() : '',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        FancyToast.showError(
          context,
          'Failed to create admin',
          message: e.toString().replaceAll('Exception: ', ''),
        );
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Onboard New Admin',
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
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The new admin will be created under your organization with their unique Admin Code. Credentials can be shared directly via WhatsApp.',
                          style: GoogleFonts.lato(
                            fontSize: 12.5,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section 1: Admin Account Details
                Text(
                  'Admin Account Details',
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
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
                          hint: 'e.g. Ramesh Kumar',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 2) {
                            return 'Please enter the admin\'s full name';
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
                          hint: 'e.g. ramesh@example.com',
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.lato(fontSize: 14),
                        decoration: _buildInputDecoration(
                          label: 'Password (Optional)',
                          hint: 'Leave blank to auto-generate',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 2: Initial PG Property Details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Assign Initial PG Property',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    Switch.adaptive(
                      value: _includeInitialProperty,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (val) => setState(() => _includeInitialProperty = val),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_includeInitialProperty) ...[
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
                          controller: _propertyNameController,
                          style: GoogleFonts.lato(fontSize: 14),
                          decoration: _buildInputDecoration(
                            label: 'PG / Hostel Name',
                            hint: 'e.g. Sri Balaji Luxury PG',
                            icon: Icons.apartment_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          style: GoogleFonts.lato(fontSize: 14),
                          decoration: _buildInputDecoration(
                            label: 'Street Address',
                            hint: 'e.g. 4th Cross, Electronic City',
                            icon: Icons.place_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cityController,
                                style: GoogleFonts.lato(fontSize: 14),
                                decoration: _buildInputDecoration(
                                  label: 'City',
                                  hint: 'Bengaluru',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _stateController,
                                style: GoogleFonts.lato(fontSize: 14),
                                decoration: _buildInputDecoration(
                                  label: 'State',
                                  hint: 'Karnataka',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _pincodeController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                style: GoogleFonts.lato(fontSize: 14),
                                decoration: _buildInputDecoration(
                                  label: 'Pincode',
                                  hint: '560100',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _floorsController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.lato(fontSize: 14),
                                decoration: _buildInputDecoration(
                                  label: 'Total Floors',
                                  hint: '1',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Onboard Admin Account',
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
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
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF64748B)),
      hintText: hint,
      hintStyle: GoogleFonts.lato(fontSize: 13, color: const Color(0xFFCBD5E1)),
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF94A3B8), size: 18) : null,
      prefixText: prefixText,
      prefixStyle: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
      suffixIcon: suffixIcon,
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
