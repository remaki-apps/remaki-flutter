import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/web_upi_util.dart';

class UniversalUpiCheckoutModal extends StatefulWidget {
  final double amount;
  final String upiId;
  final String payeeName;
  final String? propertyName;
  final String? tenantName;
  final String? note;
  final VoidCallback onProceedToUpload;

  const UniversalUpiCheckoutModal({
    super.key,
    required this.amount,
    required this.upiId,
    required this.payeeName,
    this.propertyName,
    this.tenantName,
    this.note,
    required this.onProceedToUpload,
  });

  static Future<void> show(
    BuildContext context, {
    required double amount,
    required String upiId,
    required String payeeName,
    String? propertyName,
    String? tenantName,
    String? note,
    required VoidCallback onProceedToUpload,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => UniversalUpiCheckoutModal(
        amount: amount,
        upiId: upiId,
        payeeName: payeeName,
        propertyName: propertyName,
        tenantName: tenantName,
        note: note,
        onProceedToUpload: onProceedToUpload,
      ),
    );
  }

  @override
  State<UniversalUpiCheckoutModal> createState() => _UniversalUpiCheckoutModalState();
}

class _UniversalUpiCheckoutModalState extends State<UniversalUpiCheckoutModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _transactionRef;
  bool _isLaunching = false;

  bool get _isDesktop {
    if (kIsWeb) {
      return defaultTargetPlatform == TargetPlatform.windows ||
             defaultTargetPlatform == TargetPlatform.macOS ||
             defaultTargetPlatform == TargetPlatform.linux;
    }
    return defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.macOS ||
           defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    // Desktop defaults to Scan QR Code tab (index 1).
    // iOS Safari / Mobile Browser / App defaults to Pay via App tab (index 0).
    final initialTabIndex = _isDesktop ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialTabIndex);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _transactionRef = 'RMK$timestamp';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _buildUpiUri({String? scheme}) {
    final note = widget.note?.trim().isNotEmpty == true
        ? widget.note!.trim()
        : 'Rent payment for ${widget.propertyName ?? "PG"}';

    final queryParams = {
      'pa': widget.upiId.trim(),
      'pn': widget.payeeName.trim(),
      'am': widget.amount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': note,
      'tr': _transactionRef,
    };

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    if (scheme == 'tez' || scheme == 'gpay') {
      return 'tez://upi/pay?$queryString';
    } else if (scheme == 'phonepe') {
      return 'phonepe://pay?$queryString';
    } else if (scheme == 'paytmmp' || scheme == 'paytm') {
      return 'paytmmp://pay?$queryString';
    } else if (scheme == 'credpay') {
      return 'credpay://pay?$queryString';
    }
    return 'upi://pay?$queryString';
  }

  Future<void> _launchUpiApp(String schemeName, {String? customScheme}) async {
    setState(() => _isLaunching = true);
    final upiUrl = _buildUpiUri(scheme: customScheme);
    final fallbackUrl = _buildUpiUri();

    try {
      if (kIsWeb) {
        // Direct trigger for mobile browsers (iOS Safari, mobile browsers)
        // just like Flipkart and RedBus without failing on canLaunchUrl checks.
        WebUpiUtil.launchUpi(upiUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Opening $schemeName... If app does not open, switch to "Scan QR" tab or copy UPI ID.',
                      style: GoogleFonts.lato(fontSize: 12.5, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        // Native mobile application (Android / iOS native)
        final uri = Uri.parse(upiUrl);
        bool launched = false;

        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        if (!launched && customScheme != null) {
          final fallbackUri = Uri.parse(fallbackUrl);
          if (await canLaunchUrl(fallbackUri)) {
            launched = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
          }
        }

        if (!launched && mounted) {
          _tabController.animateTo(1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$schemeName app is not directly accessible. Please scan the QR code or copy the UPI ID to pay.',
                style: GoogleFonts.lato(fontSize: 13, color: Colors.white),
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _tabController.animateTo(1);
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 18),
            const SizedBox(width: 8),
            Text('$label copied to clipboard!', style: GoogleFonts.lato(fontSize: 13, color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##,###');
    final formattedAmount = '₹${currencyFormat.format(widget.amount)}';
    final universalUpiString = _buildUpiUri();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UPI Instant Checkout',
                            style: GoogleFonts.lato(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '0% Transaction Fee • Direct to PG Owner',
                            style: GoogleFonts.lato(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Payment Summary Banner
            Container(
              margin: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL PAYABLE',
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedAmount,
                          style: GoogleFonts.lato(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.payeeName.isNotEmpty ? widget.payeeName : (widget.propertyName ?? 'Property Owner'),
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFE2E8F0),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'UPI ID',
                          style: GoogleFonts.lato(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.upiId.length > 18 ? '${widget.upiId.substring(0, 16)}...' : widget.upiId,
                              style: GoogleFonts.lato(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _copyToClipboard(widget.upiId, 'UPI ID'),
                              child: const Icon(Icons.copy_rounded, color: Color(0xFF38BDF8), size: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Selector
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w800),
                unselectedLabelStyle: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Pay via App'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Scan QR Code'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: App buttons
                  _buildAppOptionsTab(),

                  // Tab 2: Dynamic QR code
                  _buildQrCodeTab(universalUpiString, formattedAmount),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Bottom Confirmation Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onProceedToUpload();
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: Text(
                        'I Have Paid • Upload Proof',
                        style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppOptionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT PAYMENT APP',
            style: GoogleFonts.lato(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 10),

          // Google Pay
          _buildUpiTile(
            title: 'Google Pay',
            subtitle: 'Instant payment via GPay app',
            badgeText: 'FASTEST',
            badgeColor: const Color(0xFF2563EB),
            badgeBg: const Color(0xFFEFF6FF),
            iconWidget: _buildGPayIcon(),
            onTap: () => _launchUpiApp('Google Pay', customScheme: 'tez'),
          ),

          const SizedBox(height: 10),

          // PhonePe
          _buildUpiTile(
            title: 'PhonePe',
            subtitle: 'Pay directly via PhonePe UPI',
            iconWidget: _buildPhonePeIcon(),
            onTap: () => _launchUpiApp('PhonePe', customScheme: 'phonepe'),
          ),

          const SizedBox(height: 10),

          // Paytm
          _buildUpiTile(
            title: 'Paytm',
            subtitle: 'Pay via Paytm UPI or Wallet',
            iconWidget: _buildPaytmIcon(),
            onTap: () => _launchUpiApp('Paytm', customScheme: 'paytmmp'),
          ),

          const SizedBox(height: 10),

          // CRED
          _buildUpiTile(
            title: 'CRED',
            subtitle: 'Pay via CRED UPI app',
            badgeText: 'POPULAR',
            badgeColor: const Color(0xFF0F172A),
            badgeBg: const Color(0xFFF1F5F9),
            iconWidget: _buildCredIcon(),
            onTap: () => _launchUpiApp('CRED', customScheme: 'credpay'),
          ),

          const SizedBox(height: 10),

          // Universal UPI / Other Apps
          _buildUpiTile(
            title: 'Any UPI App',
            subtitle: 'BHIM, Amazon Pay, Axis, SBI, etc.',
            iconWidget: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
            ),
            onTap: () => _launchUpiApp('UPI Apps'),
          ),

          const SizedBox(height: 14),

          // Desktop / iOS hint card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'On iOS Safari or Chrome? Tapping an app will open it directly on your device. You can also switch to "Scan QR Code" tab or copy the UPI ID.',
                    style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF475569), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCodeTab(String upiPayload, String formattedAmount) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        children: [
          if (_isDesktop) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.devices_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'On Desktop? Open any UPI app (GPay, PhonePe, Paytm, CRED) on your phone and scan this QR code to pay.',
                      style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E40AF), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Text(
            'Scan with Google Pay, PhonePe, Paytm, or any UPI app',
            style: GoogleFonts.lato(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Dynamic QR Card
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: QrImageView(
                data: upiPayload,
                version: QrVersions.auto,
                size: 190.0,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Copy UPI ID Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF475569)),
                const SizedBox(width: 8),
                Text(
                  widget.upiId,
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _copyToClipboard(widget.upiId, 'UPI ID'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Copy',
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiTile({
    required String title,
    required String subtitle,
    required Widget iconWidget,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
    Color? badgeBg,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLaunching ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.lato(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg ?? const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: GoogleFonts.lato(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: badgeColor ?? const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.lato(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGPayIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w900),
            children: const [
              TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhonePeIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF5F259F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'पे',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildPaytmIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF002E6E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'Paytm',
          style: TextStyle(
            color: Color(0xFF00BAF2),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildCredIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: const Center(
        child: Text(
          'CRED',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
