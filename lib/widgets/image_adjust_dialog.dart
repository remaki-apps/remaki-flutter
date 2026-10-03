import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

/// An interactive, WhatsApp/Instagram-style photo adjustment dialog.
/// Allows panning, pinch-to-zoom, 90° rotation, and real-time masking
/// for circular profile pictures or rectangular announcement photos.
class ImageAdjustDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;
  final bool isCircle;
  final double aspectRatio;

  const ImageAdjustDialog({
    super.key,
    required this.imageBytes,
    this.title = 'Adjust Photo',
    this.isCircle = true,
    this.aspectRatio = 1.0,
  });

  /// Opens the dialog and returns the adjusted/cropped image bytes,
  /// or null if the user cancelled.
  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    String title = 'Adjust Photo',
    bool isCircle = true,
    double aspectRatio = 1.0,
  }) {
    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) => ImageAdjustDialog(
        imageBytes: imageBytes,
        title: title,
        isCircle: isCircle,
        aspectRatio: aspectRatio,
      ),
    );
  }

  @override
  State<ImageAdjustDialog> createState() => _ImageAdjustDialogState();
}

class _ImageAdjustDialogState extends State<ImageAdjustDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transformController = TransformationController();

  late Uint8List _currentBytes;
  bool _isProcessing = false;
  int _rotationQuarterTurns = 0;

  @override
  void initState() {
    super.initState();
    _currentBytes = widget.imageBytes;
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetTransform() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
  }

  Future<void> _rotateImage() async {
    setState(() => _isProcessing = true);
    try {
      final original = img.decodeImage(_currentBytes);
      if (original != null) {
        // Rotate 90 degrees clockwise
        final rotated = img.copyRotate(original, angle: 90);
        final encoded = Uint8List.fromList(img.encodeJpg(rotated, quality: 95));
        setState(() {
          _currentBytes = encoded;
          _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
          _transformController.value = Matrix4.identity();
        });
      }
    } catch (e) {
      debugPrint('[ImageAdjustDialog] Rotation failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cropAndFinish(Size cropSize) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop(_currentBytes);
        return;
      }

      // Capture at 2.0x for retina sharpness
      final pixelRatio = 2.0;
      final uiImage = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) Navigator.of(context).pop(_currentBytes);
        return;
      }

      final fullPngBytes = byteData.buffer.asUint8List();
      final decodedFull = img.decodeImage(fullPngBytes);
      if (decodedFull == null) {
        if (mounted) Navigator.of(context).pop(_currentBytes);
        return;
      }

      // Calculate the crop box coordinates relative to the boundary center
      final centerX = (decodedFull.width / 2);
      final centerY = (decodedFull.height / 2);
      final targetW = (cropSize.width * pixelRatio).round();
      final targetH = (cropSize.height * pixelRatio).round();

      final cropX = (centerX - (targetW / 2)).round().clamp(0, decodedFull.width - 1);
      final cropY = (centerY - (targetH / 2)).round().clamp(0, decodedFull.height - 1);
      final safeW = math.min(targetW, decodedFull.width - cropX);
      final safeH = math.min(targetH, decodedFull.height - cropY);

      if (safeW <= 10 || safeH <= 10) {
        if (mounted) Navigator.of(context).pop(_currentBytes);
        return;
      }

      final cropped = img.copyCrop(
        decodedFull,
        x: cropX,
        y: cropY,
        width: safeW,
        height: safeH,
      );

      final resultJpg = Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
      if (mounted) {
        Navigator.of(context).pop(resultJpg);
      }
    } catch (e) {
      debugPrint('[ImageAdjustDialog] Crop failed: $e');
      if (mounted) {
        Navigator.of(context).pop(_currentBytes);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      elevation: 0,
      child: Center(
        child: Container(
          width: isMobile ? double.infinity : 520,
          height: isMobile ? size.height * 0.92 : 680,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x77000000),
                blurRadius: 32,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(),

              // Middle Interactive Viewport
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final viewportW = constraints.maxWidth;
                    final viewportH = constraints.maxHeight;

                    // Compute maximum fitting crop aperture according to aspectRatio
                    final margin = isMobile ? 24.0 : 40.0;
                    double cropW = viewportW - (margin * 2);
                    double cropH = cropW / widget.aspectRatio;

                    if (cropH > viewportH - (margin * 2)) {
                      cropH = viewportH - (margin * 2);
                      cropW = cropH * widget.aspectRatio;
                    }

                    // Enforce square if circular
                    if (widget.isCircle) {
                      final minSide = math.min(cropW, cropH);
                      cropW = minSide;
                      cropH = minSide;
                    }

                    final cropSize = Size(cropW, cropH);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // RepaintBoundary capturing the transformed image
                        Positioned.fill(
                          child: RepaintBoundary(
                            key: _boundaryKey,
                            child: Container(
                              color: Colors.black,
                              child: InteractiveViewer(
                                transformationController: _transformController,
                                clipBehavior: Clip.none,
                                minScale: 0.5,
                                maxScale: 5.0,
                                boundaryMargin: const EdgeInsets.all(double.infinity),
                                child: Center(
                                  child: Image.memory(
                                    _currentBytes,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Mask Overlay with aperture cutout & guidelines
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CropOverlayPainter(
                                isCircle: widget.isCircle,
                                cropSize: cropSize,
                              ),
                            ),
                          ),
                        ),

                        // Processing Spinner
                        if (_isProcessing)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF6366F1),
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // Bottom Control Bar
              LayoutBuilder(
                builder: (context, constraints) {
                  return _buildBottomBar();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
            onPressed: () => Navigator.of(context).pop(null),
            tooltip: 'Cancel',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 22),
            onPressed: _isProcessing ? null : _rotateImage,
            tooltip: 'Rotate 90°',
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, color: Colors.white70, size: 22),
            onPressed: _isProcessing ? null : _resetTransform,
            tooltip: 'Reset View',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtle gesture guide hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app_rounded, color: Color(0xFF94A3B8), size: 14),
              const SizedBox(width: 6),
              Text(
                'Drag to reposition • Pinch or scroll to zoom',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF94A3B8),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : () => Navigator.of(context).pop(null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            // Find current layout constraints for crop calculation
                            final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
                            if (boundary == null) {
                              if (mounted) Navigator.of(context).pop(_currentBytes);
                              return;
                            }
                            final viewportSize = boundary.size;
                            final isMobile = MediaQuery.of(context).size.width < 600;
                            final margin = isMobile ? 24.0 : 40.0;
                            double cropW = viewportSize.width - (margin * 2);
                            double cropH = cropW / widget.aspectRatio;
                            if (cropH > viewportSize.height - (margin * 2)) {
                              cropH = viewportSize.height - (margin * 2);
                              cropW = cropH * widget.aspectRatio;
                            }
                            if (widget.isCircle) {
                              final minSide = math.min(cropW, cropH);
                              cropW = minSide;
                              cropH = minSide;
                            }
                            _cropAndFinish(Size(cropW, cropH));
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Set Photo',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
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
    );
  }
}

/// Custom painter for the WhatsApp/Instagram crop mask overlay.
/// Draws a dimmed black overlay everywhere EXCEPT the central aperture,
/// and draws a clean white outline plus rule-of-thirds grid lines.
class _CropOverlayPainter extends CustomPainter {
  final bool isCircle;
  final Size cropSize;

  _CropOverlayPainter({
    required this.isCircle,
    required this.cropSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final cropRect = Rect.fromCenter(
      center: center,
      width: cropSize.width,
      height: cropSize.height,
    );

    // 1. Dark frosted vignette mask outside the aperture
    final fullScreenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final aperturePath = Path();
    if (isCircle) {
      aperturePath.addOval(cropRect);
    } else {
      aperturePath.addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(16)));
    }

    final maskPath = Path.combine(PathOperation.difference, fullScreenPath, aperturePath);
    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.72);
    canvas.drawPath(maskPath, maskPaint);

    // 2. Crisp boundary ring/frame
    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (isCircle) {
      canvas.drawOval(cropRect, framePaint);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(16)), framePaint);
    }

    // 3. Subtle Rule-of-Thirds Grid Guidelines inside aperture
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.save();
    canvas.clipPath(aperturePath);

    // Vertical third lines
    final stepX = cropSize.width / 3;
    canvas.drawLine(
      Offset(cropRect.left + stepX, cropRect.top),
      Offset(cropRect.left + stepX, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + stepX * 2, cropRect.top),
      Offset(cropRect.left + stepX * 2, cropRect.bottom),
      gridPaint,
    );

    // Horizontal third lines
    final stepY = cropSize.height / 3;
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + stepY),
      Offset(cropRect.right, cropRect.top + stepY),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + stepY * 2),
      Offset(cropRect.right, cropRect.top + stepY * 2),
      gridPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.isCircle != isCircle || oldDelegate.cropSize != cropSize;
  }
}
