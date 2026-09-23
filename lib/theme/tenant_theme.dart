import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ultra-cool market-standard design system for the Tenant portal.
/// Light Glassmorphism (Apple Glass / Frosted Translucent White) design system
/// featuring a luminous light canvas, translucent frosted glass cards,
/// pastel squircle action tiles, specular borders, and soft multi-layered float shadows.
class TenantTheme {
  // Brand Colors - Royal Indigo & Electric Violet Palette
  static const Color primary = Color(0xFF4F46E5); // Electric Indigo
  static const Color primaryDark = Color(0xFF3730A3); // Deep Indigo
  static const Color primaryDeep = Color(0xFF1E1B4B); // Midnight Indigo
  static const Color primaryLight = Color(0xFF6366F1); // Luminous Violet
  static const Color primarySoft = Color(0xFFEEF2FF); // Soft Pastel Indigo
  static const Color primaryBorder = Color(0xFFC7D2FE); // Soft Indigo Border

  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color accentSoft = Color(0xFFE0F2FE); // Soft Cyan

  // Hero Card Gradients
  static const List<Color> heroGradient = [
    Color(0xFF312E81), // Deep Royal Indigo
    Color(0xFF4338CA), // Electric Iris
    Color(0xFF6366F1), // Glowing Violet
  ];

  static const List<Color> cardGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFF8FAFC),
  ];

  static const List<Color> subtleCardGradient = [
    Color(0xCCFFFFFF),
    Color(0xB3FFFFFF),
  ];

  // Clean Modern Solid Card Surfaces
  static const Color background = Color(0xFFF8FAFC); // Clean light modern canvas
  static const Color surface = Color(0xFFFFFFFF); // Pure white surface
  static const Color glassFill = Color(0xFFFFFFFF); // Solid white card surface
  static const Color glassBorder = Color(0xFFE2E8F0); // Clean subtle card border
  static const Color glassBorderBright = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFF1F5F9); // Light divider
  static const Color borderMedium = Color(0xFFE2E8F0); // Subtle card outline
  static const Color borderDark = Color(0xFFCBD5E1);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Deep Slate / Navy
  static const Color textSecondary = Color(0xFF475569); // Refined Slate
  static const Color textMuted = Color(0xFF94A3B8); // Muted helper Slate

  // Status & Badges
  static const Color success = Color(0xFF16A34A); // Emerald Green
  static const Color successBg = Color(0xFFDCFCE7); // Pastel Emerald Pill
  static const Color successBorder = Color(0xFF86EFAC);

  static const Color danger = Color(0xFFDC2626); // Coral Red
  static const Color dangerBg = Color(0xFFFEE2E2); // Pastel Coral Pill
  static const Color dangerBorder = Color(0xFFFCA5A5);

  static const Color warning = Color(0xFFD97706); // Amber
  static const Color warningBg = Color(0xFFFEF3C7); // Pastel Amber Pill
  static const Color warningBorder = Color(0xFFFDE68A);

  static const Color info = Color(0xFF0284C7); // Sky Blue
  static const Color infoBg = Color(0xFFE0F2FE); // Pastel Sky Pill
  static const Color infoBorder = Color(0xFFBAE6FD);

  // Quick Action Tile Palettes (Pastel Squircles)
  static const Color actionStayBg = Color(0xFFEDE9FE);
  static const Color actionStayIcon = Color(0xFF7C3AED);

  static const Color actionPayRentBg = Color(0xFFD1FAE5);
  static const Color actionPayRentIcon = Color(0xFF059669);

  static const Color actionNoticesBg = Color(0xFFE0F2FE);
  static const Color actionNoticesIcon = Color(0xFF0284C7);

  static const Color actionProfileBg = Color(0xFFFEF3C7);
  static const Color actionProfileIcon = Color(0xFFD97706);

  static const Color actionComplaintsBg = Color(0xFFFFE4E6);
  static const Color actionComplaintsIcon = Color(0xFFE11D48);

  static const Color actionFoodMenuBg = Color(0xFFDCFCE7);
  static const Color actionFoodMenuIcon = Color(0xFF16A34A);

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
      color: Color(0x204F46E5),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> heroShadow = [
    BoxShadow(
      color: Color(0x354338CA),
      blurRadius: 24,
      offset: Offset(0, 10),
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
