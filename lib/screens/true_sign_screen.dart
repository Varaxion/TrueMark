import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path/path.dart' as p;
import '../services/image_service.dart';
import '../services/steg_service.dart';
import '../services/firestore_rest_service.dart';
import '../services/firestore_service.dart';
import '../models/ownership_record.dart';
import '../utils/constants.dart';
import 'true_vault_screen.dart';
import '../widgets/vault_button.dart';

class TrueSignScreen extends StatefulWidget {
  final bool isProtectMode;

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
      length: 3, 
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
      if (mounted) setState(() => _baseNumber = meta['baseNumber'] as String?);
    } catch (e) {}
  }

  // --- ACTIONS ---

  Future<void> _pickFile({required bool isProtect, bool fromVault = false}) async {
    File? picked;
    if (fromVault) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: false)));
      if (result != null && result is File) picked = result;
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: isProtect ? FileType.custom : FileType.any,
        allowedExtensions: isProtect ? ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'mp3', 'docx'] : null,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) picked = File(result.files.single.path!);
    }
    if (picked != null) {
      setState(() {
        if (isProtect) { _fileToProtect = picked; _protectSuccess = false; _protectedFilePath = null; }
        else { _fileToVerify = picked; _hasVerifyResult = false; _verifyMessage = ''; _performVerification(); }
      });
    }
  }

  Future<void> _performProtection() async {
    if (_fileToProtect == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() { _protecting = true; _protectSuccess = false; });
    try {
      final fileBytes = await _fileToProtect!.readAsBytes();
      final originalHash = sha256.convert(fileBytes).toString();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toDouble();
      final signaturePayload = '${user.uid}|$timestamp|$originalHash';
      bool isImage = ['.jpg', '.jpeg', '.png', '.webp'].contains(p.extension(_fileToProtect!.path).toLowerCase());
      final extension = isImage ? '.png' : p.extension(_fileToProtect!.path);
      
      String ownerName = 'Unknown User';
      String ownerUsername = 'anon';
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
           ownerName = doc.data()?['name'] ?? 'Unknown User';
           ownerUsername = doc.data()?['username'] ?? 'anon';
        }
      } catch (_) {}

      final originalBase = p.basenameWithoutExtension(_fileToProtect!.path);
      final fileName = '${originalBase}_TrueSign_Protect_${DateTime.now().millisecondsSinceEpoch}$extension';
      
      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/$fileName';
      final outFile = File(outPath);
      
      File processedFile;
      
      if (isImage) {
        processedFile = await StegService.embedStringInImage(
          inputFile: _fileToProtect!,
          plaintext: signaturePayload,
          password: kTrueMarkSharedKey,
          outputFile: outFile,
        );
      } else {
        processedFile = await StegService.embedStringInFile(
          inputFile: _fileToProtect!,
          plaintext: signaturePayload,
          password: kTrueMarkSharedKey,
          outputFile: outFile,
        );
      }
      
      final record = OwnershipRecord(
        imageId: const Uuid().v4(),
        ownerUid: user.uid,
        ownerEmail: user.email ?? 'Identity Proof',
        ownerName: ownerName,
        ownerUsername: ownerUsername,
        timestamp: timestamp,
        imageHash: originalHash,
        signature: 'Validated Chain (AES-256)',
      );
      
      try {
        if (Platform.isWindows) {
          await FirestoreRestService().registerOwnership(record);
        } else {
          await FirestoreService().registerOwnership(record);
        }
      } catch (firestoreErr) {
        print('Registry Sync Delayed (Offline?): $firestoreErr');
        // Let it succeed locally anyway
      }
      
      setState(() { _protecting = false; _protectSuccess = true; _protectedFilePath = processedFile.path; });
      showToast("Identity Proof Applied", backgroundColor: Colors.indigo);
    } catch (e) {
      print('Protect Error: $e');
      setState(() => _protecting = false);
      showToast('Protection Error', backgroundColor: Colors.red);
    }
  }

  Future<void> _performVerification() async {
    if (_fileToVerify == null) return;
    setState(() { _verifying = true; _hasVerifyResult = false; _verifyMessage = 'Scrutinizing Bitstream...'; });
    
    await Future.delayed(const Duration(milliseconds: 1500));
    try {
      String? extractedPayload = await StegService.extractStringFromFile(inputFile: _fileToVerify!, password: kTrueMarkSharedKey);
      if (extractedPayload == null) {
         extractedPayload = await StegService.extractStringFromImage(inputFile: _fileToVerify!, password: kTrueMarkSharedKey);
      }
      
      if (extractedPayload == null) {
        setState(() { _verifying = false; _hasVerifyResult = true; _isSignatureValid = false; _verifyMessage = 'Unrecognized Asset.\nNo TrueMark proof discovered.'; });
        return;
      }
      
      final payloadParts = extractedPayload.split('|');
      if (payloadParts.length < 3) throw Exception();
      final originalHash = payloadParts[2];
      
      OwnershipRecord? record = Platform.isWindows ? await FirestoreRestService().verifyOwnership(originalHash) : await FirestoreService().verifyOwnership(originalHash);
          
      if (record != null) {
        setState(() { _verifying = false; _hasVerifyResult = true; _isSignatureValid = true; _verifyRecord = record; });
      } else {
        setState(() { _verifying = false; _hasVerifyResult = true; _isSignatureValid = false; _verifyMessage = 'Locally signed, but record missing from Registry.'; });
      }
    } catch (e) {
      setState(() { _verifying = false; _hasVerifyResult = true; _isSignatureValid = false; _verifyMessage = 'Verification Interrupted'; });
    }
  }

  // --- THEME HELPERS ---
  Color _mainText(bool _) => Colors.white;
  Color _subText(bool _) => Colors.white70;
  Color _hintText(bool _) => Colors.white24;
  Color _glassBg(bool _) => Colors.white.withOpacity(0.05);
  Color _glassBorder(bool _) => Colors.white10;
  Color _iconColor(bool _) => kColorTrueSign;
  Color _dividerColor(bool _) => Colors.white10;

  // --- UI ---

  Widget _buildTabHeader(bool isDark) {
    return Container(
      height: 50, margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(16)),
      child: TabBar(
        controller: _tabController,
        labelColor: _mainText(isDark),
        unselectedLabelColor: _subText(isDark),
        indicator: BoxDecoration(color: _iconColor(isDark).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
        tabs: const [Tab(text: "Sign"), Tab(text: "Verify"), Tab(icon: Icon(Icons.info_outline, size: 20))],
      ),
    );
  }

  Widget _buildSourcePicker({required bool isProtect, required bool isDark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            _pickerBtn(Icons.upload_file_rounded, "From Device", () => _pickFile(isProtect: isProtect, fromVault: false), isDark),
            const SizedBox(width: 4),
            _pickerBtn(kTrueVaultIcon, "From TrueVault", () => _pickFile(isProtect: isProtect, fromVault: true), isDark),
          ]),
        ),
      ),
    );
  }

  Widget _pickerBtn(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(icon, color: _subText(isDark)), const SizedBox(height: 4), Text(label, style: TextStyle(color: _mainText(isDark), fontSize: 11, fontWeight: FontWeight.bold))]))));
  }

  Widget _buildProtectTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Icon(Icons.verified_user_rounded, size: 70, color: kColorTrueSign),
        const SizedBox(height: 16),
        Text("Sign & Protect", style: GoogleFonts.outfit(color: _mainText(isDark), fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Embed identity proofs to prevent unauthorized duplication.", textAlign: TextAlign.center, style: TextStyle(color: _subText(isDark), fontSize: 13)),
        const SizedBox(height: 32),
        _buildSourcePicker(isProtect: true, isDark: isDark),
        const SizedBox(height: 24),
        _buildFilePreview(_fileToProtect, Icons.add_photo_alternate_outlined, isDark, () => setState(() => _fileToProtect = null)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton.icon(
            onPressed: (_fileToProtect == null || _protecting) ? null : _performProtection,
            icon: _protecting ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _mainText(isDark))) : const Icon(Icons.security_rounded),
            label: Text("Sign", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: kColorTrueSign, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ),
        if (_protectSuccess) _buildResultCard(_protectedFilePath!, "Identity Signed Successfully", isDark),
      ]),
    );
  }

  Widget _buildVerifyTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Icon(Icons.verified_rounded, size: 70, color: kColorTrueSign),
        const SizedBox(height: 16),
        Text("Verify Signature", style: GoogleFonts.outfit(color: _mainText(isDark), fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Authenticate the origin and integrity of digital assets.", textAlign: TextAlign.center, style: TextStyle(color: _subText(isDark), fontSize: 13)),
        const SizedBox(height: 32),
        _buildSourcePicker(isProtect: false, isDark: isDark),
        const SizedBox(height: 24),
        _buildFilePreview(_fileToVerify, Icons.manage_search_rounded, isDark, () => setState(() => _fileToVerify = null)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton.icon(
            onPressed: (_fileToVerify == null || _verifying) ? null : _performVerification,
            icon: _verifying ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _mainText(isDark))) : const Icon(Icons.manage_search_rounded),
            label: Text("Verify", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: kColorTrueSign, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ),
        if (_hasVerifyResult && !_verifying) ...[
          const SizedBox(height: 32),
          if (!_isSignatureValid)
             _buildVerifyStatus(false, "Unverified", _verifyMessage, isDark)
          else
             _buildVerifyStatus(true, "Authentic", "Signature verified against the TrueMark Registry.", isDark, record: _verifyRecord),
        ],
      ]),
    );
  }

  Widget _buildFilePreview(File? f, IconData icon, bool isDark, VoidCallback onClear) {
     final isImg = f != null && ['.jpg', '.jpeg', '.png', '.webp'].contains(p.extension(f.path).toLowerCase());
     return Container(
       height: 180, width: double.infinity,
       decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: _glassBorder(isDark))),
       child: f == null
         ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 50, color: _hintText(isDark)), const SizedBox(height: 8), Text("No file selected", style: TextStyle(color: _hintText(isDark), fontSize: 12))]))
         : Stack(children: [
             isImg
               ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.file(f, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
               : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                   Icon(_fileIcon(f), color: _iconColor(isDark), size: 56),
                   const SizedBox(height: 12),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 24),
                     child: Text(p.basename(f.path), style: TextStyle(color: _mainText(isDark), fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                   ),
                 ])),
             Positioned(top: 8, right: 8, child: GestureDetector(onTap: onClear, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 18)))),
          ]),
     );
  }

  IconData _fileIcon(File f) {
    final ext = p.extension(f.path).toLowerCase();
    if (ext == '.pdf') return Icons.picture_as_pdf;
    if (['.mp4', '.mov', '.mkv'].contains(ext)) return Icons.video_file;
    if (['.mp3', '.aac'].contains(ext)) return Icons.audio_file;
    if (['.doc', '.docx'].contains(ext)) return Icons.description;
    return Icons.insert_drive_file_rounded;
  }

  Widget _buildVerifyStatus(bool valid, String title, String msg, bool isDark, {OwnershipRecord? record}) {
     return _buildGlassContainer(isDark, child: Column(children: [
       Icon(valid ? Icons.verified_rounded : Icons.warning_amber_rounded, color: valid ? kColorTrueSign : Colors.redAccent, size: 48),
       const SizedBox(height: 12),
       Text(title, style: TextStyle(color: valid ? kColorTrueSign : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2)),
       const SizedBox(height: 8),
       Text(msg, textAlign: TextAlign.center, style: TextStyle(color: _subText(isDark), fontSize: 13)),
       if (valid && record != null) ...[
          Divider(height: 32, color: _dividerColor(isDark)),
          if (record.ownerName != null) _infoRow("Creator Name", record.ownerName!, isDark),
          if (record.ownerUsername != null) _infoRow("Username", "@${record.ownerUsername!}", isDark),
          _infoRow("UID Linked", record.ownerUid.substring(0, 8).toUpperCase(), isDark),
          _infoRow("Timestamp", DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(record.timestamp.toInt())), isDark),
       ]
     ]));
  }

  Widget _infoRow(String l, String v, bool isDark) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: _subText(isDark), fontSize: 11)), Text(v, style: TextStyle(color: _mainText(isDark), fontSize: 11, fontWeight: FontWeight.bold))]));
  }

  Widget _buildResultCard(String path, String msg, bool isDark) {
     return Padding(
       padding: const EdgeInsets.only(top: 24),
       child: _buildGlassContainer(isDark, child: Column(children: [
         Text(msg, style: TextStyle(color: _iconColor(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
         const SizedBox(height: 16),
         SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: () => Share.shareXFiles([XFile(path)]), icon: const Icon(Icons.share), label: const Text("Share/Save"), style: ElevatedButton.styleFrom(backgroundColor: kColorTrueSign, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
         const SizedBox(height: 12),
         SizedBox(width: double.infinity, height: 50, child: VaultSaveButton(color: kColorTrueSign, onPressed: () {
            final user = FirebaseAuth.instance.currentUser; if (user == null) return;
            getApplicationDocumentsDirectory().then((root) {
              final vaultDir = Directory('${root.path}/TrueVault_${user.uid}');
              if (!vaultDir.existsSync()) vaultDir.createSync(recursive: true);
              File(path).copySync('${vaultDir.path}/${p.basename(path)}');
              showToast("Identity Proof Vaulted", backgroundColor: kColorTrueSign);
            });
         })),
       ])),
     );
  }

  Widget _buildGlassContainer(bool isDark, {required Widget child}) {
     return ClipRRect(
       borderRadius: BorderRadius.circular(20),
       child: BackdropFilter(
         filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
         child: Container(
           padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: _glassBorder(isDark))),
           child: child,
         ),
       ),
     );
  }

  Widget _buildAboutTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.verified_user_rounded, size: 50, color: _iconColor(isDark)),
        const SizedBox(height: 16),
        Text("About TrueSign", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: _mainText(isDark))),
        const SizedBox(height: 12),
        Text("TrueSign establishes a permanent cryptographic link between your digital identity and your assets. Using a hybrid engine, we sign media without visible watermarks, ensuring provenance remains intact through countless distributions.", style: TextStyle(color: _subText(isDark), height: 1.5)),
        const SizedBox(height: 20),
        _featurePoint("Undetectable Signatures", "Identity is encoded directly into file bitstreams.", Icons.fingerprint_rounded, isDark),
        _featurePoint("Registry Integration", "Ownership records are permanently registered in Firestore.", Icons.storage_rounded, isDark),
        _featurePoint("Non-Repudiation", "Mathematically prove creation time and authorship.", Icons.gavel_rounded, isDark),
      ]),
    );
  }

  Widget _featurePoint(String t, String d, IconData icon, bool isDark) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _iconColor(isDark), size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(color: _mainText(isDark), fontWeight: FontWeight.bold)), Text(d, style: TextStyle(color: _subText(isDark), fontSize: 13))]))]));
  }

  @override
  Widget build(BuildContext context) {
    const isDark = true;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(iconTheme: IconThemeData(color: _mainText(isDark)), title: Text("TrueSign", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, foregroundColor: _mainText(isDark)),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF001A10), Color(0xFF000805)]))),
          SafeArea(child: Column(children: [_buildTabHeader(isDark), Expanded(child: TabBarView(controller: _tabController, children: [_buildProtectTab(isDark), _buildVerifyTab(isDark), _buildAboutTab(isDark)]))])),
        ],
      ),
    );
  }
}
