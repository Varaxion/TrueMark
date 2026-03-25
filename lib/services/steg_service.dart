import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart' as crypto;

/// Extended Steganography and Universal Signing Service
class StegService {
  StegService._();

  static const String _fileSignMarker = "==TRUEMARK_SIGNED==";

  static encrypt.Key _makeKeyFromPassword(String password) {
    final digest = crypto.sha256.convert(password.codeUnits).bytes;
    return encrypt.Key(Uint8List.fromList(digest));
  }

  static encrypt.IV _makeZeroIV() => encrypt.IV(Uint8List(16)); 

  /// Embed plaintext into image bytes using LSB.
  /// Optimized for image 4.x using the Pixel iterator.
  static Future<File> embedStringInImage({
    required File inputFile,
    required String plaintext,
    required String password,
    required File outputFile,
  }) async {
    final bytes = await inputFile.readAsBytes();
    img.Image? src = img.decodeImage(bytes);
    if (src == null) throw Exception('Unsupported image format.');

    // PREVENT DART VM OOM CRASHES: Constrain large camera resolutions to 1080p
    // before bit-level steganography to prevent 0-byte cache dropouts during TrueLock encryption mapping.
    if (src.width > 1080 || src.height > 1080) {
      src = src.width > src.height 
          ? img.copyResize(src, width: 1080)
          : img.copyResize(src, height: 1080);
    }

    final key = _makeKeyFromPassword(password);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: _makeZeroIV()).bytes;

    final magic = 'TM'; 
    final payloadBytes = <int>[];
    payloadBytes.addAll(magic.codeUnits);
    final len = encrypted.length;
    payloadBytes.addAll([
      (len >> 24) & 0xFF, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF,
    ]);
    payloadBytes.addAll(encrypted);

    // CRC for integrity
    int computeCrc32(List<int> data) {
      int crc = 0xFFFFFFFF;
      for (var b in data) {
        crc ^= b;
        for (var k = 0; k < 8; k++) {
          if ((crc & 1) != 0) crc = (crc >> 1) ^ 0xEDB88320;
          else crc = crc >> 1;
        }
      }
      return crc ^ 0xFFFFFFFF;
    }

    final crcInt = computeCrc32(encrypted);
    payloadBytes.addAll([
      (crcInt >> 24) & 0xFF, (crcInt >> 16) & 0xFF, (crcInt >> 8) & 0xFF, crcInt & 0xFF,
    ]);

    final payload = Uint8List.fromList(payloadBytes);
    final bits = <int>[];
    for (var byte in payload) {
      for (var i = 7; i >= 0; i--) bits.add((byte >> i) & 1);
    }

    if (bits.length > (src.width * src.height)) {
      throw Exception('Image too small for this payload.');
    }

    // Embed using pixel iterator (Efficient and safe in image 4.x)
    int bitIndex = 0;
    final out = img.Image.from(src); 
    for (final pixel in out) {
      if (bitIndex < bits.length) {
        // Embed bit into Blue channel's LSB
        final b = pixel.b.toInt();
        pixel.b = (b & 0xFE) | bits[bitIndex];
        bitIndex++;
      } else {
        break;
      }
    }

    final pngBytes = img.encodePng(out);
    await outputFile.writeAsBytes(pngBytes, flush: true);
    return outputFile;
  }

  /// Extracts embedded string from PNG
  static Future<String?> extractStringFromImage({
    required File inputFile,
    required String password,
  }) async {
    final bytes = await inputFile.readAsBytes();
    final src = img.decodeImage(bytes);
    if (src == null) return null;

    final bitReader = <int>[];
    // Must extract using same pixel iteration sequence
    for (final pixel in src) {
      bitReader.add(pixel.b.toInt() & 1);
      // Small optimization: if bitReader.length is very large we can break
      // but typically we can read the whole image quickly.
    }

    List<int> bitsToBytes(List<int> bits, int start, int count) {
      final out = <int>[];
      for (int i = 0; i < count; i += 8) {
        int byte = 0;
        for (int j = 0; j < 8; j++) {
           if (start+i+j >= bits.length) break;
           byte = (byte << 1) | (bits[start+i+j] & 1);
        }
        out.add(byte);
      }
      return out;
    }

    if (bitReader.length < 48) return null; // Magic(16) + Len(32)
    final headerBytes = bitsToBytes(bitReader, 0, 48);
    if (String.fromCharCodes(headerBytes.sublist(0, 2)) != 'TM') return null; 
    
    final lenBytes = headerBytes.sublist(2, 6);
    final len = (lenBytes[0] << 24) | (lenBytes[1] << 16) | (lenBytes[2] << 8) | lenBytes[3];
    
    // Check if total bits are available for (Header + Data + CRC)
    if (bitReader.length < (6 + len + 4) * 8) return null;

    final payloadBytes = bitsToBytes(bitReader, 0, (6 + len + 4) * 8);
    final encrypted = payloadBytes.sublist(6, 6 + len);
    
    final key = _makeKeyFromPassword(password);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    try {
      return encrypter.decrypt(encrypt.Encrypted(Uint8List.fromList(encrypted)), iv: _makeZeroIV());
    } catch (e) { return null; }
  }

  // --- UNIVERSAL FILE SIGNING (Appending) ---

  /// Appends encrypted metadata to ANY file.
  static Future<File> embedStringInFile({
    required File inputFile,
    required String plaintext,
    required String password,
    required File outputFile,
  }) async {
    final bytes = await inputFile.readAsBytes();
    final key = _makeKeyFromPassword(password);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encryptedBase64 = encrypter.encrypt(plaintext, iv: _makeZeroIV()).base64;
    
    final fullPayload = "$_fileSignMarker$encryptedBase64";
    final builder = BytesBuilder();
    builder.add(bytes);
    builder.add(utf8.encode(fullPayload));
    
    await outputFile.writeAsBytes(builder.toBytes(), flush: true);
    return outputFile;
  }

  static Future<String?> extractStringFromFile({
    required File inputFile,
    required String password,
  }) async {
    final bytes = await inputFile.readAsBytes();
    final markerBytes = utf8.encode(_fileSignMarker);
    
    // Reverse byte search for marker
    int markerIndex = -1;
    for (int i = bytes.length - markerBytes.length; i >= 0; i--) {
      bool match = true;
      for (int j = 0; j < markerBytes.length; j++) {
        if (bytes[i + j] != markerBytes[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        markerIndex = i;
        break;
      }
    }
    
    if (markerIndex == -1) return null;
    
    final base64Bytes = bytes.sublist(markerIndex + markerBytes.length);
    final base64String = utf8.decode(base64Bytes, allowMalformed: true).trim();
    final key = _makeKeyFromPassword(password);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    try {
      return encrypter.decrypt(encrypt.Encrypted.fromBase64(base64String), iv: _makeZeroIV());
    } catch (e) { return null; }
  }

  // --- HELPER WRAPPERS ---

  static Future<File> embedFileInImage({
    required File carrierImage,
    required File secretFile,
    required String password,
    required File outputFile,
  }) async {
    final bytes = await secretFile.readAsBytes();
    final base64Payload = base64Encode(bytes);
    return await embedStringInImage(
      inputFile: carrierImage,
      plaintext: 'FILE:$base64Payload',
      password: password,
      outputFile: outputFile,
    );
  }

  static Future<bool> extractFileFromImage({
    required File carrierImage,
    required String password,
    required String outputFilePath,
  }) async {
     final result = await extractStringFromImage(inputFile: carrierImage, password: password);
     if (result != null && result.startsWith('FILE:')) {
       final bytes = base64Decode(result.substring(5));
       final outFile = File(outputFilePath);
       await outFile.writeAsBytes(bytes);
       return true;
     }
     return false;
  }
}
