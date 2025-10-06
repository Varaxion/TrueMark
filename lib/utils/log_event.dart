import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> logLoginAttempt({required String method}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseFirestore.instance.collection('login_attempts').add({
    'uid': user.uid,
    'emailOrPhone': user.email ?? user.phoneNumber ?? 'unknown',
    'loginMethod': method,
    'timestamp': FieldValue.serverTimestamp(),
  });
}