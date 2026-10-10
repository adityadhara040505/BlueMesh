import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/logger.dart';

/// Centralized manager for Hive local key-value boxes.
class HiveBoxes {
  HiveBoxes._();

  static late Box<Map> contactsBox;
  static late Box<Map> chatsBox;
  static late Box<Map> messagesBox;
  static late Box<dynamic> settingsBox;
  static late Box<dynamic> dedupCacheBox;
  static late Box<Map> routingTableBox;

  static bool _initialized = false;

  /// Initializes Hive storage and opens all required persistent boxes.
  static Future<void> init() async {
    if (_initialized) return;

    try {
      if (kIsWeb) {
        await Hive.initFlutter();
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        final hiveDir = Directory('${appDir.path}/bluemesh_hive');
        if (!await hiveDir.exists()) {
          await hiveDir.create(recursive: true);
        }
        await Hive.initFlutter(hiveDir.path);
      }

      contactsBox = await Hive.openBox<Map>(HiveBoxKeys.contactsBox);
      chatsBox = await Hive.openBox<Map>(HiveBoxKeys.chatsBox);
      messagesBox = await Hive.openBox<Map>(HiveBoxKeys.messagesBox);
      settingsBox = await Hive.openBox<dynamic>(HiveBoxKeys.settingsBox);
      dedupCacheBox = await Hive.openBox<dynamic>(HiveBoxKeys.dedupCacheBox);
      routingTableBox = await Hive.openBox<Map>(HiveBoxKeys.routingTableBox);

      _initialized = true;
      AppLogger.i('HiveBoxes initialized successfully');
    } catch (e, stack) {
      AppLogger.e('Failed to initialize HiveBoxes: $e', e, stack);
      rethrow;
    }
  }

  /// Wipe all data (used in settings: "Clear data / reset identity").
  static Future<void> clearAll() async {
    await contactsBox.clear();
    await chatsBox.clear();
    await messagesBox.clear();
    await settingsBox.clear();
    await dedupCacheBox.clear();
    await routingTableBox.clear();
    AppLogger.i('All Hive boxes cleared.');
  }
}
