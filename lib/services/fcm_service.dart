import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Function(String route)? _onNavigate;
  String? _lastToken;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'remaki_alerts',
    'Remaki Alerts',
    description: 'Notifications for rent reminders, dues, bills, and complaints',
    importance: Importance.max,
    playSound: true,
  );

  Future<void> init({Function(String route)? onNavigate}) async {
    _onNavigate = onNavigate;

    try {
      // 1. Request runtime notification permissions (Android 13+ & Web)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] User declined notification permissions.');
        return;
      }

      // 2. Setup Android local notifications channel for foreground alerts
      if (!kIsWeb) {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            final payload = response.payload;
            if (payload != null && payload.isNotEmpty) {
              try {
                final map = jsonDecode(payload) as Map<String, dynamic>;
                final route = map['route'] as String?;
                if (route != null && route.isNotEmpty) {
                  _onNavigate?.call(route);
                }
              } catch (_) {}
            }
          },
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
      }

      // 3. Obtain initial FCM token and synchronize with backend
      await syncTokenWithBackend();

      // Listen for token refresh events
      _messaging.onTokenRefresh.listen((newToken) {
        _lastToken = newToken;
        if (ApiService.isLoggedIn) {
          ApiService.registerDeviceToken(newToken, kIsWeb ? 'WEB' : 'ANDROID');
        }
      });

      // 4. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final data = message.data;

        if (notification != null && !kIsWeb) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
            payload: jsonEncode(data),
          );
        }
      });

      // 5. Handle Background to Foreground transition on notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final route = message.data['route'] as String?;
        if (route != null && route.isNotEmpty) {
          _onNavigate?.call(route);
        }
      });

      // 6. Handle App Cold Start from Terminated State
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        final route = initialMessage.data['route'] as String?;
        if (route != null && route.isNotEmpty) {
          // Delay briefly to allow router & splash to finish mounting
          Future.delayed(const Duration(milliseconds: 700), () {
            _onNavigate?.call(route);
          });
        }
      }
    } catch (e) {
      debugPrint('[FCM] Error initializing FCM service: $e');
    }
  }

  /// Synchronize the current device token with the backend if user is authenticated
  Future<void> syncTokenWithBackend() async {
    try {
      String? token;
      if (kIsWeb) {
        // Web requires VAPID key if configured, or default token
        token = await _messaging.getToken();
      } else {
        token = await _messaging.getToken();
      }

      if (token != null && token.isNotEmpty) {
        _lastToken = token;
        if (ApiService.isLoggedIn) {
          await ApiService.registerDeviceToken(token, kIsWeb ? 'WEB' : 'ANDROID');
        }
      }
    } catch (e) {
      debugPrint('[FCM] Failed to sync token: $e');
    }
  }

  /// Unregister device token upon user logout
  Future<void> unregisterOnLogout() async {
    try {
      if (_lastToken != null && _lastToken!.isNotEmpty) {
        await ApiService.unregisterDeviceToken(_lastToken!);
      }
    } catch (_) {}
  }
}
