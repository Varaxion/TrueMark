import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../services/image_service.dart';
import '../services/steg_service.dart';
import '../services/firestore_rest_service.dart';
import '../services/firestore_service.dart';
import '../models/ownership_record.dart';
import '../utils/constants.dart';
import '../utils/admin_config.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path/path.dart' as p;
import 'true_vault_screen.dart';

class TrueSignScreen extends StatefulWidget {
  final bool isProtectMode; // true = Protect tab, false = Verify tab

  const TrueSignScreen({super.key, required this.isProtectMode});

  @override
  State<TrueSignScreen> createState() => _TrueSignScreenState();
}

class _TrueSignScreenState extends State<TrueSignScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Protect Tab State
  File? _fileToProtect;
  bool _protecting = false;
  bool _protectSuccess = false;
  String? _protectedFilePath;
  String? _baseNumber;

  // Verify Tab State
  File? _fileToVerify;
  bool _verifying = false;
  bool _hasVerifyResult = false;
  bool _isSignatureValid = false;
  OwnershipRecord? _verifyRecord;
  String _verifyMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.isProtectMode ? 0 : 1,
    );
    _ensureUserMeta();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _ensureUserMeta() async {
    try {
      final meta = await ImageService.ensureUserMeta(allowAnonymousFallback: false);
      setState(() {
        _baseNumber = meta['baseNumber'] as String?;
      });
    } catch (e) {
      // Silent fail for now
    }
  }

  // --- PROTECT TAB ACTIONS ---

  Future<void> _pickImageToProtect() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _fileToProtect = File(result.files.single.path!);
        _protectSuccess = false;
        _protectedFilePath = null;
      });
    }
  }

  Future<void> _pickImageToProtectFromVault() async {
    final File? file = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: true)),
    );

    if (file != null) {
      setState(() {
        _fileToProtect = file;
        _protectSuccess = false;
        _protectedFilePath = null;
      });
    }
  }

  Future<void> _saveToVault(String path) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showToast("Error: Account not logged in.", backgroundColor: Colors.red);
        return;
      }
      final root = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${root.path}/TrueVault_${user.uid}');
      if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
      
      final fileToSave = File(path);
      final newPath = '${vaultDir.path}/${p.basename(fileToSave.path)}';
      await fileToSave.copy(newPath);
      showToast("File securely preserved in TrueVault!", position: ToastPosition.bottom, backgroundColor: Colors.green);
    } catch (e) {
      showToast("Error saving to vault", backgroundColor: Colors.red);
    }
  }

  Future<void> _performProtection() async {
    if (_fileToProtect == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _protecting = true;
      _protectSuccess = false;
    });

    try {
      final imageBytes = await _fileToProtect!.readAsBytes();
      final originalHash = sha256.convert(imageBytes).toString();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toDouble();
      final signaturePayload = '${user.uid}|$timestamp|$originalHash';

      // Generate output path
      final originalName = _fileToProtect!.uri.pathSegments.last.split('.').first;
      final baseRef = _baseNumber ?? 'anon';
      final fileName = '${originalName}_tm${baseRef}_$timestamp.png';

      String? outputPath;
      if (Platform.isAndroid || Platform.isIOS) {
        final directory = Platform.isAndroid
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();
        if (directory == null) throw Exception("Could not access storage");
        outputPath = '${directory.path}/$fileName';
      } else {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Protected Image',
          fileName: fileName,
        );
      }

      if (outputPath == null || outputPath.isEmpty) {
        setState(() => _protecting = false);
        return;
      }

      final outFile = File(outputPath);

      // Embed signature
      final processedFile = await StegService.embedStringInImage(
        inputFile: _fileToProtect!,
        plaintext: signaturePayload,
        password: kTrueMarkSharedKey,
        outputFile: outFile,
      );

      // Register ownership
      final record = OwnershipRecord(
        imageId: const Uuid().v4(),
        ownerUid: user.uid,
        ownerEmail: user.email ?? 'Unknown',
        timestamp: timestamp,
        imageHash: originalHash,
        signature: 'Embedded (AES-256)',
      );

      if (Platform.isWindows) {
        final restService = FirestoreRestService();
        await restService.registerOwnership(record);
      } else {
        await FirebaseFirestore.instance
            .collection('ownership_records')
            .doc(originalHash)
            .set(record.toMap());
      }

      setState(() {
        _protecting = false;
        _protectSuccess = true;
        _protectedFilePath = processedFile.path;
      });
    } catch (e) {
      setState(() => _protecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Protection failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // --- VERIFY TAB ACTIONS ---

  Future<void> _pickImageToVerify() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _fileToVerify = File(result.files.single.path!);
        _hasVerifyResult = false;
        _verifyMessage = '';
      });
      _performVerification();
    }
  }

  Future<void> _pickImageToVerifyFromVault() async {
    final File? file = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: true)),
    );

    if (file != null) {
      setState(() {
        _fileToVerify = file;
        _hasVerifyResult = false;
        _verifyMessage = '';
      });
      _performVerification();
    }
  }

  Future<void> _performVerification() async {
    if (_fileToVerify == null) return;

    setState(() {
      _verifying = true;
      _hasVerifyResult = false;
      _verifyMessage = 'Scanning for TrueMark signature...';
    });

    await Future.delayed(const Duration(seconds: 2));

    try {
      final extractedPayload = await StegService.extractStringFromImage(
        inputFile: _fileToVerify!,
        password: kTrueMarkSharedKey,
      );

      if (extractedPayload == null) {
        setState(() {
          _verifying = false;
          _hasVerifyResult = true;
          _isSignatureValid = false;
          _verifyMessage = 'No TrueMark Signature found.\nThis image is likely unprotected or tampered.';
        });
        return;
      }

      final parts = extractedPayload.split('|');
      if (parts.length != 3) {
        setState(() {
          _verifying = false;
          _hasVerifyResult = true;
          _isSignatureValid = false;
          _verifyMessage = 'Corrupted Signature Found.';
        });
        return;
      }

      final uid = parts[0];
      final originalHash = parts[2];

      OwnershipRecord? record;
      if (Platform.isWindows) {
        final restService = FirestoreRestService();
        record = await restService.verifyOwnership(originalHash);
      } else {
        final service = FirestoreService();
        record = await service.verifyOwnership(originalHash);
      }

      if (record == null) {
        setState(() {
          _verifying = false;
          _hasVerifyResult = true;
          _isSignatureValid = false;
          _verifyMessage = 'Signature is Fake.\nNo matching record found in TrueMark Registry.';
        });
        return;
      }

      if (record.ownerUid != uid) {
        setState(() {
          _verifying = false;
          _hasVerifyResult = true;
          _isSignatureValid = false;
          _verifyMessage = 'Identity Mismatch.\nSignature does not match Registry Owner.';
        });
        return;
      }

      setState(() {
        _verifying = false;
        _hasVerifyResult = true;
        _isSignatureValid = true;
        _verifyRecord = record;
        _verifyMessage = 'SUCCESS: Image Authenticated!\nVerified against TrueMark Registry.';
      });
    } catch (e) {
      setState(() {
        _verifying = false;
        _hasVerifyResult = true;
        _isSignatureValid = false;
        _verifyMessage = 'Verification Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF0097A7)], // Indigo to Teal
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    const Expanded(
                      child: Text(
                        "TrueSign",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: "PROTECT", icon: Icon(Icons.shield_rounded)),
                      Tab(text: "VERIFY", icon: Icon(Icons.verified_rounded)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProtectTab(),
                    _buildVerifyTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtectTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Feature Header
          const Icon(Icons.verified_user_rounded, size: 80, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            "Protect Your Image",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Embed an invisible, encrypted signature linked to your identity. Create permanent proof of ownership.",
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Image Picker Card
          GestureDetector(
            onTap: _protecting ? null : _pickImageToProtect,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white30, width: 2),
              ),
              child: _fileToProtect == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, size: 60, color: Colors.white70),
                          SizedBox(height: 10),
                          Text('Tap to Select Image', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_fileToProtect!, fit: BoxFit.cover),
                    ),
            ),
          ),

          if (_fileToProtect == null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _protecting ? null : _pickImageToProtectFromVault,
              icon: const Icon(Icons.lock_person_rounded, size: 20),
              label: const Text("LOAD FROM TRUEVAULT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Protect Button (Always Visible)
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: (_fileToProtect == null || _protecting) ? null : _performProtection,
              icon: _protecting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.shield_rounded),
              label: Text(_protecting ? 'PROTECTING...' : 'APPLY PROTECTION'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Success Area
          if (_protectSuccess) ...[
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.greenAccent),
                      SizedBox(width: 10),
                      Text("Protection Applied!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_protectedFilePath != null) {
                          Share.shareXFiles([XFile(_protectedFilePath!)], text: 'TrueMark Protected Image');
                        }
                      },
                      icon: const Icon(Icons.share),
                      label: const Text("SHARE / SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, 
                        foregroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_protectedFilePath != null) {
                          _saveToVault(_protectedFilePath!);
                        }
                      },
                      icon: const Icon(Icons.security),
                      label: const Text("STORE SECURELY IN VAULT", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerifyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Feature Header
          const Icon(Icons.verified, size: 80, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            "Verify Image Authenticity",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Scan any image to reveal hidden metadata. If protected with TrueMark, we'll display the creator's identity and creation date.",
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Image Picker Card
          GestureDetector(
            onTap: _verifying ? null : _pickImageToVerify,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white30, width: 2),
              ),
              child: _fileToVerify == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 60, color: Colors.white70),
                          SizedBox(height: 10),
                          Text('Tap to Select Image', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_fileToVerify!, fit: BoxFit.cover),
                    ),
            ),
          ),

          if (_fileToVerify == null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _verifying ? null : _pickImageToVerifyFromVault,
              icon: const Icon(Icons.security, size: 20),
              label: const Text("LOAD FROM TRUEVAULT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Verification Status
          if (_verifying) ...[
            const Center(child: CircularProgressIndicator(color: Colors.white)),
            const SizedBox(height: 16),
            Text(_verifyMessage, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          ],

          // Verification Result
          if (_hasVerifyResult && !_verifying) ...[
            if (!_isSignatureValid)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                    const SizedBox(height: 10),
                    const Text('VERIFICATION FAILED', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    Text(_verifyMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.5), width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified, color: Colors.tealAccent, size: 70),
                    const SizedBox(height: 10),
                    const Text('AUTHENTIC IMAGE', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w900, fontSize: 22)),
                    const Divider(height: 30, color: Colors.white24),
                    _infoRow('Creator', _verifyRecord!.ownerEmail),
                    _infoRow('Created', DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(_verifyRecord!.timestamp.toInt()))),
                    _infoRow('Registry ID', _verifyRecord!.imageHash.substring(0, 10) + '...'),
                  ],
                ),
              ),
          ],
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
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
