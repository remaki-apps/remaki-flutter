import 'package:intl/intl.dart';

/// Centralized Date and Time formatting utility for Remaki.
/// Ensures all timestamps (from API, Database, or UTC ISO-8601 strings)
/// are reliably converted to the user's local timezone (IST, UTC+05:30)
/// before display.
class AppDateUtils {
  /// Converts any dynamic date value (DateTime, String, or timestamp)
  /// into a local DateTime.
  static DateTime toLocalDateTime(dynamic dateVal) {
    if (dateVal == null) return DateTime.now();
    if (dateVal is DateTime) {
      return dateVal.isUtc ? dateVal.toLocal() : dateVal;
    }

    final str = dateVal.toString().trim();
    if (str.isEmpty || str == '-' || str == 'Not Provided') {
      return DateTime.now();
    }

    try {
      final parsed = DateTime.parse(str);
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      // Handle slash or dash formatted date strings (e.g. dd/MM/yyyy or dd-MM-yyyy)
      try {
        if (str.contains('/')) {
          final parts = str.split('/');
          if (parts.length == 3) {
            return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        } else if (str.contains('-')) {
          final parts = str.split('-');
          if (parts.length == 3 && parts[0].length <= 2) {
            return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      } catch (_) {}
      return DateTime.now();
    }
  }

  /// Formats date for display: "dd MMM yyyy" (e.g., 30 Sep 2026)
  static String formatDate(dynamic dateVal, {String defaultVal = '-'}) {
    if (dateVal == null || dateVal.toString().trim().isEmpty) return defaultVal;
    final str = dateVal.toString().trim();
    if (str == '-' || str == 'Not Provided') return str;

    try {
      final dt = toLocalDateTime(dateVal);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return str;
    }
  }

  /// Formats date and time: "dd MMM yyyy, hh:mm a" (e.g., 30 Sep 2026, 09:30 PM)
  /// If time is 00:00:00 (pure date), omits time portion and returns "dd MMM yyyy".
  static String formatDateTime(dynamic dateVal, {String defaultVal = '-'}) {
    if (dateVal == null || dateVal.toString().trim().isEmpty) return defaultVal;
    final str = dateVal.toString().trim();
    if (str == '-' || str == 'Not Provided') return str;

    try {
      final dt = toLocalDateTime(dateVal);
      if (dt.hour == 0 && dt.minute == 0 && dt.second == 0) {
        return DateFormat('dd MMM yyyy').format(dt);
      }
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return str;
    }
  }

  /// Formats for compact/card payment displays: "dd MMM, hh:mm a" (e.g., 30 Sep, 09:30 PM)
  static String formatShortDateTime(dynamic dateVal, {String defaultVal = '-'}) {
    if (dateVal == null || dateVal.toString().trim().isEmpty) return defaultVal;
    final str = dateVal.toString().trim();
    if (str == '-' || str == 'Not Provided') return str;

    try {
      final dt = toLocalDateTime(dateVal);
      if (dt.hour == 0 && dt.minute == 0 && dt.second == 0) {
        return DateFormat('dd MMM yyyy').format(dt);
      }
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return str;
    }
  }
}
