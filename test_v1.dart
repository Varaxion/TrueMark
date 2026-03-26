import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'lib/services/true_lock_service.dart';

void main() async {
  try {
    final algo = AesGcm.with256bits();
    final pswd = 'password123';
    
    // Simulate V1 encrypt
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
    final salt = Uint8List(16);
    final nonce = Uint8List(12);
    final secretKey = await pbkdf2.deriveKeyFromPassword(password: pswd, nonce: salt);
    
    final secretBox = await algo.encrypt([1,2,3], secretKey: secretKey, nonce: nonce);
    final builder = BytesBuilder();
    builder.add(utf8.encode("TMK01"));
    builder.add(salt);
    builder.add(nonce);
    builder.add(secretBox.concatenation());
    
    final tmk01Bytes = builder.toBytes();
    
    // Decrypt using TrueLockService fallback
    final srv = TrueLockService();
    final res = await srv.decryptData(tmk01Bytes, pswd);
    print("V1 Decrypt successful: ${res.bytes}");
  } catch (e, st) {
    print("Failed: $e");
    print(st);
  }
}
