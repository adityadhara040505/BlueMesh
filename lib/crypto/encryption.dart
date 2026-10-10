import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../core/logger.dart';

/// End-to-end encryption provider using ECDH (X25519) shared secrets and AES-256-GCM.
class MeshEncryption {
  final KeyExchangeAlgorithm _keyExchange = X25519();
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // Cached symmetric keys: {peerPublicKeyBase64: SecretKey}
  final Map<String, SecretKey> _derivedKeyCache = {};

  /// Derives an AES-256 symmetric key from local private key and peer's public key using X25519 + HKDF.
  Future<SecretKey> _getOrDeriveKey({
    required KeyPair myKeyPair,
    required String peerPublicKeyBase64,
  }) async {
    if (_derivedKeyCache.containsKey(peerPublicKeyBase64)) {
      return _derivedKeyCache[peerPublicKeyBase64]!;
    }

    final peerPubBytes = base64Decode(peerPublicKeyBase64);
    final remotePublicKey = SimplePublicKey(peerPubBytes, type: KeyPairType.x25519);

    // 1. Compute ECDH X25519 shared secret
    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: remotePublicKey,
    );

    // 2. Derive AES-256 key via HKDF-SHA256
    final derivedSecret = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode('BlueMesh_P2P_Encryption_v1'),
    );

    _derivedKeyCache[peerPublicKeyBase64] = derivedSecret;
    return derivedSecret;
  }

  /// Encrypts cleartext bytes for a peer.
  /// Format: [12-byte Nonce / IV] + [AES-256-GCM Ciphertext + 16-byte MAC]
  Future<Uint8List> encrypt({
    required Uint8List cleartext,
    required KeyPair myKeyPair,
    required String peerPublicKeyBase64,
  }) async {
    try {
      final secretKey = await _getOrDeriveKey(
        myKeyPair: myKeyPair,
        peerPublicKeyBase64: peerPublicKeyBase64,
      );

      // Generate 12-byte random IV
      final rng = Random.secure();
      final nonceBytes = Uint8List(12);
      for (int i = 0; i < 12; i++) {
        nonceBytes[i] = rng.nextInt(256);
      }

      final secretBox = await _aesGcm.encrypt(
        cleartext,
        secretKey: secretKey,
        nonce: nonceBytes,
      );

      // Combine [nonce (12)] + [ciphertext + mac]
      final combined = Uint8List(12 + secretBox.cipherText.length + secretBox.mac.bytes.length);
      combined.setRange(0, 12, nonceBytes);
      combined.setRange(12, 12 + secretBox.cipherText.length, secretBox.cipherText);
      combined.setRange(
        12 + secretBox.cipherText.length,
        combined.length,
        secretBox.mac.bytes,
      );

      return combined;
    } catch (e, stack) {
      AppLogger.e('Encryption failed: $e', e, stack);
      rethrow;
    }
  }

  /// Decrypts ciphertext bytes from a peer using derived shared secret.
  Future<Uint8List> decrypt({
    required Uint8List encryptedData,
    required KeyPair myKeyPair,
    required String peerPublicKeyBase64,
  }) async {
    try {
      if (encryptedData.length < 12 + 16) {
        throw const FormatException('Ciphertext data too short for nonce and MAC');
      }

      final secretKey = await _getOrDeriveKey(
        myKeyPair: myKeyPair,
        peerPublicKeyBase64: peerPublicKeyBase64,
      );

      final nonce = encryptedData.sublist(0, 12);
      final cipherTextAndMac = encryptedData.sublist(12);
      final cipherTextLength = cipherTextAndMac.length - 16;

      final cipherText = cipherTextAndMac.sublist(0, cipherTextLength);
      final macBytes = cipherTextAndMac.sublist(cipherTextLength);

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final decrypted = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return Uint8List.fromList(decrypted);
    } catch (e, stack) {
      AppLogger.e('Decryption failed: $e', e, stack);
      rethrow;
    }
  }

  /// Clears in-memory derived key cache.
  void clearCache() {
    _derivedKeyCache.clear();
  }
}
