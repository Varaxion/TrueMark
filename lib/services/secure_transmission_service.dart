import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'crypto_service.dart';
import 'carrier_generator_service.dart';

/// Coordinates the full pipeline of Encryption -> Carrier Generation -> Obfuscation (XOR).
class SecureTransmissionService {
  final CryptoService _crypto = CryptoService();
  final CarrierGeneratorService _generator = CarrierGeneratorService();

  /// SENDER SIDE: Securely prepares a file for transmission.
  /// 
  /// Returns a map containing:
  /// - 'payload': The final obfuscated bytes (StegoPayload) to be sent via chunks/CDN.
  /// - 'metadata': The header info (seed, iv, full authenticated hash) required by verification.
  /// - 'key': The raw AES key bytes (which MUST be wrapped by RSA/ECC before sending).
  Future<Map<String, dynamic>> prepareUpload({
    required Uint8List fileBytes,
    required List<int> userContext, // e.g. User ID hash
  }) async {
    // 1. Generate Ephemeral Key (K_img)
    final kImg = await _crypto.generateRandomKey();
    
    // 2. Encrypt File (AES-GCM) -> Ciphertext
    final secretBox = await _crypto.encryptBytes(data: fileBytes, key: kImg);
    final ciphertext = secretBox.cipherText; // The raw encrypted bytes
    final iv = secretBox.nonce;
    final tag = secretBox.mac.bytes;

    // 3. Generate Deterministic Seed S
    // Context: UserHash + Timestamp/Nonce to ensure uniqueness per file
    final nonce = DateTime.now().microsecondsSinceEpoch.toString().codeUnits;
    final inputMaterial = [...userContext, ...nonce]; 
    final seed = await _generator.deriveDeterministicSeed(inputMaterial);

    // 4. Generate Carrier Bytes (must match ciphertext length)
    final carrierBytes = await _generator.generateCarrierBytes(
      seed: seed,
      length: ciphertext.length,
    );

    // 5. XOR Ciphertext with Carrier -> StegoPayload
    final stegoPayload = _xorBytes(ciphertext, carrierBytes);

    // 6. Export Key bytes for the caller to handle (Caller will wrap this with Public Key)
    final kImgBytes = await _crypto.exportKey(kImg);

    return {
      'payload': stegoPayload, // Send this via Blob/CDN
      'metadata': {
        'seed': seed,          // Store in Firestore (securely)
        'iv': iv,              // Store in Firestore
        'tag': tag,            // Store in Firestore (Auth Tag)
      },
      'raw_key': kImgBytes,    // Caller MUST encrypt this before uploading!
    };
  }

  /// RECEIVER SIDE: Reconstructs the original file from payload and metadata.
  Future<Uint8List> receiveAndDecrypt({
    required Uint8List stegoPayload,
    required List<int> seed,
    required List<int> iv,
    required List<int> tag,
    required List<int> kImgBytes, // unwrapped private key
  }) async {
    // 1. Regenerate Carrier Bytes using same Seed
    final carrierBytes = await _generator.generateCarrierBytes(
      seed: seed,
      length: stegoPayload.length,
    );

    // 2. XOR StegoPayload with Carrier -> Original Ciphertext
    // (A XOR B) XOR B = A
    final ciphertext = _xorBytes(stegoPayload, carrierBytes);

    // 3. Reconstruct SecretBox (Ciphertext + IV + MAC)
    final mac = Mac(tag);
    final secretBox = SecretBox(ciphertext, nonce: iv, mac: mac);

    // 4. Import Key
    final kImg = await _crypto.importKey(kImgBytes);

    // 5. Decrypt! (This will throw error if integrity check fails)
    return Uint8List.fromList(await _crypto.decryptBytes(
      secretBox: secretBox,
      key: kImg,
    ));
  }

  /// Fast XOR operation: result[i] = a[i] ^ b[i]
  Uint8List _xorBytes(List<int> a, List<int> b) {
    if (a.length != b.length) {
      throw ArgumentError('XOR inputs must be same length');
    }
    final result = Uint8List(a.length);
    for (int i = 0; i < a.length; i++) {
      result[i] = a[i] ^ b[i];
    }
    return result;
  }
}
