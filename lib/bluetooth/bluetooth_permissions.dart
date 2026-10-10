import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/logger.dart';

/// Manages platform Bluetooth and runtime permissions.
class BluetoothPermissionsManager {
  BluetoothPermissionsManager._();

  /// Requests all necessary Bluetooth, Location (for Android <= 11), and Notification permissions.
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        // Android 12+ (API 31+) requires runtime Bluetooth permissions
        final scanStatus = await Permission.bluetoothScan.request();
        final advertiseStatus = await Permission.bluetoothAdvertise.request();
        final connectStatus = await Permission.bluetoothConnect.request();

        // Android <= 11 requires Location permission to discover BLE beacons
        final locationStatus = await Permission.locationWhenInUse.request();

        // Notifications for background mesh alerts
        await Permission.notification.request();

        final allGranted = (scanStatus.isGranted || scanStatus.isLimited) &&
            (advertiseStatus.isGranted || advertiseStatus.isLimited) &&
            (connectStatus.isGranted || connectStatus.isLimited);

        AppLogger.i('Android permissions requested: scan=$scanStatus, adv=$advertiseStatus, conn=$connectStatus, loc=$locationStatus');
        return allGranted || locationStatus.isGranted;
      }

      if (Platform.isIOS) {
        final bluetoothStatus = await Permission.bluetooth.request();
        await Permission.notification.request();
        AppLogger.i('iOS permissions requested: bluetooth=$bluetoothStatus');
        return bluetoothStatus.isGranted;
      }

      // macOS, Windows, Linux handle BLE permissions at the OS / driver level
      return true;
    } catch (e, stack) {
      AppLogger.e('Error requesting Bluetooth permissions: $e', e, stack);
      return false;
    }
  }

  /// Verifies whether Bluetooth hardware is powered on and ready.
  static Future<bool> isBluetoothPoweredOn() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      AppLogger.w('Failed to query Bluetooth adapter state: $e');
      return false;
    }
  }

  /// Stream of adapter power state changes (on/off).
  static Stream<BluetoothAdapterState> get adapterStateStream => FlutterBluePlus.adapterState;
}
