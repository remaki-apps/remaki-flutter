import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A polished, high-level animated progress bar designed for image upload and media processing flows.
/// Features a dynamic progressive curve, flowing gradient shimmer sweep, pulsing ambient glow,
/// live percentage readout, and smooth entrance/exit transitions.
class AnimatedImageUploadProgressBar extends StatefulWidget {
  final bool isUploading;
  final String title;
  final String? subtitle;
  final List<Color>? gradientColors;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onCancel;

  const AnimatedImageUploadProgressBar({
    super.key,
    required this.isUploading,
    this.title = 'Uploading & processing photo...',
    this.subtitle,
    this.gradientColors,
    this.margin,
    this.onCancel,
  });

  @override
  State<AnimatedImageUploadProgressBar> createState() => _AnimatedImageUploadProgressBarState();
}

class _AnimatedImageUploadProgressBarState extends State<AnimatedImageUploadProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;

  bool _isCompleted = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    if (widget.isUploading) {
      _startUploadAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedImageUploadProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUploading && !oldWidget.isUploading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isUploading) {
          _startUploadAnimation();
        }
      });
    } else if (!widget.isUploading && oldWidget.isUploading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.isUploading) {
          _finishUploadAnimation();
        }
      });
    }
  }

  void _startUploadAnimation() {
    setState(() {
      _isVisible = true;
      _isCompleted = false;
    });
    _progressController.reset();
    // Smooth asymptotic curve up to ~92% during upload
    _progressController.animateTo(0.92, duration: const Duration(milliseconds: 2400), curve: Curves.easeOutCubic);
  }

  void _finishUploadAnimation() {
    if (!_isVisible) return;
    setState(() {
      _isCompleted = true;
    });
    // Accelerate to 100% smoothly
    _progressController.animateTo(1.0, duration: const Duration(milliseconds: 280), curve: Curves.easeOut).then((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 320), () {
          if (mounted && !widget.isUploading) {
            setState(() {
              _isVisible = false;
              _isCompleted = false;
            });
            _progressController.reset();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _getPhaseText(double progress) {
    if (widget.subtitle != null) return widget.subtitle!;
    if (_isCompleted || progress >= 0.99) return 'Photo ready & attached!';
    if (progress < 0.25) return 'Reading & inspecting photo...';
    if (progress < 0.65) return 'Compressing & optimizing resolution...';
    if (progress < 0.88) return 'Finalizing image proof...';
    return 'Attaching photo...';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible && !widget.isUploading) {
      return const SizedBox.shrink();
    }

    final colors = widget.gradientColors ?? const [
      Color(0xFF4F46E5),
      Color(0xFF7C3AED),
      Color(0xFF06B6D4),
    ];
    final primaryAccent = colors.first;

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: Container(
          margin: widget.margin ?? const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isCompleted ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isCompleted
                    ? const Color(0x1A16A34A)
                    : primaryAccent.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: Listenable.merge([_progressAnimation, _shimmerController, _pulseController]),
            builder: (context, _) {
              final double progress = _progressAnimation.value.clamp(0.0, 1.0);
              final int percent = (progress * 100).toInt();
              final double pulseVal = _pulseController.value;
              final double shimmerVal = _shimmerController.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Animated Badge + Title/Phase + Percentage Badge
                  Row(
                    children: [
                      // Pulsing Icon Badge
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _isCompleted
                              ? const Color(0xFFDCFCE7)
                              : primaryAccent.withValues(alpha: 0.08 + (pulseVal * 0.04)),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: _isCompleted
                                ? const Color(0xFF86EFAC)
                                : primaryAccent.withValues(alpha: 0.18 + (pulseVal * 0.12)),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: _isCompleted
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF16A34A),
                                  size: 20,
                                )
                              : Icon(
                                  Icons.cloud_upload_rounded,
                                  color: primaryAccent,
                                  size: 20,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title and dynamic phase text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isCompleted ? 'Photo Uploaded' : widget.title,
                              style: GoogleFonts.lato(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getPhaseText(progress),
                              style: GoogleFonts.lato(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: _isCompleted
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Percentage Pill / Complete Check
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isCompleted
                              ? const Color(0xFFDCFCE7)
                              : primaryAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isCompleted
                                ? const Color(0xFF86EFAC)
                                : primaryAccent.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _isCompleted ? '100%' : '$percent%',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _isCompleted ? const Color(0xFF15803D) : primaryAccent,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress Track with Shimmer Wave & Glowing Leading Bead
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      final currentBarWidth = math.max(6.0, totalWidth * progress);

                      return Container(
                        height: 7,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Base gradient progress fill
                            Container(
                              width: currentBarWidth,
                              height: 7,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                gradient: LinearGradient(
                                  colors: _isCompleted
                                      ? const [Color(0xFF16A34A), Color(0xFF22C55E)]
                                      : colors,
                                ),
                              ),
                            ),

                            // Flowing light shimmer wave
                            if (!_isCompleted)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: Container(
                                  width: currentBarWidth,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(-2.0 + (4.0 * shimmerVal), 0),
                                      end: Alignment(-1.0 + (4.0 * shimmerVal), 0),
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.65),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // High-tech glowing bead at the leading head of the bar
                            if (!_isCompleted && progress > 0.04)
                              Positioned(
                                left: currentBarWidth - 4.5,
                                top: -1.5,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryAccent.withValues(alpha: 0.8),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A compact, animated micro-loader for buttons and pills when image upload is active.
/// Replaces plain circular spinners with an elegant pulsing icon and animated dot wave.
class AnimatedUploadButtonLoader extends StatefulWidget {
  final Color color;
  final double size;

  const AnimatedUploadButtonLoader({
    super.key,
    this.color = Colors.white,
    this.size = 16,
  });

  @override
  State<AnimatedUploadButtonLoader> createState() => _AnimatedUploadButtonLoaderState();
}

class _AnimatedUploadButtonLoaderState extends State<AnimatedUploadButtonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload_rounded,
              size: widget.size,
              color: widget.color.withValues(alpha: 0.7 + (math.sin(val * math.pi) * 0.3)),
            ),
            const SizedBox(width: 4),
            ...List.generate(3, (index) {
              final delay = index * 0.25;
              final adjusted = (val - delay) % 1.0;
              final scale = (math.sin(adjusted * math.pi) * 0.5 + 0.5).clamp(0.2, 1.0);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.2),
                width: 3.0,
                height: 3.0 + (scale * 3.5),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.4 + (scale * 0.6)),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

