import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/tenant_theme.dart';
import '../models/models.dart';
import '../widgets/fancy_toast.dart';
import '../widgets/tenant_avatar.dart';
import 'edit_personal_info_dialog.dart';
import 'complete_profile_dialog.dart';
import '../widgets/app_shimmer.dart';
import '../utils/image_compress_util.dart';
import '../widgets/payment_splitup_card.dart';

class TenantHomeScreen extends StatefulWidget {
  final int initialTab;
  const TenantHomeScreen({super.key, this.initialTab = 0});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
  double _effectivePlatformFee = 0.0;
  String _paymentType = 'BOTH';
  late int _currentNavIndex;
  final Set<String> _expandedPaymentIds = {};

  bool _isLoading = false;
  bool _isFetching = true;
  bool _hasSubmittedForApproval = false;
  double _totalDue = 0;
  double _pendingRent = 0;
  double _pendingBills = 0;
  List<Map<String, dynamic>> _pendingBillsList = [];
  Map<String, dynamic>? _profileData;
  String? _rejectionReason;
  Uint8List? _selectedImageBytes;
  final TextEditingController _descriptionController = TextEditingController();
  List<dynamic> _announcements = [];
  List<dynamic> _payments = [];
  DateTime _selectedPaymentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isPaymentHistoryExpanded = false;

  void _prevPaymentMonth() {
    setState(() {
      _selectedPaymentMonth = DateTime(_selectedPaymentMonth.year, _selectedPaymentMonth.month - 1, 1);
    });
  }

  void _nextPaymentMonth() {
    setState(() {
      _selectedPaymentMonth = DateTime(_selectedPaymentMonth.year, _selectedPaymentMonth.month + 1, 1);
    });
  }

  void _resetToCurrentPaymentMonth() {
    setState(() {
      _selectedPaymentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    });
  }

  bool _isDateInSelectedMonth(dynamic dateVal, DateTime targetMonth) {
    if (dateVal == null) return false;
    try {
      DateTime dt;
      if (dateVal is DateTime) {
        dt = dateVal.toLocal();
      } else if (dateVal is num) {
        final val = dateVal.toInt();
        dt = (val > 100000000000)
            ? DateTime.fromMillisecondsSinceEpoch(val).toLocal()
            : DateTime.fromMillisecondsSinceEpoch(val * 1000).toLocal();
      } else {
        final str = dateVal.toString().trim();
        final numVal = int.tryParse(str);
        if (numVal != null && str.length >= 10 && RegExp(r'^\d+$').hasMatch(str)) {
          dt = (numVal > 100000000000)
              ? DateTime.fromMillisecondsSinceEpoch(numVal).toLocal()
              : DateTime.fromMillisecondsSinceEpoch(numVal * 1000).toLocal();
        } else {
          dt = DateTime.parse(str).toLocal();
        }
      }
      return dt.year == targetMonth.year && dt.month == targetMonth.month;
    } catch (_) {
      return false;
    }
  }

  bool _isPaymentInSelectedMonth(dynamic p, DateTime targetMonth) {
    final targetMonthStr = DateFormat('yyyy-MM').format(targetMonth);
    if (p['billingMonth'] != null && p['billingMonth'].toString().isNotEmpty) {
      if (p['billingMonth'].toString() == targetMonthStr) return true;
    }
    return _isDateInSelectedMonth(p['date'], targetMonth);
  }

  bool _isBillInSelectedMonth(dynamic b, DateTime targetMonth) {
    final targetMonthStr = DateFormat('yyyy-MM').format(targetMonth);
    if (b['month'] != null && b['month'].toString().isNotEmpty) {
      if (b['month'].toString() == targetMonthStr) return true;
    }
    return _isDateInSelectedMonth(b['createdAt'] ?? b['dueDate'], targetMonth);
  }
  bool _isStayDetailsExpanded = false;
  bool _isPersonalInfoExpanded = false;
  bool _isAddressExpanded = false;

  // Change Password state
  bool _isChangePasswordExpanded = false;
  final TextEditingController _tenantNewPasswordController = TextEditingController();
  final TextEditingController _tenantConfirmPasswordController = TextEditingController();
  bool _obscureTenantNewPassword = true;
  bool _obscureTenantConfirmPassword = true;
  bool _isChangingPassword = false;
  String? _changePasswordError;

  // Security PIN state
  bool _isSecurityPinExpanded = false;
  final TextEditingController _tenantNewPinController = TextEditingController();
  final TextEditingController _tenantConfirmNewPinController = TextEditingController();
  bool _obscureTenantPin = true;
  bool _obscureTenantConfirmPin = true;
  bool _isUpdatingPin = false;
  String? _securityPinError;

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialTab;
    _loadAllData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tenantNewPasswordController.dispose();
    _tenantConfirmPasswordController.dispose();
    _tenantNewPinController.dispose();
    _tenantConfirmNewPinController.dispose();
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

  Future<void> _setLocalPendingStatus(bool isPending, String? tenantId) async {
    if (tenantId == null || tenantId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tenant_pending_payment_$tenantId', isPending);
    } catch (_) {}
  }

  Future<void> _fetchProfile() async {
    final profile = await ApiService.fetchCurrentTenantProfile();
    if (profile != null) {
      final tenantId = profile['id'] as String?;
      double dynamicPlatformFee = (profile['platformFee'] as num?)?.toDouble() ?? 9.0;
      double pendingRent = (profile['pendingRentAmount'] as num?)?.toDouble() ?? 0;
      double pendingBills = 0;
      final bills = profile['bills'] as List<dynamic>? ?? [];
      final pendingBillsList = <Map<String, dynamic>>[];
      for (var b in bills) {
        if (b['status'] == 'PENDING') {
          pendingBills += (b['amount'] as num).toDouble();
          pendingBillsList.add(Map<String, dynamic>.from(b as Map));
        }
      }
      String? rawRejection = profile['latestRejectionReason'] as String? ?? profile['rejectionReason'] as String?;

      // Platform fee collected ONLY for rent, NEVER for utility bills alone!
      final double effectivePlatformFee = pendingRent > 0 ? dynamicPlatformFee : 0.0;

      final double totalDueAmount = (pendingRent + pendingBills) > 0
          ? (pendingRent + pendingBills + effectivePlatformFee)
          : 0;

      final String calculatedPaymentType = (pendingRent > 0 && pendingBills > 0)
          ? 'BOTH'
          : (pendingRent > 0 ? 'RENT' : 'BILLS');

      // Read local persisted pending status
      bool storedPending = false;
      if (tenantId != null && tenantId.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          storedPending = prefs.getBool('tenant_pending_payment_$tenantId') ?? false;
        } catch (_) {}
      }

      // 1. Check if explicitly PAID on backend
      bool isPaid = profile['paymentStatus'] == 'PAID';

      // 2. Pending if local submission flag is true OR storedPending is true OR backend status says PENDING/submitted
      bool isPendingApproval = !isPaid &&
          (_hasSubmittedForApproval ||
           storedPending ||
           profile['paymentStatus'] == 'PENDING' ||
           profile['hasPendingRequest'] == true ||
           profile['hasSubmittedRequest'] == true);

      // 3. Check if REJECTED on backend (only if NOT currently pending new submission)
      bool isBackendRejected = !isPaid && !isPendingApproval &&
          (profile['paymentStatus'] == 'REJECTED' ||
           (rawRejection != null && rawRejection.isNotEmpty));

      // 4. Mark paid via totalDueAmount <= 0 only if not pending and not rejected
      if (!isPaid && !isPendingApproval && !isBackendRejected && totalDueAmount <= 0) {
        isPaid = true;
      }

      if (mounted) {
        setState(() {
          _effectivePlatformFee = effectivePlatformFee;
          _pendingRent = pendingRent;
          _pendingBills = pendingBills;
          _pendingBillsList = pendingBillsList;
          _paymentType = calculatedPaymentType;
          _totalDue = totalDueAmount;
          _profileData = profile;
          
          if (isPaid) {
            _hasSubmittedForApproval = false;
            _rejectionReason = null;
            _setLocalPendingStatus(false, tenantId);
          } else if (isPendingApproval) {
            _hasSubmittedForApproval = true;
            _rejectionReason = null;
            _setLocalPendingStatus(true, tenantId);
          } else if (isBackendRejected) {
            _hasSubmittedForApproval = false;
            _rejectionReason = rawRejection;
          } else {
            _hasSubmittedForApproval = false;
            _rejectionReason = null;
            _setLocalPendingStatus(false, tenantId);
          }
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
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1600,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final compressed = await ImageCompressUtil.compressDocumentOrBill(bytes);
    setState(() {
      _selectedImageBytes = compressed;
    });
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
        await _setLocalPendingStatus(true, _profileData?['id']);
        setState(() {
          _selectedImageBytes = null;
          _descriptionController.clear();
          _hasSubmittedForApproval = true;
          _rejectionReason = null;
        });
        await _loadAllData();
      }
    } catch (e) {
      final cleanMsg = ApiService.cleanErrorMessage(e);
      if (cleanMsg.contains('already have a pending payment request') || cleanMsg.contains('pending payment request')) {
        await _setLocalPendingStatus(true, _profileData?['id']);
        if (mounted) {
          setState(() {
            _hasSubmittedForApproval = true;
            _selectedImageBytes = null;
            _descriptionController.clear();
            _rejectionReason = null;
          });
          FancyToast.showSuccess(context, 'Payment Under Review', message: 'You already have a payment request pending admin approval.');
          await _loadAllData();
        }
      } else {
        if (mounted) {
          FancyToast.showError(context, 'Submission Failed', message: cleanMsg);
        }
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
    final numVal = int.tryParse(str);
    if (numVal != null && str.length >= 10 && RegExp(r'^\d+$').hasMatch(str)) {
      try {
        final dt = (numVal > 100000000000)
            ? DateTime.fromMillisecondsSinceEpoch(numVal).toLocal()
            : DateTime.fromMillisecondsSinceEpoch(numVal * 1000).toLocal();
        return DateFormat('dd MMM yyyy').format(dt);
      } catch (_) {}
    }
    try {
      final dt = DateTime.parse(str).toLocal();
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
      isPaid: _profileData?['paymentStatus'] == 'PAID',
      paymentStatus: (_profileData?['hasPendingRequest'] == true || _profileData?['paymentStatus'] == 'PENDING')
          ? 'PENDING'
          : (_profileData?['paymentStatus']?.toString() ?? 'UNPAID'),
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
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _loadAllData,
                color: TenantTheme.primary,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentNavIndex),
                    child: _isFetching ? _buildSkeletonForTab() : _buildCurrentPage(),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomNavigationBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonForTab() {
    switch (_currentNavIndex) {
      case 0:
        return const TenantHomeSkeleton();
      case 1:
        return const RentOverviewSkeleton();
      case 2:
        return const ProfileSkeleton();
      default:
        return const TenantHomeSkeleton();
    }
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
  // BOTTOM NAVIGATION BAR (FLOATING TRANSLUCENT GLASS DOCK)
  // ===========================================================================
  Widget _buildBottomNavigationBar() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 24,
              spreadRadius: 0,
              offset: Offset(0, 8),
            ),
            BoxShadow(
              color: Color(0x0A4F46E5),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.white.withValues(alpha: 0.82),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                  _buildNavItem(1, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Payments'),
                  _buildNavItem(2, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, {int badgeCount = 0}) {
    final isSelected = _currentNavIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_currentNavIndex != index) {
            setState(() => _currentNavIndex = index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? TenantTheme.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: TenantTheme.primaryBorder, width: 1) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? activeIcon : inactiveIcon,
                    color: isSelected ? TenantTheme.primary : TenantTheme.textMuted,
                    size: 21,
                  ),
                  if (badgeCount > 0 && !isSelected)
                    Positioned(
                      top: -2,
                      right: -6,
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
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? TenantTheme.primary : TenantTheme.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
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
    final isPending = _hasSubmittedForApproval ||
        _profileData?['paymentStatus'] == 'PENDING' ||
        _profileData?['hasPendingRequest'] == true;
    final isPaid = !isPending && _totalDue <= 0;
    final isUpcoming = !isPaid && !isPending && (_profileData?['paymentStatus'] == 'UPCOMING' || (_profileData?['paymentStatus'] != 'UNPAID' && _profileData?['rentDueDate'] != null && DateTime.now().isBefore(DateTime.parse(_profileData!['rentDueDate'].toString()).add(const Duration(days: 1)))));

    final double displayRentAmount = _totalDue > 0
        ? _totalDue
        : ((_profileData?['monthlyRent'] as num?)?.toDouble() ?? 0.0);
    final rentDueDateStr = _profileData?['rentDueDate'] != null
        ? _formatDate(_profileData!['rentDueDate'])
        : '-';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 95.0),
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
                                    roomNumber,
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
                                bedLabel,
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
                          color: isPaid
                              ? TenantTheme.successBg
                              : (isPending
                                  ? TenantTheme.warningBg
                                  : (isUpcoming ? const Color(0xFFEFF6FF) : TenantTheme.dangerBg)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isPaid
                                ? TenantTheme.successBorder
                                : (isPending
                                    ? TenantTheme.warningBorder
                                    : (isUpcoming ? const Color(0xFFBFDBFE) : TenantTheme.dangerBorder)),
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
                                color: isPaid
                                    ? TenantTheme.success
                                    : (isPending
                                        ? TenantTheme.warning
                                        : (isUpcoming ? const Color(0xFF2563EB) : TenantTheme.danger)),
                              ),
                            ),
                            const SizedBox(width: 4.5),
                            Text(
                              isPaid
                                  ? 'PAID'
                                  : (isPending
                                      ? 'PENDING'
                                      : (isUpcoming ? 'UPCOMING' : 'OVERDUE')),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: isPaid
                                    ? TenantTheme.success
                                    : (isPending
                                        ? TenantTheme.warning
                                        : (isUpcoming ? const Color(0xFF2563EB) : TenantTheme.danger)),
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
                            isPaid
                                ? 'All dues cleared for this month'
                                : (isPending
                                    ? 'Payment submitted • Under Admin Review'
                                    : (isUpcoming
                                        ? 'Payment due by $rentDueDateStr'
                                        : 'Payment overdue since $rentDueDateStr')),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: isPending
                                  ? TenantTheme.warning
                                  : (isUpcoming ? TenantTheme.textMuted : TenantTheme.danger),
                              fontWeight: (isPending || !isUpcoming) ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? TenantTheme.surface
                              : (isPending ? TenantTheme.warningBg : TenantTheme.primarySoft),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isPaid
                                ? TenantTheme.glassBorder
                                : (isPending ? TenantTheme.warningBorder : TenantTheme.primaryBorder),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isPaid ? 'History' : (isPending ? 'Under Review' : 'Pay Now'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isPaid
                                    ? TenantTheme.textSecondary
                                    : (isPending ? TenantTheme.warning : TenantTheme.primary),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              isPending ? Icons.hourglass_top_rounded : Icons.arrow_forward_rounded,
                              size: 13,
                              color: isPaid
                                  ? TenantTheme.textSecondary
                                  : (isPending ? TenantTheme.warning : TenantTheme.primary),
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

          // 4.5. Month-wise Payment History Section
          _buildTenantPaymentHistorySection(isHomepage: true),
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
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 95.0),
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
    final isPending = _hasSubmittedForApproval ||
        _profileData?['paymentStatus'] == 'PENDING' ||
        _profileData?['hasPendingRequest'] == true;
    final isPaid = !isPending && _totalDue <= 0;
    final isUpcoming = !isPaid && !isPending && (_profileData?['paymentStatus'] == 'UPCOMING' || (_profileData?['paymentStatus'] != 'UNPAID' && _profileData?['rentDueDate'] != null && DateTime.now().isBefore(DateTime.parse(_profileData!['rentDueDate'].toString()).add(const Duration(days: 1)))));
    final double monthlyRentVal = ((_profileData?['monthlyRent'] as num?)?.toDouble() ?? 0.0);
    final double displayRent = _totalDue > 0 ? _totalDue : monthlyRentVal;
    final rentDueDateStr = _profileData?['rentDueDate'] != null
        ? _formatDate(_profileData!['rentDueDate'])
        : '-';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 95.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title & Subtitle
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
                                    : (isPending
                                        ? const Color(0xFFF59E0B).withValues(alpha: 0.32)
                                        : (isUpcoming
                                            ? Colors.white.withValues(alpha: 0.18)
                                            : const Color(0xFFEF4444).withValues(alpha: 0.32))),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isPaid
                                      ? const Color(0xFF6EE7B7).withValues(alpha: 0.6)
                                      : (isPending
                                          ? const Color(0xFFFDE68A).withValues(alpha: 0.7)
                                          : (isUpcoming
                                              ? const Color(0xFF93C5FD).withValues(alpha: 0.7)
                                              : const Color(0xFFFCA5A5).withValues(alpha: 0.6))),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPaid
                                        ? Icons.check_circle_rounded
                                        : (isPending
                                            ? Icons.hourglass_top_rounded
                                            : (isUpcoming
                                                ? Icons.schedule_rounded
                                                : Icons.error_outline_rounded)),
                                    size: 13,
                                    color: isPaid
                                        ? const Color(0xFF6EE7B7)
                                        : (isPending
                                            ? const Color(0xFFFDE68A)
                                            : (isUpcoming
                                                ? const Color(0xFFBFDBFE)
                                                : const Color(0xFFFECACA))),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isPaid
                                        ? 'PAID & SETTLED'
                                        : (isPending
                                            ? 'PENDING APPROVAL'
                                            : (isUpcoming ? 'UPCOMING DUE' : 'PAYMENT OVERDUE')),
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
                                      isPaid
                                          ? Icons.verified_rounded
                                          : (isPending
                                              ? Icons.hourglass_top_rounded
                                              : (isUpcoming
                                                  ? Icons.schedule_rounded
                                                  : Icons.error_outline_rounded)),
                                      size: 13,
                                      color: isPaid
                                          ? const Color(0xFF6EE7B7)
                                          : (isPending
                                              ? const Color(0xFFFDE68A)
                                              : (isUpcoming
                                                  ? const Color(0xFFBFDBFE)
                                                  : const Color(0xFFFCA5A5))),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isPaid
                                          ? 'All dues cleared for this cycle'
                                          : (isPending
                                              ? 'Payment submitted • Under Admin Review'
                                              : (isUpcoming
                                                  ? 'Rent payable by $rentDueDateStr • No late fee'
                                                  : 'Overdue since $rentDueDateStr')),
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

          // Rejection Banner if admin rejected previous payment submission
          if (_rejectionReason != null && !_hasSubmittedForApproval) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Color(0x0DE11D48), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE4E6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.gpp_bad_rounded, color: Color(0xFFE11D48), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Proof Rejected',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                color: const Color(0xFF9F1239),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Re-upload proof below to resubmit for approval',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: const Color(0xFFBE123C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDA4AF)),
                        ),
                        child: Text(
                          'Rejected',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE11D48),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFE11D48), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Comment:',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF9F1239),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _rejectionReason!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: const Color(0xFF4C0519),
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
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
            const SizedBox(height: 18),
          ],

          // 2. Outstanding Dues Clearance Card OR Pending Approval Card
          if (_hasSubmittedForApproval || _profileData?['paymentStatus'] == 'PENDING' || _profileData?['hasPendingRequest'] == true) ...[
            _buildGlassContainer(
              borderRadius: 22,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment Pending Approval',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: TenantTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Proof of payment submitted for review',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: TenantTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCD34D), width: 0.8),
                        ),
                        child: Text(
                          'Under Review',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your payment transaction proof has been submitted to your property manager. Account balance will update automatically upon verification.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF92400E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ] else if (_totalDue > 0) ...[
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
                      Expanded(
                        child: Row(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clear Outstanding Dues',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: TenantTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Pay now to settle rent & utility fees',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: TenantTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                        if (_pendingRent > 0) ...[
                          _buildPaymentBreakdownRow('Pending Rent', '₹${_pendingRent.toStringAsFixed(0)}', icon: Icons.door_sliding_outlined),
                          const SizedBox(height: 8),
                        ],
                        if (_pendingBillsList.isNotEmpty) ...[
                          ..._pendingBillsList.map((bill) {
                            final desc = (bill['description'] as String?)?.trim();
                            final billLabel = (desc != null && desc.isNotEmpty) ? desc : 'Utility Bill';
                            final billAmount = (bill['amount'] as num?)?.toDouble() ?? 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _buildPaymentBreakdownRow(
                                billLabel,
                                '₹${billAmount.toStringAsFixed(0)}',
                                icon: _getBillIcon(billLabel),
                              ),
                            );
                          }),
                        ],
                        if (_effectivePlatformFee > 0) ...[
                          _buildPaymentBreakdownRow('Platform Convenience Fee', '₹${_effectivePlatformFee.toStringAsFixed(0)}', icon: Icons.verified_user_outlined),
                        ] else if (_pendingBills > 0 && _pendingRent == 0) ...[
                          _buildPaymentBreakdownRow('Platform Fee (Waived for bills)', '₹0', icon: Icons.check_circle_outline_rounded),
                        ],
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
                    GestureDetector(
                      onTap: () => _showImagePreviewDialog(context, _selectedImageBytes!),
                      child: ClipRRect(
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
                    height: 50,
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Submit Payment for Approval',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 3. Payment History Section (Month-wise)
          _buildTenantPaymentHistorySection(isHomepage: false),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatPaymentDateTime(dynamic dateVal) {
    if (dateVal == null) return '-';
    try {
      DateTime dt;
      if (dateVal is DateTime) {
        dt = dateVal.toLocal();
      } else if (dateVal is num) {
        final val = dateVal.toInt();
        dt = (val > 100000000000)
            ? DateTime.fromMillisecondsSinceEpoch(val).toLocal()
            : DateTime.fromMillisecondsSinceEpoch(val * 1000).toLocal();
      } else {
        final str = dateVal.toString().trim();
        final numVal = int.tryParse(str);
        if (numVal != null && str.length >= 10 && RegExp(r'^\d+$').hasMatch(str)) {
          dt = (numVal > 100000000000)
              ? DateTime.fromMillisecondsSinceEpoch(numVal).toLocal()
              : DateTime.fromMillisecondsSinceEpoch(numVal * 1000).toLocal();
        } else {
          dt = DateTime.parse(str).toLocal();
        }
      }
      if (dt.hour == 0 && dt.minute == 0 && dt.second == 0) {
        return DateFormat('dd MMM yyyy').format(dt);
      }
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return _formatDate(dateVal);
    }
  }

  Widget _buildTenantPaymentHistorySection({bool isHomepage = false}) {
    final selectedMonthStr = DateFormat('MMMM yyyy').format(_selectedPaymentMonth);
    final now = DateTime.now();
    final isCurrentMonth = _selectedPaymentMonth.year == now.year && _selectedPaymentMonth.month == now.month;
    final isPastMonth = _selectedPaymentMonth.isBefore(DateTime(now.year, now.month, 1));
    final double monthlyRentVal = ((_profileData?['monthlyRent'] as num?)?.toDouble() ?? 0.0);

    // 1. Filter payments belonging to the selected month
    final monthPayments = _payments.where((p) => _isPaymentInSelectedMonth(p, _selectedPaymentMonth)).toList();

    // 2. Filter bills belonging to the selected month
    final allBills = (_profileData?['bills'] as List<dynamic>? ?? []);
    final monthBills = allBills.where((b) => _isBillInSelectedMonth(b, _selectedPaymentMonth)).toList();
    final paidMonthBills = monthBills.where((b) => b['status'] == 'PAID').toList();

    // 3. Compute total paid for this selected month
    double totalPaidThisMonth = 0;
    for (var p in monthPayments) {
      double amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
      totalPaidThisMonth += amt;
    }
    for (var b in paidMonthBills) {
      if (monthPayments.isEmpty) {
        totalPaidThisMonth += (b['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }

    final isPendingApproval = isCurrentMonth && (_hasSubmittedForApproval ||
        _profileData?['paymentStatus'] == 'PENDING' ||
        _profileData?['hasPendingRequest'] == true);
    final isCurrentPaid = isCurrentMonth && !isPendingApproval && _totalDue <= 0;

    if (monthPayments.isEmpty && isCurrentPaid && monthlyRentVal > 0 && totalPaidThisMonth == 0) {
      totalPaidThisMonth = monthlyRentVal;
    }

    // Determine status badge
    String statusBadge;
    Color statusBg;
    Color statusBorder;
    Color statusColor;
    if (totalPaidThisMonth > 0 || monthPayments.isNotEmpty) {
      statusBadge = 'PAID';
      statusBg = TenantTheme.successBg;
      statusBorder = TenantTheme.successBorder;
      statusColor = TenantTheme.success;
    } else if (isCurrentMonth) {
      if (isPendingApproval) {
        statusBadge = 'PENDING';
        statusBg = TenantTheme.warningBg;
        statusBorder = TenantTheme.warningBorder;
        statusColor = TenantTheme.warning;
      } else if (_totalDue > 0) {
        final isUpcoming = _profileData?['paymentStatus'] == 'UPCOMING' ||
            (_profileData?['paymentStatus'] != 'UNPAID' && _profileData?['rentDueDate'] != null && DateTime.now().isBefore(DateTime.parse(_profileData!['rentDueDate'].toString()).add(const Duration(days: 1))));
        if (isUpcoming) {
          statusBadge = 'UPCOMING';
          statusBg = const Color(0xFFEFF6FF);
          statusBorder = const Color(0xFFBFDBFE);
          statusColor = const Color(0xFF2563EB);
        } else {
          statusBadge = 'DUE';
          statusBg = TenantTheme.dangerBg;
          statusBorder = TenantTheme.dangerBorder;
          statusColor = TenantTheme.danger;
        }
      } else {
        statusBadge = 'NO DUES';
        statusBg = const Color(0xFFF1F5F9);
        statusBorder = const Color(0xFFCBD5E1);
        statusColor = const Color(0xFF64748B);
      }
    } else if (isPastMonth) {
      statusBadge = 'NO PAYMENTS';
      statusBg = const Color(0xFFF1F5F9);
      statusBorder = const Color(0xFFCBD5E1);
      statusColor = const Color(0xFF64748B);
    } else {
      statusBadge = 'UPCOMING';
      statusBg = const Color(0xFFEFF6FF);
      statusBorder = const Color(0xFFBFDBFE);
      statusColor = const Color(0xFF2563EB);
    }

    final List<Widget> transactionWidgets = [];

    if (monthPayments.isNotEmpty) {
      for (int i = 0; i < monthPayments.length; i++) {
        final p = monthPayments[i];
        final double amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = _formatPaymentDateTime(p['date']);
        final method = p['method']?.toString() ?? 'UPI';
        final notes = p['notes']?.toString();
        final paymentId = p['_id']?.toString() ?? p['id']?.toString() ?? 'tenant_payment_$i';
        final rawDate = p['date'] != null ? (DateTime.tryParse(p['date'].toString())?.toLocal() ?? DateTime.now()) : DateTime.now();

        final displayTitle = (notes != null && notes.isNotEmpty && !notes.toLowerCase().contains('approved via payment request'))
            ? notes
            : 'Payment Settlement';

        transactionWidgets.add(_buildPaymentRecordTile(
          title: displayTitle,
          amount: '₹${NumberFormat('#,##,###').format(amount)}',
          dateStr: dateStr,
          method: method,
          status: 'Paid',
          isSuccess: true,
          paymentId: paymentId,
          rawAmount: amount,
          rawDate: rawDate,
          rentAmount: monthlyRentVal,
          platformFee: _effectivePlatformFee > 0 ? _effectivePlatformFee : 9.0,
          bills: allBills,
          notes: notes,
        ));
        if (i < monthPayments.length - 1 || monthBills.isNotEmpty) {
          transactionWidgets.add(const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16));
        }
      }
    } else if (monthPayments.isEmpty && isCurrentPaid && monthlyRentVal > 0) {
      transactionWidgets.add(_buildPaymentRecordTile(
        title: '$selectedMonthStr Rent',
        amount: '₹${NumberFormat('#,##,###').format(monthlyRentVal)}',
        dateStr: _formatPaymentDateTime(DateTime.now()),
        method: 'UPI',
        status: 'Paid',
        isSuccess: true,
        paymentId: 'synthetic_current_$selectedMonthStr',
        rawAmount: monthlyRentVal,
        rawDate: DateTime.now(),
        rentAmount: monthlyRentVal,
        platformFee: _effectivePlatformFee > 0 ? _effectivePlatformFee : 9.0,
        bills: allBills,
      ));
      if (monthBills.isNotEmpty) {
        transactionWidgets.add(const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16));
      }
    }

    for (int i = 0; i < monthBills.length; i++) {
      final b = monthBills[i];
      final isBillPaid = b['status'] == 'PAID';
      final amount = (b['amount'] as num?)?.toDouble() ?? 0;
      final title = b['description'] != null && b['description'].toString().isNotEmpty
          ? b['description'].toString()
          : (b['type'] != null ? '${b['type']} Bill' : 'Utility Bill');
      final billDate = isBillPaid
          ? _formatPaymentDateTime(b['createdAt'] ?? b['dueDate'])
          : _formatDate(b['dueDate'] ?? b['createdAt']);

      transactionWidgets.add(_buildPaymentRecordTile(
        title: title,
        amount: '₹${NumberFormat('#,##,###').format(amount)}',
        dateStr: billDate,
        method: isBillPaid ? 'PAID' : 'PENDING',
        status: isBillPaid ? 'Paid' : 'Pending',
        isSuccess: isBillPaid,
      ));
      if (i < monthBills.length - 1) {
        transactionWidgets.add(const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16));
      }
    }

    final totalCount = monthPayments.length + monthBills.length + (monthPayments.isEmpty && isCurrentPaid ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
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
            if (isHomepage)
              GestureDetector(
                onTap: () => setState(() => _currentNavIndex = 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: TenantTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_rounded, size: 13, color: TenantTheme.primary),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalCount Records',
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

        // Month Navigation Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TenantTheme.glassBorder, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 22, color: Color(0xFF1E293B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                splashRadius: 18,
                onPressed: _prevPaymentMonth,
                tooltip: 'Previous Month',
              ),
              GestureDetector(
                onTap: isCurrentMonth ? null : _resetToCurrentPaymentMonth,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 15, color: TenantTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      selectedMonthStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCurrentMonth ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCurrentMonth ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        isCurrentMonth ? 'Current' : 'Reset',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isCurrentMonth ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22, color: Color(0xFF1E293B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                splashRadius: 18,
                onPressed: _nextPaymentMonth,
                tooltip: 'Next Month',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Monthly Summary Metric Card (Frosted Glass Container)
        _buildGlassContainer(
          borderRadius: 16,
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: totalPaidThisMonth > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: totalPaidThisMonth > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 18,
                      color: totalPaidThisMonth > 0 ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL PAID FOR ${selectedMonthStr.toUpperCase()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: TenantTheme.textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${NumberFormat('#,##,###').format(totalPaidThisMonth)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: TenantTheme.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusBorder, width: 0.8),
                ),
                child: Text(
                  statusBadge,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Transactions Container
        if (transactionWidgets.isEmpty)
          _buildGlassContainer(
            borderRadius: 18,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 36,
                  color: TenantTheme.textMuted.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 8),
                Text(
                  'No Records for $selectedMonthStr',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: TenantTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'No transactions or dues were recorded for this month.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: TenantTheme.textMuted,
                  ),
                ),
              ],
            ),
          )
        else
          _buildGlassContainer(
            borderRadius: 18,
            child: Column(
              children: [
                // Summary View: show preview of top 2 items
                if (!_isPaymentHistoryExpanded) ...[
                  ...transactionWidgets.take(3), // Up to 2 items + 1 divider
                ] else ...[
                  // Detailed View: show all items
                  ...transactionWidgets,
                ],

                // Show More / Show Summary Expandable Button
                if (transactionWidgets.length > 2)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isPaymentHistoryExpanded = !_isPaymentHistoryExpanded;
                      });
                    },
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isPaymentHistoryExpanded
                                ? 'Show Summary'
                                : 'Show More ($totalCount Transactions)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: TenantTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isPaymentHistoryExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 17,
                            color: TenantTheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
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
    String? paymentId,
    double? rawAmount,
    DateTime? rawDate,
    double? rentAmount,
    double? platformFee,
    List<dynamic>? bills,
  }) {
    final isUPI = method.toUpperCase().contains('UPI');
    final isCash = method.toUpperCase().contains('CASH');
    final isExpandable = paymentId != null;
    final isExpanded = isExpandable && _expandedPaymentIds.contains(paymentId);

    return InkWell(
      onTap: isExpandable
          ? () {
              setState(() {
                if (isExpanded) {
                  _expandedPaymentIds.remove(paymentId);
                } else {
                  _expandedPaymentIds.add(paymentId);
                }
              });
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          children: [
            Row(
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
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 11.5,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 4.5),
                                Expanded(
                                  child: Text(
                                    isSuccess ? 'Paid on $dateStr' : 'Due by $dateStr',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: TenantTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
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
                              if (isExpandable) ...[
                                const SizedBox(width: 6),
                                AnimatedRotation(
                                  turns: isExpanded ? 0.25 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 19,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
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
            if (isExpanded)
              PaymentSplitupCard(
                paymentAmount: rawAmount ?? 0.0,
                rentAmount: rentAmount ?? 0.0,
                platformFee: platformFee ?? 9.0,
                bills: bills,
                method: method,
                notes: notes,
                paymentDate: rawDate ?? DateTime.now(),
              ),
          ],
        ),
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
                    _buildReceiptRow('Room / Bed', '$roomNumber • $bedLabel'),
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

  IconData _getBillIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('electric') || lower.contains('power') || lower.contains('current') || lower.contains('eb')) {
      return Icons.bolt_rounded;
    } else if (lower.contains('water')) {
      return Icons.water_drop_rounded;
    } else if (lower.contains('wifi') || lower.contains('wi-fi') || lower.contains('internet')) {
      return Icons.wifi_rounded;
    } else if (lower.contains('clean')) {
      return Icons.cleaning_services_rounded;
    } else if (lower.contains('food') || lower.contains('mess')) {
      return Icons.restaurant_rounded;
    } else if (lower.contains('maintain') || lower.contains('maintenance')) {
      return Icons.build_rounded;
    }
    return Icons.receipt_long_outlined;
  }

  Widget _buildPaymentBreakdownRow(String label, String value, {IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: const Color(0xFF64748B)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: TenantTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 95.0),
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
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 95.0),
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

          // Profile Header Card (Sleek Compact Glass Container)
          _buildGlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [TenantTheme.primary, TenantTheme.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: TenantAvatar(
                      name: name,
                      imageUrl: _profileData?['imageUrl'],
                      radius: 22,
                      enablePreview: true,
                      backgroundColor: TenantTheme.primarySoft,
                      textColor: TenantTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: TenantTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isKycComplete ? TenantTheme.successBg : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isKycComplete ? TenantTheme.successBorder : const Color(0xFFFDE68A),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isKycComplete ? Icons.verified_rounded : Icons.pending_actions_rounded,
                              size: 10,
                              color: isKycComplete ? TenantTheme.success : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isKycComplete ? 'KYC Verified' : 'KYC Pending',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isKycComplete ? TenantTheme.success : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _openEditProfileDialog(),
                      tooltip: 'Edit Profile',
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: TenantTheme.primarySoft,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 17, color: TenantTheme.primary),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _openCompleteKycDialog(),
                      tooltip: isKycComplete ? 'Update KYC' : 'Complete KYC',
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: isKycComplete ? TenantTheme.successBg : const Color(0xFFFEF3C7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(
                        isKycComplete ? Icons.assignment_turned_in_outlined : Icons.verified_user_outlined,
                        size: 17,
                        color: isKycComplete ? TenantTheme.success : const Color(0xFFD97706),
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
              subtitle: '$roomNumber${bedLabel != null && bedLabel.isNotEmpty ? ' • $bedLabel' : ''}',
              items: [
                _buildProfileRow('Room & Bed', '$roomNumber${bedLabel != null && bedLabel.isNotEmpty ? ' • $bedLabel' : ''}', icon: Icons.door_sliding_outlined),
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
            subtitle: phone != '-' ? phone : (email != 'Not Provided' ? email : 'Tap to view details'),
            items: [
              _buildProfileRow('Phone Number', phone, icon: Icons.phone_outlined),
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
          const SizedBox(height: 14),

          // Security Recovery PIN Section
          _buildSecurityPinSectionCard(),
          const SizedBox(height: 14),

          // Security & Change Password Section
          _buildChangePasswordSectionCard(),
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

  Future<void> _handleTenantUpdateSecurityPin() async {
    final newPin = _tenantNewPinController.text.trim();
    final confirmPin = _tenantConfirmNewPinController.text.trim();

    if (newPin.isEmpty) {
      setState(() => _securityPinError = 'Please enter a 4-digit PIN');
      return;
    }
    if (newPin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(newPin)) {
      setState(() => _securityPinError = 'PIN must be exactly 4 numeric digits');
      return;
    }
    if (newPin != confirmPin) {
      setState(() => _securityPinError = 'PINs do not match');
      return;
    }

    setState(() {
      _isUpdatingPin = true;
      _securityPinError = null;
    });

    try {
      final success = await ApiService.setupSecurityPin(newPin);
      if (!mounted) return;
      if (success) {
        _tenantNewPinController.clear();
        _tenantConfirmNewPinController.clear();
        setState(() {
          _isSecurityPinExpanded = false;
        });
        FancyToast.showSuccess(
          context,
          'Security PIN Updated',
          message: 'Your 4-digit Security Recovery PIN has been updated successfully.',
        );
      } else {
        setState(() {
          _securityPinError = 'Failed to update PIN. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = ApiService.cleanErrorMessage(e);
        setState(() {
          _securityPinError = cleanMsg;
        });
        FancyToast.showError(context, 'PIN Update Failed', message: cleanMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPin = false);
      }
    }
  }

  Widget _buildSecurityPinSectionCard() {
    final isExpanded = _isSecurityPinExpanded;
    final hasPin = ApiService.hasSecurityPin;

    return _buildGlassContainer(
      borderRadius: 20,
      customBorderColor: isExpanded ? const Color(0xFF6366F1).withValues(alpha: 0.85) : TenantTheme.glassBorder,
      customShadow: [
        BoxShadow(
          color: const Color(0x0A0F172A),
          blurRadius: isExpanded ? 16 : 10,
          offset: Offset(0, isExpanded ? 6 : 3),
        ),
        BoxShadow(
          color: isExpanded ? const Color(0x146366F1) : const Color(0x040F172A),
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
              onTap: () => setState(() => _isSecurityPinExpanded = !_isSecurityPinExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isExpanded ? const Color(0xFF6366F1) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isExpanded
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(Icons.pin_outlined, color: isExpanded ? Colors.white : const Color(0xFF6366F1), size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Security Recovery PIN',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: TenantTheme.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasPin ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: hasPin ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                                  ),
                                ),
                                child: Text(
                                  hasPin ? 'Active' : 'Not Set',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: hasPin ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!isExpanded) ...[
                            const SizedBox(height: 2),
                            Text(
                              hasPin
                                  ? '4-digit MPIN for instant password recovery'
                                  : 'Set up your 4-digit PIN for safe password recovery',
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
                        color: isExpanded ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isExpanded ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isExpanded ? const Color(0xFF6366F1) : const Color(0xFF64748B),
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
            secondChild: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(bottom: 14),
                    color: const Color(0xFFF1F5F9),
                  ),
                  Text(
                    'Your 4-digit PIN (ATM / UPI style) allows you to verify your identity and reset your password if you ever forget it.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: TenantTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // New PIN Input
                  TextFormField(
                    controller: _tenantNewPinController,
                    obscureText: _obscureTenantPin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                      color: TenantTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '• • • •',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        letterSpacing: 8,
                        color: TenantTheme.textMuted,
                      ),
                      prefixIcon: const Icon(Icons.pin_outlined, size: 20, color: Color(0xFF64748B)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureTenantPin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(() => _obscureTenantPin = !_obscureTenantPin),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Confirm PIN Input
                  TextFormField(
                    controller: _tenantConfirmNewPinController,
                    obscureText: _obscureTenantConfirmPin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                      color: TenantTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '• • • •',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        letterSpacing: 8,
                        color: TenantTheme.textMuted,
                      ),
                      prefixIcon: const Icon(Icons.lock_clock_outlined, size: 20, color: Color(0xFF64748B)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureTenantConfirmPin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(() => _obscureTenantConfirmPin = !_obscureTenantConfirmPin),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                      ),
                    ),
                  ),
                  if (_securityPinError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _securityPinError!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isUpdatingPin ? null : _handleTenantUpdateSecurityPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUpdatingPin
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              hasPin ? 'Update Security PIN' : 'Save Security PIN',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
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

  Future<void> _handleTenantChangePassword() async {
    final newPassword = _tenantNewPasswordController.text.trim();
    final confirmPassword = _tenantConfirmPasswordController.text.trim();

    if (newPassword.isEmpty) {
      setState(() => _changePasswordError = 'Please enter a new password');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _changePasswordError = 'Password must be at least 6 characters');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _changePasswordError = 'Passwords do not match');
      return;
    }

    setState(() {
      _isChangingPassword = true;
      _changePasswordError = null;
    });

    try {
      final success = await ApiService.changePassword(newPassword);
      if (!mounted) return;
      if (success) {
        _tenantNewPasswordController.clear();
        _tenantConfirmPasswordController.clear();
        setState(() {
          _isChangePasswordExpanded = false;
        });
        FancyToast.showSuccess(
          context,
          'Password Changed',
          message: 'Your password has been updated successfully.',
        );
      } else {
        setState(() {
          _changePasswordError = 'Failed to update password. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = ApiService.cleanErrorMessage(e);
        setState(() {
          _changePasswordError = cleanMsg;
        });
        FancyToast.showError(context, 'Password Change Failed', message: cleanMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  Widget _buildChangePasswordSectionCard() {
    final isExpanded = _isChangePasswordExpanded;
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
              onTap: () => setState(() => _isChangePasswordExpanded = !_isChangePasswordExpanded),
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
                      child: Icon(Icons.lock_reset_rounded, color: isExpanded ? Colors.white : TenantTheme.primary, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change Password',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: TenantTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (!isExpanded) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Update your account password',
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
            secondChild: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(bottom: 14),
                    color: const Color(0xFFF1F5F9),
                  ),
                  Text(
                    'Set a new password for logging into your Remaki account.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: TenantTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // New Password Input
                  TextFormField(
                    controller: _tenantNewPasswordController,
                    obscureText: _obscureTenantNewPassword,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TenantTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter new password',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: TenantTheme.textMuted,
                      ),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF64748B)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureTenantNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(() => _obscureTenantNewPassword = !_obscureTenantNewPassword),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: TenantTheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Confirm Password Input
                  TextFormField(
                    controller: _tenantConfirmPasswordController,
                    obscureText: _obscureTenantConfirmPassword,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TenantTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Confirm new password',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: TenantTheme.textMuted,
                      ),
                      prefixIcon: const Icon(Icons.lock_clock_outlined, size: 20, color: Color(0xFF64748B)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureTenantConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(() => _obscureTenantConfirmPassword = !_obscureTenantConfirmPassword),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: TenantTheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                  if (_changePasswordError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _changePasswordError!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isChangingPassword ? null : _handleTenantChangePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TenantTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isChangingPassword
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Update Password',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
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
