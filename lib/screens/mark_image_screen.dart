// lib/screens/mark_image_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/image_service.dart';
import 'package:path_provider/path_provider.dart';
import '../services/steg_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_rest_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../models/ownership_record.dart';
import '../utils/constants.dart';

class MarkImageScreen extends StatefulWidget {
  const MarkImageScreen({super.key});

  @override
  State<MarkImageScreen> createState() => _MarkImageScreenState();
}

class _MarkImageScreenState extends State<MarkImageScreen> {
  XFile? _pickedFile;
  bool _loading = false;
  String? _error;

  // numbering fields
  String? _baseNumber;
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Using 'any' to avoid potential Windows filter crash
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      
      final path = result.files.single.path!;
      setState(() {
        _pickedFile = XFile(path); // Wrap in XFile to keep compatible with Image widget logic
      });
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _enterPathManually() async {
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Image Path'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'C:\\Users\\...\\image.png',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.replaceAll('"', '')), // Remove quotes if copy-pasted
            child: const Text('Use This Path'),
          ),
        ],
      ),
    );

    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
         setState(() {
           _pickedFile = XFile(path);
           _error = null;
         });
      } else {
        setState(() => _error = 'File does not exist: $path');
      }
    }
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

      // 3b. Prompt User to Save File
      String? outputFilePath;
      
      final originalNameWithExt = inFile.uri.pathSegments.last;
      String originalName = originalNameWithExt;
      if (originalName.contains('.')) {
        originalName = originalName.split('.').first;
      }
      
      // Sanitize filename for cross-platform safety
      originalName = originalName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      // Intelligent Naming: [Original]_tm[UserBaseRef]_[Timestamp].png
      // Example: celestial_tm102030_1739812312.png
      final baseRef = _baseNumber ?? 'anon';
      final fileName = '${originalName}_tm${baseRef}_$timestamp.png';

       if (kSafeModeWindows && Platform.isWindows) {
        // Safe Mode: Manual Entry for Output Path
        final controller = TextEditingController(text: fileName);
        outputFilePath = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save Protected Image'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter full destination path or filename:'),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'C:\\Users\\...\\image.png',
                    labelText: 'File Name / Path',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.replaceAll('"', '')), 
                child: const Text('Save')
              )
            ],
          ),
        );
      } else if (Platform.isAndroid || Platform.isIOS) {
         // Mobile: Save to External Storage (Android) or Documents (iOS)
         final directory = Platform.isAndroid 
             ? await getExternalStorageDirectory() // /storage/emulated/0/Android/data/.../files
             : await getApplicationDocumentsDirectory();
         
         if (directory == null) {
            throw Exception("Could not access storage directory");
         }
         outputFilePath = '${directory.path}/$fileName';
      } else {
         // Desktop Standard: Use File Picker
         outputFilePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Protected Image To...',
          fileName: fileName,
        );
      }

      if (outputFilePath == null || outputFilePath.isEmpty) {
        setState(() => _processing = false);
        return;
      }
      
      final outFile = File(outputFilePath);

      // 4. Embed Encrypted Signature into Image
      final processedFile = await StegService.embedStringInImage(
        inputFile: inFile,
        plaintext: signaturePayload,
        password: encryptionPassword,
        outputFile: outFile,
      );

      // 5. Create Ownership Record
      final record = OwnershipRecord(
        imageId: const Uuid().v4(), 
        ownerUid: user.uid,
        ownerEmail: user.email ?? 'Unknown',
        timestamp: timestamp,
        imageHash: originalHash,
        signature: 'Embedded (AES-256)',
      );
      
      if (Platform.isWindows) {
        // Windows: Use REST API to avoid C++ Crash
        print('WINDOWS: Using Firestore REST API...');
        final restService = FirestoreRestService();
        await restService.registerOwnership(record);
      } else {
        // Android/iOS: Use Native SDK
        await FirebaseFirestore.instance
            .collection('ownership_records')
            .doc(originalHash)
            .set(record.toMap());
      }

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

      // Auto-Share removed. User must click "Share / Save Copy" button.
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
                   Icon(Icons.shield, size: 60, color: Colors.indigo),
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
            if (kSafeModeWindows && Platform.isWindows) ...[
                // SAFE MODE UI: Manual Path Only
                if (!Platform.isAndroid && !Platform.isIOS) ...[
                 const Card(
                   color: Colors.amberAccent,
                   child: Padding(
                     padding: EdgeInsets.all(8.0),
                     child: Text('⚠️ WINDOWS SAFE MODE ACTIVE\nUsing Manual Paths to bypass crash.'),
                   ),
                 ),
                 const SizedBox(height: 10),
                 ElevatedButton.icon(
                   onPressed: _enterPathManually,
                   icon: const Icon(Icons.folder_open),
                   label: const Text('Select Source Image (Manual Path)'),
                 ),
                ]
            ] else ...[
                // STANDARD UI
                _buildUploaderCard(),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Select an image from your gallery. TrueMark will embed an invisible, encrypted signature linked to your identity, creating a permanent proof of ownership.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 13),
                  ),
                ),
            ],

            const SizedBox(height: 20),

            if (_pickedFile != null) ...[
              if (kSafeModeWindows) ...[
                 Text('Selected: ${_pickedFile!.path}', style: const TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 10),
              ],
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
            ],
            
            if (_processedSuccess) ...[
               const SizedBox(height: 20),
               Card(
                 color: Colors.greenAccent,
                 child: Padding(
                   padding: const EdgeInsets.all(12),
                   child: Row(children: [
                     const Icon(Icons.check_circle),
                     const SizedBox(width: 10),
                     Expanded(child: Text('Success!\nSaved to: $_processedLocalPath'))
                   ]),
                 ),
               ),
               const SizedBox(height: 16),
               SizedBox(
                 width: double.infinity,
                 height: 50,
                 child: ElevatedButton.icon(
                   onPressed: () {
                     if (_processedLocalPath != null) {
                       Share.shareXFiles([XFile(_processedLocalPath!)], text: 'TrueMark Protected Image');
                     }
                   },
                   icon: const Icon(Icons.share),
                   label: const Text('SHARE / SAVE COPY'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.teal,
                     foregroundColor: Colors.white,
                   ),
                 ),
               ),
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