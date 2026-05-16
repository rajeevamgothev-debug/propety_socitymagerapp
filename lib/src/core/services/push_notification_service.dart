import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../firebase_options.dart';
import '../api/auth_service.dart';
import 'premium_notification_renderer.dart';

// Must be a top-level function. It runs in a separate isolate when app is terminated.
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
  static const String _notificationLogo = 'notification_logo';

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final Map<String, int> _groupCounts = <String, int>{};

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

  /// Call once from app.dart after Firebase.initializeApp() succeeds.
  /// [onNotificationTap] is called when the user taps any notification.
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
        if (kDebugMode) {
          debugPrint(
            'PushNotifications: clicked action=${response.actionId} payload=${response.payload != null}',
          );
        }
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
    if (_isSyncingToken) {
      return false;
    }

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
    if (normalizedToken.isEmpty) {
      return;
    }

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
    if (kDebugMode) {
      debugPrint(
        'PushNotifications: received type=${content.type} group=${content.groupId} image=${content.imageUrl.isNotEmpty}',
      );
    }

    final String? bigPicturePath =
        await _downloadNotificationImage(content.imageUrl);
    final AndroidBitmap<Object> bigPicture = bigPicturePath == null
        ? const DrawableResourceAndroidBitmap(_notificationLogo)
        : FilePathAndroidBitmap(bigPicturePath);

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
          largeIcon: const DrawableResourceAndroidBitmap(_notificationLogo),
          styleInformation: BigPictureStyleInformation(
            bigPicture,
            largeIcon: const DrawableResourceAndroidBitmap(_notificationLogo),
            contentTitle: content.title,
            summaryText: content.body,
            hideExpandedLargeIcon: false,
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
    await _showGroupSummary(content);
    if (kDebugMode) {
      debugPrint('PushNotifications: rendered type=${content.type}');
    }
  }

  static Future<void> _showGroupSummary(
    PremiumNotificationContent content,
  ) async {
    final int count = (_groupCounts[content.groupId] ?? 0) + 1;
    _groupCounts[content.groupId] = count;
    if (count < 2) return;

    await _localNotifications.show(
      content.groupId.hashCode,
      _summaryTitle(content.category, count),
      _summaryBody(content.category),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          groupKey: content.groupId,
          setAsGroupSummary: true,
          largeIcon: const DrawableResourceAndroidBitmap(_notificationLogo),
          styleInformation: InboxStyleInformation(
            <String>[content.body],
            contentTitle: _summaryTitle(content.category, count),
            summaryText: _summaryBody(content.category),
          ),
          playSound: false,
        ),
      ),
      payload: content.payload,
    );
  }

  static String _summaryTitle(String category, int count) {
    final String label = switch (category) {
      'bookings' => 'booking updates',
      'payments' => 'payment updates',
      'tickets' => 'ticket updates',
      'announcements' => 'notices',
      'enquiries' => 'property enquiries',
      _ => 'updates',
    };
    return '$count new $label';
  }

  static String _summaryBody(String category) {
    return switch (category) {
      'bookings' => 'Open bookings to review the latest activity.',
      'payments' => 'Open payments for bills and receipts.',
      'tickets' => 'Open support to continue the conversation.',
      'announcements' => 'Open notices for full details.',
      'enquiries' => 'Open enquiries to respond faster.',
      _ => 'Open UrbanEasyFlats for details.',
    };
  }

  static Future<String?> _downloadNotificationImage(String imageUrl) async {
    final Uri? uri = Uri.tryParse(imageUrl.trim());
    if (uri == null || !uri.hasScheme) return null;
    try {
      final http.Response response = await http.get(uri).timeout(
            const Duration(seconds: 4),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint('PushNotifications: image failed status=${response.statusCode}');
        }
        return null;
      }
      if (response.bodyBytes.length > 5 * 1024 * 1024) {
        if (kDebugMode) {
          debugPrint('PushNotifications: image skipped because it is too large');
        }
        return null;
      }
      final Directory directory = await getTemporaryDirectory();
      final File file = File(
        '${directory.path}/notification_${uri.pathSegments.isEmpty ? uri.hashCode : uri.pathSegments.last.hashCode}.jpg',
      );
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file.path;
    } catch (_) {
      if (kDebugMode) {
        debugPrint('PushNotifications: image download failed');
      }
      return null;
    }
  }
}
