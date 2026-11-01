import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/web_upi_util.dart';
import 'fancy_toast.dart';

class UniversalUpiCheckoutModal extends StatefulWidget {
  final double amount;
  final String upiId;
  final String payeeName;
  final String? propertyName;
  final String? tenantName;
  final String? note;
  final String? transactionRef;
  final VoidCallback onProceedToUpload;

  const UniversalUpiCheckoutModal({
    super.key,
    required this.amount,
    required this.upiId,
    required this.payeeName,
    this.propertyName,
    this.tenantName,
    this.note,
    this.transactionRef,
    required this.onProceedToUpload,
  });

  static final RegExp _vpaRegex = RegExp(r'^[\w.\-]{2,256}@[a-zA-Z]{2,64}$');

  static bool isValidVpa(String? vpa) {
    if (vpa == null) return false;
    return _vpaRegex.hasMatch(vpa.trim());
  }

  static String sanitizePayeeName(String raw) {
    final clean = raw
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9 .]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return 'Remaki Property';
    return clean.length > 22 ? clean.substring(0, 22).trim() : clean;
  }

  static Future<void> show(
    BuildContext context, {
    required double amount,
    required String upiId,
    required String payeeName,
    String? propertyName,
    String? tenantName,
    String? note,
    String? transactionRef,
    required VoidCallback onProceedToUpload,
  }) {
    if (amount <= 0) {
      FancyToast.showError(context, 'Invalid Amount', message: 'Payment amount must be greater than zero.');
      return Future.value();
    }
    if (!isValidVpa(upiId)) {
      FancyToast.showError(context, 'Invalid UPI ID', message: 'The payment UPI ID "$upiId" is invalid or misconfigured.');
      return Future.value();
    }

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
        transactionRef: transactionRef,
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
  bool _isLaunching = false;
  bool _isDownloadingQr = false;
  late double _currentAmount;
  bool _isSplitMode = false;
  late TextEditingController _splitController;
  late String _effectiveTxnRef;

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
    assert(UniversalUpiCheckoutModal.isValidVpa(widget.upiId), 'Invalid UPI VPA passed to checkout: ${widget.upiId}');
    _effectiveTxnRef = widget.transactionRef ?? 'RMK${DateTime.now().millisecondsSinceEpoch}';
    // Desktop defaults to Scan QR Code tab (index 1).
    // iOS Safari / Mobile Browser / App defaults to Pay via App tab (index 0).
    _currentAmount = widget.amount;
    _splitController = TextEditingController(text: widget.amount > 0 ? (widget.amount / 2).toStringAsFixed(0) : '0');
    final initialTabIndex = _isDesktop ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _splitController.dispose();
    super.dispose();
  }

  String _buildQueryString() {
    // 1. Lowercase and trim VPA for strict bank switch compatibility
    final cleanVpa = widget.upiId.trim().toLowerCase();

    // Keep only UPI ID (pa), Amount (am), and Currency (cu) - omitting Payee Name (pn) and Note (tn)
    // This allows GPay, Paytm, Navi, Groww to resolve the verified recipient directly from NPCI directory,
    // avoiding payee mismatch errors and bank limit decline flags.
    final queryParams = <String, String>{
      'pa': cleanVpa,
      if (_currentAmount > 0) 'am': _currentAmount.toStringAsFixed(2),
      'cu': 'INR',
    };

    return queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  String _buildGenericUpiUri() {
    final queryString = _buildQueryString();
    return 'upi://pay?$queryString';
  }

  String _buildTargetedUpiUri({String? customScheme, String? packageName, String? iosScheme}) {
    final queryString = _buildQueryString();

    // 1. Mobile Chrome Web Browser: intent:// URI with package targets the specific app directly
    if (kIsWeb) {
      if (packageName != null && packageName.isNotEmpty) {
        return 'intent://pay?' + queryString + '#Intent;scheme=upi;package=' + packageName + ';end';
      }
      return 'upi://pay?' + queryString;
    }

    // 2. iOS custom schemes (gpay://, phonepe://, paytmmp://, credpay://)
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final scheme = iosScheme ?? customScheme;
      if (scheme != null && scheme.isNotEmpty) {
        final s = scheme.toLowerCase();
        if (s == 'gpay' || s == 'tez') return 'gpay://upi/pay?' + queryString;
        if (s == 'phonepe') return 'phonepe://pay?' + queryString;
        if (s == 'paytm' || s == 'paytmmp') return 'paytmmp://pay?' + queryString;
        if (s == 'cred' || s == 'credpay') return 'credpay://pay?' + queryString;
      }
      return 'upi://pay?' + queryString;
    }

    // 3. Android: Universal standard upi://pay intent (same proven method as Navi, Groww, and QR)
    // Avoids proprietary merchant acquiring schemes (tez://, paytmmp://) that trigger
    // false-positive "Bank limit exceeded" (U16) declines on personal savings VPAs.
    return 'upi://pay?' + queryString;
  }

  Future<void> _launchUpiApp(String schemeName, {String? customScheme, String? packageName, String? iosScheme}) async {
    setState(() => _isLaunching = true);
    final targetedUrl = _buildTargetedUpiUri(customScheme: customScheme, packageName: packageName, iosScheme: iosScheme);
    final genericFallback = _buildGenericUpiUri();

    // Diagnostic logging for exact link verification
    debugPrint('🔍 UPI Targeted URI ($schemeName): $targetedUrl');
    debugPrint('🔍 UPI Generic Fallback: $genericFallback');

    try {
      if (kIsWeb) {
        // Mobile Chrome on Android parses intent://package=... and opens the app DIRECTLY!
        WebUpiUtil.launchUpi(targetedUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Redirecting to $schemeName directly... If app does not open, switch to "Scan QR" tab or copy UPI ID.',
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
        // Native Android / iOS application - Belt-and-suspenders direct launch
        // Avoid gating on canLaunchUrl as some OEM Android skins (MIUI, ColorOS) return false even when installed
        final uri = Uri.parse(targetedUrl);
        bool launched = false;

        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('[UniversalUpi] Targeted launch failed: $e');
          launched = false;
        }

        // If targeted scheme/intent failed (e.g. app not installed), try universal upi://pay which QR test proved works
        if (!launched) {
          try {
            final fallbackUri = Uri.parse(genericFallback);
            launched = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
          } catch (e) {
            debugPrint('[UniversalUpi] Generic fallback failed: $e');
            launched = false;
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
    } catch (e, stack) {
      debugPrint('[UniversalUpi] Launch app error ($schemeName): $e\n$stack');
      try {
        final fallbackUri = Uri.parse(genericFallback);
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) _tabController.animateTo(1);
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }


  Future<void> _downloadQrCode(String upiPayload) async {
    if (_isDownloadingQr) return;
    setState(() => _isDownloadingQr = true);

    try {
      final qrValidationResult = QrValidator.validate(
        data: upiPayload,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF0F172A),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
        );

        final picData = await painter.toImageData(800, format: ui.ImageByteFormat.png);
        if (picData != null) {
          final pngBytes = picData.buffer.asUint8List();

          if (kIsWeb) {
            WebUpiUtil.downloadBytes(pngBytes, 'remaki_payment_qr.png');
          } else {
            Directory? targetDir;
            if (Platform.isAndroid) {
              final externalDir = Directory('/storage/emulated/0/Download');
              if (await externalDir.exists()) {
                targetDir = externalDir;
              }
            }
            targetDir ??= await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

            final filePath = '${targetDir.path}/remaki_payment_qr.png';
            final file = File(filePath);
            await file.writeAsBytes(pngBytes);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.download_done_rounded, color: Color(0xFF4ADE80), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QR Code Downloaded to Gallery!',
                            style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Open Google Pay, PhonePe, or Paytm, tap Scan QR and choose from gallery.',
                            style: GoogleFonts.lato(fontSize: 11.5, color: const Color(0xFFE2E8F0)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF0F172A),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[UniversalUpi] Download QR error: $e');
      if (mounted) {
        FancyToast.showError(context, 'Download Error', message: 'Could not save QR code: $e');
      }
    } finally {
      if (mounted) setState(() => _isDownloadingQr = false);
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

  Future<void> _copyAndOpenApp(String appName, {String? packageName, String? iosScheme}) async {
    await Clipboard.setData(ClipboardData(text: widget.upiId.trim()));
    HapticFeedback.lightImpact();

    final currencyFormat = NumberFormat('#,##,###');
    final formattedAmt = currencyFormat.format(_currentAmount);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'UPI ID Copied to Clipboard!',
                    style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Opening $appName... Tap "Pay to UPI ID", paste ${widget.upiId}, and pay ₹$formattedAmt.',
                style: GoogleFonts.lato(fontSize: 11.5, color: const Color(0xFFE2E8F0)),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    if (kIsWeb) {
      WebUpiUtil.launchUpi(_buildGenericUpiUri());
      return;
    }

    bool opened = false;
    if (defaultTargetPlatform == TargetPlatform.iOS && iosScheme != null) {
      try {
        opened = await launchUrl(Uri.parse('$iosScheme://'), mode: LaunchMode.externalApplication);
      } catch (_) {}
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (packageName == 'com.google.android.apps.nbu.paisa.user') {
          opened = await launchUrl(Uri.parse('gpay://'), mode: LaunchMode.externalApplication);
        } else if (packageName == 'net.one97.paytm') {
          opened = await launchUrl(Uri.parse('paytmmp://'), mode: LaunchMode.externalApplication);
        } else if (packageName == 'com.phonepe.app') {
          opened = await launchUrl(Uri.parse('phonepe://'), mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }

    if (!opened) {
      try {
        await launchUrl(Uri.parse(_buildGenericUpiUri()), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Future<void> _shareOnWhatsApp(String universalUpiString, String formattedAmount) async {
    final text = '🏠 *Remaki Rent Payment*\n'
        '• Property: ${widget.propertyName ?? "Remaki Property"}\n'
        '• Amount: ₹$formattedAmount\n'
        '• Pay to UPI ID: ${widget.upiId}\n\n'
        '👉 Tap link to pay via any UPI app:\n'
        '$universalUpiString\n\n'
        'You can also copy the UPI ID above and pay via Google Pay, PhonePe, Paytm, Navi, or Groww.';

    final whatsappUrl = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      final launched = await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        _copyToClipboard(text, 'Payment Details');
      }
    } catch (_) {
      _copyToClipboard(text, 'Payment Details');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##,###');
    final formattedAmount = '₹${currencyFormat.format(_currentAmount)}';
    final universalUpiString = _buildGenericUpiUri();

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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ref: ${_effectiveTxnRef.length > 14 ? "${_effectiveTxnRef.substring(0, 12)}..." : _effectiveTxnRef}',
                              style: GoogleFonts.lato(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _copyToClipboard(_effectiveTxnRef, 'Ref ID'),
                              child: const Icon(Icons.copy_rounded, color: Color(0xFF38BDF8), size: 11),
                            ),
                          ],
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

            // Split Payment Helper Toggle & Controls
            if (widget.amount > 100) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isSplitMode ? 'Paying in parts (Split Mode)' : 'Bank Limit Helper:',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isSplitMode = !_isSplitMode;
                          if (!_isSplitMode) {
                            _currentAmount = widget.amount;
                          } else {
                            final parsed = double.tryParse(_splitController.text);
                            if (parsed != null && parsed > 0 && parsed <= widget.amount) {
                              _currentAmount = parsed;
                            } else {
                              _currentAmount = (widget.amount / 2).roundToDouble();
                              _splitController.text = _currentAmount.toStringAsFixed(0);
                            }
                          }
                        });
                      },
                      icon: Icon(
                        _isSplitMode ? Icons.check_circle_rounded : Icons.call_split_rounded,
                        size: 15,
                        color: const Color(0xFF2563EB),
                      ),
                      label: Text(
                        _isSplitMode ? 'Pay Full (₹${currencyFormat.format(widget.amount)})' : 'Split Payment / Pay in Parts',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSplitMode)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Enter amount to pay now (Total due: ₹${currencyFormat.format(widget.amount)}):',
                              style: GoogleFonts.lato(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF93C5FD)),
                              ),
                              child: TextField(
                                controller: _splitController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700),
                                decoration: const InputDecoration(
                                  prefixText: ' ₹ ',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val);
                                  if (numVal != null && numVal > 0) {
                                    setState(() => _currentAmount = numVal);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('50%'),
                            labelStyle: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E40AF)),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            onPressed: () {
                              final half = (widget.amount / 2).roundToDouble();
                              _splitController.text = half.toStringAsFixed(0);
                              setState(() => _currentAmount = half);
                            },
                          ),
                          const SizedBox(width: 4),
                          ActionChip(
                            label: const Text('100%'),
                            labelStyle: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E40AF)),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            onPressed: () {
                              _splitController.text = widget.amount.toStringAsFixed(0);
                              setState(() => _currentAmount = widget.amount);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],

            // If on Desktop: Display QR code directly without mobile UPI app buttons
            // If on Mobile (iOS / Android): Display full tabs (Pay via App & Scan QR Code)
            if (!_isDesktop) ...[
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
                    // Tab 1: Mobile App buttons (GPay, PhonePe, Paytm, CRED)
                    _buildAppOptionsTab(universalUpiString, formattedAmount),

                    // Tab 2: Dynamic QR code
                    _buildQrCodeTab(universalUpiString, formattedAmount),
                  ],
                ),
              ),
            ] else ...[
              // Desktop View: Direct, prominent QR code without mobile UPI app buttons
              Flexible(
                child: _buildQrCodeTab(universalUpiString, formattedAmount),
              ),
            ],

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

  Widget _buildAppOptionsTab(String universalUpiString, String formattedAmount) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notice banner explaining GPay, PhonePe, Paytm status
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_rounded, color: Color(0xFFD97706), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Pay, PhonePe & Paytm Notice',
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Direct app button transfer is not supported for now due to bank limits on personal accounts.\n\n'
                        '👉 Switch to the "Scan QR Code" tab above to download the QR code to your gallery and pay via Google Pay, PhonePe, or Paytm.',
                        style: GoogleFonts.lato(
                          fontSize: 11.5,
                          color: const Color(0xFFB45309),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'DIRECT 1-TAP SUPPORTED APPS',
            style: GoogleFonts.lato(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 10),

          // 1. Navi UPI
          _buildUpiTile(
            title: 'Navi UPI',
            subtitle: 'Direct 1-tap transfer (pre-filled amount)',
            badgeText: '1-TAP DIRECT',
            badgeColor: const Color(0xFF059669),
            badgeBg: const Color(0xFFECFDF5),
            iconWidget: _buildNaviIcon(),
            onTap: () => _launchUpiApp('Navi', packageName: 'com.navi.finance'),
          ),

          const SizedBox(height: 10),

          // 2. Groww UPI
          _buildUpiTile(
            title: 'Groww UPI',
            subtitle: 'Direct 1-tap transfer (pre-filled amount)',
            badgeText: '1-TAP DIRECT',
            badgeColor: const Color(0xFF059669),
            badgeBg: const Color(0xFFECFDF5),
            iconWidget: _buildGrowwIcon(),
            onTap: () => _launchUpiApp('Groww', packageName: 'com.nextbillion.groww'),
          ),

          const SizedBox(height: 10),

          // 3. Any Other UPI App
          _buildUpiTile(
            title: 'Any Other UPI App',
            subtitle: 'BHIM, CRED, Amazon Pay, Axis, etc.',
            badgeText: 'ALL APPS',
            badgeColor: const Color(0xFF0F172A),
            badgeBg: const Color(0xFFF1F5F9),
            iconWidget: _buildBhimIcon(),
            onTap: () => _launchUpiApp('UPI Apps'),
          ),

          const SizedBox(height: 18),

          // Share screenshot hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'After payment in your UPI app, take a screenshot and tap "Share" -> choose Remaki to submit for approval automatically!',
                    style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF334155), height: 1.35),
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
            'Scan or download QR code with pre-filled amount ($formattedAmount)',
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

          const SizedBox(height: 14),

          // Download QR Code Button
          ElevatedButton.icon(
            onPressed: _isDownloadingQr ? null : () => _downloadQrCode(upiPayload),
            icon: _isDownloadingQr
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(
              _isDownloadingQr ? 'Saving QR Code...' : 'Download QR Code (Save to Gallery)',
              style: GoogleFonts.lato(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
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

          const SizedBox(height: 14),

          // How to pay instructions card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to pay via Google Pay, PhonePe, or Paytm:',
                  style: GoogleFonts.lato(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                Text(
                  '1. Tap "Download QR Code" above.\n'
                  '2. Open Google Pay, PhonePe, or Paytm.\n'
                  '3. Tap "Scan QR" -> select this downloaded image from your Gallery.\n'
                  '4. The amount ($formattedAmount) is pre-filled. Enter your UPI PIN to pay.\n'
                  '5. After paying, tap "Share" on your payment receipt screenshot and select Remaki to submit for approval automatically!',
                  style: GoogleFonts.lato(fontSize: 11.5, color: const Color(0xFF475569), height: 1.45),
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
  Widget _buildNaviIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF00C087),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C087).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'navi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildGrowwIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D09C), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D09C).withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF00D09C),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildBhimIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'BHIM',
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

  Widget _buildWhatsAppTile(String universalUpiString, String formattedAmount) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _shareOnWhatsApp(universalUpiString, formattedAmount),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Share to WhatsApp',
                          style: GoogleFonts.lato(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF166534),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ROOMIE / PARENT',
                            style: GoogleFonts.lato(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Send pre-filled payment link to whoever is paying',
                      style: GoogleFonts.lato(
                        fontSize: 11.5,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF16A34A), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
