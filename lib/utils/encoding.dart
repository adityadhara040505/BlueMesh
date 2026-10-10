import 'dart:convert';
import 'dart:typed_data';

/// Serialization and binary hashing helper utilities.
class ProtocolEncoding {
  ProtocolEncoding._();

  /// Calculates a 32-bit FNV-1a hash of a String (e.g. UUID).
  /// FNV parameters for 32-bit:
  /// Offset basis = 2166136261 (0x811C9DC5)
  /// Prime = 16777619 (0x01000193)
  static int hashUuid(String input) {
    int hash = 0x811C9DC5;
    final bytes = utf8.encode(input);
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Converts an integer to an 8-character hex string.
  static String toHex32(int value) {
    return value.toRadixString(16).padLeft(8, '0');
  }

  /// Converts a byte array to a hex string.
  static String bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Converts a hex string back to byte array.
  static Uint8List hexToBytes(String hex) {
    final clean = hex.replaceAll(' ', '').replaceAll(':', '');
    final result = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < clean.length; i += 2) {
      result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
