import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

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
      throw Exception("Decryption failed. Incorrect password or corrupted file.");
    }
  }

  // --- FILE HANDLING METHODS (Requested in TrueLockScreen) ---

  Future<File> encryptFile(File inputFile, String password) async {
    final bytes = await inputFile.readAsBytes();
    final encryptedData = await encryptData(bytes, password);
    // [FileName]_TrueLock_Encrypt_[Timestamp].tmk
    final originalBase = p.basenameWithoutExtension(inputFile.path);
    final outPath = p.join(p.dirname(inputFile.path), '${originalBase}_TrueLock_Encrypt_${DateTime.now().millisecondsSinceEpoch}.tmk');
    final outFile = File(outPath);
    await outFile.writeAsBytes(encryptedData);
    return outFile;
  }

  Future<File> decryptFile(File encryptedFile, String password) async {
    final bytes = await encryptedFile.readAsBytes();
    final decryptedData = await decryptData(bytes, password);
    // [EncryptedName]_TrueLock_Decrypt_[Timestamp].dec
    final currentBase = p.basenameWithoutExtension(encryptedFile.path);
    final outPath = p.join(p.dirname(encryptedFile.path), '${currentBase}_TrueLock_Decrypt_${DateTime.now().millisecondsSinceEpoch}.dec');
    final outFile = File(outPath);
    await outFile.writeAsBytes(decryptedData);
    return outFile;
  }

  /// PBKDF2 Key Derivation
  Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000, 
      bits: 256,
    );
    return await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  /// Utility to generate secure random bytes
  Future<Uint8List> _generateRandomBytes(int length) async {
    return Uint8List.fromList(List.generate(length, (_) => _secureRandom.nextInt(256)));
  }
  
  final _secureRandom = Random.secure();
}
