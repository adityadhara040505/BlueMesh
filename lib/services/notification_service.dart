import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/logger.dart';

/// Manages local system notifications for foreground mesh status and incoming messages.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String channelIdForeground = 'bluemesh_foreground_channel';
  static const String channelNameForeground = 'BlueMesh Background Service';
  static const String channelIdMessages = 'bluemesh_messages_channel';
  static const String channelNameMessages = 'BlueMesh Messages';

  /// Initializes notification plugin and sets up platform notification channels.
  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open BlueMesh',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notifications.initialize(initSettings);

      // Create Android Notification Channels
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelIdForeground,
            channelNameForeground,
            description: 'Maintains active BLE mesh routing when app is minimized',
            importance: Importance.low,
          ),
        );

        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelIdMessages,
            channelNameMessages,
            description: 'Alerts for incoming mesh chat messages',
            importance: Importance.high,
            sound: RawResourceAndroidNotificationSound('notification'),
          ),
        );
      }

      _initialized = true;
      AppLogger.i('NotificationService initialized successfully.');
    } catch (e, stack) {
      AppLogger.e('Failed to initialize NotificationService: $e', e, stack);
    }
  }

  /// Displays an alert when an incoming message is received.
  static Future<void> showMessageNotification({
    required int id,
    required String senderName,
    required String messageText,
  }) async {
    if (!_initialized || kIsWeb) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        channelIdMessages,
        channelNameMessages,
        channelDescription: 'Alerts for incoming mesh chat messages',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'New BlueMesh message',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

      await _notifications.show(
        id,
        senderName,
        messageText,
        details,
      );
    } catch (e) {
      AppLogger.w('Failed to show message notification: $e');
    }
  }
}
