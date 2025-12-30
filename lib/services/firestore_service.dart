import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Restoring import for parity
import 'package:uuid/uuid.dart';
import '../models/transfer_metadata.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // Restoring usage for parity

  /// Uploads the StegoPayload to Storage (Transport Layer).
  /// STUBBED for Windows to prevent C++ SDK Crashes.
  Future<void> sendFileTransfer({
    required List<int> stegoPayload,
    required TransferMetadata metadata,
  }) async {
    final transferId = const Uuid().v4();
    final ref = _storage.ref().child('secure_uploads/$transferId.bin');
    
    // 1. Upload Payload to Firebase Storage (Native SDK)
    print('>>> [UPLOAD] Starting upload to ${ref.fullPath}...');
    final task = await ref.putData(
      Uint8List.fromList(stegoPayload),
      SettableMetadata(contentType: 'application/octet-stream'),
    );
    
    final downloadUrl = await task.ref.getDownloadURL();
    print('>>> [UPLOAD] Success. URL: $downloadUrl');

    // 2. Save Metadata to Firestore
    final finalMeta = metadata.copyWith(
      id: transferId,
      payloadUrl: downloadUrl,
    );

    await _firestore
        .collection('transfers')
        .doc(transferId)
        .set(finalMeta.toMap());
        
    print('>>> [FIRESTORE] Metadata Saved.');
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
