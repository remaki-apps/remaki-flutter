// Stub implementation for non-web platforms (Android, iOS)
import 'dart:async';

void showWebNotificationImpl(String title, String body, String route, [String? tag]) {}

/// On non-web platforms there is no concept of a web FCM token.
Future<String?> getWebFcmToken(String vapidKey) async => null;
