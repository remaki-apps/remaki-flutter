import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class EditFinancialsDialog extends StatefulWidget {
  final AppProvider provider;
  final dynamic tenant; // Tenant model

  const EditFinancialsDialog({
    Key? key,
    required this.provider,
    required this.tenant,
  }) : super(key: key);

  @override
  State<EditFinancialsDialog> createState() => _EditFinancialsDialogState();
}

class _EditFinancialsDialogState extends State<EditFinancialsDialog> {
  late TextEditingController _rentController;
  late TextEditingController _dueDayController;
  String _paymentMode = 'CASH';
  
  // Controllers for bills
  final Map<String, TextEditingController> _billControllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _rentController = TextEditingController(text: widget.tenant.rentAmount.toStringAsFixed(0));
    _dueDayController = TextEditingController(text: widget.tenant.rentDueDate.day.toString());
    _paymentMode = widget.tenant.defaultPaymentMode ?? 'CASH';

    // Initialize controllers for pending bills
    for (var bill in widget.tenant.additionalCharges) {
      if (bill.billType != 'RENT') {
        _billControllers[bill.id] = TextEditingController(text: bill.amount.toStringAsFixed(0));
      }
    }
  }

  @override
  void dispose() {
    _rentController.dispose();
    _dueDayController.dispose();
    for (var controller in _billControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      final rent = double.tryParse(_rentController.text);
      final dueDay = int.tryParse(_dueDayController.text) ?? 5;

      if (rent != null) {
        await widget.provider.editTenantFinancials(
          widget.tenant.id,
          rent,
          null, // omit deposit
          dueDay,
          _paymentMode,
        );
      }


      for (var entry in _billControllers.entries) {
        final amount = double.tryParse(entry.value.text);
        if (amount != null) {
          await widget.provider.editBillAmount(entry.key, amount);
        }
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Financials updated successfully!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: \$e'),
            backgroundColor: Colors.red,
          ),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Financials',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.close, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              const Text('Monthly Rent (₹)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: _rentController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 16),

              const Text('Rent Due Date (Day of month)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: _dueDayController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 16),

              const Text('Default Payment Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _paymentMode,
                decoration: _inputDecoration(),
                items: ['CASH', 'UPI', 'BANK_TRANSFER', 'CARD', 'OTHER']
                    .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMode = val);
                },
              ),
              const SizedBox(height: 16),

              if (_billControllers.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text('Pending Bills', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                ...widget.tenant.additionalCharges.where((c) => c.billType != 'RENT').map((bill) {
                  final label = (bill.description == null || bill.description.trim().isEmpty) ? 'Utility Charge' : bill.description;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('\$label (₹)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _billControllers[bill.id],
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _saveChanges,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
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
        borderSide: const BorderSide(color: AppTheme.primaryColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
