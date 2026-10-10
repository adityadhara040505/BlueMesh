import 'dart:convert';
import 'dart:typed_data';
import 'package:blue_mesh/crypto/message_signer.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageSigner Cryptography Tests', () {
    late MessageSigner signer;
    late SignatureAlgorithm algorithm;

    setUp(() {
      signer = MessageSigner();
      algorithm = Ed25519();
    });

    test('Digital signature generation and verification succeeds for valid payload', () async {
      final keyPair = await algorithm.newKeyPair();
      final pubKey = await keyPair.extractPublicKey();
      final pubKeyBase64 = base64Encode((pubKey as SimplePublicKey).bytes);

      final messageBytes = Uint8List.fromList(utf8.encode('Hello BlueMesh mesh network'));

      final signature = await signer.sign(messageBytes, keyPair);
      expect(signature, isNotEmpty);

      final isValid = await signer.verify(
        data: messageBytes,
        base64Signature: signature,
        base64PublicKey: pubKeyBase64,
      );

      expect(isValid, isTrue);
    });

    test('Digital signature verification fails when payload is tampered', () async {
      final keyPair = await algorithm.newKeyPair();
      final pubKey = await keyPair.extractPublicKey();
      final pubKeyBase64 = base64Encode((pubKey as SimplePublicKey).bytes);

      final messageBytes = Uint8List.fromList(utf8.encode('Original message'));
      final signature = await signer.sign(messageBytes, keyPair);

      final tamperedBytes = Uint8List.fromList(utf8.encode('Tampered message!'));
      final isValid = await signer.verify(
        data: tamperedBytes,
        base64Signature: signature,
        base64PublicKey: pubKeyBase64,
      );

      expect(isValid, isFalse);
    });
  });
}
