import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/fancy_toast.dart';

class AllocateTenantScreen extends StatefulWidget {
  final String roomId;
  final String bedId;

  const AllocateTenantScreen({super.key, required this.roomId, required this.bedId});

  @override
  State<AllocateTenantScreen> createState() => _AllocateTenantScreenState();
}

class _AllocateTenantScreenState extends State<AllocateTenantScreen> {
  int _currentStep = 0;
  String? _selectedTenantId;

  // Rent Details
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
    _moveInController.text = "${_moveInDate.day}-${_moveInDate.month}-${_moveInDate.year}";
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
        _moveInController.text = "${picked.day}-${picked.month}-${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final unallocatedTenants = appProvider.tenants.where((t) => t.roomId.isEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Allocate Tenant'),
      ),
      body: unallocatedTenants.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/no_tenant1.png',
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Unallocated Tenants Found',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create a new tenant to allocate to this bed.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.push('/add_tenant?roomId=${widget.roomId}&bedId=${widget.bedId}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Create New Tenant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
          : Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 0) {
                  if (_selectedTenantId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a tenant.')));
                    return;
                  }
                  setState(() => _currentStep += 1);
                } else {
                  appProvider.allocateTenant(
                    _selectedTenantId!,
                    widget.roomId,
                    widget.bedId,
                    rentAmount: double.tryParse(_rentController.text) ?? 0.0,
                    securityDeposit: double.tryParse(_securityController.text) ?? 0.0,
                    moveInDate: _moveInDate,
                  );
                  context.pop();
                  FancyToast.showSuccess(
                    context,
                    'Tenant Allocated!',
                    message: 'Tenant successfully assigned to bed.',
                  );
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) setState(() => _currentStep -= 1);
              },
              steps: [
                Step(
                  title: const Text('Select Tenant'),
                  isActive: _currentStep >= 0,
                  content: DropdownButtonFormField<String>(
                    value: _selectedTenantId,
                    decoration: const InputDecoration(labelText: 'Select Tenant *'),
                    items: unallocatedTenants.map((t) => DropdownMenuItem(value: t.id, child: Text('${t.name} (${t.phone})'))).toList(),
                    onChanged: (val) => setState(() => _selectedTenantId = val),
                  ),
                ),
                Step(
                  title: const Text('Rent Details'),
                  isActive: _currentStep >= 1,
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
}
