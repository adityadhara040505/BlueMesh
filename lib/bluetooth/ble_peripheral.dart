import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import 'gatt_definitions.dart';

/// Callback invoked when a remote Central client writes a packet to our TX GATT characteristic.
typedef OnPeripheralPacketReceived = void Function(Uint8List packet);

/// Manages the BLE Peripheral (GATT server) and BLE advertising lifecycle.
class BlePeripheralManager {
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  final int myDeviceId;
  final String myDisplayName;
  final OnPeripheralPacketReceived onPacketReceived;

  bool _isAdvertising = false;
  bool _isDisposed = false;
  Timer? _advertisingWatchdogTimer;

  bool get isAdvertising => _isAdvertising;

  BlePeripheralManager({
    required this.myDeviceId,
    required this.myDisplayName,
    required this.onPacketReceived,
  });

  static const MethodChannel _gattChannel = MethodChannel('com.bluemesh.app/gatt_server');

  /// Full 8-character hex suffix for advertised device name.
  String get fullHexId => myDeviceId.toRadixString(16).padLeft(8, '0');
  String get shortHexId => fullHexId;

  /// Initializes GATT Server and begins continuous advertising.
  Future<void> start() async {
    if (_isDisposed) return;

    try {
      final isSupported = await _blePeripheral.isSupported;
      if (!isSupported) {
        AppLogger.w('BLE Peripheral advertising is NOT supported on this hardware/platform.');
        return;
      }

      // Start native Android GATT Server to listen for Central writes and allow notifications
      if (!kIsWeb && Platform.isAndroid) {
        _gattChannel.setMethodCallHandler((call) async {
          if (call.method == 'onPacketReceived') {
            final args = call.arguments as Map<dynamic, dynamic>?;
            final packet = args?['packet'];
            if (packet is Uint8List) {
              onPacketReceived(packet);
            } else if (packet is List) {
              onPacketReceived(Uint8List.fromList(packet.cast<int>()));
            }
          }
        });
        await _gattChannel.invokeMethod('startServer');
        AppLogger.i('Native Android GATT Server started with TX & RX characteristics.');
      }

      final advertisedName = '${BleConstants.advertisedNamePrefix}$fullHexId';

      // 4-byte deviceId hash + 1-byte capability flag (dual-role = 0x01)
      final mfgData = Uint8List(5);
      ByteData.sublistView(mfgData)
        ..setUint32(0, myDeviceId, Endian.little)
        ..setUint8(4, 0x01);

      // Single compact advertisement packet (strictly <= 31-byte BLE legacy advertising limit):
      // - 128-bit Service UUID: 18 bytes
      // - Manufacturer Data (0xFFFF company ID + 5-byte payload): 9 bytes
      // - Flags: 3 bytes
      // Total: 30 bytes <= 31 byte limit!
      // Setting includeDeviceName: false avoids appending long OS device names which would cause ADVERTISE_FAILED_DATA_TOO_LARGE.
      final advertiseData = AdvertiseData(
        serviceUuid: GattDefinitions.serviceUuid,
        manufacturerId: 0xFFFF,
        manufacturerData: mfgData,
        includeDeviceName: false,
        localName: advertisedName,
      );

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeLowLatency,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        connectable: true,
        timeout: 0, // Continuous advertising
      );

      AppLogger.i('Starting BLE Peripheral advertising as "$advertisedName"...');
      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      _isAdvertising = true;

      // Start watchdog to monitor advertising status and auto-restart if dropped
      _startWatchdog();
    } catch (e, stack) {
      AppLogger.e('Failed to start BLE Peripheral advertising: $e', e, stack);
      _isAdvertising = false;
    }
  }

  /// Pushes a message payload to connected Centrals via RX characteristic notification.
  Future<void> notifyMessage(Uint8List fragment) async {
    if (!_isAdvertising) return;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _gattChannel.invokeMethod('notifyMessage', {'data': fragment});
      }
    } catch (e) {
      AppLogger.w('Peripheral notify error on RX characteristic: $e');
    }
  }

  /// Pushes a presence ping to connected Centrals via HEARTBEAT characteristic notification.
  Future<void> notifyHeartbeat(Uint8List heartbeatPacket) async {
    if (!_isAdvertising) return;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _gattChannel.invokeMethod('notifyHeartbeat', {'data': heartbeatPacket});
      }
    } catch (e) {
      AppLogger.w('Peripheral notify error on HEARTBEAT characteristic: $e');
    }
  }

  /// Stops advertising and releases resources.
  Future<void> stop() async {
    _advertisingWatchdogTimer?.cancel();
    try {
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _gattChannel.invokeMethod('stopServer');
        } catch (_) {}
      }
      if (_isAdvertising) {
        await _blePeripheral.stop();
        _isAdvertising = false;
        AppLogger.i('BLE Peripheral advertising stopped.');
      }
    } catch (e) {
      AppLogger.w('Error stopping BLE Peripheral: $e');
    }
  }

  /// Periodic watchdog to detect OS drops in advertising and auto-recover.
  void _startWatchdog() {
    _advertisingWatchdogTimer?.cancel();
    _advertisingWatchdogTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_isDisposed) return;
      try {
        final active = await _blePeripheral.isAdvertising;
        if (!active && _isAdvertising) {
          AppLogger.w('Advertising dropped unexpectedly! Auto-restarting peripheral...');
          await start();
        }
      } catch (e) {
        AppLogger.d('Advertising watchdog check error: $e');
      }
    });
  }

  void dispose() {
    _isDisposed = true;
    _advertisingWatchdogTimer?.cancel();
    stop();
  }
}
