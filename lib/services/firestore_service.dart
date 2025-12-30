import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/transfer_metadata.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Note: We intentionally avoid 'FirebaseStorage' import to prevent Windows C++ SDK Linker Errors.
  
  /// Uploads the StegoPayload to Storage (Transport Layer) using REST API to prevent Windows C++ Crashes.
  /// Saves Metadata to Firestore.
  Future<void> sendFileTransfer({
    required List<int> stegoPayload,
    required TransferMetadata metadata,
  }) async {
    final transferId = const Uuid().v4();
    final path = 'secure_transfers/$transferId.bin';
    
    print('>>> [DEBUG] Starting REST Upload to: $path');

    // 1. Upload via REST (Safe for Windows)
    final downloadUrl = await _uploadViaRest(stegoPayload, path);
    print('>>> [DEBUG] REST Upload Success. URL: $downloadUrl');

    // 2. Save Metadata to Firestore
    final finalMeta = metadata.copyWith(
      id: transferId,
      payloadUrl: downloadUrl,
    );

    await _firestore
        .collection('transfers')
        .doc(transferId)
        .set(finalMeta.toMap());
        
    print('>>> [DEBUG] Metadata Saved to Firestore.');
  }

  /// Internal helper to upload using raw HTTP (Bypasses C++ SDK)
  Future<String> _uploadViaRest(List<int> bytes, String storagePath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in - cannot obtain upload token.');
    
    final token = await user.getIdToken();
    
    // Hardcoded bucket avoids querying FirebaseStorage plugin (which crashes build)
    const bucket = 'truemark-5f8bb.appspot.com'; 
    
    // URL Encode the path
    final encodedPath = Uri.encodeComponent(storagePath);
    final url = 'https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=$encodedPath';
    
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw Exception('REST Upload Failed (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body);
    final name = json['name'];
    final bucketName = json['bucket'];
    final downloadToken = json['downloadTokens']; 
    
    return 'https://firebasestorage.googleapis.com/v0/b/$bucketName/o/${Uri.encodeComponent(name)}?alt=media&token=$downloadToken';
  }

  /// Listens for incoming transfers for a specific user.
  Stream<List<TransferMetadata>> getIncomingTransfers(String receiverId) {
    return _firestore
        .collection('transfers')
        .where('receiverId', isEqualTo: receiverId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransferMetadata.fromMap(doc.data());
      }).toList();
    });
  }
}
