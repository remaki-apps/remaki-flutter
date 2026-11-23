// Web implementation using dart:js_util and dart:html
import 'dart:js_util' as js_util;
import 'dart:html' as html;

void showWebNotificationImpl(String title, String body, String route) {
  try {
    js_util.callMethod(html.window, 'showWebNotification', [title, body, route]);
  } catch (_) {}
}
