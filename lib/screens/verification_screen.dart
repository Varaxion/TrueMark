// lib/screens/verification_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/steg_service.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({Key? key}) : super(key: key);

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;
  bool _loading = false;
  String? _error;
  String? _extractedPayload; // decrypted string extracted
  String? _verificationResult; // human readable result
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _error = null;
      _extractedPayload = null;
      _verificationResult = null;
    });

    try {
      final XFile? f = await _picker.pickImage(source: ImageSource.gallery);
      if (f == null) return;
      setState(() { _pickedFile = f; });
    } catch (e) {
      setState(() { _error = 'Failed to pick image: $e'; });
    }
  }

  Future<void> _verify() async {
    if (_pickedFile == null) {
      setState(() { _error = 'Pick an image first.'; });
      return;
    }
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() { _error = 'Enter the encryption password (image id) to try decryption.'; });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _extractedPayload = null;
      _verificationResult = null;
    });

    try {
      final file = File(_pickedFile!.path);

      // Attempt extraction and decryption. This should return the plaintext embedded string or null.
      final extracted = await StegService.extractStringFromImage(
        inputFile: file,
        password: password,
      );

      if (extracted == null) {
        setState(() {
          _extractedPayload = null;
          _verificationResult = 'No valid embedded payload found or decryption failed with the given password.';
        });
        return;
      }

      setState(() {
        _extractedPayload = extracted;
      });

      // If extraction succeeded, check Firestore record for this user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _verificationResult = 'Not signed in; cannot verify against Firestore.';
        });
        return;
      }

      // We expect imageId format equals extracted (your scheme)
      final imageId = extracted;
      final docRef = FirebaseFirestore.instance
          .collection('userMeta')
          .doc(user.uid)
          .collection('images')
          .doc(imageId);

      final doc = await docRef.get();
      if (!doc.exists) {
        setState(() {
          _verificationResult = 'Payload extracted: "$imageId", but no matching record found in Firestore for this user.';
        });
      } else {
        final data = doc.data()!;
        setState(() {
          _verificationResult = 'Verified: extracted id matches Firestore. Stored metadata: ${data.keys.map((k) => "$k").join(", ")}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Verification failed: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _preview() {
    if (_pickedFile == null) {
      return Container(
        height: 220,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo.shade200, width: 2),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,4))],
        ),
        child: const Center(child: Text('No image selected')),
      );
    }
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Image.file(File(_pickedFile!.path), fit: BoxFit.contain),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Verify',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 36,
            color: Colors.indigo,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _preview(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 4,
                  ),
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pick image'),
                ),
                const SizedBox(width: 18),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _pickedFile == null
                      ? null
                      : () {
                          setState(() {
                            _pickedFile = null;
                            _extractedPayload = null;
                            _verificationResult = null;
                          });
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Encryption password (image id)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _loading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      onPressed: _verify,
                      child: const Text('Verify'),
                    ),
                  ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_extractedPayload != null) ...[
              const SizedBox(height: 8),
              Text('Extracted payload: $_extractedPayload', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            if (_verificationResult != null) ...[
              const SizedBox(height: 8),
              Text(_verificationResult!, style: const TextStyle(color: Colors.green)),
            ],
          ],
        ),
      ),
    );
  }
}