import 'dart:typed_data';

void launchUpiWebImpl(String upiUrl) {
  // No-op on non-web platforms (mobile uses url_launcher)
}

void downloadBytesWebImpl(Uint8List bytes, String filename) {
  // No-op on non-web platforms
}
