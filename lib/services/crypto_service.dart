import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  // Use AES-GCM with 256-bit keys for authenticated encryption
  final Algorithm _aesGcm = AesGcm.with256bits();
  final Sha256 _sha256 = Sha256();

  /// Generates a secure random 256-bit (32-byte) key.
  Future<SecretKey> generateRandomKey() async {
    return await _aesGcm.newSecretKey();
  }

  /// Computes the SHA-256 hash of the given bytes.
  Future<Uint8List> hashData(List<int> data) async {
    final hash = await _sha256.hash(data);
    return Uint8List.fromList(hash.bytes);
  }

  /// Encrypts bytes using AES-256-GCM.
  /// Returns a [SecretBox] payload containing ciphertext, nonce (IV), and auth tag (MAC).
  Future<SecretBox> encryptBytes({
    required List<int> data,
    required SecretKey key,
  }) async {
    // AesGcm automatically generates a random nonce if one isn't provided.
    // We let it handle nonce generation for safety.
    return await _aesGcm.encrypt(
      data,
      secretKey: key,
    );
  }

  /// Decrypts a [SecretBox] (ciphertext + nonce + mac) using the key.
  /// Throws [SecretBoxAuthenticationError] if authentication fails (tampering detected).
  Future<List<int>> decryptBytes({
    required SecretBox secretBox,
    required SecretKey key,
  }) async {
    return await _aesGcm.decrypt(
      secretBox,
      secretKey: key,
    );
  }

  /// Helper to convert raw bytes (from storage/metadata) back into a SecretKey object.
  Future<SecretKey> importKey(List<int> keyBytes) async {
    return SecretKey(keyBytes);
  }

  /// Helper to extract raw bytes from a SecretKey object (for wrapping/storage).
  Future<List<int>> exportKey(SecretKey key) async {
    return await key.extractBytes();
  }
}
