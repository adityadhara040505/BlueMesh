import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../core/logger.dart';
import 'notification_service.dart';

/// Service orchestrating background BLE execution on mobile platforms.
class AppBackgroundService {
  AppBackgroundService._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();

  /// Configures and starts the background execution service.
  static Future<void> initialize() async {
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      AppLogger.i('Desktop platform: Standard background execution active without foreground service daemon.');
      return;
    }

    try {
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: true,
          isForegroundMode: true,
          notificationChannelId: NotificationService.channelIdForeground,
          initialNotificationTitle: 'BlueMesh Mesh Active',
          initialNotificationContent: 'Bluetooth mesh node running in background...',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );

      await _service.startService();
      AppLogger.i('AppBackgroundService configured and started.');
    } catch (e, stack) {
      AppLogger.e('Failed to initialize AppBackgroundService: $e', e, stack);
    }
  }

  /// Updates the foreground notification text with active peer count.
  static void updatePeerCount(int peerCount) {
    if (kIsWeb || !Platform.isAndroid) return;
    _service.invoke('update_status', {
      'content': 'BlueMesh active — $peerCount peers in cluster',
    });
  }

  /// Android background isolate entrypoint.
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });

      service.on('update_status').listen((event) {
        final content = event?['content'] as String? ?? 'BlueMesh active';
        service.setForegroundNotificationInfo(
          title: 'BlueMesh Mesh Active',
          content: content,
        );
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  /// iOS background fetch entry point.
  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    DartPluginRegistrant.ensureInitialized();
    return true;
  }
}
