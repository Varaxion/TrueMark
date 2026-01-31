import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ownership_record.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registers a new image ownership record in Firestore.
  /// This acts as the immutable proof of creation.
  Future<void> registerOwnership(OwnershipRecord record) async {
    // We use the imageHash as the Document ID to ensure uniqueness 
    // and fast lookup during verification.
    await _firestore
        .collection('ownership_records')
        .doc(record.imageHash)
        .set(record.toMap());
        
    print('>>> [FIRESTORE] Ownership registered for hash: ${record.imageHash}');
  }

  /// Verifies ownership by looking up the image hash.
  /// Returns the record if found, or null if not registered.
  Future<OwnershipRecord?> verifyOwnership(String imageHash) async {
    try {
      final doc = await _firestore
          .collection('ownership_records')
          .doc(imageHash)
          .get();

      if (doc.exists && doc.data() != null) {
        return OwnershipRecord.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('>>> [FIRESTORE] Verification error: $e');
      return null;
    }
  }

  /// Optional: Get all records created by a specific user (for History)
  Stream<List<OwnershipRecord>> getUserRecords(String uid) {
    return _firestore
        .collection('ownership_records')
        .where('ownerUid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OwnershipRecord.fromMap(doc.data())).toList();
    });
  }
}
