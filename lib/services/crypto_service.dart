import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';

// REPLACES previous implementation to use 'encrypt' package (Pure Dart, Stable)
class CryptoService {
  // Use AES-CBC-PKCS7 (standard in encrypt package)
  // AES-256 = 32 bytes Key, 16 bytes IV

  /// Generates a secure random 32-byte key.
  enc.Key generateRandomKey() {
    return enc.Key.fromSecureRandom(32);
  }

  /// Generates a secure random 16-byte IV.
  enc.IV generateRandomIV() {
    return enc.IV.fromSecureRandom(16);
  }

  /// Encrypts bytes using AES-CBC.
  /// Returns raw ciphertext bytes.
  Uint8List encryptBytes({
    required List<int> data,
    required enc.Key key,
    required enc.IV iv,
  }) {
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    return encrypted.bytes;
  }

  /// Decrypts bytes using AES-CBC.
  List<int> decryptBytes({
    required List<int> ciphertext,
    required enc.Key key,
    required enc.IV iv,
  }) {
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(Uint8List.fromList(ciphertext)), iv: iv);
    return decrypted;
  }

  /// Hashes data (SHA-256)
  List<int> hashData(List<int> data) {
    return sha256.convert(data).bytes;
  }
}
