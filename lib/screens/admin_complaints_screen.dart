import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fancy_toast.dart';
import '../widgets/app_shimmer.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  bool _isLoading = true;
  List<Complaint> _complaints = [];
  String? _errorMessage;
  String _selectedFilter = 'ALL'; // 'ALL', 'PENDING', 'IN_PROGRESS', 'RESOLVED'

  final List<Map<String, dynamic>> _categories = [
    {'key': 'PLUMBING', 'label': 'Plumbing', 'icon': Icons.plumbing_rounded, 'color': Color(0xFF0284C7)},
    {'key': 'ELECTRICAL', 'label': 'Electrical', 'icon': Icons.electric_bolt_rounded, 'color': Color(0xFFD97706)},
    {'key': 'CLEANING', 'label': 'Cleaning', 'icon': Icons.cleaning_services_rounded, 'color': Color(0xFF059669)},
    {'key': 'WIFI', 'label': 'WiFi & Net', 'icon': Icons.wifi_rounded, 'color': Color(0xFF4F46E5)},
    {'key': 'MAINTENANCE', 'label': 'Room & Furniture', 'icon': Icons.build_rounded, 'color': Color(0xFF7C3AED)},
    {'key': 'NOISE', 'label': 'Noise / Disturbance', 'icon': Icons.volume_off_rounded, 'color': Color(0xFFE11D48)},
    {'key': 'OTHER', 'label': 'Other', 'icon': Icons.help_outline_rounded, 'color': Color(0xFF64748B)},
  ];

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.fetchAdminComplaints();
      if (!mounted) return;
      setState(() {
        _complaints = data
            .whereType<Map<String, dynamic>>()
            .map((e) => Complaint.fromJson(e))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiService.cleanErrorMessage(e);
      });
    }
  }

  List<Complaint> get _filteredComplaints {
    if (_selectedFilter == 'ALL') return _complaints;
    return _complaints.where((c) => c.status == _selectedFilter).toList();
  }

  Future<void> _callTenant(String phoneNumber) async {
    if (phoneNumber.trim().isEmpty) return;
    final clean = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        FancyToast.showError(context, 'Could not launch dialer');
      }
    }
  }

  void _showReplyModal(Complaint complaint) {
    final replyCtrl = TextEditingController(text: complaint.adminReply ?? '');
    String selectedStatus = complaint.status == 'PENDING' ? 'IN_PROGRESS' : complaint.status;
    bool isSubmitting = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.reply_rounded, color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reply to Complaint',
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Tenant: ${complaint.tenantName} (${complaint.roomNumber != null ? formatRoomName(complaint.roomNumber) : "No room"})',
                            style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (modalError != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      modalError!,
                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],

                // Update Status
                Text(
                  'Update Status *',
                  style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatusOption(
                      label: 'Pending',
                      statusVal: 'PENDING',
                      currentSel: selectedStatus,
                      activeColor: const Color(0xFFD97706),
                      onTap: () => setModalState(() => selectedStatus = 'PENDING'),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusOption(
                      label: 'In Progress',
                      statusVal: 'IN_PROGRESS',
                      currentSel: selectedStatus,
                      activeColor: const Color(0xFF2563EB),
                      onTap: () => setModalState(() => selectedStatus = 'IN_PROGRESS'),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusOption(
                      label: 'Resolved',
                      statusVal: 'RESOLVED',
                      currentSel: selectedStatus,
                      activeColor: const Color(0xFF059669),
                      onTap: () => setModalState(() => selectedStatus = 'RESOLVED'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  'Reply Message to Tenant *',
                  style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: replyCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. Plumber is visiting at 4 PM to fix the tap...',
                    hintStyle: GoogleFonts.lato(color: const Color(0xFF94A3B8), fontSize: 13),
                    contentPadding: const EdgeInsets.all(14),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final replyText = replyCtrl.text.trim();
                            if (replyText.isEmpty) {
                              setModalState(() => modalError = 'Please enter a reply message.');
                              return;
                            }

                            setModalState(() {
                              isSubmitting = true;
                              modalError = null;
                            });

                            final nav = Navigator.of(ctx);
                            try {
                              await ApiService.replyComplaint(
                                complaintId: complaint.id,
                                reply: replyText,
                                status: selectedStatus,
                              );

                              nav.pop();
                              if (context.mounted) {
                                FancyToast.showSuccess(
                                  context,
                                  'Reply Sent',
                                  message: 'Tenant has been notified of your update.',
                                );
                              }
                              _fetchComplaints();
                            } catch (e) {
                              setModalState(() {
                                isSubmitting = false;
                                modalError = ApiService.cleanErrorMessage(e);
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Send Reply & Update Status', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption({
    required String label,
    required String statusVal,
    required String currentSel,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final isSel = currentSel == statusVal;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSel ? activeColor.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? activeColor : const Color(0xFFE2E8F0),
              width: isSel ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
              color: isSel ? activeColor : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  void _showMediaDialog(String mediaUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    child: _buildImageFromUrl(mediaUrl, maxHeight: 400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFromUrl(String url, {double? maxHeight}) {
    if (url.startsWith('data:image')) {
      final commaIdx = url.indexOf(',');
      final b64 = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
      try {
        final bytes = base64Decode(b64);
        return Image.memory(bytes, fit: BoxFit.contain, height: maxHeight);
      } catch (_) {
        return const SizedBox(height: 100, child: Center(child: Text('Invalid image format')));
      }
    }
    return Image.network(url, fit: BoxFit.contain, height: maxHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tenant Complaints',
          style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _fetchComplaints,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchComplaints,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 750),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('ALL', 'All (${_complaints.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('PENDING', 'Pending (${_complaints.where((c) => c.isPending).length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('IN_PROGRESS', 'In Progress (${_complaints.where((c) => c.isInProgress).length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('RESOLVED', 'Resolved (${_complaints.where((c) => c.isResolved).length})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isLoading) ...[
                    const AppShimmer(
                      child: Column(
                        children: [
                          ShimmerBox(height: 150, borderRadius: 16),
                          SizedBox(height: 12),
                          ShimmerBox(height: 150, borderRadius: 16),
                          SizedBox(height: 12),
                          ShimmerBox(height: 150, borderRadius: 16),
                        ],
                      ),
                    ),
                  ] else if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626))),
                          const SizedBox(height: 10),
                          ElevatedButton(onPressed: _fetchComplaints, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  ] else if (_filteredComplaints.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(color: Color(0xFFF8FAFC), shape: BoxShape.circle),
                            child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 40),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _selectedFilter == 'ALL' ? 'No Complaints Found' : 'No $_selectedFilter Complaints',
                            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Complaints raised privately by tenants will appear here for you and other co-owners to resolve.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lato(fontSize: 12.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredComplaints.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _filteredComplaints[index];
                        return _buildAdminComplaintCard(item);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSel = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSel ? AppTheme.primaryColor : const Color(0xFFE2E8F0)),
          boxShadow: isSel
              ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : const [],
        ),
        child: Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 12.5,
            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
            color: isSel ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminComplaintCard(Complaint complaint) {
    final catInfo = _categories.firstWhere(
      (c) => c['key'] == complaint.category,
      orElse: () => {'label': complaint.category, 'icon': Icons.help_outline_rounded, 'color': const Color(0xFF64748B)},
    );

    Color statusColor;
    Color statusBg;
    String statusText;
    IconData statusIcon;

    if (complaint.isResolved) {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
      statusText = 'Resolved';
      statusIcon = Icons.check_circle_rounded;
    } else if (complaint.isInProgress) {
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFFEFF6FF);
      statusText = 'In Progress';
      statusIcon = Icons.autorenew_rounded;
    } else {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFEF3C7);
      statusText = 'Pending Review';
      statusIcon = Icons.hourglass_empty_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: complaint.isPending ? const Color(0xFFFDE68A) : const Color(0xFFF1F5F9),
          width: complaint.isPending ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tenant Info + Call Button
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint.tenantName,
                      style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (complaint.roomNumber != null) ...[
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                formatRoomAndBed(complaint.roomNumber, complaint.bedLabel),
                                style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          DateFormat('dd MMM, hh:mm a').format(complaint.createdAt),
                          style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (complaint.tenantPhone.isNotEmpty)
                IconButton(
                  onPressed: () => _callTenant(complaint.tenantPhone),
                  icon: const Icon(Icons.phone_rounded, color: Color(0xFF059669), size: 20),
                  tooltip: 'Call Tenant (${complaint.tenantPhone})',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFECFDF5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Category + Status
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (catInfo['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(catInfo['icon'] as IconData, size: 13, color: catInfo['color'] as Color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          catInfo['label'] as String,
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: catInfo['color'] as Color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Description
          Text(
            complaint.title,
            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            complaint.description,
            style: GoogleFonts.lato(fontSize: 13.5, color: const Color(0xFF475569), height: 1.4),
          ),

          // Attached Media Preview
          if (complaint.mediaUrl != null && complaint.mediaUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showMediaDialog(complaint.mediaUrl!, complaint.title),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    _buildImageFromUrl(complaint.mediaUrl!, maxHeight: 150),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xBF000000), borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('View Photo', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Admin Response Bubble (if replied)
          if (complaint.adminReply != null && complaint.adminReply!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.forum_outlined, size: 15, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Your Reply',
                        style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
                      ),
                      if (complaint.repliedAt != null) ...[
                        const Spacer(),
                        Text(
                          DateFormat('dd MMM, hh:mm a').format(complaint.repliedAt!),
                          style: GoogleFonts.lato(fontSize: 10.5, color: const Color(0xFF6366F1)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    complaint.adminReply!,
                    style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E1B4B), height: 1.4),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Action Button: Reply / Update Status
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () => _showReplyModal(complaint),
              icon: Icon(
                complaint.adminReply != null ? Icons.edit_note_rounded : Icons.reply_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              label: Text(
                complaint.adminReply != null ? 'Edit Reply / Status' : 'Reply & Update Status',
                style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFC7D2FE)),
                backgroundColor: const Color(0xFFFAFAFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
