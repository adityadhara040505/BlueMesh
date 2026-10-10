import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'logger.dart';

/// Platform capability detector to evaluate BLE Central and Peripheral features.
class PlatformCapabilities {
  PlatformCapabilities._();

  static bool? _isPeripheralSupportedCache;

  /// Whether the host operating system supports running as a BLE Central (GATT client).
  /// Supported across Android, iOS, Windows, macOS, and Linux.
  static bool get isCentralSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux;
  }

  /// Whether the host operating system and hardware can run as a BLE Peripheral (GATT server).
  /// macOS and Windows standard APIs do not reliably support custom GATT Peripheral advertising
  /// through cross-platform plugins, so they run in Central-Only mode.
  static Future<bool> isPeripheralSupported() async {
    if (_isPeripheralSupportedCache != null) {
      return _isPeripheralSupportedCache!;
    }

    if (kIsWeb) {
      _isPeripheralSupportedCache = false;
      return false;
    }

    // Windows, macOS, and Linux desktop run in Central-only mode
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      AppLogger.i('Platform is ${Platform.operatingSystem}: operating in Central-only mode.');
      _isPeripheralSupportedCache = false;
      return false;
    }

    // Android and iOS support full dual-role operation if hardware allows it
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final peripheral = FlutterBlePeripheral();
        final supported = await peripheral.isSupported;
        _isPeripheralSupportedCache = supported;
        AppLogger.i('Peripheral advertising hardware supported: $supported');
        return supported;
      } catch (e, stack) {
        AppLogger.w('Failed checking BLE peripheral capability, falling back to Central-only: $e', e, stack);
        _isPeripheralSupportedCache = false;
        return false;
      }
    }

    _isPeripheralSupportedCache = false;
    return false;
  }

  /// Human-readable description of current platform BLE capability mode.
  static Future<String> getModeDescription() async {
    final canPeripheral = await isPeripheralSupported();
    if (canPeripheral) {
      return 'Dual-Role Mesh Node (Central + Peripheral)';
    } else {
      return 'Central-Only Mesh Node (Scanner/Client)';
    }
  }
}
