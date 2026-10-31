import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../utils/image_compress_util.dart';
import '../widgets/fancy_toast.dart';
import '../widgets/universal_upi_checkout_modal.dart';

class PlatformFeeSummaryScreen extends StatefulWidget {
  final String? propertyId;

  const PlatformFeeSummaryScreen({super.key, this.propertyId});

  @override
  State<PlatformFeeSummaryScreen> createState() => _PlatformFeeSummaryScreenState();
}

class _PlatformFeeSummaryScreenState extends State<PlatformFeeSummaryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _summaryData;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final propId = widget.propertyId ??
          (appProvider.selectedPropertyId != 'ALL' ? appProvider.selectedPropertyId : null);

      final data = await ApiService.fetchPropertyPlatformFeeSummary(
        propertyId: propId,
      );

      if (mounted) {
        setState(() {
          _summaryData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  static const String organizationUpiId = 'kishoremagesh1@okhdfcbank';
  static const String organizationPayeeName = 'Remaki Organization';

  void _openOrganizationPaymentModal() {
    final totalCollected = (_summaryData?['monthlyPlatformFeeCollected'] as num?)?.toDouble() ?? 0.0;
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final pgName = _summaryData?['propertyName'] ?? appProvider.pgName;
    final billingMonth = _summaryData?['billingMonth'] as String? ??
        DateFormat('yyyy-MM').format(DateTime.now());

    if (totalCollected <= 0) {
      FancyToast.showError(
        context,
        'No Fees Collected',
        message: 'No tenant platform fee has been collected yet to remit for this cycle.',
      );
      return;
    }

    UniversalUpiCheckoutModal.show(
      context,
      amount: totalCollected,
      upiId: organizationUpiId,
      payeeName: organizationPayeeName,
      propertyName: pgName,
      note: 'Platform fee - $pgName ($billingMonth)',
      onProceedToUpload: () {
        _pickAndConfirmProof(totalCollected, pgName, billingMonth);
      },
    );
  }

  Future<void> _pickAndConfirmProof(
    double amount,
    String pgName,
    String billingMonth,
  ) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1600,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final compressed = await ImageCompressUtil.compressDocumentOrBill(bytes);

      if (!mounted) return;
      _showProofConfirmationDialog(compressed, amount, pgName, billingMonth);
    } catch (e) {
      if (mounted) {
        FancyToast.showError(
          context,
          'Image Selection Error',
          message: e.toString(),
        );
      }
    }
  }

  void _showProofConfirmationDialog(
    Uint8List imageBytes,
    double amount,
    String pgName,
    String billingMonth,
  ) {
    final utrController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0D9488), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Remittance Proof',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Amount Remitted:', style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF64748B))),
                        Text('₹${amount.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F766E))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payee UPI:', style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF64748B))),
                        Text(organizationUpiId, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Property:', style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF64748B))),
                        Text(pgName, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Payment Screenshot',
                style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: const Color(0xFFF1F5F9),
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'UPI Reference / UTR (Optional)',
                style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: utrController,
                decoration: InputDecoration(
                  hintText: 'e.g. 12-digit UTR (423891823901)',
                  hintStyle: GoogleFonts.lato(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                  ),
                ),
                style: GoogleFonts.lato(fontSize: 13),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.lato(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              FancyToast.showSuccess(
                context,
                'Remittance Submitted',
                message: 'Platform fee payment proof of ₹${amount.toStringAsFixed(0)} sent to Remaki Organization.',
              );
              _loadSummary();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Submit Remittance',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPayBar(double totalCollected) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collected Platform Fee',
                    style: GoogleFonts.lato(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '₹${totalCollected.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _openOrganizationPaymentModal,
              icon: const Icon(Icons.payment_rounded, size: 18),
              label: Text(
                'Send Payment',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final pgName = _summaryData?['propertyName'] ?? appProvider.pgName;
    final totalCollected = (_summaryData?['monthlyPlatformFeeCollected'] as num?)?.toDouble() ?? 0.0;
    final feePerTenant = (_summaryData?['feePerTenant'] as num?)?.toDouble() ?? 9.0;
    final totalTenants = (_summaryData?['totalTenantsContributed'] as num?)?.toInt() ?? 0;
    final billingMonth = _summaryData?['billingMonth'] as String? ??
        DateFormat('yyyy-MM').format(DateTime.now());
    final resetsOn = _summaryData?['resetsOn'] as String? ?? '1st of next month';
    final items = (_summaryData?['items'] as List<dynamic>?) ?? [];

    DateTime? parsedMonthDate;
    try {
      final parts = billingMonth.split('-');
      if (parts.length == 2) {
        parsedMonthDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      }
    } catch (_) {}

    final formattedMonth = parsedMonthDate != null
        ? DateFormat('MMMM yyyy').format(parsedMonthDate)
        : billingMonth;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Platform Fee Details',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0D9488)),
            tooltip: 'Refresh',
            onPressed: _loadSummary,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D9488)),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to Load Fee Summary',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(color: const Color(0xFF64748B), fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _loadSummary,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF0D9488),
                  onRefresh: _loadSummary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Property & Month Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDFA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.apartment_rounded, color: Color(0xFF0D9488), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pgName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Billing Cycle: $formattedMonth',
                                      style: GoogleFonts.lato(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCCFBF1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Active PG',
                                  style: GoogleFonts.lato(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Hero Total Platform Fee Card
                        _buildHeroTotalCard(
                          totalCollected: totalCollected,
                          formattedMonth: formattedMonth,
                          feePerTenant: feePerTenant,
                          totalTenants: totalTenants,
                          resetsOn: resetsOn,
                        ),
                        const SizedBox(height: 14),

                        // Reset Information Alert Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Automatic 1st-of-Month Reset',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF166534),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'For tracking and billing reconciliation, this total platform fee automatically resets on the 1st of every month ($resetsOn).',
                                      style: GoogleFonts.lato(
                                        fontSize: 12,
                                        color: const Color(0xFF15803D),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Transactions Breakdown Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tenant Fee Collections',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${items.length} records',
                                style: GoogleFonts.lato(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (items.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 26,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No Fee Collections Yet',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'When rent payment requests are approved for this month, ₹${feePerTenant.toStringAsFixed(0)} platform fee per tenant will appear here.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.lato(
                                    fontSize: 12.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = items[index] as Map<String, dynamic>;
                              return _buildFeeItemCard(item);
                            },
                          ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: totalCollected > 0 ? _buildBottomPayBar(totalCollected) : null,
    );
  }

  Widget _buildHeroTotalCard({
    required double totalCollected,
    required String formattedMonth,
    required double feePerTenant,
    required int totalTenants,
    required String resetsOn,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F766E),
            Color(0xFF0D9488),
            Color(0xFF14B8A6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330D9488),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      formattedMonth,
                      style: GoogleFonts.lato(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '₹${feePerTenant.toStringAsFixed(0)} / tenant',
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total Platform Fee Collected',
            style: GoogleFonts.lato(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${totalCollected.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'this month',
                style: GoogleFonts.lato(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Tenants Paid', '$totalTenants'),
                Container(height: 24, width: 1, color: Colors.white.withValues(alpha: 0.2)),
                _buildStatColumn('Fee per Paid Rent', '₹${feePerTenant.toStringAsFixed(0)}'),
                Container(height: 24, width: 1, color: Colors.white.withValues(alpha: 0.2)),
                _buildStatColumn('Next Reset', resetsOn),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openOrganizationPaymentModal,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0FDFA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        size: 15,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      totalCollected > 0
                          ? 'Send Payment to Organization (₹${totalCollected.toStringAsFixed(0)})'
                          : 'Send Payment to Organization',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Color(0xFF0F766E),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeItemCard(Map<String, dynamic> item) {
    final tenantName = item['tenantName']?.toString() ?? 'Tenant';
    final roomNumber = item['roomNumber']?.toString() ?? '';
    final bedLabel = item['bedLabel']?.toString() ?? '';
    final amount = (item['amount'] as num?)?.toDouble() ?? 9.0;
    final dateStr = item['date']?.toString() ?? '';
    final status = item['status']?.toString() ?? 'SUBMITTED';

    String formattedDate = '';
    if (dateStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(dateStr).toLocal();
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      } catch (_) {
        formattedDate = dateStr;
      }
    }

    String roomBedInfo = '';
    if (roomNumber.isNotEmpty && bedLabel.isNotEmpty) {
      roomBedInfo = 'Room $roomNumber • Bed $bedLabel';
    } else if (roomNumber.isNotEmpty) {
      roomBedInfo = 'Room $roomNumber';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_rounded,
              color: Color(0xFF0D9488),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenantName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (roomBedInfo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    roomBedInfo,
                    style: GoogleFonts.lato(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
                if (formattedDate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF16A34A)),
                    const SizedBox(width: 3),
                    Text(
                      status == 'SUBMITTED' ? 'Collected' : status,
                      style: GoogleFonts.lato(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
