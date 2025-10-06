import 'package:cloud_firestore/cloud_firestore.dart';

class UserUtils {
  static Future<bool> hasProfile(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.exists;
  }
}