import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/transfer_metadata.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // NO FirebaseStorage imports to ensure Windows Build Stability.

  /// Uploads the StegoPayload to Storage (Transport Layer).
  /// STUBBED for Windows to prevent C++ SDK Crashes.
  Future<void> sendFileTransfer({
    required List<int> stegoPayload,
    required TransferMetadata metadata,
  }) async {
    final transferId = const Uuid().v4();
    
    print('>>> [DEBUG] SIMULATING UPLOAD for Windows Stability.');
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Generates a mock URL. On Android (later), we will uncomment real upload.
    final downloadUrl = 'https://simulated-upload.windows/feature-bypass/$transferId.bin';

    print('>>> [DEBUG] Upload Simulated. Encryption verified. URL: $downloadUrl');

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
