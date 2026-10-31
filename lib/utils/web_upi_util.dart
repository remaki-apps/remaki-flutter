import 'package:flutter/foundation.dart';
import 'web_upi_util_stub.dart'
    if (dart.library.html) 'web_upi_util_web.dart' as impl;

class WebUpiUtil {
  /// Directly triggers UPI custom scheme / universal link in web browsers
  /// (e.g. iOS Safari, Chrome on iOS) just like Flipkart and Redbus,
  /// bypassing canLaunchUrl checks which fail on Web.
  static void launchUpi(String upiUrl) {
    if (kIsWeb) {
      impl.launchUpiWebImpl(upiUrl);
    }
  }
}
