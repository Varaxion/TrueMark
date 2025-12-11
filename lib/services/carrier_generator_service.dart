import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CarrierGeneratorService {
  // We use ChaCha20 as our deterministic Pseudo-Random Function (PRF) 'Generator'.
  // In the future, this can be swapped with a quantized ONNX model.
  final Chacha20 _generatorAlgo = Chacha20.poly1305Aead();

  /// Generates a deterministic 'carrier' byte stream based on a seed.
  /// 
  /// [seed] - The 32-byte seed that acts as the 'input' to our generator.
  /// [length] - The exact number of bytes needed for the keystream.
  /// 
  /// Returns a byte array of [length] that looks random but is 100% reproducible from the seed.
  Future<Uint8List> generateCarrierBytes({
    required List<int> seed,
    required int length,
  }) async {
    if (seed.length != 32) {
      throw ArgumentError('Seed must be exactly 32 bytes.');
    }

    // We use the 'seed' as the Key for ChaCha20.
    final secretKey = SecretKey(seed);
    
    // We encrypt a stream of ZEROS. 
    // Encrypting zeros with a stream cipher effectively outputs the pure Keystream.
    final zeros = Uint8List(length); // All zeros
    
    // We use a fixed deterministic nonce (e.g., all zeros) because the uniqueness comes from the 'seed' (Key).
    // In this specific architecture, 'seed' changes per message, so fixed nonce is safe here for stream generation.
    final nonce = Uint8List(12); // 12 bytes of zeros
    
    final secretBox = await _generatorAlgo.encrypt(
      zeros,
      secretKey: secretKey,
      nonce: nonce,
    );

    // The 'ciphertext' of all-zeros IS the keystream.
    return Uint8List.fromList(secretBox.cipherText);
  }
  
  /// Helper to expand a user-provided salt/context into a valid 32-byte seed.
  /// Uses HKDF (HMAC-based Key Derivation Function) to ensure the seed is uniformly distributed.
  /// 
  /// [inputMaterial] - High entropy input (e.g., UserHash + Counter + RandomNonce).
  Future<List<int>> deriveDeterministicSeed(List<int> inputMaterial) async {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    
    final secretKey = SecretKey(inputMaterial);
    final output = await hkdf.deriveKey(
      secretKey: secretKey,
      nonce: const [], // No salt needed if inputMaterial is already high entropy, but good practice to add if possible.
    );

    return await output.extractBytes();
  }
}
