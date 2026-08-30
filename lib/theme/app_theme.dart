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
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
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
