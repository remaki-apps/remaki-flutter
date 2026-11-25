import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/organization_models.dart';
import '../../providers/organization_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fancy_toast.dart';

class OrgPlatformFeeScreen extends StatefulWidget {
  const OrgPlatformFeeScreen({super.key});

  @override
  State<OrgPlatformFeeScreen> createState() => _OrgPlatformFeeScreenState();
}

class _OrgPlatformFeeScreenState extends State<OrgPlatformFeeScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = true;
  List<OrganizationPropertyPlatformFeeSummary> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _monthStr => DateFormat('yyyy-MM').format(_selectedMonth);

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final raw = await ApiService.fetchOrganizationPlatformFeeOverview(billingMonth: _monthStr);
      if (mounted) {
        setState(() {
          _items = raw
              .map((e) => OrganizationPropertyPlatformFeeSummary.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        FancyToast.showError(context, 'Load Failed', message: ApiService.cleanErrorMessage(e));
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
    _loadData();
  }

  Future<void> _showAssignFeeDialog(OrganizationPropertyPlatformFeeSummary pg) async {
    final feeCtrl = TextEditingController(text: pg.feePerTenant.toStringAsFixed(0));
    final upiCtrl = TextEditingController(text: pg.platformFeeUpiId ?? '');
    final payeeCtrl = TextEditingController(text: pg.platformFeePayeeName ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Assign / Edit Fee — ${pg.propertyName}', style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: feeCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Fee per Tenant (₹)'),
            ),
            const SizedBox(height: 10),
            TextField(controller: upiCtrl, decoration: const InputDecoration(labelText: 'Collection UPI ID')),
            const SizedBox(height: 10),
            TextField(controller: payeeCtrl, decoration: const InputDecoration(labelText: 'Payee Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      try {
        await context.read<OrganizationProvider>().updateProperty({
          'propertyId': pg.propertyId,
          'platformFee': double.tryParse(feeCtrl.text.trim()) ?? pg.feePerTenant,
          'platformFeeUpiId': upiCtrl.text.trim().isNotEmpty ? upiCtrl.text.trim() : null,
          'platformFeePayeeName': payeeCtrl.text.trim().isNotEmpty ? payeeCtrl.text.trim() : null,
        });
        if (mounted) {
          FancyToast.showSuccess(context, 'Updated', message: 'Platform fee updated for ${pg.propertyName}.');
          _loadData();
        }
      } catch (e) {
        if (mounted) FancyToast.showError(context, 'Error', message: ApiService.cleanErrorMessage(e));
      }
    }
  }

  Future<void> _showMarkPaidDialog(
    OrganizationPropertyPlatformFeeSummary pg, {
    OrgPlatformFeeSettlementItem? existing,
  }) async {
    final defaultAmt = existing?.amountPaid ?? (pg.pendingAmount > 0 ? pg.pendingAmount : pg.totalCollected);
    final amtCtrl = TextEditingController(text: defaultAmt > 0 ? defaultAmt.toStringAsFixed(0) : '');
    final refCtrl = TextEditingController(text: existing?.referenceId ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String mode = existing?.paymentMode ?? 'UPI';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            existing == null ? 'Mark Platform Fee Paid' : 'Edit Settlement',
            style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${pg.propertyName} • ${pg.billingMonth}', style: GoogleFonts.lato(fontSize: 12.5, color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount Settled (₹)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: mode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  ],
                  onChanged: (v) => setModalState(() => mode = v ?? 'UPI'),
                ),
                const SizedBox(height: 10),
                TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'UTR / Reference ID (optional)')),
                const SizedBox(height: 10),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
              child: Text(existing == null ? 'Mark as Paid' : 'Update'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
      if (amt <= 0) {
        FancyToast.showError(context, 'Invalid Amount', message: 'Enter an amount greater than 0.');
        return;
      }
      try {
        if (existing == null) {
          await ApiService.markPlatformFeePaidUnderOrg({
            'propertyId': pg.propertyId,
            'billingMonth': pg.billingMonth,
            'amountPaid': amt,
            'paymentMode': mode,
            'referenceId': refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          });
        } else {
          await ApiService.updatePlatformFeeSettlementUnderOrg({
            'settlementId': existing.id,
            'amountPaid': amt,
            'paymentMode': mode,
            'referenceId': refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          });
        }
        if (mounted) {
          FancyToast.showSuccess(context, 'Saved', message: 'Settlement synced to Admin account.');
          _loadData();
        }
      } catch (e) {
        if (mounted) FancyToast.showError(context, 'Failed', message: ApiService.cleanErrorMessage(e));
      }
    }
  }

  Future<void> _deleteSettlement(OrgPlatformFeeSettlementItem s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Settlement?'),
        content: Text('Delete ₹${s.amountPaid.toStringAsFixed(0)} settlement record? This will revert the paid balance on the Admin side.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ApiService.deletePlatformFeeSettlementUnderOrg(s.id);
        if (mounted) {
          FancyToast.showSuccess(context, 'Deleted', message: 'Settlement reverted.');
          _loadData();
        }
      } catch (e) {
        if (mounted) FancyToast.showError(context, 'Error', message: ApiService.cleanErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Platform Fee & Settlements', style: GoogleFonts.lato(fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _changeMonth(-1)),
                Text(DateFormat('MMMM yyyy').format(_selectedMonth), style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800)),
                IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _buildPgCard(_items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPgCard(OrganizationPropertyPlatformFeeSummary pg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pg.propertyName, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
                    Text('${pg.adminName} (${pg.adminCode}) • ₹${pg.feePerTenant.toStringAsFixed(0)}/tenant',
                        style: GoogleFonts.lato(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAssignFeeDialog(pg),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Fee'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric('Collected', '₹${pg.totalCollected.toStringAsFixed(0)}', AppTheme.primaryColor),
              _metric('Settled', '₹${pg.totalSettled.toStringAsFixed(0)}', AppTheme.success),
              _metric('Pending', '₹${pg.pendingAmount.toStringAsFixed(0)}', pg.pendingAmount > 0 ? AppTheme.danger : AppTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showMarkPaidDialog(pg),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text('Mark Platform Fee Paid', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (pg.settlements.isNotEmpty) ...[
            const Divider(height: 22),
            Text('Settlement History', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
            const SizedBox(height: 6),
            ...pg.settlements.map((s) {
              final dt = DateTime.tryParse(s.paidAt)?.toLocal();
              final dateLabel = dt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(dt) : s.paidAt;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('₹${s.amountPaid.toStringAsFixed(0)} via ${s.paymentMode}', style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text('$dateLabel${s.referenceId != null ? " • Ref: ${s.referenceId}" : ""}', style: GoogleFonts.lato(fontSize: 11.5)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                      onPressed: () => _showMarkPaidDialog(pg, existing: s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                      onPressed: () => _deleteSettlement(s),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String val, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.lato(fontSize: 11, color: AppTheme.textSecondary)),
            Text(val, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
