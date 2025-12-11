import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'dart:convert';

// REPLACES previous implementation to use SHA-256 Counter Mode (Pure Dart)
class CarrierGeneratorService {
  /// Generates a deterministic 'carrier' byte stream based on a seed.
  /// Uses SHA-256 in Counter Mode (Seed + Counter -> Hash).
  Future<Uint8List> generateCarrierBytes({
    required List<int> seed,
    required int length,
  }) async {
    final carrier = BytesBuilder();
    int counter = 0;
    
    // Append hashes until we have enough bytes
    while (carrier.length < length) {
      // Input = Seed + Counter (Simple increment)
      final input = [...seed, ...utf8.encode(counter.toString())];
      final hash = sha256.convert(input).bytes;
      carrier.add(hash);
      counter++;
    }
    
    // Truncate to exact length
    return carrier.toBytes().sublist(0, length);
  }

  // Derive Seed using SHA256 of input material
  Future<List<int>> deriveDeterministicSeed(List<int> inputMaterial) async {
    return sha256.convert(inputMaterial).bytes;
  }
}
