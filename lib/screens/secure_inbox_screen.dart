import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/transfer_metadata.dart';
import '../services/firestore_service.dart';
import '../services/secure_transmission_service.dart';

class SecureInboxScreen extends StatefulWidget {
  const SecureInboxScreen({super.key});

  @override
  State<SecureInboxScreen> createState() => _SecureInboxScreenState();
}

class _SecureInboxScreenState extends State<SecureInboxScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final SecureTransmissionService _transmissionService = SecureTransmissionService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  bool _isProcessing = false;

  Future<void> _handleSendFile() async {
    // 1. Pick File
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    
    if (result == null) return;
    
    Uint8List? fileBytes = result.files.single.bytes;
    final fileName = result.files.single.name;

    // On Desktop/Mobile, 'bytes' is often null, so we read from 'path'
    if (fileBytes == null && result.files.single.path != null) {
      fileBytes = await File(result.files.single.path!).readAsBytes();
    }

    if (fileBytes == null) return; // Should not happen if path exists

    setState(() => _isProcessing = true);

    try {
      // 2. Prepare Secure Payload (Encrypt + Carrier Gen + XOR)
      // Note: In real app, you'd pick a specific receiver. For demo, we send to ourselves or a test user.
      final receiverId = _currentUserId; 
      
      final prepResult = await _transmissionService.prepareUpload(
        fileBytes: fileBytes,
        userContext: utf8.encode(_currentUserId),
      );

      final payload = prepResult['payload'];
      final metaMap = prepResult['metadata'];
      final rawKey = prepResult['raw_key'];

      // Note: In MVP, we are skipping the RSA Wrapping of 'rawKey' for simplicity.
      // We assume the channel (Firestore TLS) is secure enough for this Phase 1.
      // Real implementation would: rawKey = RSA_Encrypt(ReceiverPubKey, rawKey)

      final metadata = TransferMetadata(
        id: '', // Set by service
        senderId: _currentUserId,
        receiverId: receiverId,
        fileName: fileName,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        seed: base64Encode(metaMap['seed']),
        iv: base64Encode(metaMap['iv']),
        authTag: base64Encode(metaMap['tag']),
        wrappedKey: base64Encode(rawKey), // Sending raw key for MVP (WARN: Fix in Phase X)
        payloadUrl: '', // Set by service
      );

      // 3. Upload
      await _firestoreService.sendFileTransfer(
        stegoPayload: payload,
        metadata: metadata,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Secure Transfer Sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDecrypt(TransferMetadata metadata) async {
    setState(() => _isProcessing = true);

    try {
      // 1. Download Stego Payload
      final response = await http.get(Uri.parse(metadata.payloadUrl));
      if (response.statusCode != 200) throw Exception('Download failed');
      final stegoPayload = response.bodyBytes;

      // 2. Run Decryption Pipeline
      final recoveredBytes = await _transmissionService.receiveAndDecrypt(
        stegoPayload: stegoPayload,
        seed: base64Decode(metadata.seed),
        iv: base64Decode(metadata.iv),
        tag: base64Decode(metadata.authTag),
        kImgBytes: base64Decode(metadata.wrappedKey),
      );

      // 3. Success (For now just show size, normally we'd save/open it)
      if (mounted) {
         showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Decryption Successful'),
            content: Text('Recovered file: ${metadata.fileName}\nSize: ${recoveredBytes.length} bytes\n\nIntegrity verified.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Decryption Failed'),
            content: Text('Integrity check failed. The file may have been tampered with.\n\nError: $e'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Inbox')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _handleSendFile,
        label: const Text('Encrypt & Send'),
        icon: const Icon(Icons.lock_person),
      ),
      body: StreamBuilder<List<TransferMetadata>>(
        stream: _firestoreService.getIncomingTransfers(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final transfers = snapshot.data!;
          if (transfers.isEmpty) {
            return const Center(child: Text('No secure messages yet.'));
          }

          return ListView.builder(
            itemCount: transfers.length,
            itemBuilder: (context, index) {
              final item = transfers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.security, color: Colors.green),
                  title: Text(item.fileName),
                  subtitle: Text('ID: ${item.id.substring(0, 8)}...'),
                  trailing: IconButton(
                    icon: const Icon(Icons.download_for_offline),
                    onPressed: _isProcessing ? null : () => _handleDecrypt(item),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
