import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/organization_models.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fancy_toast.dart';

class OrgPropertyFormScreen extends StatefulWidget {
  final String? propertyId; // null = Create PG, non-null = Edit PG (preloaded)
  final String? initialAdminId;

  const OrgPropertyFormScreen({
    super.key,
    this.propertyId,
    this.initialAdminId,
  });

  @override
  State<OrgPropertyFormScreen> createState() => _OrgPropertyFormScreenState();
}

class _OrgPropertyFormScreenState extends State<OrgPropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _pincodeCtrl;
  late TextEditingController _floorsCtrl;
  late TextEditingController _upiIdCtrl;
  late TextEditingController _upiPayeeCtrl;
  late TextEditingController _platformFeeCtrl;
  late TextEditingController _feeUpiIdCtrl;
  late TextEditingController _feePayeeCtrl;

  String? _selectedAdminId;
  bool _isActive = true;
  bool _isSaving = false;
  bool _initialized = false;

  bool get isEdit => widget.propertyId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final orgProvider = context.read<OrganizationProvider>();

    OrganizationPropertyItem? existing;
    if (isEdit) {
      try {
        existing = orgProvider.properties.firstWhere((p) => p.id == widget.propertyId);
      } catch (_) {}
    }

    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _addressCtrl = TextEditingController(text: existing?.address ?? '');
    _cityCtrl = TextEditingController(text: existing?.city ?? '');
    _stateCtrl = TextEditingController(text: existing?.state ?? '');
    _pincodeCtrl = TextEditingController(text: existing?.pincode ?? '');
    _floorsCtrl = TextEditingController(text: '${existing?.totalFloors ?? 1}');
    _upiIdCtrl = TextEditingController(text: existing?.upiId ?? '');
    _upiPayeeCtrl = TextEditingController(text: existing?.upiPayeeName ?? '');
    _platformFeeCtrl = TextEditingController(text: '${existing?.platformFee ?? 9}');
    _feeUpiIdCtrl = TextEditingController(text: existing?.platformFeeUpiId ?? 'kishoremagesh1@okhdfcbank');
    _feePayeeCtrl = TextEditingController(text: existing?.platformFeePayeeName ?? 'Remaki Organization');

    _isActive = existing?.isActive ?? true;
    _selectedAdminId = existing?.adminId ??
        widget.initialAdminId ??
        (orgProvider.admins.isNotEmpty ? orgProvider.admins.first.id : null);

    _initialized = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _floorsCtrl.dispose();
    _upiIdCtrl.dispose();
    _upiPayeeCtrl.dispose();
    _platformFeeCtrl.dispose();
    _feeUpiIdCtrl.dispose();
    _feePayeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAdminId == null || _selectedAdminId!.isEmpty) {
      FancyToast.showError(context, 'Admin Required', message: 'Please select an Admin for this PG.');
      return;
    }

    setState(() => _isSaving = true);
    final orgProvider = context.read<OrganizationProvider>();

    try {
      final payload = <String, dynamic>{
        'adminId': _selectedAdminId,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'totalFloors': int.tryParse(_floorsCtrl.text.trim()) ?? 1,
        'upiId': _upiIdCtrl.text.trim().isNotEmpty ? _upiIdCtrl.text.trim() : null,
        'upiPayeeName': _upiPayeeCtrl.text.trim().isNotEmpty ? _upiPayeeCtrl.text.trim() : null,
        'platformFee': double.tryParse(_platformFeeCtrl.text.trim()) ?? 9.0,
        'platformFeeUpiId': _feeUpiIdCtrl.text.trim().isNotEmpty ? _feeUpiIdCtrl.text.trim() : null,
        'platformFeePayeeName': _feePayeeCtrl.text.trim().isNotEmpty ? _feePayeeCtrl.text.trim() : null,
      };

      if (isEdit) {
        payload['propertyId'] = widget.propertyId;
        payload['isActive'] = _isActive;
        await orgProvider.updateProperty(payload);
        if (mounted) {
          FancyToast.showSuccess(context, 'PG Updated', message: 'All PG details saved successfully.');
          context.pop();
        }
      } else {
        await orgProvider.createProperty(payload);
        if (mounted) {
          FancyToast.showSuccess(context, 'PG Created', message: 'New PG property onboarded under selected admin.');
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        FancyToast.showError(context, 'Save Failed', message: e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admins = context.watch<OrganizationProvider>().admins;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit PG Property' : 'Add PG Property',
          style: GoogleFonts.lato(fontWeight: FontWeight.w800, color: AppTheme.primaryDark),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('ASSIGNED ADMIN'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: admins.any((a) => a.id == _selectedAdminId) ? _selectedAdminId : null,
                decoration: _inputDeco('Select Admin (supports multi-PG)'),
                items: admins.map((a) {
                  return DropdownMenuItem<String>(
                    value: a.id,
                    child: Text('${a.displayName} (${a.adminCode})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedAdminId = val),
                validator: (val) => val == null ? 'Please select an admin' : null,
              ),
              const SizedBox(height: 18),

              _sectionLabel('PG DETAILS'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDeco('PG Name *'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter PG name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descCtrl,
                decoration: _inputDeco('Description (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressCtrl,
                decoration: _inputDeco('Street / Full Address *'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter address' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: _inputDeco('City *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _stateCtrl,
                      decoration: _inputDeco('State *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pincodeCtrl,
                      decoration: _inputDeco('Pincode *'),
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.trim().length < 4) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _floorsCtrl,
                      decoration: _inputDeco('Total Floors'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _sectionLabel('RENT COLLECTION UPI'),
              const SizedBox(height: 8),
              TextFormField(controller: _upiIdCtrl, decoration: _inputDeco('PG Rent UPI ID')),
              const SizedBox(height: 10),
              TextFormField(controller: _upiPayeeCtrl, decoration: _inputDeco('PG Rent Payee Name')),
              const SizedBox(height: 18),

              _sectionLabel('PLATFORM FEE SETTINGS (PER TENANT)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _platformFeeCtrl,
                decoration: _inputDeco('Platform Fee (₹ per tenant)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              TextFormField(controller: _feeUpiIdCtrl, decoration: _inputDeco('Organization Fee UPI ID')),
              const SizedBox(height: 10),
              TextFormField(controller: _feePayeeCtrl, decoration: _inputDeco('Organization Fee Payee Name')),

              if (isEdit) ...[
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Property Active', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Save Changes' : 'Create PG Property', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.lato(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    );
  }
}
