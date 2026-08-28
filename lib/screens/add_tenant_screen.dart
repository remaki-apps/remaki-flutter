import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

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
  String _paymentMode = 'Cash';
  String _agreementDuration = '12 Months';

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.initialRoomId;
    _selectedBedId = widget.initialBedId;
    _moveInController.text = DateFormat('dd-MM-yyyy').format(_moveInDate);
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
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Add Tenant'),
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          } else {
            _submit(appProvider);
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: [
          Step(
            title: const Text('Personal Info', style: TextStyle(fontSize: 10)),
            isActive: _currentStep >= 0,
            content: Column(
              children: [
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'Enter full name')),
                TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number *', hintText: 'Enter phone number'), keyboardType: TextInputType.phone),
                TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', hintText: 'Enter email address')),
                TextField(
                  controller: _dobController,
                  decoration: const InputDecoration(labelText: 'Date of Birth', hintText: 'Select DOB', suffixIcon: Icon(Icons.calendar_today)),
                  readOnly: true,
                  onTap: () => _selectDob(context),
                ),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _gender = val!),
                ),
                TextField(controller: _emergencyContactController, decoration: const InputDecoration(labelText: 'Emergency Contact', hintText: 'Name & Phone number'), maxLines: 2),
              ],
            ),
          ),
          Step(
            title: const Text('Allocate Bed', style: TextStyle(fontSize: 10)),
            isActive: _currentStep >= 1,
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedRoomId,
                  hint: const Text('Select Room'),
                  items: appProvider.rooms.where((r) => !r.isFull).map((r) => DropdownMenuItem(value: r.id, child: Text('Room ${r.number}'))).toList(),
                  onChanged: (val) => setState(() {
                    _selectedRoomId = val;
                    _selectedBedId = null;
                  }),
                ),
                if (_selectedRoomId != null) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedBedId,
                    hint: const Text('Select Bed'),
                    items: appProvider.rooms.firstWhere((r) => r.id == _selectedRoomId).beds.where((b) => b.isAvailable).map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (val) => setState(() => _selectedBedId = val),
                  ),
                ]
              ],
            ),
          ),
          Step(
            title: const Text('Rent Details', style: TextStyle(fontSize: 10)),
            isActive: _currentStep >= 2,
            content: Column(
              children: [
                TextField(controller: _rentController, decoration: const InputDecoration(labelText: 'Monthly Rent (₹)', hintText: 'e.g. 8500'), keyboardType: TextInputType.number),
                TextField(controller: _securityController, decoration: const InputDecoration(labelText: 'Security Deposit (₹)', hintText: 'e.g. 10000'), keyboardType: TextInputType.number),
                DropdownButtonFormField<String>(
                  value: _rentDueDate,
                  decoration: const InputDecoration(labelText: 'Rent Due Date'),
                  items: ['1st of every month', '5th of every month', '10th of every month'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _rentDueDate = val!),
                ),
                TextField(
                  controller: _moveInController,
                  decoration: const InputDecoration(labelText: 'Move-in Date', suffixIcon: Icon(Icons.calendar_today)),
                  readOnly: true,
                  onTap: () => _selectMoveInDate(context),
                ),
                DropdownButtonFormField<String>(
                  value: _paymentMode,
                  decoration: const InputDecoration(labelText: 'Rent Payment Mode'),
                  items: ['Cash', 'UPI', 'Bank Transfer'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _paymentMode = val!),
                ),
                DropdownButtonFormField<String>(
                  value: _agreementDuration,
                  decoration: const InputDecoration(labelText: 'Agreement Duration'),
                  items: ['6 Months', '11 Months', '12 Months'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _agreementDuration = val!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submit(AppProvider provider) {
    if (_nameController.text.isEmpty || _selectedRoomId == null || _selectedBedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields (Name, Room, Bed)')),
      );
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
    var bed = room.beds.firstWhere((b) => b.id == _selectedBedId);
    
    // Prevent dropdown crash on rebuild by clearing selection before notifying listeners
    _selectedBedId = null;
    _selectedRoomId = null;
    
    provider.addTenant(tenant);
    
    context.go('/tenant_added_success?name=${Uri.encodeComponent(tenant.name)}&roomBed=${Uri.encodeComponent('Room ${room.number} - ${bed.name}')}&rent=${tenant.rentAmount}&moveIn=${Uri.encodeComponent(_moveInController.text)}');
  }
}

