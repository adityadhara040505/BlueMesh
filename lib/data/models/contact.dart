/// Represents a peer node contact in the BlueMesh cluster.
class Contact {
  final int deviceId;
  final String name;
  final String publicKey; // Base64 encoded ECDH / ECDSA public key
  final String fingerprint; // First 8 hex characters of SHA-256(publicKey)
  DateTime lastSeen;
  bool isOnline;
  int batteryLevel;
  int hopCount;
  bool isVerified; // User manually verified fingerprint

  Contact({
    required this.deviceId,
    required this.name,
    required this.publicKey,
    required this.fingerprint,
    required this.lastSeen,
    this.isOnline = true,
    this.batteryLevel = 100,
    this.hopCount = 1,
    this.isVerified = false,
  });

  /// Hex representation of deviceId (e.g. 0xA1B2C3D4 -> "a1b2c3d4").
  String get deviceHex => deviceId.toRadixString(16).padLeft(8, '0');

  Contact copyWith({
    int? deviceId,
    String? name,
    String? publicKey,
    String? fingerprint,
    DateTime? lastSeen,
    bool? isOnline,
    int? batteryLevel,
    int? hopCount,
    bool? isVerified,
  }) {
    return Contact(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      publicKey: publicKey ?? this.publicKey,
      fingerprint: fingerprint ?? this.fingerprint,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      hopCount: hopCount ?? this.hopCount,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'name': name,
      'publicKey': publicKey,
      'fingerprint': fingerprint,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'isOnline': isOnline,
      'batteryLevel': batteryLevel,
      'hopCount': hopCount,
      'isVerified': isVerified,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      deviceId: map['deviceId'] as int,
      name: map['name'] as String,
      publicKey: map['publicKey'] as String,
      fingerprint: map['fingerprint'] as String,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] as int),
      isOnline: map['isOnline'] as bool? ?? false,
      batteryLevel: map['batteryLevel'] as int? ?? 100,
      hopCount: map['hopCount'] as int? ?? 1,
      isVerified: map['isVerified'] as bool? ?? false,
    );
  }
}
