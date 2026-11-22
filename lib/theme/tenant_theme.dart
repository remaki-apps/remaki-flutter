import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system for the Tenant portal.
/// Palette: Sage (#9CAF88), Off-White (#F7F5EF), Tomato Red (#E3412C).
/// Clean, warm, modern aesthetic with no purple or blue.
class TenantTheme {
  // Brand Colors - Sage (#9CAF88) Palette
  static const Color primary = Color(0xFF9CAF88); // Sage
  static const Color primaryDark = Color(0xFF7A8D67); // Deep Sage
  static const Color primaryDeep = Color(0xFF38442E); // Deep Forest Olive
  static const Color primaryLight = Color(0xFFAEC09C); // Luminous Sage
  static const Color primarySoft = Color(0xFFEFF3EB); // Soft Pastel Sage
  static const Color primaryBorder = Color(0xFFC7D7BE); // Soft Sage Border

  static const Color accent = Color(0xFF7D906A); // Warm Sage Accent
  static const Color accentSoft = Color(0xFFEEF3EA); // Soft Sage Tint

  // Hero Card Gradients
  static const List<Color> heroGradient = [
    Color(0xFF5B6E4A), // Rich Deep Sage
    Color(0xFF758A63), // Medium Olive Sage
    Color(0xFF9CAF88), // Sage
  ];

  static const List<Color> cardGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFF7F5EF), // Off-White
  ];

  static const List<Color> subtleCardGradient = [
    Color(0xCCFFFFFF),
    Color(0xB3F7F5EF),
  ];

  // Clean Modern Solid Card Surfaces
  static const Color background = Color(0xFFF7F5EF); // Off-White (#F7F5EF)
  static const Color surface = Color(0xFFFFFFFF); // Pure white surface
  static const Color glassFill = Color(0xFFFFFFFF); // Solid white card surface
  static const Color glassBorder = Color(0xFFE5E2D9); // Clean subtle warm border
  static const Color glassBorderBright = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFEFECE4); // Light warm divider
  static const Color borderMedium = Color(0xFFE5E2D9); // Subtle card outline
  static const Color borderDark = Color(0xFFCAC5B7);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F241C); // Deep Forest Charcoal
  static const Color textSecondary = Color(0xFF4A5243); // Refined Earth Slate
  static const Color textMuted = Color(0xFF889180); // Muted helper Slate

  // Status & Badges
  static const Color success = Color(0xFF16A34A); // Emerald Green
  static const Color successBg = Color(0xFFDCFCE7); // Pastel Emerald Pill
  static const Color successBorder = Color(0xFF86EFAC);

  static const Color danger = Color(0xFFE3412C); // Tomato Red (#E3412C)
  static const Color dangerBg = Color(0xFFFDE8E5); // Pastel Tomato Red Pill
  static const Color dangerBorder = Color(0xFFF8B5AC); // Pastel Tomato Red Border

  static const Color warning = Color(0xFFD97706); // Amber
  static const Color warningBg = Color(0xFFFEF3C7); // Pastel Amber Pill
  static const Color warningBorder = Color(0xFFFDE68A);

  static const Color info = Color(0xFF9CAF88); // Sage (replaces Sky Blue)
  static const Color infoBg = Color(0xFFEFF3EB); // Soft Sage Pill
  static const Color infoBorder = Color(0xFFC7D7BE); // Soft Sage Border

  // Quick Action Tile Palettes (Pastel Squircles)
  static const Color actionStayBg = Color(0xFFEFF3EB); // Soft Sage (replaces purple)
  static const Color actionStayIcon = Color(0xFF6B7E58); // Olive Sage Icon (replaces purple)

  static const Color actionPayRentBg = Color(0xFFFDE8E5); // Soft Tomato Red
  static const Color actionPayRentIcon = Color(0xFFE3412C); // Tomato Red (#E3412C)

  static const Color actionNoticesBg = Color(0xFFEFF3EB); // Soft Sage (replaces blue)
  static const Color actionNoticesIcon = Color(0xFF758A63); // Olive Sage Icon (replaces blue)

  static const Color actionProfileBg = Color(0xFFFEF3C7);
  static const Color actionProfileIcon = Color(0xFFD97706);

  static const Color actionComplaintsBg = Color(0xFFFDE8E5); // Soft Tomato Red
  static const Color actionComplaintsIcon = Color(0xFFE3412C); // Tomato Red (#E3412C)

  static const Color actionFoodMenuBg = Color(0xFFEFF3EB); // Soft Sage
  static const Color actionFoodMenuIcon = Color(0xFF6B7E58); // Sage

  // Float Micro-Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x050F172A),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> glowShadow = [
    BoxShadow(
      color: Color(0x209CAF88),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> heroShadow = [
    BoxShadow(
      color: Color(0x355B6E4A),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  // Typography Tokens with GoogleFonts Lato
  static TextStyle heading({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w800,
    Color color = textPrimary,
    double letterSpacing = -0.5,
  }) {
    return GoogleFonts.lato(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle title({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double letterSpacing = -0.3,
  }) {
    return GoogleFonts.lato(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = textSecondary,
    double? height,
  }) {
    return GoogleFonts.lato(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle caption({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color color = textMuted,
  }) {
    return GoogleFonts.lato(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// Complete ThemeData tailored for the Tenant portal, dialogs, and popups.
  /// Enforces Sage (#9CAF88), Off-White (#F7F5EF), and Tomato Red (#E3412C)
  /// with zero purple or blue.
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.lato().fontFamily,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        primaryContainer: primarySoft,
        secondary: primaryDark,
        surface: surface,
        onSurface: textPrimary,
        error: danger,
        onError: Colors.white,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        headerBackgroundColor: primary,
        headerForegroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
