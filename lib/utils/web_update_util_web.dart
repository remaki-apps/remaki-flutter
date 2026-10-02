// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Web implementation using dart:js_util and dart:html
import 'dart:js_util' as js_util;
import 'dart:html' as html;

void triggerWebCacheClearAndReloadImpl() {
  try {
    js_util.callMethod(html.window, 'clearRemakiCache', []);
  } catch (_) {
    html.window.location.reload();
  }
}
