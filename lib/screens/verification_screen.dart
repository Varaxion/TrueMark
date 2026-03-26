import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/steg_service.dart';
import '../services/firestore_service.dart';
import '../services/firestore_rest_service.dart';
import '../utils/constants.dart';
import '../models/ownership_record.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  File? _imageFile;
  bool _scanning = false;
  
  // Verification Results
  bool _hasResult = false;
  bool _isSignatureValid = false;
  OwnershipRecord? _record;
  String _statusMessage = '';

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any, 
      allowMultiple: false
    );
    
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.single.path!;
      setState(() {
        _imageFile = File(path);
        _hasResult = false;
        _statusMessage = '';
      });
      _performVerification();
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
            decoration: const InputDecoration(hintText: 'C:\\path\\to\\image.png'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.replaceAll('"', '')),
              child: const Text('Verify This File'),
            )
          ],
        ),
      );

      if (path != null && path.isNotEmpty) {
        setState(() {
          _imageFile = File(path);
          _hasResult = false;
          _statusMessage = '';
        });
        _performVerification();
      }
  }

  Future<void> _performVerification() async {
    if (_imageFile == null) return;

    setState(() {
      _scanning = true;
      _statusMessage = 'Scanning for TrueMark signature...';
      _hasResult = false;
    });

    // Artifical delay for "Scanning" feel
    await Future.delayed(const Duration(seconds: 2));

    try {
      // 1. Attempt to Extract Signature
      final extractedPayload = await StegService.extractStringFromImage(
        inputFile: _imageFile!,
        password: kTrueMarkSharedKey,
      );

      if (extractedPayload == null) {
        setState(() {
          _scanning = false;
          _hasResult = true;
          _isSignatureValid = false;
          _statusMessage = 'No TrueMark Signature found.\nThis image is likely unprotected or has been tampered with (stripped).';
        });
        return;
      }

      // 2. Parse Payload "UID|Timestamp|Hash"
      final parts = extractedPayload.split('|');
      if (parts.length != 3) {
         setState(() {
          _scanning = false;
          _hasResult = true;
          _isSignatureValid = false;
          _statusMessage = 'Corrupted Signature Found.\nStructure mismatch.';
        });
        return;
      }

      final uid = parts[0];
      // final timestampStr = parts[1]; // unused
      final originalHash = parts[2];
      
      
      OwnershipRecord? record;

      if (Platform.isWindows) {
         // REST API for Windows
         print('WINDOWS: Verifying via REST API...');
         final restService = FirestoreRestService();
         record = await restService.verifyOwnership(originalHash);
         // Note: If 404, record is null
      } else {
         // Native SDK for Android
         final service = FirestoreService();
         record = await service.verifyOwnership(originalHash);
      }
      
      // If SafeMode (Manual Picker) is active, we still try the REST call first.
      // If REST fails (e.g. auth error, network), we could fall back to offline, 
      // but "Solving Problem Completely" implies we want the DB check.


      if (record == null) {
         setState(() {
          _scanning = false;
          _hasResult = true;
          _isSignatureValid = false;
          _statusMessage = 'Signature is Fake.\nNo matching record found in TrueMark Cloud Registry.';
        });
        return;
      }

      // 4. Double check UID match
      if (record.ownerUid != uid) {
          setState(() {
          _scanning = false;
          _hasResult = true;
          _isSignatureValid = false;
          _statusMessage = 'Identity Mismatch.\nSignature ID does not match Registry Owner.';
        });
        return;
      }
      
      // Update message
      _statusMessage = 'SUCCESS: Image Authenticated!\nVerified against TrueMark Cloud Registry.';

      // SUCCESS
      setState(() {
        _scanning = false;
        _hasResult = true;
        _isSignatureValid = true;
        _record = record;
        // _statusMessage already set
      });

    } catch (e) {
      setState(() {
        _scanning = false;
        _hasResult = true;
        _isSignatureValid = false;
        _statusMessage = 'Error during verification: $e';
      });
    }
  }

  Widget _buildResultCard() {
    if (!_hasResult) return const SizedBox.shrink();

    if (!_isSignatureValid) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 10),
            const Text(
              'VERIFICATION FAILED',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        ),
      );
    }

    // Success Card
    final date = DateTime.fromMillisecondsSinceEpoch(_record!.timestamp.toInt());
    final fmtDate = DateFormat.yMMMd().add_jm().format(date);
    // Safer substring logic with string interpolation
    final hashPreview = (_record!.imageHash.length > 10) 
        ? '${_record!.imageHash.substring(0, 10)}...' 
        : _record!.imageHash;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified, color: Colors.teal, size: 70),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'AUTHENTIC IMAGE',
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1),
            ),
          ),
          const Divider(height: 30),
          _infoRow('Creator', _record!.ownerEmail),
          _infoRow('Created', fmtDate),
          _infoRow('Registry ID', hashPreview),

        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Image')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             InkWell(
               onTap: _scanning ? null : (kSafeModeWindows ? _enterPathManually : _pickImage),
               child: Container(
                 height: 200,
                 width: double.infinity,
                 decoration: BoxDecoration(
                   color: kSafeModeWindows ? Colors.amber.shade50 : Colors.grey.shade200,
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: kSafeModeWindows ? Colors.amber : Colors.grey.shade400),
                 ),
                 child: _imageFile != null
                     ? ClipRRect(
                         borderRadius: BorderRadius.circular(16),
                         child: Image.file(_imageFile!, fit: BoxFit.cover),
                       )
                     : Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(kSafeModeWindows ? Icons.folder_open : Icons.verified, 
                                size: 50, 
                                color: kSafeModeWindows ? Colors.amber.shade800 : Colors.teal),
                           const SizedBox(height: 10),
                           Text(kSafeModeWindows 
                                ? 'Tap to Select Image (Safe Mode)' 
                                : 'Tap to Verify Image'),
                         ],
                       ),
               ),
             ),
             const SizedBox(height: 16),
             if (!_scanning && !_hasResult)
               const Padding(
                 padding: EdgeInsets.symmetric(horizontal: 16.0),
                 child: Text(
                   'Scan a suspicious image to reveal its hidden metadata. If it was protected with TrueMark, we will display the creator\'s identity and creation date.',
                   textAlign: TextAlign.center,
                   style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 13),
                 ),
               ),

             const SizedBox(height: 30),
             if (_scanning) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_statusMessage),
             ] else ...[
                _buildResultCard(),
             ],
             const SizedBox(height: 20),
             if ((kSafeModeWindows && Platform.isWindows) || (!Platform.isAndroid && !Platform.isIOS)) ...[
                // Desktop / Web Debug Option
                TextButton(
                  onPressed: _enterPathManually,
                  child: const Text('Enter Path Manually (Debug)'),
                )
             ]
          ],
        ),
      ),
    );
  }
}