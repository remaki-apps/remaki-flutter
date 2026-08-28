import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class RecordPaymentScreen extends StatefulWidget {
  final String tenantId;
  const RecordPaymentScreen({super.key, required this.tenantId});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _dateController = TextEditingController();
  String _paymentMethod = 'Cash';
  DateTime _paymentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(_paymentDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final tenantIndex = appProvider.tenants.indexWhere((t) => t.id == widget.tenantId);
      if (tenantIndex != -1) {
        final tenant = appProvider.tenants[tenantIndex];
        _amountController.text = tenant.totalDue.toStringAsFixed(0);
      }
    });
  }

  Future<void> _selectPaymentDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _paymentDate = picked;
        _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final tenantIndex = appProvider.tenants.indexWhere((t) => t.id == widget.tenantId);
    if (tenantIndex == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record Payment')),
        body: const Center(child: Text('Tenant not found')),
      );
    }
    final tenant = appProvider.tenants[tenantIndex];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Record Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Amount Due: ₹${tenant.totalDue.toStringAsFixed(0)}', style: TextStyle(color: tenant.isPaid ? AppTheme.success : AppTheme.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: (tenant.isPaid ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(tenant.isPaid ? 'Paid' : 'Unpaid', style: TextStyle(color: tenant.isPaid ? AppTheme.success : AppTheme.danger, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount Received (₹)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildMethodRadio('Cash')),
                Expanded(child: _buildMethodRadio('UPI')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildMethodRadio('Bank Transfer')),
                Expanded(child: _buildMethodRadio('Other')),
              ],
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Payment Date', suffixIcon: Icon(Icons.calendar_today)),
              readOnly: true,
              onTap: () => _selectPaymentDate(context),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (Optional)'),
              maxLines: 2,
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(_amountController.text) ?? 0;
                  if (amount > 0) {
                    appProvider.recordPayment(widget.tenantId, amount, _paymentMethod);
                    
                    final roomIndex = appProvider.rooms.indexWhere((r) => r.id == tenant.roomId);
                    final roomNumber = roomIndex != -1 ? appProvider.rooms[roomIndex].number : 'N/A';
                    final bedName = (roomIndex != -1) ? appProvider.rooms[roomIndex].beds.firstWhere((b) => b.id == tenant.bedId, orElse: () => Bed(id: '', name: '')).name : '';
                    
                    final dateStr = DateFormat('dd-MM-yyyy').format(_paymentDate);
                    context.go('/payment_success?amount=$amount&name=${Uri.encodeComponent(tenant.name)}&roomBed=${Uri.encodeComponent('Room $roomNumber - $bedName')}&dateMethod=${Uri.encodeComponent('$dateStr • $_paymentMethod')}');
                  }
                },
                child: const Text('Confirm Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodRadio(String value) {
    return RadioListTile<String>(
      title: Text(value, style: const TextStyle(fontSize: 14)),
      value: value,
      groupValue: _paymentMethod,
      onChanged: (val) {
        if (val != null) setState(() => _paymentMethod = val);
      },
      contentPadding: EdgeInsets.zero,
    );
  }
}
