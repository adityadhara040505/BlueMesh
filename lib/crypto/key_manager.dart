import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/logger.dart';
import '../utils/encoding.dart';

/// Manages ECDH / X25519 key generation, secure hardware storage, and fingerprint derivation.
class KeyManager {
  static const String _privateKeyStorageKey = 'bluemesh_ecdh_priv_key';
  static const String _publicKeyStorageKey = 'bluemesh_ecdh_pub_key';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final KeyExchangeAlgorithm _keyExchange = X25519();
  final Sha256 _sha256 = Sha256();

  SimpleKeyPair? _keyPair;
  String? _cachedPublicKeyBase64;
  String? _cachedFingerprint;

  /// In-memory active keypair.
  SimpleKeyPair get keyPair => _keyPair!;

  /// Base64 encoded public key bytes.
  String get publicKeyBase64 => _cachedPublicKeyBase64 ?? '';

  /// 8-character hex fingerprint derived from SHA-256 of the public key.
  String get fingerprint => _cachedFingerprint ?? '00000000';

  /// Initializes or restores cryptographic identity from secure storage.
  Future<void> initialize() async {
    try {
      final savedPrivBase64 = await _secureStorage.read(key: _privateKeyStorageKey);
      final savedPubBase64 = await _secureStorage.read(key: _publicKeyStorageKey);

      if (savedPrivBase64 != null && savedPubBase64 != null) {
        final privBytes = base64Decode(savedPrivBase64);
        final pubBytes = base64Decode(savedPubBase64);

        final publicKey = SimplePublicKey(pubBytes, type: KeyPairType.x25519);
        _keyPair = SimpleKeyPairData(
          privBytes,
          publicKey: publicKey,
          type: KeyPairType.x25519,
        );
        _cachedPublicKeyBase64 = savedPubBase64;
        _cachedFingerprint = await _deriveFingerprint(pubBytes);

        AppLogger.i('Restored existing cryptographic identity with fingerprint: $_cachedFingerprint');
      } else {
        await generateNewIdentity();
      }
    } catch (e, stack) {
      AppLogger.w('Failed reading secure storage, regenerating keys: $e', e, stack);
      await generateNewIdentity();
    }
  }

  /// Generates a fresh keypair and saves it to secure storage.
  Future<void> generateNewIdentity() async {
    AppLogger.i('Generating new ECDH X25519 keypair identity...');
    final newPair = await _keyExchange.newKeyPair();
    final privData = await newPair.extract() as SimpleKeyPairData;
    final pubKey = await newPair.extractPublicKey() as SimplePublicKey;

    final privBase64 = base64Encode(privData.bytes);
    final pubBase64 = base64Encode(pubKey.bytes);

    try {
      await _secureStorage.write(key: _privateKeyStorageKey, value: privBase64);
      await _secureStorage.write(key: _publicKeyStorageKey, value: pubBase64);
    } catch (e) {
      AppLogger.w('Failed saving keypair to secure storage: $e');
    }

    _keyPair = privData;
    _cachedPublicKeyBase64 = pubBase64;
    _cachedFingerprint = await _deriveFingerprint(pubKey.bytes);

    AppLogger.i('Fresh cryptographic identity generated with fingerprint: $_cachedFingerprint');
  }

  /// Derives first 8 hex characters of SHA-256(publicKey).
  Future<String> _deriveFingerprint(List<int> pubBytes) async {
    final digest = await _sha256.hash(pubBytes);
    final hex = ProtocolEncoding.bytesToHex(Uint8List.fromList(digest.bytes));
    return hex.substring(0, 8).toUpperCase();
  }

  /// Derives fingerprint from an external peer's base64 public key for verification in UI.
  static Future<String> derivePeerFingerprint(String base64PublicKey) async {
    final pubBytes = base64Decode(base64PublicKey);
    final digest = await Sha256().hash(pubBytes);
    final hex = ProtocolEncoding.bytesToHex(Uint8List.fromList(digest.bytes));
    return hex.substring(0, 8).toUpperCase();
  }
}
