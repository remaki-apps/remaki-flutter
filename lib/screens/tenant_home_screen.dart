import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/tenant_theme.dart';
import '../models/models.dart';
import '../widgets/fancy_toast.dart';
import '../widgets/tenant_avatar.dart';
import 'edit_personal_info_dialog.dart';
import 'complete_profile_dialog.dart';

class TenantHomeScreen extends StatefulWidget {
  final int initialTab;
  const TenantHomeScreen({super.key, this.initialTab = 0});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
  static const double _convenienceFee = 9.0;
  final String _paymentType = 'BOTH';
  late int _currentNavIndex;

  bool _isLoading = false;
  bool _isFetching = true;
  double _totalDue = 0;
  double _pendingRent = 0;
  double _pendingBills = 0;
  Map<String, dynamic>? _profileData;
  String? _rejectionReason;
  Uint8List? _selectedImageBytes;
  final TextEditingController _descriptionController = TextEditingController();
  List<dynamic> _announcements = [];

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialTab;
    _loadAllData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isFetching = true);
    await Future.wait([
      _fetchProfile(),
      _fetchAnnouncements(),
    ]);
    if (mounted) setState(() => _isFetching = false);
  }

  Future<void> _fetchAnnouncements() async {
    final announcements = await ApiService.fetchAnnouncements(false);
    if (mounted) {
      setState(() {
        _announcements = announcements;
      });
    }
  }

  Future<void> _fetchProfile() async {
    final profile = await ApiService.fetchCurrentTenantProfile();
    if (profile != null) {
      double pendingRent = (profile['pendingRentAmount'] as num?)?.toDouble() ?? 0;
      double pendingBills = 0;
      final bills = profile['bills'] as List<dynamic>? ?? [];
      for (var b in bills) {
        if (b['status'] == 'PENDING') {
          pendingBills += (b['amount'] as num).toDouble();
        }
      }
      final rejectionReason = profile['latestRejectionReason'] as String?;
      final double totalDueAmount = (pendingRent + pendingBills) > 0
          ? (pendingRent + pendingBills + _convenienceFee)
          : 0;

      if (mounted) {
        setState(() {
          _pendingRent = pendingRent;
          _pendingBills = pendingBills;
          _totalDue = totalDueAmount;
          _profileData = profile;
          _rejectionReason = (rejectionReason != null && rejectionReason.isNotEmpty) ? rejectionReason : null;
        });
      }
    } else {
      if (mounted) {
        FancyToast.showError(context, 'Failed to Load', message: 'Failed to load profile details.');
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 20);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _selectedImageBytes = bytes;
    });
  }

  Future<void> _submitRequest() async {
    if (_totalDue <= 0) {
      FancyToast.showError(context, 'No Dues', message: 'No outstanding dues to pay.');
      return;
    }
    if (_selectedImageBytes == null) {
      FancyToast.showError(context, 'Screenshot Required', message: 'Please upload a UPI payment screenshot.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final base64Image = base64Encode(_selectedImageBytes!);

      await ApiService.performQuery('''
        mutation SubmitPaymentRequest(\$input: SubmitPaymentRequestInput!) {
          submitPaymentRequest(input: \$input) {
            id
          }
        }
      ''', variables: {
        'input': {
          'tenantId': _profileData?['id'] ?? '',
          'amount': _totalDue,
          'paymentType': _paymentType,
          'proofImageBase64': 'data:image/jpeg;base64,$base64Image',
          'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        }
      });

      if (mounted) {
        FancyToast.showSuccess(context, 'Payment request submitted for admin approval!');
        setState(() {
          _selectedImageBytes = null;
          _descriptionController.clear();
        });
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        FancyToast.showError(context, 'Submission Failed', message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  double _calculateProfileCompletion() {
    if (_profileData == null) return 0.0;
    int filled = 0;
    final keysToCheck = [
      'name',
      'phone',
      'email',
      'emergencyContact',
      'dateOfBirth',
      'fatherName',
      'occupation',
      'permanentAddress',
      'district',
      'pinCode',
    ];
    for (final key in keysToCheck) {
      final val = _profileData![key];
      if (val != null && val.toString().trim().isNotEmpty && val.toString().trim() != 'Not Provided' && val.toString().trim() != '-') {
        filled++;
      }
    }
    return (filled / keysToCheck.length).clamp(0.0, 1.0);
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().trim().isEmpty) return 'Not Provided';
    final str = dateStr.toString().trim();
    if (str == 'Not Provided' || str == '-') return str;
    try {
      final dt = DateTime.parse(str);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      try {
        if (str.contains('/')) {
          final parts = str.split('/');
          if (parts.length == 3) {
            final dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            return DateFormat('dd MMM yyyy').format(dt);
          }
        } else if (str.contains('-')) {
          final parts = str.split('-');
          if (parts.length == 3 && parts[0].length <= 2) {
            final dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            return DateFormat('dd MMM yyyy').format(dt);
          }
        }
      } catch (_) {}
      return str;
    }
  }

  Tenant _buildTenantModel() {
    return Tenant(
      id: _profileData?['id'] ?? '',
      name: _profileData?['name'] ?? '',
      phone: _profileData?['phone'] ?? '',
      email: _profileData?['email'] ?? '',
      emergencyContact: _profileData?['emergencyContact'],
      imageUrl: _profileData?['imageUrl'],
      roomId: _profileData?['room']?['id'] ?? '',
      bedId: _profileData?['bed']?['id'] ?? '',
      moveInDate: DateTime.tryParse(_profileData?['moveInDate'] ?? _profileData?['joiningDate'] ?? '') ?? DateTime.now(),
      rentAmount: (_profileData?['monthlyRent'] as num?)?.toDouble() ?? 0.0,
      securityDeposit: (_profileData?['securityDeposit'] as num?)?.toDouble() ?? 0.0,
      rentDueDate: DateTime.tryParse(_profileData?['rentDueDate'] ?? '') ?? DateTime.now(),
      dateOfBirth: _profileData?['dateOfBirth'],
      maritalStatus: _profileData?['maritalStatus'],
      fatherName: _profileData?['fatherName'],
      occupation: _profileData?['occupation'],
      nationality: _profileData?['nationality'],
      permanentAddress: _profileData?['permanentAddress'],
      houseNo: _profileData?['houseNo'],
      wardNo: _profileData?['wardNo'],
      villageOrTown: _profileData?['villageOrTown'] ?? _profileData?['village'],
      district: _profileData?['district'],
      state: _profileData?['state'],
      pinCode: _profileData?['pinCode'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TenantTheme.background,
      body: SafeArea(
        child: _isFetching
            ? const Center(child: CircularProgressIndicator(color: TenantTheme.primary))
            : RefreshIndicator(
                onRefresh: _loadAllData,
                color: TenantTheme.primary,
                child: _buildCurrentPage(),
              ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentNavIndex) {
      case 0:
        return _buildDashboardScreen();
      case 1:
        return _buildRentAndPaymentsScreen();
      case 2:
        return _buildProfileScreen();
      default:
        return _buildDashboardScreen();
    }
  }

  // ===========================================================================
  // BOTTOM NAVIGATION BAR
  // ===========================================================================
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E202B).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.grid_view_rounded, Icons.grid_view_outlined, 'Home'),
              _buildNavItem(1, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Payments'),
              _buildNavItem(2, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, {int badgeCount = 0}) {
    final isSelected = _currentNavIndex == index;

    return GestureDetector(
      onTap: () {
        if (_currentNavIndex != index) {
          setState(() => _currentNavIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? TenantTheme.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected ? TenantTheme.primary : TenantTheme.textMuted,
                  size: 22,
                ),
              ),
              if (badgeCount > 0 && !isSelected)
                Positioned(
                  top: 0,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: TenantTheme.danger,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? TenantTheme.primary : TenantTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _openNoticesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: TenantTheme.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: TenantTheme.textPrimary, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: Text(
              'Notices & Announcements',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: TenantTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: false,
          ),
          body: SafeArea(
            child: _buildNoticesScreen(showHeader: false),
          ),
        ),
      ),
    );
  }

  void _openMyStayDetails() {
    final stayStatus = (_profileData?['status'] as String? ?? 'ACTIVE').toUpperCase();
    final isActive = stayStatus == 'ACTIVE';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: TenantTheme.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: TenantTheme.textPrimary, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: Text(
              'My Stay',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: TenantTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? TenantTheme.successBg : TenantTheme.dangerBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isActive ? TenantTheme.successBorder : TenantTheme.dangerBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive ? TenantTheme.success : TenantTheme.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isActive ? 'Active Stay' : 'Inactive',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isActive ? TenantTheme.success : TenantTheme.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: _buildMyStayScreen(hideHeaderTitle: true),
        ),
      ),
    );
  }

  // ===========================================================================
  // SCREEN 1: DASHBOARD (HOME) - STRICTLY API DATA ONLY
  // ===========================================================================
  Widget _buildDashboardScreen() {
    final tenantName = _profileData?['name'] ?? 'Tenant';
    final firstName = tenantName.toString().split(' ').first;
    final roomNumber = _profileData?['room']?['roomNumber'] != null
        ? '${_profileData!['room']['roomNumber']}'
        : 'Not Assigned';
    final bedLabel = _profileData?['bed']?['bedLabel'] != null
        ? '${_profileData!['bed']['bedLabel']}'
        : 'Not Assigned';
    final isPaid = _totalDue <= 0;

    final double displayRentAmount = _totalDue > 0
        ? _totalDue
        : ((_profileData?['monthlyRent'] as num?)?.toDouble() ?? 0.0);
    final rentDueDateStr = _profileData?['rentDueDate'] != null
        ? _formatDate(_profileData!['rentDueDate'])
        : '-';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Greeting Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_getGreeting()},',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: TenantTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '$firstName ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: TenantTheme.textPrimary,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const Text('👋', style: TextStyle(fontSize: 22)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Welcome to your resident dashboard',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: TenantTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _currentNavIndex = 2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: TenantTheme.primary.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: TenantAvatar(
                    name: tenantName,
                    imageUrl: _profileData?['imageUrl'],
                    radius: 24,
                    backgroundColor: TenantTheme.primarySoft,
                    textColor: TenantTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Hero Room Card
          GestureDetector(
            onTap: _openMyStayDetails,
            child: Container(
              width: double.infinity,
              height: 104,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: TenantTheme.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: TenantTheme.heroShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Positioned(
                      right: -25,
                      top: -25,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Room $roomNumber',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bed $bedLabel',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 3. Rent Status Card
          GestureDetector(
            onTap: () => setState(() => _currentNavIndex = 1), // Navigate to Payments
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: TenantTheme.borderLight, width: 1.2),
                boxShadow: TenantTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rent Status',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: TenantTheme.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: isPaid ? TenantTheme.successBg : TenantTheme.dangerBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isPaid ? TenantTheme.successBorder : TenantTheme.dangerBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPaid ? TenantTheme.success : TenantTheme.danger,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isPaid ? 'Paid' : 'Due',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isPaid ? TenantTheme.success : TenantTheme.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '₹${NumberFormat('#,##,###').format(displayRentAmount)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: TenantTheme.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPaid ? 'All dues cleared for this month' : 'Payment due on $rentDueDateStr',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: TenantTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Recent Notice Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Notice',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: TenantTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: _openNoticesScreen,
                child: Text(
                  'View All',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: TenantTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: _announcements.isNotEmpty
                ? const EdgeInsets.all(18)
                : const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TenantTheme.borderLight, width: 1.2),
              boxShadow: TenantTheme.cardShadow,
            ),
            child: _announcements.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _announcements.first['heading'] ?? 'Notice',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: TenantTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _announcements.first['description'] ?? '',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: TenantTheme.textSecondary,
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/no_notices.png',
                          height: 130,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No Notices Yet',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Official PG notices will appear here once posted by management.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }



  // ===========================================================================
  // SCREEN 2: MY STAY - STRICTLY API DATA ONLY
  // ===========================================================================
  Widget _buildMyStayScreen({bool hideHeaderTitle = false}) {
    final roomNumber = _profileData?['room']?['roomNumber'] != null
        ? '${_profileData!['room']['roomNumber']}'
        : 'Not Assigned';
    final bedLabel = _profileData?['bed']?['bedLabel'] != null
        ? '${_profileData!['bed']['bedLabel']}'
        : 'Not Assigned';
    final checkInDate = _formatDate(_profileData?['moveInDate'] ?? _profileData?['joiningDate']);
    final rentDueDate = _formatDate(_profileData?['rentDueDate']);
    final monthlyRent = _profileData?['monthlyRent'] != null
        ? '₹${NumberFormat('#,##,###').format(_profileData!['monthlyRent'])}'
        : '₹0';
    final deposit = _profileData?['securityDeposit'] != null
        ? '₹${NumberFormat('#,##,###').format(_profileData!['securityDeposit'])}'
        : '₹0';
    final paymentMode = _profileData?['defaultPaymentMode'] ?? 'Not Specified';
    final stayStatus = (_profileData?['status'] as String? ?? 'ACTIVE').toUpperCase();
    final isActive = stayStatus == 'ACTIVE';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hideHeaderTitle) ...[
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Stay',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: TenantTheme.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive ? TenantTheme.successBg : TenantTheme.dangerBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isActive ? TenantTheme.successBorder : TenantTheme.dangerBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? TenantTheme.success : TenantTheme.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        stayStatus,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isActive ? TenantTheme.success : TenantTheme.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          // 1. Room & Bed Allocation Section Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: TenantTheme.borderLight, width: 1.2),
              boxShadow: TenantTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: TenantTheme.actionStayBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.meeting_room_rounded, color: TenantTheme.actionStayIcon, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Room & Bed Assignment',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: TenantTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: TenantTheme.borderLight),
                _buildStayDetailTile(Icons.door_front_door_rounded, 'Room Number', roomNumber),
                _buildStayDivider(),
                _buildStayDetailTile(Icons.single_bed_rounded, 'Bed Allocated', bedLabel),
                _buildStayDivider(),
                _buildStayDetailTile(Icons.calendar_today_rounded, 'Move-in Date', checkInDate),
                _buildStayDivider(),
                _buildStayDetailTile(Icons.verified_user_rounded, 'Tenancy Status', stayStatus),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Rent & Financial Agreement Section Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: TenantTheme.borderLight, width: 1.2),
              boxShadow: TenantTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: TenantTheme.actionPayRentBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: TenantTheme.actionPayRentIcon, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Financial Terms',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: TenantTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: TenantTheme.borderLight),
                _buildStayDetailTile(Icons.payments_rounded, 'Monthly Rent', monthlyRent),
                _buildStayDivider(),
                _buildStayDetailTile(Icons.shield_rounded, 'Security Deposit', deposit),
                _buildStayDivider(),
                _buildStayDetailTile(Icons.event_repeat_rounded, 'Monthly Due Date', rentDueDate),
                _buildStayDivider(),
                _buildStayDetailTile(Icons.account_balance_rounded, 'Payment Mode', paymentMode),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Resident Identity & Contact Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: TenantTheme.borderLight, width: 1.2),
              boxShadow: TenantTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: TenantTheme.actionFoodMenuBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.badge_rounded, color: TenantTheme.actionFoodMenuIcon, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Resident Information',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: TenantTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: TenantTheme.borderLight),
                _buildStayDetailTile(Icons.person_rounded, 'Full Name', _profileData?['name'] ?? '-'),
                _buildStayDivider(),
                _buildStayDetailTile(Icons.phone_rounded, 'Phone Number', _profileData?['phone'] ?? '-'),
                _buildStayDivider(),
                _buildStayDetailTile(Icons.email_rounded, 'Email', _profileData?['email'] ?? 'Not Provided'),
                _buildStayDivider(),
                _buildStayDetailTile(Icons.contact_emergency_rounded, 'Emergency Contact', _profileData?['emergencyContact'] ?? 'Not Provided'),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildStayDetailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: TenantTheme.textMuted),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: TenantTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: TenantTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStayDivider() {
    return const Divider(height: 1, thickness: 1, color: TenantTheme.borderLight, indent: 20, endIndent: 20);
  }

  // ===========================================================================
  // SCREEN 3: RENT & PAYMENTS - MOCKUP-ACCURATE & REAL API DRIVEN
  // ===========================================================================
  Widget _buildRentAndPaymentsScreen() {
    final currentMonthStr = DateFormat('MMMM yyyy').format(DateTime.now());
    final isPaid = _totalDue <= 0;
    final double monthlyRentVal = ((_profileData?['monthlyRent'] as num?)?.toDouble() ?? 0.0);
    final double displayRent = _totalDue > 0 ? _totalDue : monthlyRentVal;
    final rentDueDateStr = _profileData?['rentDueDate'] != null
        ? _formatDate(_profileData!['rentDueDate'])
        : '-';
    final bills = (_profileData?['bills'] as List<dynamic>? ?? []);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title
          Text(
            'Rent & Payments',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: TenantTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),

          // 1. Month Hero Banner Card (Compact, Classic & Aesthetic)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3722D3), Color(0xFF5034EA), Color(0xFF6C4DFA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5034EA).withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned(
                    right: -25,
                    top: -25,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header Row: Month & Status Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  currentMonthStr,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? const Color(0xFF10B981).withValues(alpha: 0.22)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isPaid
                                      ? const Color(0xFF34D399).withValues(alpha: 0.45)
                                      : const Color(0xFFF87171).withValues(alpha: 0.45),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5.5,
                                    height: 5.5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isPaid ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                                    ),
                                  ),
                                  const SizedBox(width: 4.5),
                                  Text(
                                    isPaid ? 'Paid' : 'Due',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Amount & Receipt Action Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '₹${NumberFormat('#,##,###').format(displayRent)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.6,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isPaid ? 'All dues cleared for this cycle' : 'Due by $rentDueDateStr',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: Colors.white.withValues(alpha: 0.80),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (isPaid)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showReceiptDialog(currentMonthStr, monthlyRentVal, rentDueDateStr),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.receipt_long_rounded,
                                          color: TenantTheme.primary,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Receipt',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: TenantTheme.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Rejection Banner if any
          if (_rejectionReason != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: TenantTheme.dangerBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TenantTheme.dangerBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: TenantTheme.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Proof Rejected',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: TenantTheme.danger, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _rejectionReason!,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: TenantTheme.textSecondary, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Outstanding Dues Clearance Card (Only when dues > 0)
          if (_totalDue > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: TenantTheme.borderLight, width: 1.2),
                boxShadow: TenantTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Clear Outstanding Dues',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: TenantTheme.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: TenantTheme.dangerBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Action Required',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: TenantTheme.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentBreakdownRow('Pending Rent', '₹${_pendingRent.toStringAsFixed(0)}'),
                  const SizedBox(height: 6),
                  _buildPaymentBreakdownRow('Room & Utility Bills', '₹${_pendingBills.toStringAsFixed(0)}'),
                  const SizedBox(height: 6),
                  _buildPaymentBreakdownRow('Platform Convenience Fee', '₹${_convenienceFee.toStringAsFixed(0)}'),
                  const Divider(height: 18, color: TenantTheme.borderLight),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Payable',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: TenantTheme.textPrimary),
                      ),
                      Text(
                        '₹${_totalDue.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: TenantTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Compact Image upload button
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _selectedImageBytes != null ? TenantTheme.successBg : TenantTheme.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedImageBytes != null ? TenantTheme.successBorder : TenantTheme.primaryBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedImageBytes != null ? Icons.check_circle_rounded : Icons.add_photo_alternate_rounded,
                            color: _selectedImageBytes != null ? TenantTheme.success : TenantTheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedImageBytes != null ? 'Screenshot Attached' : 'Attach UPI Screenshot',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _selectedImageBytes != null ? TenantTheme.success : TenantTheme.primary,
                              ),
                            ),
                          ),
                          Text(
                            _selectedImageBytes != null ? 'Change' : 'Upload',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _selectedImageBytes != null ? TenantTheme.success : TenantTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedImageBytes != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_selectedImageBytes!, height: 80, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'UTR / Transaction Reference (optional)',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: TenantTheme.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                      filled: true,
                      fillColor: TenantTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: TenantTheme.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: TenantTheme.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: TenantTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TenantTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Submit Payment for Approval', style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 3. Payment History Section
          Text(
            'Payment History',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: TenantTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          // Display Rent cycle record + bills dynamically from API
          _buildPaymentHistoryList(currentMonthStr, monthlyRentVal, isPaid, bills),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryList(String currentMonthStr, double monthlyRentVal, bool isPaid, List<dynamic> bills) {
    // If no bills and rent not recorded, show empty state
    if (!isPaid && bills.isEmpty && monthlyRentVal <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TenantTheme.borderLight, width: 1.2),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_outlined, size: 36, color: TenantTheme.textMuted.withValues(alpha: 0.7)),
              const SizedBox(height: 8),
              Text(
                'No past payment records found.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: TenantTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TenantTheme.borderLight, width: 1.2),
        boxShadow: TenantTheme.cardShadow,
      ),
      child: Column(
        children: [
          // If current cycle is paid, show it as verified paid rent history item
          if (isPaid && monthlyRentVal > 0) ...[
            _buildHistoryTile(
              title: currentMonthStr,
              amount: '₹${NumberFormat('#,##,###').format(monthlyRentVal)}',
              status: 'Paid',
              isSuccess: true,
            ),
            if (bills.isNotEmpty) const Divider(height: 1, color: TenantTheme.borderLight, indent: 16, endIndent: 16),
          ],
          // Real bills from API
          ...bills.asMap().entries.map((entry) {
            final idx = entry.key;
            final b = entry.value;
            final isBillPaid = b['status'] == 'PAID';
            final amount = (b['amount'] as num?)?.toDouble() ?? 0;
            final title = b['description'] != null && b['description'].toString().isNotEmpty
                ? b['description'].toString()
                : (b['type'] != null ? '${b['type']} Bill' : 'Utility Bill');

            return Column(
              children: [
                _buildHistoryTile(
                  title: title,
                  amount: '₹${NumberFormat('#,##,###').format(amount)}',
                  status: isBillPaid ? 'Paid' : 'Pending',
                  isSuccess: isBillPaid,
                ),
                if (idx < bills.length - 1)
                  const Divider(height: 1, color: TenantTheme.borderLight, indent: 16, endIndent: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHistoryTile({
    required String title,
    required String amount,
    required String status,
    required bool isSuccess,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: TenantTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              Text(
                amount,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: TenantTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: isSuccess ? TenantTheme.successBg : TenantTheme.warningBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSuccess ? TenantTheme.successBorder : TenantTheme.warningBorder,
                  ),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isSuccess ? TenantTheme.success : TenantTheme.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReceiptDialog(String monthStr, double amount, String dueDateStr) {
    final tenantName = _profileData?['name'] ?? 'Tenant';
    final roomNumber = _profileData?['room']?['roomNumber'] ?? '-';
    final bedLabel = _profileData?['bed']?['bedLabel'] ?? '-';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: TenantTheme.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: TenantTheme.success, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                'Payment Receipt',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: TenantTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Official Rent Statement',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: TenantTheme.textMuted),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TenantTheme.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: TenantTheme.borderLight),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow('Tenant Name', tenantName),
                    const SizedBox(height: 8),
                    _buildReceiptRow('Room / Bed', 'Room $roomNumber • Bed $bedLabel'),
                    const SizedBox(height: 8),
                    _buildReceiptRow('Billing Period', monthStr),
                    const SizedBox(height: 8),
                    _buildReceiptRow('Payment Status', 'PAID & VERIFIED', isGreen: true),
                    const Divider(height: 20, color: TenantTheme.borderMedium),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Amount Paid', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: TenantTheme.textPrimary)),
                        Text('₹${NumberFormat('#,##,###').format(amount)}', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: TenantTheme.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TenantTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Close Receipt', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: TenantTheme.textSecondary)),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isGreen ? TenantTheme.success : TenantTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentBreakdownRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: TenantTheme.textSecondary)),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: TenantTheme.textPrimary)),
      ],
    );
  }

  // ===========================================================================
  // SCREEN 4: NOTICES - STRICTLY API DATA ONLY (tenantAnnouncements)
  // ===========================================================================
  Widget _buildNoticesScreen({bool showHeader = true}) {
    if (_announcements.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader) ...[
                        Text(
                          'Notices & Announcements',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: TenantTheme.textPrimary,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/no_notices.png',
                                  height: 180,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Notices Found',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Official PG notices will appear here once posted by management.',
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          if (showHeader) ...[
            Text(
              'Notices & Announcements',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: TenantTheme.textPrimary,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 16),
          ],
          ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _announcements.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 14),
              itemBuilder: (ctx, i) {
                final item = _announcements[i];
                final heading = item['heading'] ?? 'Notice';
                final desc = item['description'] ?? '';
                final date = _formatDate(item['createdAt']);
                final imgUrl = item['imageUrl'] as String?;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: TenantTheme.borderLight, width: 1.2),
                    boxShadow: TenantTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              heading,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: TenantTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: TenantTheme.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: TenantTheme.primaryBorder),
                            ),
                            child: Text(
                              'Official',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: TenantTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: TenantTheme.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        desc,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: TenantTheme.textSecondary, height: 1.45),
                      ),
                      if (imgUrl != null && imgUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imgUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) => const SizedBox(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

  // ===========================================================================
  // SCREEN 5: PROFILE & KYC - STRICTLY API DATA ONLY
  // ===========================================================================
  Widget _buildProfileScreen() {
    final name = _profileData?['name'] ?? 'Tenant';
    final phone = _profileData?['phone'] ?? '-';
    final email = _profileData?['email'] ?? 'Not Provided';
    final emergency = _profileData?['emergencyContact'] ?? 'Not Provided';
    final dob = _formatDate(_profileData?['dateOfBirth']);
    final marital = _profileData?['maritalStatus'] ?? 'Not Provided';
    final father = _profileData?['fatherName'] ?? 'Not Provided';
    final occupation = _profileData?['occupation'] ?? 'Not Provided';
    final nationality = _profileData?['nationality'] ?? 'Not Provided';

    final address = _profileData?['permanentAddress'] ?? 'Not Provided';
    final houseNo = _profileData?['houseNo'];
    final wardNo = _profileData?['wardNo'];
    final village = _profileData?['villageOrTown'] ?? _profileData?['village'];
    final district = _profileData?['district'] ?? 'Not Provided';
    final state = _profileData?['state'] ?? 'Not Provided';
    final pinCode = _profileData?['pinCode'] ?? 'Not Provided';

    final completion = _calculateProfileCompletion();
    final isKycComplete = completion >= 1.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'My Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: TenantTheme.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 16),

          // Profile Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: TenantTheme.borderLight, width: 1.2),
              boxShadow: TenantTheme.cardShadow,
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: TenantTheme.cardShadow,
                        border: Border.all(color: TenantTheme.primaryBorder, width: 3),
                      ),
                      child: TenantAvatar(
                        name: name,
                        imageUrl: _profileData?['imageUrl'],
                        radius: 38,
                        backgroundColor: TenantTheme.primarySoft,
                        textColor: TenantTheme.primary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _openEditProfileDialog(),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: TenantTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(fontSize: 18.5, fontWeight: FontWeight.w800, color: TenantTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: TenantTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),

                // KYC Completion Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'KYC Profile Completion',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: TenantTheme.textSecondary),
                            ),
                            if (isKycComplete) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Verified',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF16A34A)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${(completion * 100).toInt()}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isKycComplete ? const Color(0xFF16A34A) : TenantTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: completion,
                        minHeight: 7,
                        backgroundColor: TenantTheme.background,
                        valueColor: AlwaysStoppedAnimation<Color>(isKycComplete ? const Color(0xFF16A34A) : TenantTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Action Buttons (Edit Info + Complete KYC)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openEditProfileDialog(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: TenantTheme.primaryBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Edit Info',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: TenantTheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _openCompleteKycDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isKycComplete ? const Color(0xFF16A34A) : TenantTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          isKycComplete ? 'Update KYC' : 'Complete KYC',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Personal Details Section
          _buildProfileSectionCard(
            title: 'Personal Information',
            icon: Icons.person_rounded,
            items: [
              _buildProfileRow('Email', email),
              _buildProfileRow('Emergency Contact', emergency),
              _buildProfileRow('Date of Birth', dob),
              _buildProfileRow('Father\'s Name', father),
              _buildProfileRow('Occupation', occupation),
              _buildProfileRow('Marital Status', marital),
              _buildProfileRow('Nationality', nationality),
            ],
          ),
          const SizedBox(height: 14),

          // Address Section
          _buildProfileSectionCard(
            title: 'Permanent Address',
            icon: Icons.location_on_rounded,
            items: [
              _buildProfileRow('Address', address),
              if (houseNo != null && houseNo.toString().isNotEmpty) _buildProfileRow('House No.', houseNo.toString()),
              if (wardNo != null && wardNo.toString().isNotEmpty) _buildProfileRow('Ward No.', wardNo.toString()),
              if (village != null && village.toString().isNotEmpty) _buildProfileRow('Village / Town', village.toString()),
              _buildProfileRow('District', district),
              _buildProfileRow('State', state),
              _buildProfileRow('PIN Code', pinCode),
            ],
          ),
          const SizedBox(height: 20),

          // Log Out Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(),
              icon: const Icon(Icons.logout_rounded, color: TenantTheme.danger, size: 18),
              label: Text(
                'Log Out',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: TenantTheme.danger),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: TenantTheme.dangerBorder),
                backgroundColor: TenantTheme.dangerBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TenantTheme.borderLight, width: 1.2),
        boxShadow: TenantTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                Icon(icon, color: TenantTheme.primary, size: 19),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: TenantTheme.textPrimary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: TenantTheme.borderLight),
          ...items,
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: TenantTheme.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: TenantTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditProfileDialog() {
    if (_profileData == null) return;
    showDialog(
      context: context,
      builder: (ctx) => EditPersonalInfoDialog(
        tenant: _buildTenantModel(),
        isAdmin: false,
      ),
    ).then((_) => _loadAllData());
  }

  void _openCompleteKycDialog() {
    if (_profileData == null) return;
    showDialog(
      context: context,
      builder: (ctx) => CompleteProfileDialog(
        tenant: _buildTenantModel(),
        onProfileUpdated: () {
          _loadAllData();
        },
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to log out of your tenant account?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: TenantTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: TenantTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.clearAuthToken();
              if (mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TenantTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Log Out', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
