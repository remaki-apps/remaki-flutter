import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ultra-cool market-standard design system for the Tenant portal.
/// Inspired by top co-living & fintech apps (Stanza Living, Zolo, CRED, Revolut)
/// featuring a modern Royal Indigo / Electric Violet palette, GoogleFonts typography,
/// pastel squircle action tiles, glassmorphism, and soft multi-layered shadows.
class TenantTheme {
  // Brand Colors - Royal Indigo & Electric Violet Palette
  static const Color primary = Color(0xFF5338ED); // Royal Iris / Indigo
  static const Color primaryDark = Color(0xFF3B25C7); // Deep Indigo
  static const Color primaryDeep = Color(0xFF221575); // Dark Navy Indigo
  static const Color primaryLight = Color(0xFF6F52FF); // Vibrant Violet
  static const Color primarySoft = Color(0xFFF3EFFF); // Soft Lavender Tint
  static const Color primaryBorder = Color(0xFFDDD3FE); // Subtle Lavender Border

  static const Color accent = Color(0xFF6366F1); // Indigo Accent
  static const Color accentSoft = Color(0xFFEEF2FF); // Indigo Light Tint

  // Hero Card Gradients
  static const List<Color> heroGradient = [
    Color(0xFF4528E8), // Deep Electric Indigo
    Color(0xFF5538EE), // Vibrant Royal Iris
    Color(0xFF6F52FF), // Radiant Violet
  ];

  static const List<Color> cardGradient = [
    Color(0xFF5338ED),
    Color(0xFF6F52FF),
  ];

  static const List<Color> subtleCardGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFF9FAFD),
  ];

  // Neutrals & Surfaces
  static const Color background = Color(0xFFF6F7FC); // Modern cool-tinted background
  static const Color surface = Colors.white;
  static const Color borderLight = Color(0xFFEFF0F8); // Crisp card border
  static const Color borderMedium = Color(0xFFE2E4F0);
  static const Color borderDark = Color(0xFFCAD0E2);

  // Text Colors
  static const Color textPrimary = Color(0xFF1E202B); // High-contrast Charcoal
  static const Color textSecondary = Color(0xFF6A6D88); // Modern Slate Gray
  static const Color textMuted = Color(0xFF9EA2BD); // Muted helper text

  // Status & Badges
  static const Color success = Color(0xFF00B074); // Modern Mint Green
  static const Color successBg = Color(0xFFE8F8F0); // Pastel Mint Pill
  static const Color successBorder = Color(0xFFA5F0D2);

  static const Color danger = Color(0xFFEE4444); // Coral Red
  static const Color dangerBg = Color(0xFFFFF0F0); // Pastel Red Pill
  static const Color dangerBorder = Color(0xFFFFCCCC);

  static const Color warning = Color(0xFFFF9500); // Amber Orange
  static const Color warningBg = Color(0xFFFFF7E8); // Pastel Amber Pill
  static const Color warningBorder = Color(0xFFFFE3B3);

  static const Color info = Color(0xFF2F80ED); // Modern Blue
  static const Color infoBg = Color(0xFFEDF5FF); // Pastel Blue
  static const Color infoBorder = Color(0xFFBFDBFE);

  // Quick Action Tile Palettes (Mockup Match)
  static const Color actionComplaintsBg = Color(0xFFFFF3EB);
  static const Color actionComplaintsIcon = Color(0xFFFF6D3B);

  static const Color actionPayRentBg = Color(0xFFE8F8F0);
  static const Color actionPayRentIcon = Color(0xFF00B074);

  static const Color actionFoodMenuBg = Color(0xFFEDF4FF);
  static const Color actionFoodMenuIcon = Color(0xFF2F80ED);

  static const Color actionStayBg = Color(0xFFF2EEFF);
  static const Color actionStayIcon = Color(0xFF7245FA);

  // Ultra-Cool Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A1E202B),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x041E202B),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> glowShadow = [
    BoxShadow(
      color: Color(0x355338ED),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> heroShadow = [
    BoxShadow(
      color: Color(0x404528E8),
      blurRadius: 26,
      offset: Offset(0, 12),
    ),
  ];

  // Typography Tokens with GoogleFonts Plus Jakarta Sans
  static TextStyle heading({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w800,
    Color color = textPrimary,
    double letterSpacing = -0.5,
  }) {
    return GoogleFonts.plusJakartaSans(
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
    return GoogleFonts.plusJakartaSans(
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
    return GoogleFonts.plusJakartaSans(
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
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}
