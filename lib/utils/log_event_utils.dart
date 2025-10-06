import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> logLoginAttempt(String method, bool success, String message) async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown";
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection("login_attempts").add({
      'userId': uid,
      'method': method,
      'success': success,
      'message': message,
      'timestamp': now.toIso8601String(),
    });
  } catch (e) {
    print("Failed to log login attempt: $e");
  }
}