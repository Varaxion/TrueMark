import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/transfer_metadata.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  /// Uploads the StegoPayload to Storage (Transport Layer) and saves Metadata to Firestore.
  /// Returns the ID of the created transfer.
  Future<String> sendFileTransfer({
    required Uint8List stegoPayload,
    required TransferMetadata metadata,
  }) async {
    final transferId = _uuid.v4();
    final fileName = '${metadata.senderId}_${metadata.timestamp}.bin'; // Obscure name
    
    try {
      // 1. Upload the 'StegoPayload' (Blobs of seemingly random noise)
      // Note: In a production version, this would be auto-deleting or ephemeral.
      final ref = _storage.ref().child('transfers/$transferId/$fileName');
      final uploadTask = await ref.putData(stegoPayload);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 2. Update metadata with the actual transport URL and ID
      final finalMetadata = TransferMetadata(
        id: transferId,
        senderId: metadata.senderId,
        receiverId: metadata.receiverId,
        fileName: metadata.fileName,
        timestamp: metadata.timestamp,
        seed: metadata.seed,
        iv: metadata.iv,
        authTag: metadata.authTag,
        wrappedKey: metadata.wrappedKey,
        payloadUrl: downloadUrl,
      );

      // 3. Save Metadata to Firestore 'transfers' collection
      await _firestore
          .collection('transfers')
          .doc(transferId)
          .set(finalMetadata.toMap());

      return transferId;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
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
