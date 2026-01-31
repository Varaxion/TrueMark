class OwnershipRecord {
  final String imageId;      // The unique ID generated for this image
  final String ownerUid;     // The User ID of the creator
  final String ownerEmail;   // Email of creator (for display)
  final double timestamp;    // When it was marked
  final String imageHash;    // SHA-256 hash of the original image bytes
  final String signature;    // The encrypted signature string embedded in LSB

  OwnershipRecord({
    required this.imageId,
    required this.ownerUid,
    required this.ownerEmail,
    required this.timestamp,
    required this.imageHash,
    required this.signature,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageId': imageId,
      'ownerUid': ownerUid,
      'ownerEmail': ownerEmail,
      'timestamp': timestamp,
      'imageHash': imageHash,
      'signature': signature,
    };
  }

  factory OwnershipRecord.fromMap(Map<String, dynamic> map) {
    return OwnershipRecord(
      imageId: map['imageId'] ?? '',
      ownerUid: map['ownerUid'] ?? '',
      ownerEmail: map['ownerEmail'] ?? 'Unknown',
      timestamp: (map['timestamp'] is int) 
          ? (map['timestamp'] as int).toDouble() 
          : (map['timestamp'] as double? ?? 0.0),
      imageHash: map['imageHash'] ?? '',
      signature: map['signature'] ?? '',
    );
  }
}
