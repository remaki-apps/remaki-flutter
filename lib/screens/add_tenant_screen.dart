import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class AddTenantScreen extends StatefulWidget {
  final String? initialRoomId;
  final String? initialBedId;
  const AddTenantScreen({super.key, this.initialRoomId, this.initialBedId});

  @override
  State<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends State<AddTenantScreen> {
  int _currentStep = 0;

  // Step 1: Personal Info
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _selectedDob;
  String _gender = 'Male';
  final _emergencyContactController = TextEditingController();

  // Step 2: Allocate Bed
  String? _selectedRoomId;
  String? _selectedBedId;

  // Step 3: Rent Details
  final _rentController = TextEditingController();
  final _securityController = TextEditingController();
  DateTime _moveInDate = DateTime.now();
  final _moveInController = TextEditingController();
  String _rentDueDate = '5th of every month';
  String _agreementDuration = 'None';

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.initialRoomId;
    _selectedBedId = widget.initialBedId;
    _moveInController.text = DateFormat('dd-MM-yyyy').format(_moveInDate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _emergencyContactController.dispose();
    _rentController.dispose();
    _securityController.dispose();
    _moveInController.dispose();
    super.dispose();
  }

  Future<void> _selectDob(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  Future<void> _selectMoveInDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _moveInDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _moveInDate = picked;
        _moveInController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Add New Tenant',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Enter details to onboard a new resident',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Step Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildStepProgressItem(0, 'Personal', Icons.person_outline),
                  _buildStepDivider(0),
                  _buildStepProgressItem(1, 'Room & Bed', Icons.meeting_room_outlined),
                  _buildStepDivider(1),
                  _buildStepProgressItem(2, 'Rent Details', Icons.payments_outlined),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 2)),
                    ],
                  ),
                  child: _buildCurrentStepContent(appProvider),
                ),
              ),
            ),

            // Bottom Navigation Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => setState(() => _currentStep -= 1),
                        child: const Text(
                          'Back',
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        if (_currentStep < 2) {
                          if (_currentStep == 0 && _nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter full name')),
                            );
                            return;
                          }
                          if (_currentStep == 1 && (_selectedRoomId == null || _selectedBedId == null)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select Room and Bed')),
                            );
                            return;
                          }
                          setState(() => _currentStep += 1);
                        } else {
                          _submit(appProvider);
                        }
                      },
                      child: Text(
                        _currentStep == 2 ? 'Complete & Save' : 'Continue',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepProgressItem(int stepIndex, String title, IconData icon) {
    final isActive = _currentStep >= stepIndex;
    final isCurrent = _currentStep == stepIndex;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFFEEF2FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isCurrent ? Border.all(color: const Color(0xFFC7D2FE)) : null,
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppTheme.primaryColor : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDivider(int stepIndex) {
    final isDone = _currentStep > stepIndex;
    return Container(
      width: 16,
      height: 2,
      margin: const EdgeInsets.only(bottom: 14),
      color: isDone ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildCurrentStepContent(AppProvider appProvider) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Personal Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            _buildInputField(_nameController, 'Full Name *', 'Enter tenant full name', Icons.person_outline),
            _buildInputField(_phoneController, 'Phone Number *', 'Enter 10-digit phone number', Icons.phone_outlined, keyboardType: TextInputType.phone),
            _buildInputField(_emailController, 'Email Address', 'Enter email address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            
            // DOB Picker
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: _dobController,
                readOnly: true,
                onTap: () => _selectDob(context),
                decoration: _inputDecoration('Date of Birth', 'Select DOB', Icons.calendar_today_outlined),
              ),
            ),

            // Gender Dropdown
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                menuMaxHeight: 200.0,
                value: _gender,
                decoration: _inputDecoration('Gender', '', Icons.wc_outlined),
                items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) => setState(() => _gender = val!),
              ),
            ),

            _buildInputField(_emergencyContactController, 'Emergency Contact', 'Name & Phone number', Icons.contact_phone_outlined, maxLines: 2),
          ],
        );
      case 1:
        final availableRooms = appProvider.rooms.where((r) => !r.isFull).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room & Bed Allocation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),

            // Room Selection
            DropdownButtonFormField<String>(
              isExpanded: true,
              menuMaxHeight: 200.0,
              value: _selectedRoomId,
              hint: const Text('Select Available Room', overflow: TextOverflow.ellipsis),
              decoration: _inputDecoration('Select Room *', '', Icons.meeting_room_outlined),
              items: availableRooms.map((r) => DropdownMenuItem(
                value: r.id,
                child: Text('Room ${r.number} (${r.availableBeds} beds left)', overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (val) => setState(() {
                _selectedRoomId = val;
                _selectedBedId = null;
              }),
            ),
            const SizedBox(height: 16),

            // Bed Selection
            if (_selectedRoomId != null) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                menuMaxHeight: 200.0,
                value: _selectedBedId,
                hint: const Text('Select Available Bed', overflow: TextOverflow.ellipsis),
                decoration: _inputDecoration('Select Bed *', '', Icons.single_bed_outlined),
                items: appProvider.rooms
                    .firstWhere((r) => r.id == _selectedRoomId)
                    .beds
                    .where((b) => b.isAvailable)
                    .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBedId = val),
              ),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please select a room first to see available beds',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rent & Payment Terms', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            _buildInputField(_rentController, 'Monthly Rent (₹) *', 'e.g. 8500', Icons.payments_outlined, keyboardType: TextInputType.number),
            _buildInputField(_securityController, 'Security Deposit (₹) *', 'e.g. 10000', Icons.security_outlined, keyboardType: TextInputType.number),
            
            // Rent Due Date Dropdown
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                menuMaxHeight: 200.0,
                value: _rentDueDate,
                decoration: _inputDecoration('Rent Due Date', '', Icons.event_outlined),
                items: List.generate(31, (index) {
                  final day = index + 1;
                  String suffix = 'th';
                  if (day < 11 || day > 13) {
                    switch (day % 10) {
                      case 1:
                        suffix = 'st';
                        break;
                      case 2:
                        suffix = 'nd';
                        break;
                      case 3:
                        suffix = 'rd';
                        break;
                    }
                  }
                  final val = '$day$suffix of every month';
                  return DropdownMenuItem(
                    value: val,
                    child: Text(val, overflow: TextOverflow.ellipsis),
                  );
                }),
                onChanged: (val) => setState(() => _rentDueDate = val!),
              ),
            ),

            // Move-In Date Picker
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: _moveInController,
                readOnly: true,
                onTap: () => _selectMoveInDate(context),
                decoration: _inputDecoration('Move-in Date', '', Icons.calendar_month_outlined),
              ),
            ),

            // Agreement Duration
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                menuMaxHeight: 200.0,
                value: _agreementDuration,
                decoration: _inputDecoration('Agreement Duration', '', Icons.description_outlined),
                items: ['None', '6 Months', '11 Months', '12 Months'].map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) => setState(() => _agreementDuration = val!),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: _inputDecoration(label, hint, icon),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
    );
  }

  void _submit(AppProvider provider) {
    if (_nameController.text.trim().isEmpty ||
        _selectedRoomId == null ||
        _selectedBedId == null ||
        _rentController.text.trim().isEmpty ||
        _securityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields (Name, Room, Bed, Rent, Security Deposit)')),
      );
      return;
    }

    var tenant = Tenant(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      roomId: _selectedRoomId!,
      bedId: _selectedBedId!,
      moveInDate: _moveInDate,
      rentAmount: double.tryParse(_rentController.text) ?? 0.0,
      securityDeposit: double.tryParse(_securityController.text) ?? 0.0,
      rentDueDate: DateTime.now().add(const Duration(days: 30)),
    );

    var room = provider.rooms.firstWhere((r) => r.id == _selectedRoomId);
    var bed = room.beds.firstWhere((b) => b.id == _selectedBedId);

    _selectedBedId = null;
    _selectedRoomId = null;

    provider.addTenant(tenant);

    context.go('/tenant_added_success?name=${Uri.encodeComponent(tenant.name)}&roomBed=${Uri.encodeComponent('Room ${room.number} - ${bed.name}')}&rent=${tenant.rentAmount}&moveIn=${Uri.encodeComponent(_moveInController.text)}');
  }
}


