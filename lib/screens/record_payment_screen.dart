import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/fancy_toast.dart';
import '../widgets/tenant_avatar.dart';
import '../widgets/custom_date_picker.dart';
import '../widgets/keyboard_responsive_layout.dart';

class RecordPaymentScreen extends StatefulWidget {
  final String tenantId;
  const RecordPaymentScreen({super.key, required this.tenantId});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  // Payment method state defaulted to Cash
  String _paymentMethod = 'Cash';
  String _paymentType = 'BOTH';
  DateTime _paymentDate = DateTime.now();
  bool _isLoading = false;
  bool _initializedTenant = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final tenantIndex = appProvider.tenants.indexWhere((t) => t.id == widget.tenantId);
      if (tenantIndex != -1) {
        final tenant = appProvider.tenants[tenantIndex];
        final double rentAmt = tenant.pendingRentAmount > 0 ? tenant.pendingRentAmount : tenant.rentAmount;
        final double billsAmt = tenant.totalPendingBills;
        final bool hasRent = rentAmt > 0 && !tenant.isPaid;
        final bool hasBills = billsAmt > 0;

        setState(() {
          if (hasRent && hasBills) {
            _paymentType = 'BOTH';
            _amountController.text = (rentAmt + billsAmt).toStringAsFixed(0);
          } else if (hasBills) {
            _paymentType = 'BILLS';
            _amountController.text = billsAmt.toStringAsFixed(0);
          } else {
            _paymentType = 'RENT';
            _amountController.text = rentAmt.toStringAsFixed(0);
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
      _paymentType = type;
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final tenantIndex = appProvider.tenants.indexWhere((t) => t.id == widget.tenantId);

    if (tenantIndex == -1) {
      if (appProvider.isLoading) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FD),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
              onPressed: () => context.canPop() ? context.pop() : context.go('/rent'),
            ),
            title: const Text('Record Payment'),
          ),
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () => context.canPop() ? context.pop() : context.go('/rent'),
          ),
          title: const Text('Record Payment'),
        ),
        body: const Center(
          child: Text('Tenant not found', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    final tenant = appProvider.tenants[tenantIndex];
    final double rentAmt = tenant.pendingRentAmount > 0 ? tenant.pendingRentAmount : tenant.rentAmount;
    final double billsAmt = tenant.totalPendingBills;
    final bool hasRent = rentAmt > 0 && !tenant.isPaid;
    final bool hasBills = billsAmt > 0;
    final double pFee = (hasRent && tenant.pendingConvenienceFee > 0)
        ? tenant.pendingConvenienceFee
        : ((hasRent && tenant.pendingConvenienceFee != 0.0 && !tenant.isPaid && !tenant.isPartiallyPaid)
            ? (tenant.platformFee > 0 ? tenant.platformFee : 5.0)
            : 0.0);

    if (!_initializedTenant) {
      _initializedTenant = true;
      if (hasRent && hasBills) {
        _paymentType = 'BOTH';
      } else if (hasBills) {
        _paymentType = 'BILLS';
      } else {
        _paymentType = 'RENT';
      }
      double initAmount = 0.0;
      if (_paymentType == 'BOTH') {
        initAmount = (hasRent ? (rentAmt + pFee) : 0.0) + (hasBills ? billsAmt : 0.0);
      } else if (_paymentType == 'RENT') {
        initAmount = rentAmt + pFee;
      } else if (_paymentType == 'BILLS') {
        initAmount = billsAmt;
      }
      if (initAmount == 0.0 && tenant.rentAmount > 0) {
        initAmount = tenant.rentAmount + pFee;
      }
      if (_amountController.text.isEmpty) {
        _amountController.text = initAmount.toStringAsFixed(0);
      }
    }

    final roomIndex = appProvider.rooms.indexWhere((r) => r.id == tenant.roomId);
    final roomNumber = roomIndex != -1 ? appProvider.rooms[roomIndex].number : 'N/A';
    final bedName = (roomIndex != -1)
        ? appProvider.rooms[roomIndex].beds.firstWhere((b) => b.id == tenant.bedId, orElse: () => Bed(id: '', name: '')).name
        : '';
    final roomBedString = formatRoomAndBed(roomNumber, bedName);

    final double enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final currentAmount = enteredAmount;
    final totalDue = tenant.totalPayableWithPlatformFee;
    final isValid = currentAmount > 0;
    final balanceAfter = (totalDue - currentAmount).clamp(0.0, double.infinity);

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
          style: GoogleFonts.lato(
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
            return KeyboardAutoScroll(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

                        // 2. Fixed Amount Display & Payment For Selection Card
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
                                'SELECT PAYMENT FOR',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '₹',
                                      style: GoogleFonts.lato(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _amountController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: GoogleFonts.lato(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                          letterSpacing: -0.5,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'Enter amount',
                                          hintStyle: TextStyle(fontSize: 18, color: Color(0xFF94A3B8)),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Choice Chips: Quick Presets
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (hasRent && hasBills)
                                    _buildPresetChip(
                                      'Full Dues (₹${(rentAmt + billsAmt + pFee).toStringAsFixed(0)})',
                                      _paymentType == 'BOTH' && enteredAmount == (rentAmt + billsAmt + pFee),
                                      () => _setAmountAndType(rentAmt + billsAmt + pFee, 'BOTH'),
                                    ),
                                  if (hasRent)
                                    _buildPresetChip(
                                      'Rent Only (₹${(rentAmt + pFee).toStringAsFixed(0)})',
                                      _paymentType == 'RENT' && enteredAmount == (rentAmt + pFee),
                                      () => _setAmountAndType(rentAmt + pFee, 'RENT'),
                                    ),
                                  if (hasBills)
                                    _buildPresetChip(
                                      'Bill Only (₹${billsAmt.toStringAsFixed(0)})',
                                      _paymentType == 'BILLS' && enteredAmount == billsAmt,
                                      () => _setAmountAndType(billsAmt, 'BILLS'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Payment Method Selection Card
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PAYMENT METHOD',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildPaymentMethodTile(
                                      label: 'Cash',
                                      icon: Icons.payments_rounded,
                                      value: 'Cash',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildPaymentMethodTile(
                                      label: 'UPI',
                                      icon: Icons.qr_code_scanner_rounded,
                                      value: 'UPI',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildPaymentMethodTile(
                                      label: 'Bank',
                                      icon: Icons.account_balance_rounded,
                                      value: 'Bank',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Classic Details Card (Date & Notes)
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

                        // 5. Classic Summary / Receipt Card
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
                              _buildSummaryRow(
                                'Payment For',
                                _paymentType == 'BOTH'
                                    ? 'Rent + Bills'
                                    : (_paymentType == 'RENT' ? 'Rent Only' : 'Bill Only'),
                              ),
                              const SizedBox(height: 6),
                              _buildSummaryRow('Payment Method', _paymentMethod),
                              const SizedBox(height: 6),
                              if (hasRent) ...[
                                _buildSummaryRow('Rent Balance', '₹${rentAmt.toStringAsFixed(0)}'),
                                const SizedBox(height: 6),
                              ],
                              if (pFee > 0 && hasRent) ...[
                                _buildSummaryRow('Platform Fee', '₹${pFee.toStringAsFixed(0)}'),
                                const SizedBox(height: 6),
                              ],
                              if (hasBills) ...[
                                _buildSummaryRow('Bills Due', '₹${billsAmt.toStringAsFixed(0)}'),
                                const SizedBox(height: 6),
                              ],
                              _buildSummaryRow('Total Due', '₹${totalDue.toStringAsFixed(0)}', isHighlight: true),
                              const SizedBox(height: 6),
                              _buildSummaryRow('Paying Now', '₹${enteredAmount.toStringAsFixed(0)}'),
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
                                    balanceAfter <= 0
                                        ? '₹0 (Cleared)'
                                        : '₹${balanceAfter.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: balanceAfter <= 0
                                          ? const Color(0xFF16A34A)
                                          : AppTheme.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),
                        const SizedBox(height: 16),

                        // 6. Confirm Payment Button
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
                                        paymentDate: _paymentDate,
                                        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
                                      );

                                      final dateStr = DateFormat('dd-MM-yyyy').format(_paymentDate);
                                      final fullRoomBed = formatRoomAndBed(roomNumber, bedName, separator: ' - ');

                                      if (context.mounted) {
                                        context.pushReplacement(
                                          '/payment_success'
                                          '?amount=${currentAmount.toStringAsFixed(0)}'
                                          '&name=${Uri.encodeComponent(tenant.name)}'
                                          '&roomBed=${Uri.encodeComponent(fullRoomBed)}'
                                          '&dateMethod=${Uri.encodeComponent("$dateStr • $_paymentMethod")}'
                                          '&tenantId=${widget.tenantId}',
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) setState(() => _isLoading = false);
                                      if (context.mounted) {
                                        FancyToast.showError(context, 'Payment Failed', message: ApiService.cleanErrorMessage(e));
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
                                        : 'Select Payment',
                                    style: GoogleFonts.lato(
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

  Widget _buildPaymentMethodTile({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
