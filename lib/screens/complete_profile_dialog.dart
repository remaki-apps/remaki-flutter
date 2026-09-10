import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fancy_toast.dart';

class CompleteProfileDialog extends StatefulWidget {
  final Tenant tenant;
  final VoidCallback onProfileUpdated;

  const CompleteProfileDialog({super.key, required this.tenant, required this.onProfileUpdated});

  @override
  State<CompleteProfileDialog> createState() => _CompleteProfileDialogState();
}

class _CompleteProfileDialogState extends State<CompleteProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _dateOfBirthCtrl;
  late TextEditingController _fatherNameCtrl;
  late TextEditingController _permanentAddressCtrl;
  late TextEditingController _villageOrTownCtrl;
  late TextEditingController _houseNoCtrl;
  late TextEditingController _wardNoCtrl;
  late TextEditingController _districtCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _nationalityCtrl;
  late TextEditingController _pinCodeCtrl;
  late TextEditingController _occupationCtrl;
  
  String? _maritalStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dateOfBirthCtrl = TextEditingController(text: widget.tenant.dateOfBirth);
    _fatherNameCtrl = TextEditingController(text: widget.tenant.fatherName);
    _permanentAddressCtrl = TextEditingController(text: widget.tenant.permanentAddress);
    _villageOrTownCtrl = TextEditingController(text: widget.tenant.villageOrTown);
    _houseNoCtrl = TextEditingController(text: widget.tenant.houseNo);
    _wardNoCtrl = TextEditingController(text: widget.tenant.wardNo);
    _districtCtrl = TextEditingController(text: widget.tenant.district);
    _stateCtrl = TextEditingController(text: widget.tenant.state);
    _nationalityCtrl = TextEditingController(text: widget.tenant.nationality);
    _pinCodeCtrl = TextEditingController(text: widget.tenant.pinCode);
    _occupationCtrl = TextEditingController(text: widget.tenant.occupation);
    _maritalStatus = widget.tenant.maritalStatus;
  }

  @override
  void dispose() {
    _dateOfBirthCtrl.dispose();
    _fatherNameCtrl.dispose();
    _permanentAddressCtrl.dispose();
    _villageOrTownCtrl.dispose();
    _houseNoCtrl.dispose();
    _wardNoCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _nationalityCtrl.dispose();
    _pinCodeCtrl.dispose();
    _occupationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    DateTime initial = DateTime(2000, 1, 1);
    try {
      if (_dateOfBirthCtrl.text.isNotEmpty) {
        final parts = _dateOfBirthCtrl.text.split(RegExp(r'[-/]'));
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            initial = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          } else {
            initial = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dateOfBirthCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      await ApiService.updateMyProfile({
        if (_dateOfBirthCtrl.text.isNotEmpty) 'dateOfBirth': _dateOfBirthCtrl.text,
        if (_maritalStatus != null) 'maritalStatus': _maritalStatus,
        if (_fatherNameCtrl.text.isNotEmpty) 'fatherName': _fatherNameCtrl.text,
        if (_permanentAddressCtrl.text.isNotEmpty) 'permanentAddress': _permanentAddressCtrl.text,
        if (_villageOrTownCtrl.text.isNotEmpty) 'villageOrTown': _villageOrTownCtrl.text,
        if (_houseNoCtrl.text.isNotEmpty) 'houseNo': _houseNoCtrl.text,
        if (_wardNoCtrl.text.isNotEmpty) 'wardNo': _wardNoCtrl.text,
        if (_districtCtrl.text.isNotEmpty) 'district': _districtCtrl.text,
        if (_stateCtrl.text.isNotEmpty) 'state': _stateCtrl.text,
        if (_nationalityCtrl.text.isNotEmpty) 'nationality': _nationalityCtrl.text,
        if (_pinCodeCtrl.text.isNotEmpty) 'pinCode': _pinCodeCtrl.text,
        if (_occupationCtrl.text.isNotEmpty) 'occupation': _occupationCtrl.text,
      });
      
      widget.onProfileUpdated();
      if (mounted) {
        Navigator.pop(context);
        FancyToast.showSuccess(context, 'KYC details updated successfully!');
      }
    } catch (e) {
      if (mounted) FancyToast.showError(context, 'Error', message: e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 650),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Complete Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Please fill in your details', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildTextField(
                      'Date of Birth',
                      _dateOfBirthCtrl,
                      'DD/MM/YYYY',
                      readOnly: true,
                      onTap: _pickDateOfBirth,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryColor, size: 20),
                        onPressed: _pickDateOfBirth,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown('Marital Status', ['Single', 'Married'], _maritalStatus, (val) => setState(() => _maritalStatus = val)),
                    const SizedBox(height: 16),
                    _buildTextField('Father\'s Name', _fatherNameCtrl, 'Father\'s Name'),
                    const SizedBox(height: 16),
                    _buildTextField('Occupation', _occupationCtrl, 'e.g. Software Engineer'),
                    const SizedBox(height: 16),
                    _buildTextField('Nationality', _nationalityCtrl, 'e.g. Indian'),
                    const SizedBox(height: 24),
                    const Text('Address Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 16),
                    _buildTextField('Permanent Address', _permanentAddressCtrl, 'Full Address', maxLines: 3),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('House No.', _houseNoCtrl, 'House No.')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Ward No.', _wardNoCtrl, 'Ward No.')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Village / Town', _villageOrTownCtrl, 'Village or Town'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('District', _districtCtrl, 'District')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('State', _stateCtrl, 'State')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('PIN Code', _pinCodeCtrl, 'PIN Code', keyboardType: TextInputType.number),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> options, String? value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: (value != null && options.contains(value)) ? value : null,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
