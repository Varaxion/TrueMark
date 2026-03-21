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
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'true_vault_screen.dart';
import '../widgets/vault_button.dart';

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
      // Silent fail
    }
  }

  // --- PROTECT TAB ACTIONS ---

  Future<void> _pickFileToProtect() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
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

  Future<void> _pickFileToProtectFromVault() async {
    final File? file = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: false)),
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
      if (user == null) return;
      
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
    if (user == null) {
       showToast("Account not logged in.", backgroundColor: Colors.red);
       return;
    }

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
          dialogTitle: 'Save Protected File',
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
      showToast('Protection failed: $e', backgroundColor: Colors.red);
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

      final originalHash = parts[2];

      OwnershipRecord? record;
      if (Platform.isWindows) {
        final restService = FirestoreRestService();
        record = await restService.verifyOwnership(originalHash);
      } else {
        final service = FirestoreService();
        record = await service.verifyOwnership(originalHash);
      }

      if (record != null) {
        setState(() {
          _verifying = false;
          _hasVerifyResult = true;
          _isSignatureValid = true;
          _verifyRecord = record;
        });
      } else {
        setState(() {
          _verifying = false;
          _hasVerifyResult = true;
          _isSignatureValid = false;
          _verifyMessage = 'Ownership record not found in registry.';
        });
      }
    } catch (e) {
      setState(() {
        _verifying = false;
        _hasVerifyResult = true;
        _isSignatureValid = false;
        _verifyMessage = 'Verification error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF000000), const Color(0xFF0D1B2A)]
                : [const Color(0xFF1A237E), const Color(0xFF3949AB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Standard Header
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

              // Tab Bar Navigation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                    tabs: const [Tab(text: "Sign"), Tab(text: "Verify")],
                  ),
                ),
              ),

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
          // Header
          const Icon(Icons.verified_user_rounded, size: 80, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            "Protect Your File",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Embed an invisible, encrypted signature linked to your identity. Create permanent proof of ownership.",
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Source Picker
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _protecting ? null : _pickFileToProtect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.phonelink_setup_rounded, color: Colors.white70),
                          SizedBox(height: 4),
                          Text('From device', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: _protecting ? null : _pickFileToProtectFromVault,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        children: [
                          Icon(kTrueVaultIcon, color: Colors.white70),
                          SizedBox(height: 4),
                          Text('From TrueVault', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // File Area
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: _fileToProtect == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.drive_file_rename_outline_rounded, size: 60, color: Colors.white24),
                        SizedBox(height: 12),
                        Text('Select file to secure', style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (['.jpg', '.jpeg', '.png', '.webp'].contains(p.extension(_fileToProtect!.path).toLowerCase()))
                           Image.file(_fileToProtect!, fit: BoxFit.cover, width: double.infinity)
                        else
                           Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 70),
                               const SizedBox(height: 10),
                               Text(p.basename(_fileToProtect!.path), style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                             ],
                           ),
                        Container(color: Colors.black12),
                        Positioned(
                           top: 8, right: 8,
                           child: IconButton(
                             icon: const Icon(Icons.close, color: Colors.white, size: 28),
                             onPressed: () => setState(() => _fileToProtect = null),
                           ),
                        )
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 24),

          // Action
          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: (_fileToProtect == null || _protecting) ? null : _performProtection,
              icon: _protecting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.shield_rounded),
              label: Text(_protecting ? 'Signing...' : 'Sign and protect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Success Logic
          if (_protectSuccess) ...[
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
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
                          Share.shareXFiles([XFile(_protectedFilePath!)], text: 'TrueMark Proof');
                        }
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text("Share Proof"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, 
                        foregroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: VaultSaveButton(
                      onPressed: _protectedFilePath != null ? () => _saveToVault(_protectedFilePath!) : null,
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
          // Header
          const Icon(Icons.verified_rounded, size: 80, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            "Verify Authenticity",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Scan any document to reveal hidden metadata and display the verified creator's legal digital identity.",
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Source Picker (Verify)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _verifying ? null : _pickImageToVerify,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.file_upload_rounded, color: Colors.white70),
                          SizedBox(height: 4),
                          Text('From device', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: _verifying ? null : _pickImageToVerifyFromVault,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        children: [
                          Icon(kTrueVaultIcon, color: Colors.white70),
                          SizedBox(height: 4),
                          Text('From TrueVault', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // File View (Verify)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: _fileToVerify == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.zoom_in_rounded, size: 60, color: Colors.white24),
                        SizedBox(height: 10),
                        Text('Select image to verify', style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.file(_fileToVerify!, fit: BoxFit.cover, width: double.infinity),
                        Container(color: Colors.black12),
                        Positioned(
                          top: 8, right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                            onPressed: () => setState(() => _fileToVerify = null),
                          ),
                        )
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 24),

          // Status & Results
          if (_verifying) ...[
            const Center(child: CircularProgressIndicator(color: Colors.white)),
            const SizedBox(height: 16),
            Text(_verifyMessage, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          ],

          if (_hasVerifyResult && !_verifying) ...[
            if (!_isSignatureValid)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 50),
                    const SizedBox(height: 12),
                    const Text('VERIFICATION FAILED', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(_verifyMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.3), width: 1),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.tealAccent, size: 60),
                    const SizedBox(height: 12),
                    const Text('AUTHENTIC IMAGE', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w900, fontSize: 20)),
                    const Divider(height: 30, color: Colors.white12),
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
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
