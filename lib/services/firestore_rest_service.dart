import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ownership_record.dart';

class FirestoreRestService {
  // Project ID should be dynamic but hardcoded for now based on firebase_options
  static const String _projectId = 'truemark-5f8bb'; // From firebase_options.dart
  static const String _baseUrl = 'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  Future<String?> _getAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<void> registerOwnership(OwnershipRecord record) async {
    final token = await _getAuthToken();
    if (token == null) throw Exception("User not authenticated");

    final url = Uri.parse('$_baseUrl/ownership_records/${record.imageHash}');
    
    // Firestore REST API Format
    final body = {
      "fields": {
        "imageId": {"stringValue": record.imageId},
        "ownerUid": {"stringValue": record.ownerUid},
        "ownerEmail": {"stringValue": record.ownerEmail},
        "timestamp": {"doubleValue": record.timestamp},
        "imageHash": {"stringValue": record.imageHash},
        "signature": {"stringValue": record.signature},
      }
    };

    final response = await http.patch(
      url, // Use PATCH to Create/Update
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception("Firestore REST Error: ${response.body}");
    }
  }

  Future<OwnershipRecord?> verifyOwnership(String imageHash) async {
    final token = await _getAuthToken();
    if (token == null) throw Exception("User not authenticated");

    final url = Uri.parse('$_baseUrl/ownership_records/$imageHash');
    
    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception("Firestore REST Error: ${response.body}");
    }

    final json = jsonDecode(response.body);
    final fields = json['fields'];
    
    // Parse Firestore REST Format back to Object
    return OwnershipRecord(
      imageId: fields['imageId']['stringValue'],
      ownerUid: fields['ownerUid']['stringValue'],
      ownerEmail: fields['ownerEmail']['stringValue'],
      timestamp: (fields['timestamp']['doubleValue'] ?? fields['timestamp']['integerValue'] ?? 0).toDouble(),
      imageHash: fields['imageHash']['stringValue'],
      signature: fields['signature']['stringValue'],
    );
  }
}
