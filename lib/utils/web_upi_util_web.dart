// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'dart:js_util' as js_util;
import 'dart:html' as html;

void launchUpiWebImpl(String upiUrl) {
  try {
    js_util.callMethod(html.window, 'remakiTriggerUpi', [upiUrl]);
  } catch (_) {
    try {
      final anchor = html.AnchorElement(href: upiUrl)
        ..target = '_self'
        ..rel = 'noopener';
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
    } catch (_) {
      html.window.location.href = upiUrl;
    }
  }
}

void downloadBytesWebImpl(Uint8List bytes, String filename) {
  try {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  } catch (_) {}
}
