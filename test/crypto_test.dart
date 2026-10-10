import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:blue_mesh/crypto/encryption.dart';
import 'package:blue_mesh/crypto/key_manager.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  group('Cryptography & E2E Encryption Tests', () {
    late MeshEncryption encryption;
    final algorithm = X25519();

    setUp(() {
      encryption = MeshEncryption();
    });

    test('X25519 ECDH + AES-256-GCM encryption and decryption roundtrip', () async {
      // Create Alice & Bob key pairs
      final alicePair = await algorithm.newKeyPair();
      final bobPair = await algorithm.newKeyPair();

      final alicePub = await alicePair.extractPublicKey() as SimplePublicKey;
      final bobPub = await bobPair.extractPublicKey() as SimplePublicKey;

      final alicePubBase64 = base64Encode(alicePub.bytes);
      final bobPubBase64 = base64Encode(bobPub.bytes);

      const plaintext = 'Secret BlueMesh P2P message between Alice and Bob!';
      final cleartextBytes = Uint8List.fromList(utf8.encode(plaintext));

      // Alice encrypts for Bob
      final encryptedBytes = await encryption.encrypt(
        cleartext: cleartextBytes,
        myKeyPair: alicePair,
        peerPublicKeyBase64: bobPubBase64,
      );

      expect(encryptedBytes, isNotNull);
      expect(encryptedBytes.isNotEmpty, true);

      // Bob decrypts from Alice
      final decryptedBytes = await encryption.decrypt(
        encryptedData: encryptedBytes,
        myKeyPair: bobPair,
        peerPublicKeyBase64: alicePubBase64,
      );

      final decryptedText = utf8.decode(decryptedBytes);
      expect(decryptedText, plaintext);
    });

    test('derivePeerFingerprint produces deterministic 8-char hex fingerprint', () async {
      final pair = await algorithm.newKeyPair();
      final pubKey = await pair.extractPublicKey() as SimplePublicKey;
      final pubBase64 = base64Encode(pubKey.bytes);

      final fingerprint1 = await KeyManager.derivePeerFingerprint(pubBase64);
      final fingerprint2 = await KeyManager.derivePeerFingerprint(pubBase64);

      expect(fingerprint1.length, 8);
      expect(fingerprint1, fingerprint2);
      expect(fingerprint1, fingerprint1.toUpperCase());
    });
  });
}
