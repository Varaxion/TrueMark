class TransferMetadata {
  final String id;
  final String senderId;
  final String receiverId;
  final String fileName;
  final int timestamp;
  
  // Crypto fields (Base64 encoded strings for storage)
  final String seed;      // The seed for the ML/Carrier generator
  final String iv;        // AES-GCM Interialization Vector
  final String authTag;   // AES-GCM Authentication Tag
  final String wrappedKey; // The AES key encrypted with Receiver's Public Key

  // Location of the payload (The stego blob)
  final String payloadUrl; 

  TransferMetadata({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.fileName,
    required this.timestamp,
    required this.seed,
    required this.iv,
    required this.authTag,
    required this.wrappedKey,
    required this.payloadUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'fileName': fileName,
      'timestamp': timestamp,
      'seed': seed,
      'iv': iv,
      'authTag': authTag,
      'wrappedKey': wrappedKey,
      'payloadUrl': payloadUrl,
    };
  }

  factory TransferMetadata.fromMap(Map<String, dynamic> map) {
    return TransferMetadata(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      fileName: map['fileName'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      seed: map['seed'] ?? '',
      iv: map['iv'] ?? '',
      authTag: map['authTag'] ?? '',
      wrappedKey: map['wrappedKey'] ?? '',
      payloadUrl: map['payloadUrl'] ?? '',
    );
  }

  TransferMetadata copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? fileName,
    int? timestamp,
    String? seed,
    String? iv,
    String? authTag,
    String? wrappedKey,
    String? payloadUrl,
  }) {
    return TransferMetadata(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      fileName: fileName ?? this.fileName,
      timestamp: timestamp ?? this.timestamp,
      seed: seed ?? this.seed,
      iv: iv ?? this.iv,
      authTag: authTag ?? this.authTag,
      wrappedKey: wrappedKey ?? this.wrappedKey,
      payloadUrl: payloadUrl ?? this.payloadUrl,
    );
  }
}
