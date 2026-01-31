// lib/screens/mark_image_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_service.dart';
import 'package:path_provider/path_provider.dart';
import '../services/steg_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../models/ownership_record.dart';
import '../utils/constants.dart';
import '../utils/admin_config.dart';

class MarkImageScreen extends StatefulWidget {
  const MarkImageScreen({Key? key}) : super(key: key);

  @override
  State<MarkImageScreen> createState() => _MarkImageScreenState();
}

class _MarkImageScreenState extends State<MarkImageScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;
  bool _loading = false;
  String? _error;

  // numbering fields
  String? _baseNumber;
  int _imageCount = 0;
  String? _lastGeneratedId;
  bool _processing = false;
  bool _processedSuccess = false;
  String? _processedLocalPath;

  @override
  void initState() {
    super.initState();
    _ensureSignedInAndMeta();
  }

  Future<void> _ensureSignedInAndMeta() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // false = do not fallback to anonymous
      final meta = await ImageService.ensureUserMeta(allowAnonymousFallback: false);
      setState(() {
        _baseNumber = meta['baseNumber'] as String?;
        _imageCount = meta['imageCount'] as int? ?? 0;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to prepare user meta: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (file == null) {
        setState(() => _loading = false);
        return;
      }
      final generatedId = await ImageService.generateNextImageId(allowAnonymousFallback: false);

      setState(() {
        _pickedFile = file;
        _lastGeneratedId = generatedId;
        if (_baseNumber != null && generatedId.startsWith(_baseNumber!)) {
           // simple parse logic
           _imageCount++; 
        }
      });
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickFromCamera() async {
     setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (file == null) {
        setState(() => _loading = false);
        return;
      }
      final generatedId = await ImageService.generateNextImageId(allowAnonymousFallback: false);

      setState(() {
        _pickedFile = file;
        _lastGeneratedId = generatedId;
        // count update logic
      });
    } catch (e) {
      setState(() => _error = 'Failed to capture image: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _removeImage() {
    setState(() {
      _pickedFile = null;
      _error = null;
      _lastGeneratedId = null;
      _processedSuccess = false;
      _processedLocalPath = null;
    });
  }

  Future<void> _processPickedImage() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick an image first.')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _processing = true;
      _error = null;
      _processedSuccess = false;
    });

    try {
      final inFile = File(_pickedFile!.path);
      final imageBytes = await inFile.readAsBytes();
      
      // 1. Calculate Original Image Hash (Identity of the content)
      final originalHash = sha256.convert(imageBytes).toString();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toDouble();
      
      // 2. Generate Signature Payload
      // Format: "UID|Timestamp|Hash"
      // This string will be encrypted and hidden inside the image.
      final signaturePayload = '${user.uid}|$timestamp|$originalHash';
      
      // 3. Use Shared Key so Receivers can Decrypt/Verify
      // (Security is strictly enforced by the Image Hash check, not the key secrecy)
      const encryptionPassword = kTrueMarkSharedKey; 

      final dir = await getTemporaryDirectory();
      // Filename includes timestamp to avoid collisions
      final outPath = '${dir.path}/TrueMark_${DateTime.now().millisecondsSinceEpoch}.png';
      final outFile = File(outPath);

      // 4. Embed Encrypted Signature into Image (Invisible Watermark)
      // StegService handles the AES Encryption using the password internally.
      final processedFile = await StegService.embedStringInImage(
        inputFile: inFile,
        plaintext: signaturePayload,
        password: encryptionPassword,
        outputFile: outFile,
      );

      // 5. Register Ownership in Firestore (Immutable Record)
      // The presence of this record proves *when* it was created.
      // We use the Original Hash as the ID.
      final record = OwnershipRecord(
        imageId: const Uuid().v4(), // Unique event ID
        ownerUid: user.uid,
        ownerEmail: user.email ?? 'Unknown',
        timestamp: timestamp,
        imageHash: originalHash,
        signature: 'Embedded (AES-256)',
      );
      
      await FirebaseFirestore.instance
          .collection('ownership_records')
          .doc(originalHash)
          .set(record.toMap());

      setState(() {
        _processedLocalPath = processedFile.path;
        _processedSuccess = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Protected Image Saved: ${processedFile.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        )
      );
    } catch (e) {
      print(e);
      setState(() => _error = 'Protection failed: $e');
    } finally {
      setState(() => _processing = false);
    }
  }

  Widget _buildUploaderCard() {
    return GestureDetector(
      onTap: _loading ? null : _pickFromGallery,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo.shade200, width: 2),
          // Dotted border effect simulation or just solid
        ),
        child: _pickedFile == null
            ? const Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.shield_outlined, size: 48, color: Colors.indigo),
                   SizedBox(height: 10),
                   Text('Tap to Protect Image', style: TextStyle(fontSize: 16)),
                ],
              ))
            : Image.file(File(_pickedFile!.path), fit: BoxFit.cover),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protect Image'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildUploaderCard(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.image),
                  label: const Text('Gallery'),
                ),
                ElevatedButton.icon(
                  onPressed: _pickFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_pickedFile != null)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _processing ? null : _processPickedImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: _processing 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('APPLY TRUEMARK PROTECTION'),
                ),
              ),
            if (_processedSuccess) ...[
               const SizedBox(height: 20),
               const Card(
                 color: Colors.greenAccent,
                 child: Padding(
                   padding: EdgeInsets.all(12),
                   child: Row(children: [
                     Icon(Icons.check_circle),
                     SizedBox(width: 10),
                     Expanded(child: Text('Image Protected Successfully!\nSaved to gallery/temp.'))
                   ]),
                 ),
               )
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}