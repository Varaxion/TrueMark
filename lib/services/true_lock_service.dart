
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class TrueLockService {
  // Using AES-GCM (Galois/Counter Mode) for Authenticated Encryption
  final _algorithm = AesGcm.with256bits();
  
  // Custom file header to identify our encrypted files
  // "TMK" = TrueMark Key, "01" = Version 1
  static const _fileHeader = "TMK01"; 

  /// Encrypts bytes using a user-provided password.
  /// Returns a custom binary format:
  /// [Header (5 bytes)] + [Salt (16 bytes)] + [Nonce (12 bytes)] + [Tag + CipherText]
  Future<Uint8List> encryptData(Uint8List plainText, String password) async {
    // 1. Generate a random 16-byte Salt for PBKDF2
    final salt = await _generateRandomBytes(16);
    
    // 2. Derive a 256-bit Key from the Password + Salt
    final secretKey = await _deriveKey(password, salt);

    // 3. Generate a random 12-byte Nonce (Standard for GCM)
    final nonce = await _generateRandomBytes(12);

    // 4. Encrypt the data
    // Authenticated encryption: verifies the data hasn't been tampered with
    final secretBox = await _algorithm.encrypt(
      plainText,
      secretKey: secretKey,
      nonce: nonce,
    );

    // 5. Construct the final binary blob
    final builder = BytesBuilder();
    builder.add(utf8.encode(_fileHeader));
    builder.add(salt);
    builder.add(nonce);
    builder.add(secretBox.concatenation()); // Includes Tag + Ciphertext

    return builder.toBytes();
  }

  /// Decrypts data using a user-provided password.
  /// Throws standard errors if password is wrong or file is tampered.
  Future<Uint8List> decryptData(Uint8List fileData, String password) async {
    // 1. Verify Header
    final headerBytes = utf8.encode(_fileHeader);
    if (fileData.length < headerBytes.length + 16 + 12) {
      throw Exception("Invalid file format: Too short");
    }

    final fileHeader = fileData.sublist(0, headerBytes.length);
    if (utf8.decode(fileHeader) != _fileHeader) {
      throw Exception("Invalid file format: Not a TrueMark Vault file");
    }

    // 2. Extract Metadata
    int offset = headerBytes.length;
    final salt = fileData.sublist(offset, offset + 16);
    offset += 16;
    final nonce = fileData.sublist(offset, offset + 12);
    offset += 12;
    
    // The rest is the Ciphertext (and Auth Tag)
    final cipherBytes = fileData.sublist(offset);

    // 3. Re-derive the Key
    final secretKey = await _deriveKey(password, salt);

    // 4. Decrypt
    // If the password is wrong OR the file was modified, logic throws an error here.
    // SecretBox.fromConcatenation splits the bytes into Tag + Cipher correctly.
    final secretBox = SecretBox.fromConcatenation(
      cipherBytes,
      nonceLength: 12,
      macLength: 16, 
    );
    
    try {
      final decrypted = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return Uint8List.fromList(decrypted);
    } catch (e) {
      // Typically CryptographyError if auth tag mismatch (wrong password/tampering)
      throw Exception("Decryption failed. Incorrect password or corrupted file.");
    }
  }

  /// PBKDF2 Key Derivation
  /// Turns a text password into a strong 256-bit key
  Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000, // NIST recommended minimum (High iteration cost)
      bits: 256,
    );

    final newSecretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    return newSecretKey;
  }

  /// Utility to generate secure random bytes
  Future<Uint8List> _generateRandomBytes(int length) async {
    final bytes = List<int>.filled(length, 0);
    // Cryptography package handles secure random internally generally,
    // but for simple bytes we can use standard interface or a simple helper if needed.
    // Actually, `SecretKeyGenerator` is not for raw bytes.
    // Let's use Dart's math.Random.secure() or the package's robust way if available.
    // The `cryptography` package typically uses `MyRandom` but we can just use universal logic
    // or standard Dart secure random since `cryptography` deals with keys mainly.
    // Wait, `cryptography` usually doesn't expose a raw random bytes helper publicly easily 
    // without `SimpleKeyPair`.
    // Let's use `dart:math` SecureRandom for the Salt/Nonce which is standard.
    
    return Uint8List.fromList(List.generate(length, (_) => _secureRandom.nextInt(256)));
  }
  
  // Basic secure random usage
  final _secureRandom = Random.secure();
}
