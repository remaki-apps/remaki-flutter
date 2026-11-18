import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';
import '../widgets/fancy_toast.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/keyboard_responsive_layout.dart';
import '../utils/phone_utils.dart';

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  List<dynamic> _requests = [];
  List<dynamic> _historyRequests = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Pending, 1: History
  String _historyFilter = 'ALL'; // ALL, APPROVED, REJECTED

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final reqs = await ApiService.fetchPendingPaymentRequests();
      final historyReqs = await ApiService.fetchApprovalHistory();
      if (!mounted) return;

      // Filter to only show requests belonging to the currently selected property.
      // appProvider.currentTenants already respects selectedPropertyId.
      final currentTenantIds = appProvider.currentTenants.map((t) => t.id).toSet();
      final filtered = reqs.where((r) {
        final tid = r['tenantProfileId']?.toString() ?? '';
        if (appProvider.properties.length <= 1 ||
            appProvider.selectedPropertyId == null ||
            appProvider.selectedPropertyId == 'ALL') {
          return true;
        }
        return currentTenantIds.contains(tid);
      }).toList();

      final filteredHistory = historyReqs.where((r) {
        final tid = r['tenantProfileId']?.toString() ?? '';
        if (appProvider.properties.length <= 1 ||
            appProvider.selectedPropertyId == null ||
            appProvider.selectedPropertyId == 'ALL') {
          return true;
        }
        return currentTenantIds.contains(tid);
      }).toList();

      setState(() {
        _requests = filtered;
        _historyRequests = filteredHistory;
      });
    } catch (e) {
      if (mounted) FancyToast.showError(context, 'Failed to Load Requests', message: ApiService.cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAccept(String requestId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    // Optimistically remove request from UI immediately
    setState(() {
      _requests.removeWhere((r) => r['id']?.toString() == requestId);
    });
    try {
      await ApiService.resolvePaymentRequest(requestId, 'APPROVE');
      await appProvider.loadFromAPI();
      if (!mounted) return;
      FancyToast.showSuccess(context, 'Payment Accepted');
      await _loadRequests();
    } catch (e) {
      // Reload on failure to restore accurate state
      await _loadRequests();
      if (mounted) FancyToast.showError(context, 'Approval Failed', message: ApiService.cleanErrorMessage(e));
    }
  }

  Future<void> _handleDecline(String requestId) async {
    final reasonController = TextEditingController();
    String? selectedPresetReason;
    final presetReasons = [
      'Incorrect Screenshot',
      'Amount Mismatch',
      'Blurry Image',
      'Invalid UTR Number',
    ];

    String? reason;
    try {
      reason = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) {
          return KeyboardAwareDialog(
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              backgroundColor: Colors.white,
              child: KeyboardAutoScroll(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header with Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Decline Payment',
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(c),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Provide a reason so the tenant can correct and re-upload their proof.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  // Quick Suggestion Chips
                  const Text(
                    'QUICK REASONS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presetReasons.map((preset) {
                      final isSelected = selectedPresetReason == preset;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedPresetReason = preset;
                            reasonController.text = preset;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.danger : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.danger : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            preset,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Reason TextField
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Rejection Reason *',
                      hintText: 'e.g. Payment screenshot is unclear',
                      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.danger, width: 1.5)),
                    ),
                    onChanged: (val) {
                      if (selectedPresetReason != val) {
                        setDialogState(() {
                          selectedPresetReason = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (reasonController.text.trim().isNotEmpty) {
                              Navigator.pop(c, reasonController.text.trim());
                            }
                          },
                          child: const Text('Decline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
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
    );
  } finally {
    reasonController.dispose();
  }

    if (reason != null && reason.isNotEmpty) {
      if (!mounted) return;
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final req = _requests.firstWhere((r) => r['id']?.toString() == requestId, orElse: () => null);

      // Optimistically remove request from UI immediately
      setState(() {
        _requests.removeWhere((r) => r['id']?.toString() == requestId);
      });

      try {
        await ApiService.resolvePaymentRequest(requestId, 'REJECT', rejectionReason: reason);
        await appProvider.loadFromAPI();

        // Launch WhatsApp to notify tenant
        if (req != null) {
          final tenant = appProvider.tenants.firstWhere((t) => t.id == req['tenantProfileId'], orElse: () => appProvider.tenants.first);
          final msg = Uri.encodeComponent('Your request for marking rent payment as paid is rejected. Reason: $reason. Kindly upload a valid screenshot.');
          final phoneNum = PhoneUtils.formatForWhatsApp(tenant.phone);
          final url = Uri.parse('https://wa.me/$phoneNum?text=$msg');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        }

        if (!mounted) return;
        FancyToast.showSuccess(context, 'Payment Declined');
        await _loadRequests();
      } catch (e) {
        // Reload on failure to restore accurate state
        await _loadRequests();
        if (mounted) FancyToast.showError(context, 'Decline Failed', message: ApiService.cleanErrorMessage(e));
      }
    }
  }

  void _showImagePreviewDialog(BuildContext context, Uint8List imageBytes) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          // Immersive Dark Frosted Glass Backdrop (Tap outside to dismiss)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.86),
                ),
              ),
            ),
          ),
          Center(
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Glassmorphic Navigation & Badge Header
                  Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Payment Receipt',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // High-Contrast Image Viewport (Slate-900 background makes white receipts crisp)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1120),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 36,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: double.infinity,
                        height: 480,
                        color: const Color(0xFF0B1120),
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Center(
                            child: Image.memory(
                              imageBytes,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Subtle Pinch-to-Zoom Helper Hint
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pinch_outlined, color: Colors.white70, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Pinch or drag to inspect text details',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> req) {
    final bool isApproved = req['status'] == 'APPROVED';
    final amount = (req['amount'] as num?)?.toDouble() ?? 0.0;
    final paymentType = req['paymentType']?.toString().toUpperCase() ?? 'RENT';
    final method = req['method']?.toString().toUpperCase() ?? 'UPI';
    final tenantName = req['tenantName']?.toString() ?? 'Tenant';
    final roomNumber = req['roomNumber']?.toString();
    final bedLabel = req['bedLabel']?.toString();
    final rejectionReason = req['rejectionReason']?.toString();
    final updatedAtStr = req['updatedAt'] ?? req['createdAt'];
    DateTime? updatedDate;
    if (updatedAtStr != null) {
      updatedDate = DateTime.tryParse(updatedAtStr.toString())?.toLocal();
    }
    final formattedDate = updatedDate != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(updatedDate)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TenantAvatar(name: tenantName, radius: 18),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenantName,
                        style: GoogleFonts.lato(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (roomNumber != null && roomNumber.isNotEmpty)
                        Text(
                          formatRoomAndBed(roomNumber, bedLabel),
                          style: GoogleFonts.lato(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isApproved ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 13,
                      color: isApproved ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isApproved ? 'Approved' : 'Declined',
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isApproved ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Amount', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$paymentType • $method',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  if (formattedDate.isNotEmpty)
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),
            ],
          ),
          if (!isApproved && rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFE11D48), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reason: $rejectionReason',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFBE123C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (req['proofImageBase64'] != null &&
              req['proofImageBase64'].toString().trim().isNotEmpty &&
              req['proofImageBase64'].toString().trim() != 'null') ...[
            Builder(
              builder: (ctx) {
                Uint8List? proofBytes;
                try {
                  final raw = req['proofImageBase64'].toString().trim();
                  if (raw.isNotEmpty && raw != 'null') {
                    proofBytes = base64Decode(raw.split(',').last);
                  }
                } catch (_) {}

                if (proofBytes == null || proofBytes.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showImagePreviewDialog(ctx, proofBytes!),
                      icon: const Icon(Icons.receipt_long_rounded, size: 15),
                      label: const Text('View Payment Proof', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: Color(0xFFC7D2FE)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryFilterChip(String filterVal, String label) {
    final isSelected = _historyFilter == filterVal;
    return GestureDetector(
      onTap: () => setState(() => _historyFilter = filterVal),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    final filtered = _historyRequests.where((r) {
      if (_historyFilter == 'APPROVED') return r['status'] == 'APPROVED';
      if (_historyFilter == 'REJECTED') return r['status'] == 'REJECTED';
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              _buildHistoryFilterChip('ALL', 'All (${_historyRequests.length})'),
              const SizedBox(width: 8),
              _buildHistoryFilterChip('APPROVED', 'Approved (${_historyRequests.where((r) => r['status'] == 'APPROVED').length})'),
              const SizedBox(width: 8),
              _buildHistoryFilterChip('REJECTED', 'Declined (${_historyRequests.where((r) => r['status'] == 'REJECTED').length})'),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEF2FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history_rounded, size: 40, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Approval History',
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _historyFilter == 'ALL'
                              ? 'Approved and declined payment requests will appear here.'
                              : 'No $_historyFilter requests found.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildHistoryCard(filtered[index] as Map<String, dynamic>),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9FE),
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedTab == 0 ? 'Pending Approvals' : 'Approval History',
              style: GoogleFonts.lato(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              _selectedTab == 0
                  ? '${_requests.length} payment request(s) awaiting review'
                  : '${_historyRequests.length} past approval record(s)',
              style: GoogleFonts.lato(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Segmented Tab Controller
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 0
                              ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pending_actions_rounded,
                              size: 16,
                              color: _selectedTab == 0 ? AppTheme.primaryColor : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 0 ? AppTheme.primaryColor : const Color(0xFF64748B),
                              ),
                            ),
                            if (_requests.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 0 ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_requests.length}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 1
                              ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 16,
                              color: _selectedTab == 1 ? AppTheme.primaryColor : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'History',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 1 ? AppTheme.primaryColor : const Color(0xFF64748B),
                              ),
                            ),
                            if (_historyRequests.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 1 ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_historyRequests.length}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRequests,
              color: AppTheme.primaryColor,
              child: _isLoading
                  ? const PendingApprovalsSkeleton()
                  : _selectedTab == 1
                      ? _buildHistoryView()
                      : _requests.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 24.0 + MediaQuery.paddingOf(context).bottom),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/no_pending_approvals.png',
                            height: 180,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCFCE7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_outline_rounded, size: 54, color: Color(0xFF16A34A)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'No Pending Approvals',
                            style: GoogleFonts.lato(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'All tenant rent and payment requests have been reviewed.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      // Request Items List
                      ..._requests.map((req) {
                        final String tenantName = req['tenantName']?.toString() ?? 'Tenant';
                        final double amount = (req['amount'] as num?)?.toDouble() ?? 0.0;
                        final String paymentType = req['paymentType']?.toString() ?? 'RENT';
                        final String? description = req['description']?.toString();
                        final String? proofImageBase64 = req['proofImageBase64']?.toString();
                        final String method = req['method']?.toString() ?? '';
                        final String? createdAtRaw = req['createdAt']?.toString();

                        DateTime? requestDateTime;
                        String formattedDateTime = '';
                        if (createdAtRaw != null && createdAtRaw.isNotEmpty) {
                          requestDateTime = DateTime.tryParse(createdAtRaw)?.toLocal();
                          if (requestDateTime != null) {
                            formattedDateTime = DateFormat('dd MMM yyyy, hh:mm a').format(requestDateTime);
                          }
                        }

                        Uint8List? proofBytes;
                        if (proofImageBase64 != null && proofImageBase64.isNotEmpty) {
                          try {
                            proofBytes = base64Decode(proofImageBase64.split(',').last);
                          } catch (_) {}
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tenant Header Row
                                Row(
                                  children: [
                                    TenantAvatar(
                                      name: tenantName,
                                      radius: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tenantName,
                                            style: GoogleFonts.lato(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEEF2FF),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  paymentType.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: AppTheme.primaryColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (method.isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    method.toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Color(0xFF475569),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₹${amount.toStringAsFixed(0)}',
                                      style: GoogleFonts.lato(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),

                                // Sent Date & Time Badge
                                if (formattedDateTime.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.schedule_rounded,
                                          size: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Sent: ',
                                          style: GoogleFonts.lato(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            formattedDateTime,
                                            style: GoogleFonts.lato(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                if (description != null && description.trim().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF64748B)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            description.trim(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF475569),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Screenshot Proof Container
                                if (proofBytes != null) ...[
                                  const SizedBox(height: 14),
                                  GestureDetector(
                                    onTap: () => _showImagePreviewDialog(context, proofBytes!),
                                    child: Container(
                                      height: 160,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.memory(
                                              proofBytes,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Center(
                                                child: Text('Invalid Screenshot', style: TextStyle(color: Color(0xFF94A3B8))),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.65),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Tap to View',
                                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // Accept / Decline Actions
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                                          backgroundColor: const Color(0xFFFEF2F2),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () => _handleDecline(req['id']),
                                        icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 18),
                                        label: const Text(
                                          'Decline',
                                          style: TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () => _handleAccept(req['id']),
                                        icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                        label: const Text(
                                          'Approve',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
