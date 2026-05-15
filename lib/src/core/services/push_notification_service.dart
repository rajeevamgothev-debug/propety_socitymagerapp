import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../firebase_options.dart';
import '../api/auth_service.dart';
import 'premium_notification_renderer.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  if (message.notification == null) {
    await PushNotificationService.showBackgroundNotification(message);
  }
}

class PushNotificationService {
  PushNotificationService._();

  static const String _channelId = 'urbaneasyflats_main';
  static const String _channelName = 'UrbanEasyFlats Alerts';

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    _channelId,
    _channelName,
    importance: Importance.high,
    enableVibration: true,
  );

  static void Function(String? payload)? _onNotificationTap;
  static bool _initialized = false;
  static bool _isSyncingToken = false;

  static Future<void> initialize({
    void Function(String? payload)? onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap;
    if (_initialized) {
      unawaited(syncToken());
      return;
    }
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    await _setupLocalNotifications();
    await _requestPermission();
    await syncToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      unawaited(_syncTokenValue(token));
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final String payload =
          PremiumNotificationContent.fromRemoteMessage(message).payload;
      _onNotificationTap?.call(payload);
    });

    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        final String payload =
            PremiumNotificationContent.fromRemoteMessage(initialMessage).payload;
        _onNotificationTap?.call(payload);
      });
    }
  }

  static Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _onNotificationTap?.call(response.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _requestPermission() async {
    final NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint(
        'PushNotifications: permission=${settings.authorizationStatus.name}',
      );
    }
  }

  static Future<bool> syncToken() async {
    if (_isSyncingToken) return false;
    _isSyncingToken = true;
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _syncTokenValue(token);
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PushNotifications: token registration failed - $e');
      }
    } finally {
      _isSyncingToken = false;
    }
    return false;
  }

  static Future<void> _syncTokenValue(String token) async {
    final String normalizedToken = token.trim();
    if (normalizedToken.isEmpty) return;
    await AuthService.registerPushToken(normalizedToken);
    if (kDebugMode) {
      debugPrint('PushNotifications: token registered');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _showPremiumNotification(message);
  }

  static Future<void> showBackgroundNotification(RemoteMessage message) async {
    await _setupLocalNotifications();
    await _showPremiumNotification(message);
  }

  static Future<void> _showPremiumNotification(RemoteMessage message) async {
    final PremiumNotificationContent content =
        PremiumNotificationContent.fromRemoteMessage(message);
    if (content.title.trim().isEmpty && content.body.trim().isEmpty) return;

    await _localNotifications.show(
      content.stableId,
      content.title,
      content.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: content.androidImportance,
          priority: content.androidPriority,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            content.body,
            contentTitle: content.title,
          ),
          actions: content.actions,
          groupKey: content.groupId,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: content.payload,
    );
  }
}
