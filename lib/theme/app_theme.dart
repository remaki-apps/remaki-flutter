import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF5B32E4); // Vibrant Purple accent
  static const Color primaryDark = Color(0xFF131429); // Deep dark purple title text
  static const Color accentColor = Color(0xFFF0EAFF); // Soft lavender tint
  static const Color backgroundColor = Color(0xFFFAF9FE); // Light greyish lavender background
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF131429);
  static const Color textSecondary = Color(0xFF808191);
  
  static const Color success = Color(0xFF00B074); // Mint green
  static const Color successBg = Color(0xFFE8F8F0);
  
  static const Color danger = Color(0xFFE53935); // Crimson red
  static const Color dangerBg = Color(0xFFFFEAEA);

  static const Color brandOrange = Color(0xFFFF7A00); // Orange
  static const Color orangeBg = Color(0xFFFFF2E8);

  static const Color purpleBg = Color(0xFFF4EFFE);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF0F172A),
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        elevation: 10,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        headerBackgroundColor: primaryColor,
        headerForegroundColor: Colors.white,
        headerHeadlineStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headerHelpStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
        dayStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFF0F172A);
        }),
        todayBackgroundColor: WidgetStateProperty.all(const Color(0xFFEEF2FF)),
        todayForegroundColor: WidgetStateProperty.all(primaryColor),
        todayBorder: const BorderSide(color: primaryColor, width: 1.5),
        yearStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFF0F172A);
        }),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: const Color(0xFF64748B),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryDark),
        titleTextStyle: TextStyle(
          color: primaryDark,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
