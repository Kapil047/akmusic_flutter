import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';
import '../config/app_constants.dart';

class CryptoService {
  static final AesGcm _aesGcm = AesGcm.with256bits(nonceLength: 16);
  static final SecretKey _secretKey = SecretKey(hex.decode(AppConstants.cryptoSecretHex));
 
  static Future<dynamic> decryptPayload({
    required String payloadBase64,
    required String ivBase64,
    required String authTagBase64,
  }) async {
    final cipherText = base64.decode(payloadBase64);
    final iv = base64.decode(ivBase64);
    final authTag = base64.decode(authTagBase64);

    final secretBox = SecretBox(
      cipherText,
      nonce: iv,
      mac: Mac(authTag),
    );

    final decryptedBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: _secretKey,
    );

    final decryptedString = utf8.decode(decryptedBytes);
    try {
      return jsonDecode(decryptedString);
    } catch (_) {
      return decryptedString;
    }
  }

  /// Encrypts outgoing request body using AES-256-GCM (16-byte random IV)
  static Future<Map<String, String>> encryptPayload(dynamic data) async {
    final plainText = data is String ? data : jsonEncode(data);
    final plainBytes = utf8.encode(plainText);

    final secretBox = await _aesGcm.encrypt(
      plainBytes,
      secretKey: _secretKey,
      nonce: _aesGcm.newNonce(),
    );

    return {
      'payload': base64.encode(secretBox.cipherText),
      'iv': base64.encode(secretBox.nonce),
      'authTag': base64.encode(secretBox.mac.bytes),
    };
  }
}
