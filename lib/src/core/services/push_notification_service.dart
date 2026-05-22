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

void _logIosPushDebug(String message) {
  if (Platform.isIOS) {
    debugPrint('iOSPushDebug: $message');
  }
}

// Must be a top-level function. It runs in a separate isolate when app is terminated.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  _logIosPushDebug(
    'background message id=${message.messageId} notification=${message.notification != null} data=${message.data}',
  );
  if (message.notification == null) {
    await PushNotificationService.showBackgroundNotification(message);
  }
}

class PushNotificationService {
  PushNotificationService._();

  static const String _channelId = 'urbaneasyflats_manager_alerts';
  static const String _legacyChannelId = 'urbaneasyflats_main';
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
        playSound: true,
      );
  static const AndroidNotificationChannel _legacyAndroidChannel =
      AndroidNotificationChannel(
        _legacyChannelId,
        _channelName,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

  static void Function(String? payload)? _onNotificationTap;
  static bool _initialized = false;
  static bool _localNotificationsReady = false;
  static bool _backgroundHandlerRegistered = false;
  static bool _isSyncingToken = false;

  static void configureBackgroundHandler() {
    if (_backgroundHandlerRegistered) {
      return;
    }
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
    _backgroundHandlerRegistered = true;
  }

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
    if (!await _ensureFirebaseInitialized()) {
      return;
    }

    configureBackgroundHandler();

    await _setupLocalNotifications();
    await _requestPermission();
    await _configureIosForegroundPresentation();
    unawaited(_registerTokenWithRetry());

    FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      _logIosPushDebug('FCM token refreshed: $token');
      AuthService.registerPushToken(token, forceSync: true)
          .then((_) => _logIosPushDebug('refreshed FCM token sent to backend'))
          .catchError(
            (Object e) => _logIosPushDebug(
              'refreshed FCM token backend update failed: $e',
            ),
          );
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logIosPushDebug(
        'notification opened id=${message.messageId} data=${message.data}',
      );
      final String payload = PremiumNotificationContent.fromRemoteMessage(
        message,
      ).payload;
      _onNotificationTap?.call(payload);
    });

    final RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      _logIosPushDebug(
        'initial notification opened id=${initialMessage.messageId} data=${initialMessage.data}',
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        final String payload = PremiumNotificationContent.fromRemoteMessage(
          initialMessage,
        ).payload;
        _onNotificationTap?.call(payload);
      });
    }
    _initialized = true;
  }

  static Future<bool> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return true;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PushNotifications: Firebase initialization failed - $e');
      }
      return false;
    }
  }

  static Future<void> _setupLocalNotifications() async {
    if (_localNotificationsReady) return;
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
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
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_legacyAndroidChannel);
    _localNotificationsReady = true;
  }

  static Future<void> _requestPermission() async {
    final NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
    final bool? localPermission = await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    if (kDebugMode) {
      debugPrint(
        'PushNotifications: permission=${settings.authorizationStatus.name} localPermission=$localPermission',
      );
    }
    _logIosPushDebug(
      'permission=${settings.authorizationStatus.name} alert=${settings.alert.name} badge=${settings.badge.name} sound=${settings.sound.name}',
    );
  }

  static Future<void> _configureIosForegroundPresentation() async {
    if (!Platform.isIOS) {
      return;
    }
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    _logIosPushDebug(
      'foreground presentation enabled alert=true badge=true sound=true',
    );
  }

  static Future<void> _registerTokenWithRetry() async {
    const List<Duration> retryDelays = <Duration>[
      Duration.zero,
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 45),
    ];

    for (final Duration delay in retryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      final bool synced = await syncToken();
      if (synced) {
        return;
      }
    }
  }

  static Future<bool> syncToken() async {
    if (_isSyncingToken) {
      return false;
    }

    _isSyncingToken = true;
    try {
      await _waitForApnsTokenIfNeeded();
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _logIosPushDebug('FCM token: $token');
        await AuthService.registerPushToken(token, forceSync: true);
        _logIosPushDebug('FCM token sent to backend');
        if (kDebugMode) {
          debugPrint('PushNotifications: token registered');
        }
        return true;
      }
      if (kDebugMode) {
        debugPrint('PushNotifications: FCM token unavailable');
      }
      _logIosPushDebug('FCM token unavailable');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PushNotifications: token registration failed - $e');
      }
    } finally {
      _isSyncingToken = false;
    }

    return false;
  }

  static Future<void> _waitForApnsTokenIfNeeded() async {
    if (!Platform.isIOS) {
      return;
    }

    for (int attempt = 0; attempt < 6; attempt += 1) {
      final String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        _logIosPushDebug('APNs token: $apnsToken');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    if (kDebugMode) {
      debugPrint('PushNotifications: APNs token not ready yet');
    }
    _logIosPushDebug('APNs token not ready after wait');
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logIosPushDebug(
      'foreground notification received id=${message.messageId} notification=${message.notification != null} data=${message.data}',
    );
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
    _logIosPushDebug(
      'notification received/rendering type=${content.type} title=${content.title} body=${content.body}',
    );

    final String? bigPicturePath = await _downloadNotificationImage(
      content.imageUrl,
    );
    final AndroidBitmap<Object>? downloadedImage = bigPicturePath == null
        ? null
        : FilePathAndroidBitmap(bigPicturePath);
    final AndroidBitmap<Object> notificationIcon =
        downloadedImage ??
        const DrawableResourceAndroidBitmap(_notificationLogo);
    final StyleInformation styleInformation = content.usesCompactImage
        ? BigTextStyleInformation(
            content.body,
            contentTitle: content.title,
            summaryText: content.body,
          )
        : BigPictureStyleInformation(
            notificationIcon,
            largeIcon: const DrawableResourceAndroidBitmap(_notificationLogo),
            contentTitle: content.title,
            summaryText: content.body,
            hideExpandedLargeIcon: false,
          );

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
          largeIcon: notificationIcon,
          styleInformation: styleInformation,
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
      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint(
            'PushNotifications: image failed status=${response.statusCode}',
          );
        }
        return null;
      }
      if (response.bodyBytes.length > 5 * 1024 * 1024) {
        if (kDebugMode) {
          debugPrint(
            'PushNotifications: image skipped because it is too large',
          );
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
