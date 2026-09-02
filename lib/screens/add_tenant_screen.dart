import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_expandable_dropdown.dart';
import '../widgets/custom_date_picker.dart';

class AddTenantScreen extends StatefulWidget {
  final String? initialRoomId;
  final String? initialBedId;
  const AddTenantScreen({super.key, this.initialRoomId, this.initialBedId});

  @override
  State<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends State<AddTenantScreen> {
  int _currentStep = 0;
  String? _inlineError;
  bool _isLoading = false;

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
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  Future<void> _selectMoveInDate(BuildContext context) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _moveInDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Move-in Date',
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
                          setState(() => _inlineError = null);
                          if (_currentStep < 2) {
                            if (_currentStep == 0) {
                              if (_nameController.text.trim().isEmpty) {
                                setState(() => _inlineError = 'Please enter tenant full name.');
                                return;
                              }
                              if (_phoneController.text.trim().length != 10) {
                                setState(() => _inlineError = 'Phone number must be exactly 10 digits.');
                                return;
                              }
                            }
                            if (_currentStep == 1) {
                              if (_selectedRoomId == null) {
                                setState(() => _inlineError = 'Please select a room.');
                                return;
                              }
                              if (_selectedBedId == null) {
                                setState(() => _inlineError = 'Please select a bed.');
                                return;
                              }
                            }
                            setState(() => _currentStep += 1);
                          } else {
                            _submit(appProvider);
                          }
                        },
                      child: _isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
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

  Widget _buildInlineErrorBanner() {
    if (_inlineError == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _inlineError!,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent(AppProvider appProvider) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInlineErrorBanner(),
            _buildSectionHeader('Personal Details', Icons.person_outline),
            _buildInputField(_nameController, 'Full Name *', 'Enter tenant full name', Icons.person_outline),
            _buildInputField(
              _phoneController,
              'Phone Number *',
              'Enter 10-digit phone number',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
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
            CustomExpandableDropdown<String>(
              label: 'Gender',
              value: _gender,
              hintText: 'Select Gender',
              icon: Icons.wc_outlined,
              items: ['Male', 'Female', 'Other'].map((g) => DropdownOption(value: g, label: g)).toList(),
              onChanged: (val) => setState(() => _gender = val),
            ),

            _buildInputField(_emergencyContactController, 'Emergency Contact', 'Name & Phone number', Icons.contact_phone_outlined, maxLines: 2),
          ],
        );
      case 1:
        final availableRooms = appProvider.rooms.where((r) => !r.isFull).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInlineErrorBanner(),
            _buildSectionHeader('Room & Bed Allocation', Icons.meeting_room_outlined),

            // Room Selection
            CustomExpandableDropdown<String>(
              label: 'Select Room *',
              value: _selectedRoomId,
              hintText: 'Select Available Room',
              icon: Icons.meeting_room_outlined,
              items: availableRooms
                  .map((r) => DropdownOption(value: r.id, label: 'Room ${r.number} [${r.availableBeds} beds left]'))
                  .toList(),
              onChanged: (val) => setState(() {
                _selectedRoomId = val;
                _selectedBedId = null;
                _inlineError = null;
              }),
            ),

            // Bed Selection
            if (_selectedRoomId != null) ...[
              CustomExpandableDropdown<String>(
                label: 'Select Bed *',
                value: _selectedBedId,
                hintText: 'Select Available Bed',
                icon: Icons.single_bed_outlined,
                items: appProvider.rooms
                    .firstWhere((r) => r.id == _selectedRoomId)
                    .beds
                    .where((b) => b.isAvailable)
                    .map((b) => DropdownOption(value: b.id, label: b.name))
                    .toList(),
                onChanged: (val) => setState(() {
                  _selectedBedId = val;
                  _inlineError = null;
                }),
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
            _buildInlineErrorBanner(),
            _buildSectionHeader('Rent & Payment Terms', Icons.payments_outlined),
            _buildInputField(_rentController, 'Monthly Rent (₹) *', 'e.g. 8500', Icons.payments_outlined, keyboardType: TextInputType.number),
            _buildInputField(_securityController, 'Security Deposit (₹) *', 'e.g. 10000', Icons.security_outlined, keyboardType: TextInputType.number),
            
            // Rent Due Date Dropdown
            CustomExpandableDropdown<String>(
              label: 'Rent Due Date',
              value: _rentDueDate,
              hintText: 'Select Rent Due Date',
              icon: Icons.event_outlined,
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
                return DropdownOption(value: val, label: val);
              }),
              onChanged: (val) => setState(() => _rentDueDate = val),
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
            CustomExpandableDropdown<String>(
              label: 'Agreement Duration',
              value: _agreementDuration,
              hintText: 'Select Duration',
              icon: Icons.description_outlined,
              items: ['None', '6 Months', '11 Months', '12 Months']
                  .map((g) => DropdownOption(value: g, label: g))
                  .toList(),
              onChanged: (val) => setState(() => _agreementDuration = val),
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        onChanged: (_) {
          if (_inlineError != null) setState(() => _inlineError = null);
        },
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

  Future<void> _submit(AppProvider provider) async {
    setState(() => _inlineError = null);

    if (_nameController.text.trim().isEmpty) {
      setState(() => _inlineError = 'Please enter tenant full name.');
      return;
    }
    if (_phoneController.text.trim().length != 10) {
      setState(() => _inlineError = 'Phone number must be exactly 10 digits.');
      return;
    }
    if (_selectedRoomId == null) {
      setState(() => _inlineError = 'Please select a room.');
      return;
    }
    if (_selectedBedId == null) {
      setState(() => _inlineError = 'Please select a bed.');
      return;
    }
    if (_rentController.text.trim().isEmpty) {
      setState(() => _inlineError = 'Please enter Monthly Rent (₹).');
      return;
    }
    if (_securityController.text.trim().isEmpty) {
      setState(() => _inlineError = 'Please enter Security Deposit (₹).');
      return;
    }

    var tenant = Tenant(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      emergencyContact: _emergencyContactController.text.trim(),
      roomId: _selectedRoomId!,
      bedId: _selectedBedId!,
      moveInDate: _moveInDate,
      rentAmount: double.tryParse(_rentController.text) ?? 0.0,
      securityDeposit: double.tryParse(_securityController.text) ?? 0.0,
      rentDueDate: DateTime.now().add(const Duration(days: 30)),
    );

    var room = provider.rooms.firstWhere((r) => r.id == _selectedRoomId);

    _selectedBedId = null;
    _selectedRoomId = null;

    setState(() => _isLoading = true);
    
    final tempPassword = await provider.addTenant(tenant);

    if (!mounted) return;
    
    setState(() => _isLoading = false);

    context.go('/tenant_added_success?tenantId=${tenant.id}&password=${Uri.encodeComponent(tempPassword ?? '')}&name=${Uri.encodeComponent(tenant.name)}&phone=${Uri.encodeComponent(tenant.phone)}&roomNumber=${Uri.encodeComponent(room.number)}&floor=${Uri.encodeComponent(room.floor)}&roomBed=${Uri.encodeComponent('Room ${room.number}')}&rent=${tenant.rentAmount}&moveIn=${Uri.encodeComponent(_moveInController.text)}');
  }
}


