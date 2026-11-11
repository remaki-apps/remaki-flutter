/// Utility to clean and format phone numbers for WhatsApp API (wa.me) and telecom usage.
class PhoneUtils {
  /// Formats any Indian or international phone number into a valid WhatsApp format (E.164 without '+').
  ///
  /// Special handling for 10-digit Indian numbers starting with '91':
  /// Previously, a 10-digit number like '9187654321' was incorrectly treated as already containing
  /// the +91 country code, leading WhatsApp to parse '91' as country code and only the remaining 8 digits
  /// as the mobile number, failing with "no number available" / "invalid number".
  static String formatForWhatsApp(String? rawPhone) {
    if (rawPhone == null) return '';

    // Remove all non-numeric characters (+, -, spaces, parentheses, etc.)
    String digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    // Handle leading international exit codes: '00' (e.g. '0091...')
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    // Handle leading single trunk zero (e.g. '09187654321' or '09876543210')
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // Standard 10-digit mobile number in India:
    // Any 10-digit number must have country code '91' prepended.
    // Even if it starts with '91' (e.g., 9187654321 -> 919187654321).
    if (digits.length == 10) {
      return '91$digits';
    }

    // 12-digit number starting with 91 is already an Indian mobile with country code
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits;
    }

    // Otherwise return digits as-is
    return digits;
  }
}

