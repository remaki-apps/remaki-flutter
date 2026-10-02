import 'package:flutter/foundation.dart';
import 'web_update_util_stub.dart'
    if (dart.library.html) 'web_update_util_web.dart' as impl;

class WebUpdateUtil {
  /// Clears Remaki Service Worker, purges browser CacheStorage,
  /// and executes a hard reload to load the freshest UI on web.
  static void refreshAndClearCache() {
    if (kIsWeb) {
      impl.triggerWebCacheClearAndReloadImpl();
    }
  }
}
