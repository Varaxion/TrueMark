import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../services/steg_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../models/ownership_record.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({Key? key}) : super(key: key);

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _scanning = false;
  
  // Verification Results
  bool _hasResult = false;
  bool _isSignatureValid = false;
  OwnershipRecord? _record;
  String _statusMessage = '';

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
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
      final timestampStr = parts[1];
      final originalHash = parts[2];

      // 3. Verify Against Registry (Firestore)
      setState(() => _statusMessage = 'Signature found. Verifying with Space Registry...');
      
      final service = FirestoreService();
      final record = await service.verifyOwnership(originalHash);

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

      // SUCCESS
      setState(() {
        _scanning = false;
        _hasResult = true;
        _isSignatureValid = true;
        _record = record;
        _statusMessage = 'SUCCESS: Image Authenticated!';
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
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.900, fontSize: 22, letterSpacing: 1),
            ),
          ),
          const Divider(height: 30),
          _infoRow('Creator', _record!.ownerEmail),
          _infoRow('Created', fmtDate),
          _infoRow('Registry ID', _record!.imageHash.substring(0, 10) + '...'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {}, 
            child: const Text('View Full Certificate'),
          )
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
               onTap: _scanning ? null : _pickImage,
               child: Container(
                 height: 200,
                 width: double.infinity,
                 decoration: BoxDecoration(
                   color: Colors.grey.shade200,
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: Colors.grey.shade400),
                 ),
                 child: _imageFile != null
                     ? ClipRRect(
                         borderRadius: BorderRadius.circular(16),
                         child: Image.file(_imageFile!, fit: BoxFit.cover),
                       )
                     : const Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.qr_code_scanner, size: 50, color: Colors.indigo),
                           SizedBox(height: 10),
                           Text('Tap to Scan Image'),
                         ],
                       ),
               ),
             ),
             const SizedBox(height: 30),
             if (_scanning) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_statusMessage),
             ] else ...[
                _buildResultCard(),
             ]
          ],
        ),
      ),
    );
  }
}