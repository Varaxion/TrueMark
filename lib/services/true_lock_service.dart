import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

class TrueLockService {
  // Pure Dart binary AES implementation - bypasses Platform Channel size constraints.
  // V9 for newly encrypted files
  static const _fileHeader = "TMK09"; 

  Future<Uint8List> encryptData(Uint8List plainText, String password, String originalExtension) async {
    if (plainText.isEmpty) throw "Cannot seal an empty asset (0 bytes input).";

    // 1. Synchronous ultra-fast key derivation (No PBKDF2 lag on mobile)
    final keyBytes = crypto.sha256.convert(utf8.encode(password)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));
    
    // 2. Pure Binary IV Generation
    final iv = enc.IV.fromSecureRandom(16);

    // 3. Native Dart Encryption (PKCS7 Padding, CBC Mode)
    // Avoids Flutter Platform Channel `Large Buffer` crashes associated with the cryptography package.
    final decrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
    final encrypted = decrypter.encryptBytes(plainText, iv: iv);

    // 4. Binary Assembly (No Base64 json memory bloat!)
    final builder = BytesBuilder();
    builder.add(utf8.encode(_fileHeader));
    builder.add(iv.bytes);
    
    final extBytes = utf8.encode(originalExtension);
    builder.addByte(extBytes.length); 
    builder.add(extBytes);

    builder.add(encrypted.bytes);

    return builder.toBytes();
  }

  Future<_DecryptedResult> decryptData(Uint8List fileData, String password) async {
    try {
      if (fileData.length < 5) throw "Format Invalid: Too short.";
      
      final sigBytes = fileData.sublist(0, 5);
      final sig = utf8.decode(sigBytes, allowMalformed: true);
      
      if (sig == "TMK09") {
        return await _decryptV9(fileData, password);
      } else {
        throw "Unsupported TrueMark wrapper ($sig). Please use latest assets.";
      }
    } catch (e) {
      print("TrueLock Decryption Failed: $e");
      rethrow;
    }
  }

  Future<_DecryptedResult> _decryptV9(Uint8List fileData, String password) async {
    final hb = utf8.encode("TMK09");
    int p = hb.length; // 5

    if (fileData.length < p + 16 + 1) throw "Corrupted Metadata Extents.";

    final ivBytes = fileData.sublist(p, p + 16);
    final iv = enc.IV(ivBytes);
    p += 16;
    
    final extLen = fileData[p];
    p += 1;
    
    if (p + extLen > fileData.length) throw "Metadata Overflow";
    final ext = utf8.decode(fileData.sublist(p, p + extLen));
    p += extLen;

    final keyBytes = crypto.sha256.convert(utf8.encode(password)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));

    final cipherText = fileData.sublist(p);
    
    final decrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
    final decrypted = decrypter.decryptBytes(enc.Encrypted(cipherText), iv: iv);

    return _DecryptedResult(Uint8List.fromList(decrypted), ext.isEmpty ? '.dec' : ext);
  }

  // --- FILE HANDLING METHODS (Requested in TrueLockScreen) ---

  Future<File> encryptFile(File inputFile, String password) async {
    if (!await inputFile.exists()) throw "Input file does not exist on disk.";
    final bytes = await inputFile.readAsBytes();
    if (bytes.isEmpty) throw "Source file evaluates to 0-bytes. Try picking it from TrueVault.";
    
    final ext = p.extension(inputFile.path);
    final encryptedData = await encryptData(bytes, password, ext);
    
    final originalBase = p.basenameWithoutExtension(inputFile.path);
    final outPath = p.join(p.dirname(inputFile.path), '${originalBase}_TrueLock_Seal_${DateTime.now().millisecondsSinceEpoch}.tmk');
    final outFile = File(outPath);
    await outFile.writeAsBytes(encryptedData, flush: true);
    return outFile;
  }

  Future<File> decryptFile(File encryptedFile, String password) async {
    if (!await encryptedFile.exists()) throw "Archive file not found.";
    
    // Check if the OS gave us a 0-byte ghost file (Android FilePicker bug on new files)
    final fileBytes = await encryptedFile.readAsBytes();
    if (fileBytes.isEmpty) {
      throw "Android FilePicker Bug Detected: The OS returned an empty file. Please pick this asset directly using 'From TrueVault' to bypass the storage glitch.";
    }

    final result = await decryptData(fileBytes, password);
    
    if (result.bytes.isEmpty) throw "Decrypted payload is unexpectedly empty.";

    final currentBase = p.basenameWithoutExtension(encryptedFile.path);
    final outPath = p.join(p.dirname(encryptedFile.path), '${currentBase}_TrueLock_Open_${DateTime.now().millisecondsSinceEpoch}${result.extension}');
    final outFile = File(outPath);
    await outFile.writeAsBytes(result.bytes, flush: true);
    return outFile;
  }

  // --- HELPERS ---

  Future<Uint8List> _generateRandomBytes(int length) async {
    return Uint8List.fromList(List.generate(length, (_) => _secureRandom.nextInt(256)));
  }
  
  final _secureRandom = Random.secure();
}

class _DecryptedResult {
  final Uint8List bytes;
  final String extension;
  _DecryptedResult(this.bytes, this.extension);
}
