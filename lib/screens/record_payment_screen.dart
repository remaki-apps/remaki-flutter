import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/fancy_toast.dart';
import '../widgets/tenant_avatar.dart';
import '../widgets/custom_date_picker.dart';

class RecordPaymentScreen extends StatefulWidget {
  final String tenantId;
  const RecordPaymentScreen({super.key, required this.tenantId});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  // Payment method and type preserved for backend recording
  final String _paymentMethod = 'UPI';
  String _paymentType = 'BOTH';
  DateTime _paymentDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final tenantIndex = appProvider.tenants.indexWhere((t) => t.id == widget.tenantId);
      if (tenantIndex != -1) {
        final tenant = appProvider.tenants[tenantIndex];
        if (tenant.totalDue > 0) {
          _amountController.text = tenant.totalDue.toStringAsFixed(0);
        } else if (tenant.rentAmount > 0) {
          _amountController.text = tenant.rentAmount.toStringAsFixed(0);
        }

        setState(() {
          if (tenant.pendingRentAmount > 0 && tenant.totalPendingBills == 0) {
            _paymentType = 'RENT';
          } else if (tenant.totalPendingBills > 0 && tenant.pendingRentAmount == 0) {
            _paymentType = 'BILLS';
          } else {
            _paymentType = 'BOTH';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectPaymentDate(BuildContext context) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Payment Date',
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  void _setAmountAndType(double amount, String type) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
      _paymentType = type;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final tenantIndex = appProvider.tenants.indexWhere((t) => t.id == widget.tenantId);

    if (tenantIndex == -1) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () => context.pop(),
          ),
          title: const Text('Record Payment'),
        ),
        body: const Center(
          child: Text('Tenant not found', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    final tenant = appProvider.tenants[tenantIndex];
    final roomIndex = appProvider.rooms.indexWhere((r) => r.id == tenant.roomId);
    final roomNumber = roomIndex != -1 ? appProvider.rooms[roomIndex].number : 'N/A';
    final bedName = (roomIndex != -1)
        ? appProvider.rooms[roomIndex].beds.firstWhere((b) => b.id == tenant.bedId, orElse: () => Bed(id: '', name: '')).name
        : '';
    final roomBedString = 'Room $roomNumber${bedName.isNotEmpty ? ' • Bed $bedName' : ''}';

    final currentAmount = double.tryParse(_amountController.text) ?? 0.0;
    final totalDue = tenant.totalDue;
    final isValid = currentAmount > 0;
    final balanceAfter = totalDue - currentAmount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Record Payment',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Classic Tenant Overview Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x04000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              TenantAvatar(
                                name: tenant.name,
                                imageUrl: tenant.imageUrl,
                                radius: 24,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tenant.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      roomBedString,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${totalDue.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: totalDue == 0 ? const Color(0xFF16A34A) : AppTheme.danger,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    totalDue == 0 ? 'Fully Paid' : 'Total Due',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: totalDue == 0 ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Amount Input Hero Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x04000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AMOUNT RECEIVED',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '₹',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _amountController,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: -0.5,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: '0',
                                        hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Preset Quick Chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (totalDue > 0)
                                    _buildPresetChip(
                                      'Full Due (₹${totalDue.toStringAsFixed(0)})',
                                      currentAmount == totalDue,
                                      () => _setAmountAndType(totalDue, 'BOTH'),
                                    ),
                                  if (tenant.pendingRentAmount > 0 && tenant.pendingRentAmount != totalDue)
                                    _buildPresetChip(
                                      'Rent (₹${tenant.pendingRentAmount.toStringAsFixed(0)})',
                                      currentAmount == tenant.pendingRentAmount,
                                      () => _setAmountAndType(tenant.pendingRentAmount, 'RENT'),
                                    ),
                                  if (tenant.totalPendingBills > 0 && tenant.totalPendingBills != totalDue)
                                    _buildPresetChip(
                                      'Bills (₹${tenant.totalPendingBills.toStringAsFixed(0)})',
                                      currentAmount == tenant.totalPendingBills,
                                      () => _setAmountAndType(tenant.totalPendingBills, 'BILLS'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Classic Details Card (Date & Notes)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x04000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Date Row
                              InkWell(
                                onTap: () => _selectPaymentDate(context),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryColor),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Payment Date',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(_paymentDate),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              // Notes Row
                              Row(
                                children: [
                                  const Icon(Icons.note_alt_outlined, size: 18, color: AppTheme.primaryColor),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _notesController,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                      decoration: const InputDecoration(
                                        hintText: 'Notes or reference (Optional)',
                                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Classic Summary / Receipt Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'RECEIPT SUMMARY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildSummaryRow('Tenant', tenant.name),
                              const SizedBox(height: 6),
                              _buildSummaryRow('Space', roomBedString),
                              const SizedBox(height: 6),
                              _buildSummaryRow('Current Balance', '₹${totalDue.toStringAsFixed(0)}'),
                              const SizedBox(height: 6),
                              _buildSummaryRow(
                                'Recording Amount',
                                '₹${currentAmount.toStringAsFixed(0)}',
                                isHighlight: true,
                              ),
                              const Divider(height: 16, color: Color(0xFFE2E8F0)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Balance After Payment',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    balanceAfter == 0
                                        ? '₹0 (Cleared)'
                                        : (balanceAfter > 0
                                            ? '₹${balanceAfter.toStringAsFixed(0)}'
                                            : '₹${(-balanceAfter).toStringAsFixed(0)} (Advance)'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: balanceAfter == 0
                                          ? const Color(0xFF16A34A)
                                          : (balanceAfter > 0 ? AppTheme.danger : const Color(0xFF2563EB)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),
                        const SizedBox(height: 16),

                        // 5. Classic Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (!isValid || _isLoading)
                                ? null
                                : () async {
                                    setState(() => _isLoading = true);
                                    try {
                                      await appProvider.recordPayment(
                                        widget.tenantId,
                                        currentAmount,
                                        _paymentMethod,
                                        paymentType: _paymentType,
                                      );

                                      final dateStr = DateFormat('dd-MM-yyyy').format(_paymentDate);
                                      final bedDisplay = bedName.isNotEmpty ? ' - Bed $bedName' : '';
                                      final fullRoomBed = 'Room $roomNumber$bedDisplay';

                                      if (context.mounted) {
                                        context.go(
                                          '/payment_success'
                                          '?amount=${currentAmount.toStringAsFixed(0)}'
                                          '&name=${Uri.encodeComponent(tenant.name)}'
                                          '&roomBed=${Uri.encodeComponent(fullRoomBed)}'
                                          '&dateMethod=${Uri.encodeComponent('$dateStr • $_paymentMethod')}',
                                        );
                                      }
                                    } catch (e) {
                                      setState(() => _isLoading = false);
                                      if (context.mounted) {
                                        FancyToast.showError(context, 'Payment Failed', message: e.toString());
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              disabledBackgroundColor: const Color(0xFFCBD5E1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                  )
                                : Text(
                                    isValid
                                        ? 'Confirm Payment • ₹${currentAmount.toStringAsFixed(0)}'
                                        : 'Enter Amount',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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
          },
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: isHighlight ? AppTheme.primaryColor : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
