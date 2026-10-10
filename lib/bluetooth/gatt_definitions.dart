import '../core/constants.dart';

/// GATT Service and Characteristic UUID declarations and properties for BlueMesh.
class GattDefinitions {
  GattDefinitions._();

  /// Primary 128-bit Mesh Service UUID
  static const String serviceUuid = BleConstants.serviceUuid;

  /// TX Characteristic: Central writes packets to Peripheral without response.
  /// Property: WriteWithoutResponse (Fast, no roundtrip ACK stall).
  static const String txCharUuid = BleConstants.txCharacteristicUuid;

  /// RX Characteristic: Peripheral pushes notifications to connected Centrals.
  /// Property: Notify.
  static const String rxCharUuid = BleConstants.rxCharacteristicUuid;

  /// CONTACT Characteristic: Peer discovery card exchange.
  /// Property: Read, Write.
  static const String contactCharUuid = BleConstants.contactCharacteristicUuid;

  /// HEARTBEAT Characteristic: Presence beacon emitted every 10 seconds.
  /// Property: Notify.
  static const String heartbeatCharUuid = BleConstants.heartbeatCharacteristicUuid;

  /// ROUTING Characteristic: Dynamic distance-vector routing table updates.
  /// Property: Read, Write.
  static const String routingCharUuid = BleConstants.routingCharacteristicUuid;
}
