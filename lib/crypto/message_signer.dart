import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../core/logger.dart';

/// Signs and validates mesh payloads using Ed25519 digital signatures.
class MessageSigner {
  final SignatureAlgorithm _algorithm = Ed25519();

  /// Signs raw data bytes using the node's private key.
  /// Returns a Base64 encoded signature.
  Future<String> sign(Uint8List data, KeyPair keyPair) async {
    try {
      final signature = await _algorithm.sign(data, keyPair: keyPair);
      return base64Encode(signature.bytes);
    } catch (e, stack) {
      AppLogger.e('Failed to sign message payload: $e', e, stack);
      rethrow;
    }
  }

  /// Verifies an Ed25519 signature against the sender's known public key.
  /// Returns `true` if valid, `false` otherwise.
  Future<bool> verify({
    required Uint8List data,
    required String base64Signature,
    required String base64PublicKey,
  }) async {
    try {
      final sigBytes = base64Decode(base64Signature);
      final pubBytes = base64Decode(base64PublicKey);

      final publicKey = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
      final signature = Signature(sigBytes, publicKey: publicKey);

      final isValid = await _algorithm.verify(data, signature: signature);
      if (!isValid) {
        AppLogger.w('Signature verification FAILED.');
      }
      return isValid;
    } catch (e) {
      AppLogger.w('Signature verification error: $e');
      return false;
    }
  }
}
