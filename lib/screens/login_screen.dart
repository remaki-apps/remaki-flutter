import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/fancy_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _keepLoggedIn = true;
  String _errorMessage = '';

  late AnimationController _mainController;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _formSlide;
  late Animation<double> _formFade;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    _formSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
      ),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter phone number and password');
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '');
    if (cleanPhone.startsWith('+91')) {
      cleanPhone = cleanPhone.substring(3);
    } else if (cleanPhone.startsWith('91') && cleanPhone.length == 12) {
      cleanPhone = cleanPhone.substring(2);
    } else if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = cleanPhone.substring(1);
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);

      // Perform GraphQL login
      final result = await ApiService.performQuery('''
        mutation CustomLogin(\$input: CustomLoginInput!) {
          customLogin(input: \$input) {
            token
            user {
              id
              email
              role
              hasSecurityPin
            }
          }
        }
      ''', variables: {
        'input': {
          'phoneNumber': cleanPhone,
          'password': password,
        }
      });

      final token = result['customLogin']['token'];
      final role = result['customLogin']['user']['role'];
      final bool hasSecurityPin = result['customLogin']['user']['hasSecurityPin'] == true;

      // Save token in ApiService (persisted via SharedPreferences)
      await ApiService.setAuthToken(token, role, hasSecurityPin: hasSecurityPin);

      if (mounted) {
        if (role == 'ADMIN') {
          // Load initial admin data
          await appProvider.loadFromAPI();
          if (mounted) context.go('/');
        } else {
          // For Tenants: Check if they have setup their compulsory 4-digit Security Recovery PIN
          if (!hasSecurityPin) {
            context.go('/setup_security_pin');
          } else {
            context.go('/tenant_home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = ApiService.cleanErrorMessage(e);
        setState(() {
          _isLoading = false;
          _errorMessage = cleanMsg;
        });
        FancyToast.showError(context, 'Login Failed', message: cleanMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Top Hero Gradient Background Banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.40,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F0C20),
                    Color(0xFF1E1B4B),
                    Color(0xFF312E81),
                    Color(0xFF4338CA),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(42),
                  bottomRight: Radius.circular(42),
                ),
              ),
              child: Stack(
                children: [
                  // Animated Pulsing Ambient Glow Orbs
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final pulse = _pulseController.value;
                      return Stack(
                        children: [
                          Positioned(
                            top: -40 + (pulse * 10),
                            right: -40 - (pulse * 10),
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF818CF8).withValues(alpha: 0.12 + (pulse * 0.05)),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -20 - (pulse * 8),
                            left: -40 + (pulse * 8),
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF6366F1).withValues(alpha: 0.14 - (pulse * 0.04)),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),

                      // Animated R_logo.jpeg Header Badge
                      AnimatedBuilder(
                        animation: _mainController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: child,
                            ),
                          );
                        },
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final breath = _pulseController.value * 0.03;
                            return Transform.scale(
                              scale: 1.0 + breath,
                              child: Container(
                                width: 88,
                                height: 88,
                                padding: const EdgeInsets.all(3.5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE0E7FF),
                                      Color(0xFFA5B4FC),
                                      Color(0xFF6366F1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.28),
                                      blurRadius: 28,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'assets/logo/R_logo.jpeg',
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => const Icon(
                                      Icons.apartment_rounded,
                                      size: 44,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Animated Brand Title & Tagline
                      FadeTransition(
                        opacity: _titleFade,
                        child: Column(
                          children: [
                            Text(
                              'REMAKI',
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 3.5,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Resident & Management Portal',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFFC7D2FE),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Animated Form Card Container
                      AnimatedBuilder(
                        animation: _mainController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _formFade,
                            child: SlideTransition(
                              position: _formSlide,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.09),
                                blurRadius: 32,
                                spreadRadius: 2,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Sign In to Your Account',
                                style: GoogleFonts.outfit(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enter your credentials to access your account',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Error Alert Message Banner
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _errorMessage.isNotEmpty
                                    ? Container(
                                        key: ValueKey(_errorMessage),
                                        padding: const EdgeInsets.all(14),
                                        margin: const EdgeInsets.only(bottom: 20),
                                        decoration: BoxDecoration(
                                          color: AppTheme.dangerBg,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: AppTheme.danger.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              color: AppTheme.danger,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _errorMessage,
                                                style: GoogleFonts.inter(
                                                  color: AppTheme.danger,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              // Phone Number Field
                              Text(
                                'Phone Number',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                autocorrect: false,
                                enableSuggestions: false,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: '9876543210',
                                  hintStyle: GoogleFonts.inter(
                                    color: const Color(0xFFA0AEC0),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.phone_outlined,
                                      color: Color(0xFF4F46E5),
                                      size: 18,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF4F46E5),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Password Field
                              Text(
                                'Password',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                autocorrect: false,
                                enableSuggestions: false,
                                textCapitalization: TextCapitalization.none,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  hintStyle: GoogleFonts.inter(
                                    color: const Color(0xFFA0AEC0),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: Color(0xFF4F46E5),
                                      size: 18,
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppTheme.textSecondary,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF4F46E5),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Checkbox & Forgot Password Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: Checkbox(
                                            value: _keepLoggedIn,
                                            activeColor: const Color(0xFF4F46E5),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() => _keepLoggedIn = val);
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Keep me signed in',
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => context.push('/forgot_password'),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      foregroundColor: const Color(0xFF4F46E5),
                                    ),
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // Premium Animated Gradient Login Button
                              Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFF4F46E5),
                                      Color(0xFF3730A3),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.38),
                                      blurRadius: 18,
                                      offset: const Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Sign In',
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
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



