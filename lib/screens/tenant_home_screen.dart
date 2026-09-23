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
  List<dynamic> _payments = [];
  bool _isStayDetailsExpanded = false;
  bool _isPersonalInfoExpanded = false;
  bool _isAddressExpanded = false;

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
      _fetchPayments(),
    ]);
    if (mounted) setState(() => _isFetching = false);
  }

  Future<void> _fetchPayments() async {
    final payments = await ApiService.fetchPayments();
    if (mounted) {
      setState(() {
        _payments = payments;
      });
    }
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

  Widget _buildGlassContainer({
    required Widget child,
    double borderRadius = 20,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    Color? customGlassFill,
    Color? customBorderColor,
    double borderWidth = 1.0,
    List<BoxShadow>? customShadow,
    Clip clipBehavior = Clip.antiAlias,
  }) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: customGlassFill ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: customBorderColor ?? const Color(0xFFE2E8F0),
          width: borderWidth,
        ),
        boxShadow: customShadow ?? TenantTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: clipBehavior,
        child: padding != null
            ? Padding(padding: padding, child: child)
            : child,
      ),
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
  // BOTTOM NAVIGATION BAR (FROSTED LIGHT GLASS)
  // ===========================================================================
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
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
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? TenantTheme.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(color: TenantTheme.primaryBorder, width: 1) : null,
                ),
                child: Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected ? TenantTheme.primary : TenantTheme.textMuted,
                  size: 21,
                ),
              ),
              if (badgeCount > 0 && !isSelected)
                Positioned(
                  top: -2,
                  right: 4,
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
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? TenantTheme.primary : TenantTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: TenantTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
            shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
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
            shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
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
          body: SafeArea(
            child: _buildMyStayScreen(hideHeaderTitle: true),
          ),
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
                      fontSize: 13.5,
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
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: TenantTheme.textPrimary,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const Text('👋', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Welcome to your resident dashboard',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
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
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x100F172A),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: TenantTheme.glassBorder, width: 2),
                  ),
                  child: TenantAvatar(
                    name: tenantName,
                    imageUrl: _profileData?['imageUrl'],
                    radius: 23,
                    enablePreview: true,
                    backgroundColor: TenantTheme.primarySoft,
                    textColor: TenantTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

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
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.2),
                boxShadow: TenantTheme.heroShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Room $roomNumber',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bed $bedLabel',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'My Stay',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ],
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
          const SizedBox(height: 16),

          // 3. Quick Action Grid
          Row(
            children: [
              _buildQuickActionTile(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Pay Rent',
                iconColor: TenantTheme.actionPayRentIcon,
                bgColor: TenantTheme.actionPayRentBg,
                onTap: () => setState(() => _currentNavIndex = 1),
              ),
              const SizedBox(width: 12),
              _buildQuickActionTile(
                icon: Icons.meeting_room_rounded,
                label: 'My Stay',
                iconColor: TenantTheme.actionStayIcon,
                bgColor: TenantTheme.actionStayBg,
                onTap: _openMyStayDetails,
              ),
              const SizedBox(width: 12),
              _buildQuickActionTile(
                icon: Icons.campaign_rounded,
                label: 'Notices',
                iconColor: TenantTheme.actionNoticesIcon,
                bgColor: TenantTheme.actionNoticesBg,
                onTap: _openNoticesScreen,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Rent Status Card (Frosted Glass)
          GestureDetector(
            onTap: () => setState(() => _currentNavIndex = 1), // Navigate to Payments
            child: _buildGlassContainer(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rent Status',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: TenantTheme.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPaid ? TenantTheme.successBg : TenantTheme.dangerBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isPaid ? TenantTheme.successBorder : TenantTheme.dangerBorder,
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
                                color: isPaid ? TenantTheme.success : TenantTheme.danger,
                              ),
                            ),
                            const SizedBox(width: 4.5),
                            Text(
                              isPaid ? 'PAID' : 'DUE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: isPaid ? TenantTheme.success : TenantTheme.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${NumberFormat('#,##,###').format(displayRentAmount)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: TenantTheme.textPrimary,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPaid ? 'All dues cleared for this month' : 'Payment due on $rentDueDateStr',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: TenantTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPaid ? TenantTheme.surface : TenantTheme.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isPaid ? TenantTheme.glassBorder : TenantTheme.primaryBorder,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isPaid ? 'History' : 'Pay Now',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isPaid ? TenantTheme.textSecondary : TenantTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: isPaid ? TenantTheme.textSecondary : TenantTheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Recent Notice Card (Frosted Glass)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Notice',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: TenantTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGlassContainer(
            padding: const EdgeInsets.all(18),
            child: _announcements.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: TenantTheme.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: TenantTheme.primaryBorder, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, size: 12, color: TenantTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Official Notice',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: TenantTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_announcements.first['createdAt'] != null)
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 12, color: TenantTheme.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(_announcements.first['createdAt']),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: TenantTheme.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: TenantTheme.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: TenantTheme.primaryBorder, width: 0.8),
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              size: 18,
                              color: TenantTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _announcements.first['heading'] ?? 'Notice',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: TenantTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
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
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/no_notices.png',
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Notices Yet',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: TenantTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Official PG notices will appear here once posted by management.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: TenantTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
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
          _buildGlassContainer(
            borderRadius: 24,
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
          _buildGlassContainer(
            borderRadius: 24,
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
          _buildGlassContainer(
            borderRadius: 24,
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
          // Screen Title & Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rent & Payments',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: TenantTheme.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage monthly rent, utility bills & transactions',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: TenantTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TenantTheme.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TenantTheme.primaryBorder.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: TenantTheme.primary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Month Hero Banner Card (Modern Gradient & Subtle Float Shadow)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF281E99), Color(0xFF3722D3), Color(0xFF5034EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5034EA).withValues(alpha: 0.32),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFF281E99).withValues(alpha: 0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 40,
                    bottom: -40,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header Row: Month Pill & Status Pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    currentMonthStr,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? const Color(0xFF10B981).withValues(alpha: 0.25)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.32),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isPaid
                                      ? const Color(0xFF6EE7B7).withValues(alpha: 0.6)
                                      : const Color(0xFFFCA5A5).withValues(alpha: 0.6),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                    size: 13,
                                    color: isPaid ? const Color(0xFF6EE7B7) : const Color(0xFFFECACA),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isPaid ? 'PAID & SETTLED' : 'PAYMENT DUE',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Amount & Receipt Action Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPaid ? 'Cleared Rent' : 'Payable Amount',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.78),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${NumberFormat('#,##,###').format(displayRent)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.8,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      isPaid ? Icons.verified_rounded : Icons.schedule_rounded,
                                      size: 13,
                                      color: isPaid ? const Color(0xFF6EE7B7) : Colors.white.withValues(alpha: 0.82),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isPaid ? 'All dues cleared for this cycle' : 'Due by $rentDueDateStr',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (isPaid)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showReceiptDialog(currentMonthStr, monthlyRentVal, rentDueDateStr),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.12),
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
                                          color: Colors.white,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Receipt',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 12.5,
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
          const SizedBox(height: 18),

          // Rejection Banner if any
          if (_rejectionReason != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Color(0x08EF4444), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCA5A5).withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Proof Rejected',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFFDC2626), fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _rejectionReason!,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF7F1D1D), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 2. Outstanding Dues Clearance Card (Frosted Glass Container, only when dues > 0)
          if (_totalDue > 0) ...[
            _buildGlassContainer(
              borderRadius: 22,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Header
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
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFEF4444), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Clear Outstanding Dues',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: TenantTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Pay now to settle rent & utility fees',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: TenantTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA), width: 0.8),
                        ),
                        child: Text(
                          'Action Required',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Itemized Breakdown Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildPaymentBreakdownRow('Pending Rent', '₹${_pendingRent.toStringAsFixed(0)}', icon: Icons.door_sliding_outlined),
                        const SizedBox(height: 8),
                        _buildPaymentBreakdownRow('Room & Utility Bills', '₹${_pendingBills.toStringAsFixed(0)}', icon: Icons.receipt_long_outlined),
                        const SizedBox(height: 8),
                        _buildPaymentBreakdownRow('Platform Convenience Fee', '₹${_convenienceFee.toStringAsFixed(0)}', icon: Icons.verified_user_outlined),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Payable',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: TenantTheme.textPrimary,
                              ),
                            ),
                            Text(
                              '₹${_totalDue.toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: TenantTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Compact / Clean Image Upload Button
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedImageBytes != null ? const Color(0xFFF0FDF4) : const Color(0xFFF5F7FD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedImageBytes != null ? const Color(0xFF86EFAC) : const Color(0xFFC7D2FE),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _selectedImageBytes != null ? const Color(0xFFDCFCE7) : TenantTheme.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _selectedImageBytes != null ? Icons.check_circle_rounded : Icons.add_photo_alternate_rounded,
                              color: _selectedImageBytes != null ? const Color(0xFF16A34A) : TenantTheme.primary,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedImageBytes != null ? 'Screenshot Attached' : 'Attach UPI Screenshot',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedImageBytes != null ? const Color(0xFF15803D) : TenantTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  _selectedImageBytes != null ? 'Tap to replace image' : 'Proof of transaction for admin approval',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: TenantTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _selectedImageBytes != null ? const Color(0xFF16A34A) : TenantTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedImageBytes != null ? 'Change' : 'Upload',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedImageBytes != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF86EFAC)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Image.memory(
                          _selectedImageBytes!,
                          height: 90,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Transaction Reference TextField
                  TextField(
                    controller: _descriptionController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: TenantTheme.textPrimary),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: Color(0xFF94A3B8)),
                      hintText: 'UTR / Transaction Reference (optional)',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: TenantTheme.primary, width: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Submit Button
                  Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [TenantTheme.primary, Color(0xFF4338CA)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TenantTheme.primary.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Submit Payment for Approval',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 3. Payment History Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: TenantTheme.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_rounded, color: TenantTheme.primary, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Payment History',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: TenantTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              if (_payments.isNotEmpty || bills.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_payments.length + bills.where((b) => b['status'] == 'PAID').length} Records',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Display Rent cycle record + bills dynamically from API
          _buildPaymentHistoryList(currentMonthStr, monthlyRentVal, isPaid, bills),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatPaymentDateTime(dynamic dateVal) {
    if (dateVal == null) return '-';
    try {
      final dt = dateVal is DateTime ? dateVal : DateTime.parse(dateVal.toString());
      if (dt.hour == 0 && dt.minute == 0 && dt.second == 0) {
        return DateFormat('dd MMM yyyy').format(dt);
      }
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return _formatDate(dateVal);
    }
  }

  Widget _buildPaymentHistoryList(String currentMonthStr, double monthlyRentVal, bool isPaid, List<dynamic> bills) {
    final hasRecordedPayments = _payments.isNotEmpty;
    final hasPaidBills = bills.any((b) => b['status'] == 'PAID');
    final hasPaidCycle = isPaid && monthlyRentVal > 0;

    if (!hasRecordedPayments && !hasPaidBills && !hasPaidCycle) {
      return _buildGlassContainer(
        borderRadius: 22,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.receipt_long_outlined, size: 26, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              Text(
                'No Payment Records Found',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: TenantTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your payment history and rent clearances will be recorded here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: TenantTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildGlassContainer(
      borderRadius: 22,
      child: Column(
        children: [
            // 1. If backend payments exist, display each payment record with exact paid date
            if (hasRecordedPayments) ...[
              ..._payments.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                final dateStr = _formatPaymentDateTime(p['date']);
                final method = p['method']?.toString() ?? 'UPI';
                final notes = p['notes']?.toString();
                final isLast = idx == _payments.length - 1 && bills.isEmpty;

                return Column(
                  children: [
                    _buildPaymentRecordTile(
                      title: notes != null && notes.isNotEmpty ? notes : 'Rent Payment',
                      amount: '₹${NumberFormat('#,##,###').format(amount)}',
                      dateStr: dateStr,
                      method: method,
                      status: 'Paid',
                      isSuccess: true,
                    ),
                    if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16),
                  ],
                );
              }),
            ] else if (hasPaidCycle) ...[
              // Fallback if backend payments list is empty but profile is marked PAID
              _buildPaymentRecordTile(
                title: '$currentMonthStr Rent',
                amount: '₹${NumberFormat('#,##,###').format(monthlyRentVal)}',
                dateStr: _formatPaymentDateTime(DateTime.now()),
                method: 'UPI',
                status: 'Paid',
                isSuccess: true,
              ),
              if (bills.isNotEmpty) const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16),
            ],

            // 2. Bills history
            ...bills.asMap().entries.map((entry) {
              final idx = entry.key;
              final b = entry.value;
              final isBillPaid = b['status'] == 'PAID';
              final amount = (b['amount'] as num?)?.toDouble() ?? 0;
              final title = b['description'] != null && b['description'].toString().isNotEmpty
                  ? b['description'].toString()
                  : (b['type'] != null ? '${b['type']} Bill' : 'Utility Bill');
              final billDate = isBillPaid
                  ? _formatPaymentDateTime(b['createdAt'] ?? b['dueDate'])
                  : _formatDate(b['dueDate'] ?? b['createdAt']);

              return Column(
                children: [
                  _buildPaymentRecordTile(
                    title: title,
                    amount: '₹${NumberFormat('#,##,###').format(amount)}',
                    dateStr: billDate,
                    method: isBillPaid ? 'PAID' : 'PENDING',
                    status: isBillPaid ? 'Paid' : 'Pending',
                    isSuccess: isBillPaid,
                  ),
                  if (idx < bills.length - 1)
                    const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16),
                ],
              );
            }),
          ],
        ),
      );
  }

  Widget _buildPaymentRecordTile({
    required String title,
    required String amount,
    required String dateStr,
    required String method,
    required String status,
    required bool isSuccess,
    String? notes,
  }) {
    final isUPI = method.toUpperCase().contains('UPI');
    final isCash = method.toUpperCase().contains('CASH');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                width: 1,
              ),
            ),
            child: Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
              color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: TenantTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      amount,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: TenantTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 11.5,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4.5),
                        Text(
                          isSuccess ? 'Paid on $dateStr' : 'Due by $dateStr',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: TenantTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (method.isNotEmpty && method != 'PAID' && method != 'PENDING') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isUPI
                                  ? TenantTheme.primarySoft
                                  : (isCash ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isUPI
                                    ? TenantTheme.primaryBorder.withValues(alpha: 0.6)
                                    : (isCash ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              method.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: isUPI
                                    ? TenantTheme.primary
                                    : (isCash ? const Color(0xFFB45309) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isSuccess ? 'PAID' : 'DUE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    notes,
                    style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: TenantTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A10B981), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 34),
              ),
              const SizedBox(height: 14),
              Text(
                'Payment Receipt',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: TenantTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Official Rent & Utility Statement',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: TenantTheme.textSecondary),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow('Tenant Name', tenantName),
                    const SizedBox(height: 9),
                    _buildReceiptRow('Room / Bed', 'Room $roomNumber • Bed $bedLabel'),
                    const SizedBox(height: 9),
                    _buildReceiptRow('Billing Period', monthStr),
                    const SizedBox(height: 9),
                    _buildReceiptRow('Payment Status', 'PAID & VERIFIED', isGreen: true),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount Paid',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: TenantTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '₹${NumberFormat('#,##,###').format(amount)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: TenantTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TenantTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Close Receipt',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
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
            color: isGreen ? const Color(0xFF10B981) : TenantTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentBreakdownRow(String label, String value, {IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: TenantTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: TenantTheme.textPrimary,
          ),
        ),
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
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: TenantTheme.textPrimary,
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
                                    color: TenantTheme.textSecondary,
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

              return _buildGlassContainer(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: TenantTheme.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: TenantTheme.primaryBorder, width: 0.8),
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            size: 20,
                            color: TenantTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                heading,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: TenantTheme.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (date.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 12,
                                      color: TenantTheme.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      date,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: TenantTheme.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: TenantTheme.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: TenantTheme.primaryBorder, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, size: 12, color: TenantTheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Official',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: TenantTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      desc,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        height: 1.5,
                        color: TenantTheme.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (imgUrl != null && imgUrl.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: TenantTheme.glassBorder),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Image.network(
                            imgUrl,
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) => const SizedBox(),
                          ),
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

    final roomNumber = _profileData?['room']?['roomNumber']?.toString();
    final bedLabel = _profileData?['bed']?['bedLabel']?.toString();
    final monthlyRent = _profileData?['monthlyRent'];
    final monthlyRentStr = monthlyRent != null ? '₹${NumberFormat('#,##,###').format(monthlyRent)}' : null;
    final moveInDateStr = _formatDate(_profileData?['moveInDate'] ?? _profileData?['joiningDate']);

    final rawKycStatus = (_profileData?['kycStatus'] as String?)?.toUpperCase();
    final isKycComplete = rawKycStatus == 'VERIFIED' || _calculateProfileCompletion() >= 1.0;

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

          // Profile Header Card (Frosted Glass Container with specular border & soft float shadow)
          _buildGlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [TenantTheme.primary, TenantTheme.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: TenantTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: TenantAvatar(
                      name: name,
                      imageUrl: _profileData?['imageUrl'],
                      radius: 40,
                      enablePreview: true,
                      backgroundColor: TenantTheme.primarySoft,
                      textColor: TenantTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20.5,
                    fontWeight: FontWeight.w800,
                    color: TenantTheme.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_iphone_rounded, size: 14, color: TenantTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      phone,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: TenantTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Status Badges Row (Room/Bed info & KYC Verification Status)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (roomNumber != null && roomNumber.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                        decoration: BoxDecoration(
                          color: TenantTheme.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TenantTheme.primaryBorder.withValues(alpha: 0.7), width: 0.9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.meeting_room_outlined, size: 13, color: TenantTheme.primary),
                            const SizedBox(width: 4.5),
                            Text(
                              'Room $roomNumber${bedLabel != null && bedLabel.isNotEmpty ? ' • Bed $bedLabel' : ''}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: TenantTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                      decoration: BoxDecoration(
                        color: isKycComplete ? TenantTheme.successBg : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isKycComplete ? TenantTheme.successBorder : const Color(0xFFFDE68A),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isKycComplete ? Icons.verified_rounded : Icons.pending_actions_rounded,
                            size: 13,
                            color: isKycComplete ? TenantTheme.success : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4.5),
                          Text(
                            isKycComplete ? 'KYC Verified' : 'KYC Pending',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isKycComplete ? TenantTheme.success : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Action Buttons (Edit Profile + Complete/Update KYC)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditProfileDialog(),
                        icon: const Icon(Icons.edit_outlined, size: 16, color: TenantTheme.primary),
                        label: Text(
                          'Edit Profile',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: TenantTheme.primary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: TenantTheme.primaryBorder, width: 1.2),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openCompleteKycDialog(),
                        icon: Icon(
                          isKycComplete ? Icons.assignment_turned_in_outlined : Icons.verified_user_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          isKycComplete ? 'Update KYC' : 'Complete KYC',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isKycComplete ? TenantTheme.success : TenantTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 1.5,
                          shadowColor: (isKycComplete ? TenantTheme.success : TenantTheme.primary).withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stay / Tenancy Details Card (if room is assigned)
          if (roomNumber != null && roomNumber.isNotEmpty) ...[
            _buildProfileSectionCard(
              title: 'Stay Details',
              icon: Icons.home_work_outlined,
              isExpanded: _isStayDetailsExpanded,
              onToggle: () => setState(() => _isStayDetailsExpanded = !_isStayDetailsExpanded),
              subtitle: 'Room $roomNumber${bedLabel != null && bedLabel.isNotEmpty ? ' • Bed $bedLabel' : ''}',
              items: [
                _buildProfileRow('Room & Bed', 'Room $roomNumber${bedLabel != null && bedLabel.isNotEmpty ? ' • Bed $bedLabel' : ''}', icon: Icons.door_sliding_outlined),
                if (monthlyRentStr != null)
                  _buildProfileRow('Monthly Rent', monthlyRentStr, icon: Icons.currency_rupee_rounded),
                if (moveInDateStr.isNotEmpty && moveInDateStr != 'Not Provided')
                  _buildProfileRow('Joining Date', moveInDateStr, icon: Icons.calendar_today_outlined),
                _buildProfileRow('Stay Status', 'Active Resident', icon: Icons.verified_outlined),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Personal Details Section
          _buildProfileSectionCard(
            title: 'Personal Information',
            icon: Icons.person_rounded,
            isExpanded: _isPersonalInfoExpanded,
            onToggle: () => setState(() => _isPersonalInfoExpanded = !_isPersonalInfoExpanded),
            subtitle: email != 'Not Provided' ? email : 'Tap to view details',
            items: [
              _buildProfileRow('Email', email, icon: Icons.email_outlined),
              _buildProfileRow('Emergency Contact', emergency, icon: Icons.contact_phone_outlined),
              _buildProfileRow('Date of Birth', dob, icon: Icons.cake_outlined),
              _buildProfileRow('Father\'s Name', father, icon: Icons.person_outline_rounded),
              _buildProfileRow('Occupation', occupation, icon: Icons.work_outline_rounded),
              _buildProfileRow('Marital Status', marital, icon: Icons.favorite_border_rounded),
              _buildProfileRow('Nationality', nationality, icon: Icons.flag_outlined),
            ],
          ),
          const SizedBox(height: 14),

          // Address Section
          _buildProfileSectionCard(
            title: 'Permanent Address',
            icon: Icons.location_on_rounded,
            isExpanded: _isAddressExpanded,
            onToggle: () => setState(() => _isAddressExpanded = !_isAddressExpanded),
            subtitle: district != 'Not Provided' ? '$district, $state' : 'Tap to view address',
            items: [
              _buildProfileRow('Address', address, icon: Icons.home_outlined),
              if (houseNo != null && houseNo.toString().isNotEmpty) _buildProfileRow('House No.', houseNo.toString(), icon: Icons.tag_rounded),
              if (wardNo != null && wardNo.toString().isNotEmpty) _buildProfileRow('Ward No.', wardNo.toString(), icon: Icons.tag_rounded),
              if (village != null && village.toString().isNotEmpty) _buildProfileRow('Village / Town', village.toString(), icon: Icons.location_city_outlined),
              _buildProfileRow('District', district, icon: Icons.map_outlined),
              _buildProfileRow('State', state, icon: Icons.public_outlined),
              _buildProfileRow('PIN Code', pinCode, icon: Icons.pin_drop_outlined),
            ],
          ),
          const SizedBox(height: 20),

          // Log Out Button (Clean modern solid button)
          _buildGlassContainer(
            width: double.infinity,
            height: 52,
            borderRadius: 16,
            customGlassFill: const Color(0xFFFEF2F2),
            customBorderColor: const Color(0xFFFECACA),
            customShadow: const [
              BoxShadow(
                color: Color(0x06EF4444),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _confirmLogout(),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, color: TenantTheme.danger, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Log Out',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: TenantTheme.danger,
                      ),
                    ),
                  ],
                ),
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
    required bool isExpanded,
    required VoidCallback onToggle,
    String? subtitle,
  }) {
    return _buildGlassContainer(
      borderRadius: 20,
      customBorderColor: isExpanded ? TenantTheme.primaryBorder.withValues(alpha: 0.85) : TenantTheme.glassBorder,
      customShadow: [
        BoxShadow(
          color: const Color(0x0A0F172A),
          blurRadius: isExpanded ? 16 : 10,
          offset: Offset(0, isExpanded ? 6 : 3),
        ),
        BoxShadow(
          color: isExpanded ? TenantTheme.primary.withValues(alpha: 0.04) : const Color(0x040F172A),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isExpanded ? TenantTheme.primary : TenantTheme.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isExpanded
                              ? [
                                  BoxShadow(
                                    color: TenantTheme.primary.withValues(alpha: 0.28),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(icon, color: isExpanded ? Colors.white : TenantTheme.primary, size: 19),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: TenantTheme.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (subtitle != null && !isExpanded) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: TenantTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isExpanded ? TenantTheme.primarySoft : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isExpanded ? TenantTheme.primaryBorder.withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isExpanded ? TenantTheme.primary : const Color(0xFF64748B),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(height: 4),
                  ...items,
                  const SizedBox(height: 8),
                ],
              ),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 240),
              firstCurve: Curves.easeIn,
              secondCurve: Curves.easeOut,
            ),
          ],
        ),
      );
  }

  Widget _buildProfileRow(String label, String value, {IconData? icon}) {
    final isNotProvided = value.trim().isEmpty || value == 'Not Provided' || value == '-';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Icon(icon, size: 16, color: TenantTheme.primary.withValues(alpha: 0.85)),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: TenantTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isNotProvided ? 'Not Provided' : value,
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isNotProvided ? FontWeight.w500 : FontWeight.w700,
                color: isNotProvided ? const Color(0xFF94A3B8) : TenantTheme.textPrimary,
                fontStyle: isNotProvided ? FontStyle.italic : FontStyle.normal,
              ),
              overflow: TextOverflow.ellipsis,
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
        backgroundColor: TenantTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TenantTheme.glassBorder),
        ),
        title: Text('Log Out', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: TenantTheme.textPrimary)),
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
