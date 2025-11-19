// lib/services/steg_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart' as crypto;

/// Simple LSB steg + AES encrypt/decrypt
class StegService {
  StegService._();

  // AES key must be 32 bytes for AES-256. You can derive from user's secret if you want.
  static encrypt.Key _makeKeyFromPassword(String password) {
    // Derive 32-byte key via SHA256(password)
    final digest = crypto.sha256.convert(password.codeUnits).bytes;
    return encrypt.Key(Uint8List.fromList(digest));
  }

  static encrypt.IV _makeZeroIV() => encrypt.IV(Uint8List(16)); // zero IV (or random + prepend)

  /// Embed plaintext into image bytes (returns new PNG bytes).
  /// - plaintext: the string to embed (e.g., "<base><count>")
  /// - password: used for AES encryption (show this to user as "encryption password")
  /// - inputFile: original image file
  /// - outputFile: where to save processed image (PNG)
  static Future<File> embedStringInImage({
    required File inputFile,
    required String plaintext,
    required String password,
    required File outputFile,
  }) async {
    final bytes = await inputFile.readAsBytes();
    final src = img.decodeImage(bytes);
    if (src == null) throw Exception('Unsupported image format.');

    // 1) Encrypt plaintext
    final key = _makeKeyFromPassword(password);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final iv = _makeZeroIV(); // For production use random iv and prepend it; keep simple here
    final encrypted = encrypter.encrypt(plaintext, iv: iv).bytes;

    // 2) Prepare payload: MAGIC + length (32-bit) + encrypted bytes + crc32
    final magic = 'TM'; // 2 bytes magic
    final payloadBytes = <int>[];
    payloadBytes.addAll(magic.codeUnits);
    final len = encrypted.length;
    payloadBytes.addAll([
      (len >> 24) & 0xFF,
      (len >> 16) & 0xFF,
      (len >> 8) & 0xFF,
      len & 0xFF,
    ]);
    payloadBytes.addAll(encrypted);

    // --- compute CRC32 (inline implementation) ---
    int computeCrc32(List<int> data) {
      int crc = 0xFFFFFFFF;
      for (var b in data) {
        crc ^= b;
        for (var k = 0; k < 8; k++) {
          if ((crc & 1) != 0) {
            crc = (crc >> 1) ^ 0xEDB88320;
          } else {
            crc = crc >> 1;
          }
        }
      }
      return crc ^ 0xFFFFFFFF;
    }

    final crcInt = computeCrc32(encrypted);
    payloadBytes.addAll([
      (crcInt >> 24) & 0xFF,
      (crcInt >> 16) & 0xFF,
      (crcInt >> 8) & 0xFF,
      crcInt & 0xFF,
    ]);

    // 3) Convert payload to bit stream
    final payload = Uint8List.fromList(payloadBytes);
    final bits = <int>[];
    for (var byte in payload) {
      for (var i = 7; i >= 0; i--) bits.add((byte >> i) & 1);
    }

    // 4) Ensure capacity (we will use 1 bit per pixel channel; here use blue channel only)
    final capacity = src.width * src.height; // 1 bit per pixel if using blue
    if (bits.length > capacity) {
      throw Exception('Image too small to embed payload (${bits.length} bits needed, $capacity available).');
    }

    // 5) Embed bits into LSB of blue channel
    int bitIndex = 0;
    final out = img.Image.from(src);

    for (int y = 0; y < out.height && bitIndex < bits.length; y++) {
      for (int x = 0; x < out.width && bitIndex < bits.length; x++) {

        // read current pixel
        final pixel = out.getPixel(x, y);

        // get channels
        final int rInt = ((pixel.r ?? 0) as num).toInt() & 0xFF;
        final int gInt = ((pixel.g ?? 0) as num).toInt() & 0xFF;
        final int bInt = ((pixel.b ?? 0) as num).toInt() & 0xFF;
        final int aInt = ((pixel.a ?? 255) as num).toInt() & 0xFF;

        // modify blue LSB, ensure bit is 0/1
        final int newBInt = ((bInt & 0xFE) | (bits[bitIndex] & 1));
        bitIndex++;

        // compose ARGB int (safe int math)
        final int newColor = ((aInt << 24) & 0xFF000000) |
                            ((rInt << 16) & 0x00FF0000) |
                            ((gInt << 8)  & 0x0000FF00) |
                            (newBInt & 0x000000FF);

        // attempt multiple write APIs to cover package differences
        bool wrote = false;

        // 1) preferred: instance method setPixel on Image
        try {
          (out as dynamic).setPixel(x, y, newColor);
          wrote = true;
        } catch (_) {}

        // 3) instance setPixelRgba fallback if available
        if (!wrote) {
          try {
            (out as dynamic).setPixelRgba(x, y, rInt, gInt, newBInt, aInt);
            wrote = true;
          } catch (_) {}
        }
      }
    }

    // 6) Encode PNG and write to outputFile
    final pngBytes = img.encodePng(out);
    await outputFile.writeAsBytes(pngBytes, flush: true);
    return outputFile;
  }

  /// Extracts embedded string from PNG bytes using password
  static Future<String?> extractStringFromImage({
    required File inputFile,
    required String password,
  }) async {
    final bytes = await inputFile.readAsBytes();
    final src = img.decodeImage(bytes);
    if (src == null) throw Exception('Unsupported image format.');

    // Read enough bits to get header and length first: magic(2 bytes) + len(4) = 6 bytes => 48 bits
    final bitReader = <int>[];
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        final b = (pixel.b as num).toInt();
        bitReader.add(b & 1); // read LSB of blue
      }
    }

    // helper to read next N bits and produce byte list
    List<int> bitsToBytes(List<int> bits, int start, int count) {
      final out = <int>[];
      for (int i = 0; i < count; i += 8) {
        int byte = 0;
        for (int j = 0; j < 8; j++) {
          final bit = bits[start + i + j];
          byte = (byte << 1) | (bit & 1);
        }
        out.add(byte);
      }
      return out;
    }

    if (bitReader.length < 48) return null;
    final headerBytes = bitsToBytes(bitReader, 0, 48);
    final magic = String.fromCharCodes(headerBytes.sublist(0, 2));
    if (magic != 'TM') return null; // not found
    final lenBytes = headerBytes.sublist(2, 6);
    final len = (lenBytes[0] << 24) | (lenBytes[1] << 16) | (lenBytes[2] << 8) | lenBytes[3];

    final totalPayloadBits = (6 + len + 4) * 8; // magic+len + encrypted + crc32
    if (bitReader.length < totalPayloadBits) {
      // Not enough bits - image might be small; but we read all bits anyway
      if (bitReader.length < totalPayloadBits) return null;
    }

    final payloadBytes = bitsToBytes(bitReader, 0, totalPayloadBits);
    // slice encrypted part:
    final encrypted = payloadBytes.sublist(6, 6 + len);
    final crcBytes = payloadBytes.sublist(6 + len, 6 + len + 4);
    final crcExtracted = (crcBytes[0] << 24) | (crcBytes[1] << 16) | (crcBytes[2] << 8) | crcBytes[3];

    // verify CRC32
    int computeCrc32(List<int> data) {
      int crc = 0xFFFFFFFF;
      for (var b in data) {
        crc ^= b;
        for (var k = 0; k < 8; k++) {
          if ((crc & 1) != 0) {
            crc = (crc >> 1) ^ 0xEDB88320;
          } else {
            crc = crc >> 1;
          }
        }
      }
      return crc ^ 0xFFFFFFFF;
    }
    final crcCheck = computeCrc32(encrypted);
    if (crcCheck != crcExtracted) {
      // data corrupted
      return null;
    }

    // Decrypt
    final key = _makeKeyFromPassword(password);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final iv = _makeZeroIV(); // matches embedding
    try {
      final encBytes = Uint8List.fromList(encrypted);
      final encryptedObj = encrypt.Encrypted(encBytes);
      final plain = encrypter.decrypt(encryptedObj, iv: iv);
      return plain;
    } catch (e) {
      return null; // decryption failed
    }
  }
}
