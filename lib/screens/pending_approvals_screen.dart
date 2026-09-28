import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';
import '../widgets/fancy_toast.dart';
import '../widgets/app_shimmer.dart';

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final reqs = await ApiService.fetchPendingPaymentRequests();
      if (!mounted) return;
      setState(() => _requests = reqs);
    } catch (e) {
      if (mounted) FancyToast.showError(context, 'Failed to Load Requests', message: ApiService.cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAccept(String requestId) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    try {
      await ApiService.resolvePaymentRequest(requestId, 'APPROVE');
      await appProvider.loadFromAPI();
      if (!mounted) return;
      FancyToast.showSuccess(context, 'Payment Accepted');
      _loadRequests();
    } catch (e) {
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

    final reason = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 8,
            backgroundColor: Colors.white,
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
                            style: GoogleFonts.outfit(
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
          );
        },
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      if (!mounted) return;
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      try {
        await ApiService.resolvePaymentRequest(requestId, 'REJECT', rejectionReason: reason);

        // Launch WhatsApp to notify tenant
        final req = _requests.firstWhere((r) => r['id'] == requestId, orElse: () => null);
        if (req != null) {
          final tenant = appProvider.tenants.firstWhere((t) => t.id == req['tenantProfileId'], orElse: () => appProvider.tenants.first);
          final msg = Uri.encodeComponent('Your request for marking rent payment as paid is rejected. Reason: $reason. Kindly upload a valid screenshot.');
          final url = Uri.parse('https://wa.me/${tenant.phone}?text=$msg');
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        }

        if (!mounted) return;
        FancyToast.showSuccess(context, 'Payment Declined');
        _loadRequests();
      } catch (e) {
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
          // Frosted White Blurred Backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
          Center(
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 420, maxHeight: 540),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1F000000), blurRadius: 28, offset: Offset(0, 10)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 480,
                            color: Colors.white,
                            child: InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4.0,
                              child: Image.memory(
                                imageBytes,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            right: 14,
                            child: GestureDetector(
                              onTap: () => Navigator.of(ctx).pop(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: const Icon(Icons.close_rounded, color: Color(0xFF475569), size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
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
              'Pending Approvals',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: const Color(0xFF0F172A),
              ),
            ),
            if (_requests.isNotEmpty)
              Text(
                '${_requests.length} payment request(s) awaiting review',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        color: AppTheme.primaryColor,
        child: _isLoading
            ? const PendingApprovalsSkeleton()
            : _requests.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
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
                            style: GoogleFonts.outfit(
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
                            style: GoogleFonts.plusJakartaSans(
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
                    children: [
                      // Request Items List
                      ..._requests.map((req) {
                        final String tenantName = req['tenantName']?.toString() ?? 'Tenant';
                        final double amount = (req['amount'] as num?)?.toDouble() ?? 0.0;
                        final String paymentType = req['paymentType']?.toString() ?? 'RENT';
                        final String? description = req['description']?.toString();
                        final String? proofImageBase64 = req['proofImageBase64']?.toString();

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
                                            style: GoogleFonts.outfit(
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
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₹${amount.toStringAsFixed(0)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),

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
    );
  }
}
