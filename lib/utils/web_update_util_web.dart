// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Web implementation using dart:js_util and dart:html
import 'dart:js_util' as js_util;
import 'dart:html' as html;

void triggerWebCacheClearAndReloadImpl() {
  try {
    if (js_util.hasProperty(html.window, 'clearRemakiCache')) {
      js_util.callMethod(html.window, 'clearRemakiCache', []);
      return;
    }
  } catch (_) {}

  try {
    html.window.location.href = '${html.window.location.origin}${html.window.location.pathname}?_t=${DateTime.now().millisecondsSinceEpoch}';
  } catch (_) {
    html.window.location.reload();
  }
}
