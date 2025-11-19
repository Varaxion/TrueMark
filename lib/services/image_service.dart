// lib/services/image_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImageService {
  ImageService._(); // static-only

  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;
  static final _collection = _firestore.collection('userMeta');

  /// Ensure we have a signed-in user.
  /// If [allowAnonymousFallback] is true, sign in anonymously when no user exists.
  /// Otherwise throw if no authenticated user is present.
  static Future<User> ensureSignedIn({bool allowAnonymousFallback = false}) async {
    User? user = _auth.currentUser;
    if (user != null) return user;

    if (!allowAnonymousFallback) {
      throw Exception('No authenticated user. Set allowAnonymousFallback=true to sign in anonymously.');
    }

    final cred = await _auth.signInAnonymously();
    user = cred.user;
    if (user == null) throw Exception('Failed to sign in anonymously.');
    return user;
  }

  /// Ensures the user meta doc exists and returns a map with baseNumber and imageCount.
  /// If missing, creates the doc with a random baseNumber and imageCount 0.
  static Future<Map<String, dynamic>> ensureUserMeta({bool allowAnonymousFallback = false}) async {
    final user = await ensureSignedIn(allowAnonymousFallback: allowAnonymousFallback);
    final docRef = _collection.doc(user.uid);

    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>;
      return {
        'baseNumber': (data['baseNumber'] ?? '').toString(),
        'imageCount': (data['imageCount'] ?? 0) as int,
      };
    } else {
      final rnd = Random();
      final base = (100000 + rnd.nextInt(900000)).toString(); // 6-digit base
      await docRef.set({
        'baseNumber': base,
        'imageCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return {'baseNumber': base, 'imageCount': 0};
    }
  }

  /// Atomically increments the user's imageCount and returns the generated id "<baseNumber><newCount>".
  /// Uses a transaction to ensure atomicity.
  static Future<String> generateNextImageId({bool allowAnonymousFallback = false}) async {
    final user = await ensureSignedIn(allowAnonymousFallback: allowAnonymousFallback);
    final docRef = _collection.doc(user.uid);

    final result = await _firestore.runTransaction<String>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        // create with a random base and count 1
        final rnd = Random();
        final base = (100000 + rnd.nextInt(900000)).toString();
        tx.set(docRef, {
          'baseNumber': base,
          'imageCount': 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return '$base${1}';
      } else {
        final data = snap.data() as Map<String, dynamic>;
        final baseNumber = (data['baseNumber'] ?? '').toString();
        final currentCount = (data['imageCount'] ?? 0) as int;
        final nextCount = currentCount + 1;
        tx.update(docRef, {'imageCount': nextCount});
        return '$baseNumber$nextCount';
      }
    });

    return result;
  }

  /// Read-only helper to fetch baseNumber + count if you need to show them:
  static Future<Map<String, dynamic>> fetchUserMeta({bool allowAnonymousFallback = false}) async {
    final user = await ensureSignedIn(allowAnonymousFallback: allowAnonymousFallback);
    final snap = await _collection.doc(user.uid).get();
    if (!snap.exists) return {};
    final d = snap.data() as Map<String, dynamic>;
    return {
      'baseNumber': (d['baseNumber'] ?? '').toString(),
      'imageCount': (d['imageCount'] ?? 0) as int,
    };
  }
}
