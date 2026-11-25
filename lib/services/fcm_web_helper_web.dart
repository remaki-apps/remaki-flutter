// Web implementation: uses dart:js_util + dart:html
// This file is loaded on Web only (conditional import in fcm_service.dart).
import 'dart:async';
import 'dart:js_util' as js_util;
import 'dart:html' as html;

/// Shows a native OS notification by routing through the active service worker
/// registration (prefers firebase-messaging-sw.js stored at window._fcmSwRegistration).
void showWebNotificationImpl(String title, String body, String route, [String? tag]) {
  try {
    js_util.callMethod(html.window, 'showWebNotification', [title, body, route, tag]);
  } catch (_) {}
}

/// Retrieves the FCM web token using the explicitly registered
/// firebase-messaging-sw.js ServiceWorkerRegistration stored at
/// window._fcmSwRegistration.  Returns null on any error.
Future<String?> getWebFcmToken(String vapidKey) async {
  try {
    // Wait up to 5 seconds for the SW registration promise to be set.
    final swReg = await _awaitSwRegistration();

    if (swReg == null) {
      // No explicit SW registration found — fall through to default getToken() without SW.
      return null;
    }

    // Call FirebaseMessaging.instance.getToken() via JS interop passing the SW registration.
    // The flutter firebase_messaging plugin exposes the underlying JS Firebase messaging
    // object at window._firebaseMessagingInstance (set in index.html after Firebase init).
    final messagingInstance = js_util.getProperty(html.window, '_firebaseMessagingInstance');
    if (messagingInstance == null) {
      return null;
    }

    final tokenPromise = js_util.callMethod(messagingInstance, 'getToken', [
      js_util.jsify({'vapidKey': vapidKey, 'serviceWorkerRegistration': swReg})
    ]);
    final token = await js_util.promiseToFuture<String?>(tokenPromise as Object);
    return token;
  } catch (e) {
    return null;
  }
}

/// Waits up to 5 seconds for window._fcmSwRegistration to be populated
/// (set in index.html after firebase-messaging-sw.js registers).
Future<Object?> _awaitSwRegistration() async {
  for (var i = 0; i < 50; i++) {
    final reg = js_util.getProperty(html.window, '_fcmSwRegistration');
    if (reg != null) return reg;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return null;
}
