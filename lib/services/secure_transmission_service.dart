import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'crypto_service.dart';
import 'carrier_generator_service.dart';

/// Coordinates the full pipeline of Encryption -> Carrier Generation -> Obfuscation (XOR).
class SecureTransmissionService {
  final CryptoService _crypto = CryptoService();
  final CarrierGeneratorService _generator = CarrierGeneratorService();

  /// SENDER SIDE: Securely prepares a file for transmission.
  Future<Map<String, dynamic>> prepareUpload({
    required Uint8List fileBytes,
    required List<int> userContext,
  }) async {
    // 1. Generate Ephemeral Key (K_img) and IV
    final kImg = _crypto.generateRandomKey();
    final iv = _crypto.generateRandomIV();
    
    // 2. Encrypt File (AES-CBC) -> Ciphertext
    // AES-CBC does not produce an Auth Tag (MAC) automatically. 
    // For MVP, we rely on the SHA-256 integrity check of the final XOR payload or the implicit check.
    // Ideally, we'd add HMAC here.
    final ciphertext = _crypto.encryptBytes(data: fileBytes, key: kImg, iv: iv);

    // 3. Generate Deterministic Seed S
    final nonce = DateTime.now().microsecondsSinceEpoch.toString().codeUnits;
    final inputMaterial = [...userContext, ...nonce]; 
    final seed = await _generator.deriveDeterministicSeed(inputMaterial);

    // 4. Generate Carrier Bytes
    final carrierBytes = await _generator.generateCarrierBytes(
      seed: seed,
      length: ciphertext.length,
    );

    // 5. XOR Ciphertext with Carrier -> StegoPayload
    final stegoPayload = _xorBytes(ciphertext, carrierBytes);

    // 6. Generate Simple Auth Tag (SHA-256 of Ciphertext)
    // Replaces AES-GCM tag.
    final tag = _crypto.hashData(ciphertext);

    return {
      'payload': stegoPayload,
      'metadata': {
        'seed': seed,
        'iv': iv.bytes,
        'tag': tag,
      },
      'raw_key': kImg.bytes,
    };
  }

  /// RECEIVER SIDE: Reconstructs the original file.
  Future<Uint8List> receiveAndDecrypt({
    required Uint8List stegoPayload,
    required List<int> seed,
    required List<int> iv,
    required List<int> tag,
    required List<int> kImgBytes,
  }) async {
    // 1. Regenerate Carrier Bytes
    final carrierBytes = await _generator.generateCarrierBytes(
      seed: seed,
      length: stegoPayload.length,
    );

    // 2. XOR StegoPayload -> Original Ciphertext
    final ciphertext = _xorBytes(stegoPayload, carrierBytes);

    // 3. Verify Integrity (Hash Check)
    // Note: This is "Encrypt-then-MAC" effectively but simplified.
    final calculatedTag = _crypto.hashData(ciphertext);
    // Compare tags (constant time prefered, but list equals is ok for demo)
    if (!_listsEqual(calculatedTag, tag)) {
      throw Exception('Integrity Check Failed: Hash mismatch');
    }

    // 4. Decrypt
    final kImg = enc.Key(Uint8List.fromList(kImgBytes));
    final ivObj = enc.IV(Uint8List.fromList(iv));

    final plaintext = _crypto.decryptBytes(
      ciphertext: ciphertext,
      key: kImg,
      iv: ivObj,
    );

    return Uint8List.fromList(plaintext);
  }

  /// Fast XOR
  Uint8List _xorBytes(List<int> a, List<int> b) {
    if (a.length != b.length) throw ArgumentError('XOR inputs length mismatch');
    final result = Uint8List(a.length);
    for (int i = 0; i < a.length; i++) {
      result[i] = a[i] ^ b[i];
    }
    return result;
  }

  bool _listsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
    }
    return true;
  }
}
