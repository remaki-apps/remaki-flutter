// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
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
