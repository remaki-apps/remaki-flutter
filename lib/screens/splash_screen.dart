import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rippleController;
  late AnimationController _shimmerController;
  late AnimationController _particleController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _logoRotate;

  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _textLetterSpacing;

  late Animation<double> _loaderFade;

  String _loadingStatus = 'Preparing your experience...';
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();

    // Main entrance timeline (2.0s)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Sonar pulse ripples (infinite)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    // Shimmer sheen sweep across logo (infinite)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Floating particles (infinite)
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Logo Animations
    _logoScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _logoRotate = Tween<double>(begin: -0.08, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.05, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Brand Text Animations
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _textLetterSpacing = Tween<double>(begin: 1.0, end: 4.5).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // Bottom Loader Animations
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
      ),
    );

    _mainController.forward();

    // Dynamic loading status messages
    _statusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _loadingStatus = 'Syncing PG Workspace...';
        });
      }
    });

    // Navigate to next screen after 2.6 seconds
    Timer(const Duration(milliseconds: 2600), () {
      _navigateToNextScreen();
    });
  }

  void _navigateToNextScreen() {
    if (!mounted) return;

    if (!ApiService.isLoggedIn) {
      context.go('/login');
    } else if (ApiService.role == 'TENANT') {
      if (!ApiService.hasSecurityPin) {
        context.go('/setup_security_pin');
      } else {
        context.go('/tenant_home');
      }
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _mainController.dispose();
    _rippleController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Ultra Light Clean Radial Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 1.15,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF8FAFC),
                    Color(0xFFEEF2FF),
                  ],
                  stops: [0.0, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // 2. Animated Floating Background Micro-Particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _SplashParticlesPainter(_particleController.value),
                );
              },
            ),
          ),

          // 3. Animated Sonar Ripple Rings behind Logo (Centered)
          Center(
            child: AnimatedBuilder(
              animation: _rippleController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: List.generate(3, (index) {
                    final delay = index * 0.33;
                    final progress = (_rippleController.value + delay) % 1.0;
                    final size = 110.0 + (progress * 170.0);
                    final opacity = (1.0 - progress) * 0.22;

                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: opacity),
                          width: 1.5,
                        ),
                        color: const Color(0xFF4F46E5).withValues(alpha: opacity * 0.25),
                      ),
                    );
                  }),
                );
              },
            ),
          ),

          // 4. Main Center Content Assembly (Exact Vertical & Horizontal Centering)
          Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Glassmorphic Logo Container with Shimmer Sweep
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _logoFade,
                        child: Transform.rotate(
                          angle: _logoRotate.value,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft Outer Glow Ring
                        Container(
                          width: 124,
                          height: 124,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(34),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.22),
                                blurRadius: 36,
                                spreadRadius: 4,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                        ),

                        // Logo Container Badge
                        Container(
                          width: 118,
                          height: 118,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFE0E7FF),
                                Color(0xFFA5B4FC),
                                Color(0xFF6366F1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Stack(
                              children: [
                                // Logo Image
                                Positioned.fill(
                                  child: Image.asset(
                                    'assets/logo/R_logo.jpeg',
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) {
                                      return Container(
                                        color: const Color(0xFF4F46E5),
                                        child: const Icon(
                                          Icons.apartment_rounded,
                                          color: Colors.white,
                                          size: 56,
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                // Shimmer Light Beam Reflection Animation Across Logo
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _shimmerController,
                                    builder: (context, child) {
                                      final shimmerPos = (_shimmerController.value * 3) - 1.0;
                                      return ShaderMask(
                                        blendMode: BlendMode.srcATop,
                                        shaderCallback: (bounds) {
                                          return LinearGradient(
                                            begin: Alignment(shimmerPos - 1, -1),
                                            end: Alignment(shimmerPos + 1, 1),
                                            colors: const [
                                              Colors.transparent,
                                              Colors.white30,
                                              Colors.white70,
                                              Colors.white30,
                                              Colors.transparent,
                                            ],
                                            stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                                          ).createShader(bounds);
                                        },
                                        child: Container(
                                          color: Colors.white.withValues(alpha: 0.1),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Staggered Title & Premium Subtitle Pill
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _textFade,
                        child: SlideTransition(
                          position: _textSlide,
                          child: Column(
                            children: [
                              // App Title with Animated Letter Spacing & Glow
                              Text(
                                'REMAKI',
                                style: GoogleFonts.outfit(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: _textLetterSpacing.value,
                                  color: const Color(0xFF0F172A),
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Subtitle Text (Clean standalone typography)
                              Text(
                                'PG & Hostel Management Simplified',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.6,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 52),

                  // Animated Progress Indicator with Glowing Trailing Dot
                  FadeTransition(
                    opacity: _loaderFade,
                    child: Column(
                      children: [
                        // Custom Glowing Linear Progress Bar
                        SizedBox(
                          width: 150,
                          height: 4,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _mainController,
                                builder: (context, child) {
                                  return FractionallySizedBox(
                                    widthFactor: math.min(1.0, math.max(0.1, _mainController.value)),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF818CF8),
                                            Color(0xFF4F46E5),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Animated Status Text
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(
                            _loadingStatus,
                            key: ValueKey(_loadingStatus),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Bottom Footer Version Tag
          Positioned(
            bottom: 24,
            child: FadeTransition(
              opacity: _loaderFade,
              child: SafeArea(
                top: false,
                child: Text(
                  'v1.0.0 • Powered by Remaki',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter to draw floating ambient micro-particles
class _SplashParticlesPainter extends CustomPainter {
  final double progress;

  _SplashParticlesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42); // Fixed seed for consistent deterministic particle paths

    for (int i = 0; i < 18; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final speed = 0.2 + random.nextDouble() * 0.8;
      final radius = 1.5 + random.nextDouble() * 2.5;

      // Move particle upwards vertically over time
      final currentY = (startY - (progress * speed * size.height)) % size.height;
      final currentX = startX + math.sin((progress * math.pi * 2) + i) * 12.0;

      // Calculate smooth alpha fading near top and bottom boundaries
      final alphaFactor = math.sin((currentY / size.height) * math.pi);
      paint.color = const Color(0xFF6366F1).withValues(alpha: (0.05 + (random.nextDouble() * 0.1)) * alphaFactor);

      canvas.drawCircle(Offset(currentX, currentY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashParticlesPainter oldDelegate) => true;
}



