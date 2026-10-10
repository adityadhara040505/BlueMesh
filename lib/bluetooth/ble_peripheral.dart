import 'dart:async';
import 'dart:typed_data';
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

      final advertisedName = '${BleConstants.advertisedNamePrefix}$fullHexId';

      // 4-byte deviceId hash + 1-byte capability flag (dual-role = 0x01)
      final mfgData = Uint8List(5);
      ByteData.sublistView(mfgData)
        ..setUint32(0, myDeviceId, Endian.little)
        ..setUint8(4, 0x01);

      // Primary advertisement packet: Service UUID only (18 bytes <= 31 byte BLE limit)
      final advertiseData = AdvertiseData(
        serviceUuid: GattDefinitions.serviceUuid,
      );

      // Scan response packet: Local Name + Manufacturer Data (22 bytes <= 31 byte BLE limit)
      final advertiseResponseData = AdvertiseData(
        localName: advertisedName,
        manufacturerId: 0xFFFF,
        manufacturerData: mfgData,
      );

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        connectable: true,
        timeout: 0, // Continuous advertising
      );

      AppLogger.i('Starting BLE Peripheral advertising as "$advertisedName"...');
      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseResponseData: advertiseResponseData,
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
      await _blePeripheral.sendData(fragment);
    } catch (e) {
      AppLogger.w('Peripheral notify error on RX characteristic: $e');
    }
  }

  /// Pushes a presence ping to connected Centrals via HEARTBEAT characteristic notification.
  Future<void> notifyHeartbeat(Uint8List heartbeatPacket) async {
    if (!_isAdvertising) return;
    try {
      await _blePeripheral.sendData(heartbeatPacket);
    } catch (e) {
      AppLogger.w('Peripheral notify error on HEARTBEAT characteristic: $e');
    }
  }

  /// Stops advertising and releases resources.
  Future<void> stop() async {
    _advertisingWatchdogTimer?.cancel();
    try {
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
