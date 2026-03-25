import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oktoast/oktoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';
import '../services/true_lock_service.dart';
import 'true_vault_screen.dart';
import '../widgets/vault_button.dart';
import '../widgets/password_strength_indicator.dart';
import '../utils/constants.dart';

class TrueLockScreen extends StatefulWidget {
  final bool isEncryptMode;

  const TrueLockScreen({super.key, required this.isEncryptMode});

  @override
  State<TrueLockScreen> createState() => _TrueLockScreenState();
}

class _TrueLockScreenState extends State<TrueLockScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TrueLockService _vaultService = TrueLockService();
  
  // Encrypt State
  File? _fileToEncrypt;
  final TextEditingController _encryptPasswordController = TextEditingController();
  bool _encrypting = false;
  String? _encryptedFilePath;

  // Decrypt State
  File? _fileToDecrypt;
  final TextEditingController _decryptPasswordController = TextEditingController();
  bool _decrypting = false;
  String? _decryptedFilePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3, 
      vsync: this,
      initialIndex: widget.isEncryptMode ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _encryptPasswordController.dispose();
    _decryptPasswordController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _pickFile({required bool isEncrypt, bool fromVault = false}) async {
    File? picked;
    if (fromVault) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: false)));
      if (result != null && result is String) picked = File(result);
      else if (result != null && result is File) picked = result;
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: isEncrypt ? FileType.any : FileType.custom,
        allowedExtensions: isEncrypt ? null : ['tmk'],
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) picked = File(result.files.single.path!);
    }
    if (picked != null) {
      if (!isEncrypt && p.extension(picked.path).toLowerCase() != '.tmk') {
        showToast("Select a .tmk encrypted wrapper", backgroundColor: Colors.amber);
        return;
      }
      setState(() {
        if (isEncrypt) { _fileToEncrypt = picked; _encryptedFilePath = null; }
        else { _fileToDecrypt = picked; _decryptedFilePath = null; }
      });
    }
  }

  Future<void> _performEncryption() async {
    final pswd = _encryptPasswordController.text;
    if (_fileToEncrypt == null || pswd.isEmpty) { showToast("Missing Credentials", backgroundColor: Colors.amber); return; }
    if (pswd.length < 8) { showToast("Password must be at least 8 chars."); return; }
    
    setState(() => _encrypting = true);
    try {
      final encryptedFile = await _vaultService.encryptFile(_fileToEncrypt!, pswd);
      
      // Auto-save to vault safely bypassing Android SAF limitations
      await _saveToVaultSilent(encryptedFile.path);

      if (mounted) setState(() { 
        _encryptedFilePath = encryptedFile.path; 
        _encrypting = false; 
        // Auto-load it into the decrypt tab to bypass FilePicker ghost bugs!
        _fileToDecrypt = encryptedFile;
      });
      showToast("Vault Sealed Successfully", backgroundColor: kColorTrueLock);
    } catch (e) {
      setState(() => _encrypting = false);
      showToast("Encryption Failed: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _saveToVaultSilent(String path) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final root = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${root.path}/TrueVault_${user.uid}');
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    final fileToSave = File(path);
    await fileToSave.copy('${vaultDir.path}/${p.basename(fileToSave.path)}');
  }

  Future<void> _performDecryption() async {
    if (_fileToDecrypt == null || _decryptPasswordController.text.isEmpty) { showToast("Credentials Required"); return; }
    setState(() => _decrypting = true);
    try {
      final decryptedFile = await _vaultService.decryptFile(_fileToDecrypt!, _decryptPasswordController.text);
      if (mounted) setState(() { _decryptedFilePath = decryptedFile.path; _decrypting = false; });
      showToast("Vault Unlocked Successfully", backgroundColor: kColorTrueLock);
    } catch (e) {
      setState(() => _decrypting = false);
      showToast("Decryption Failed: $e", backgroundColor: Colors.red, duration: const Duration(seconds: 5));
    }
  }

  Future<void> _saveToVault(String path) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final root = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${root.path}/TrueVault_${user.uid}');
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    final fileToSave = File(path);
    await fileToSave.copy('${vaultDir.path}/${p.basename(fileToSave.path)}');
    showToast("Secured in TrueVault!", backgroundColor: kColorTrueLock);
  }

  // --- THEME HELPERS ---
  Color _mainText(bool _) => Colors.white;
  Color _subText(bool _) => Colors.white70;
  Color _hintText(bool _) => Colors.white24;
  Color _glassBg(bool _) => Colors.white.withOpacity(0.05);
  Color _glassBorder(bool _) => Colors.white10;
  Color _iconColor(bool _) => kColorTrueLock;

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
        tabs: const [Tab(text: "Lock Asset"), Tab(text: "Unlock Asset"), Tab(icon: Icon(Icons.info_outline, size: 20))],
      ),
    );
  }

  Widget _buildSourcePicker({required bool isEncrypt, required bool isDark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            _pickerBtn(Icons.upload_file_rounded, "From Device", () => _pickFile(isEncrypt: isEncrypt, fromVault: false), isDark),
            const SizedBox(width: 4),
            _pickerBtn(kTrueVaultIcon, "From TrueVault", () => _pickFile(isEncrypt: isEncrypt, fromVault: true), isDark),
          ]),
        ),
      ),
    );
  }

  Widget _pickerBtn(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(icon, color: _subText(isDark)), const SizedBox(height: 4), Text(label, style: TextStyle(color: _mainText(isDark), fontSize: 11, fontWeight: FontWeight.bold))]))));
  }

  Widget _buildEncryptTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(Icons.enhanced_encryption_rounded, size: 70, color: _iconColor(isDark)),
        const SizedBox(height: 16),
        Text("Lock Asset", style: GoogleFonts.outfit(color: _mainText(isDark), fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Lock any digital asset with AES-256-GCM authenticated encryption.", textAlign: TextAlign.center, style: TextStyle(color: _subText(isDark), fontSize: 13)),
        const SizedBox(height: 32),
        _buildSourcePicker(isEncrypt: true, isDark: isDark),
        const SizedBox(height: 24),
        _buildFilePreview(_fileToEncrypt, Icons.lock_rounded, isDark, () => setState(() => _fileToEncrypt = null)),
        const SizedBox(height: 24),
        _buildGlassTextField(
          controller: _encryptPasswordController,
          hint: "Password",
          icon: Icons.password_rounded,
          isDark: isDark,
          onChanged: (_) => setState(() {}),
        ),
        PasswordStrengthIndicator(password: _encryptPasswordController.text),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton.icon(
            onPressed: (_fileToEncrypt == null || _encrypting || _encryptPasswordController.text.length < 8) ? null : _performEncryption,
            icon: _encrypting ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white : Colors.white)) : const Icon(Icons.lock_rounded),
            label: const Text("Lock", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: kColorTrueLock, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ),
        if (_encryptedFilePath != null) _buildResultCard(_encryptedFilePath!, "Assets Encrypted & Sealed", isDark),
      ]),
    );
  }

  Widget _buildDecryptTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(Icons.no_encryption_gmailerrorred_rounded, size: 70, color: _iconColor(isDark)),
        const SizedBox(height: 16),
        Text("Unlock Asset", style: GoogleFonts.outfit(color: _mainText(isDark), fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Restore original format from TrueLock (.tmk) secure wrappers.", textAlign: TextAlign.center, style: TextStyle(color: _subText(isDark), fontSize: 13)),
        const SizedBox(height: 32),
        _buildSourcePicker(isEncrypt: false, isDark: isDark),
        const SizedBox(height: 24),
        _buildFilePreview(_fileToDecrypt, Icons.key_rounded, isDark, () => setState(() => _fileToDecrypt = null)),
        const SizedBox(height: 24),
        _buildGlassTextField(
          controller: _decryptPasswordController,
          hint: "Password",
          icon: Icons.key_rounded,
          isDark: isDark,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton.icon(
            onPressed: (_fileToDecrypt == null || _decrypting || _decryptPasswordController.text.isEmpty) ? null : _performDecryption,
            icon: _decrypting ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white : Colors.white)) : const Icon(Icons.lock_open_rounded),
            label: const Text("Unlock", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: kColorTrueLock, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ),
        if (_decryptedFilePath != null) _buildResultCard(_decryptedFilePath!, "Assets Restored & Verified", isDark, isUnlock: true),
      ]),
    );
  }

  Widget _buildFilePreview(File? file, IconData icon, bool isDark, VoidCallback onClear) {
    final isImg = file != null && ['.jpg', '.jpeg', '.png', '.webp'].contains(p.extension(file.path).toLowerCase());
    return Container(
      height: 160, width: double.infinity,
      decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: _glassBorder(isDark))),
      child: file == null
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 50, color: _hintText(isDark)), const SizedBox(height: 8), Text("No file selected", style: TextStyle(color: _hintText(isDark), fontSize: 12))]))
          : Stack(children: [
              isImg
                ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
                : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_fileIcon(file), color: _iconColor(isDark), size: 48),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(p.basename(file.path), style: TextStyle(color: _mainText(isDark), fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                    ),
                  ])),
              Positioned(top: 8, right: 8, child: GestureDetector(onTap: onClear, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 18)))),
            ]),
    );
  }

  IconData _fileIcon(File f) {
    final ext = p.extension(f.path).toLowerCase();
    if (ext == '.pdf') return Icons.picture_as_pdf;
    if (ext == '.tmk') return Icons.shield;
    if (['.mp4', '.mov', '.mkv'].contains(ext)) return Icons.video_file;
    if (['.mp3', '.aac'].contains(ext)) return Icons.audio_file;
    if (['.doc', '.docx'].contains(ext)) return Icons.description;
    return Icons.insert_drive_file_rounded;
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    Function(String)? onChanged,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: TextField(
          controller: controller, obscureText: true, onChanged: onChanged,
          style: TextStyle(color: _mainText(isDark), fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint, hintStyle: TextStyle(color: _hintText(isDark)),
            filled: true, fillColor: _glassBg(isDark),
            prefixIcon: Icon(icon, color: _subText(isDark)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: _glassBorder(isDark))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: _glassBorder(isDark))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: kColorTrueLock)),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(String path, String msg, bool isDark, {bool isUnlock = false}) {
     final file = File(path);
     return Padding(
       padding: const EdgeInsets.only(top: 24),
       child: _buildGlassContainer(isDark, child: Column(children: [
         Text(msg, style: TextStyle(color: kColorTrueLock, fontWeight: FontWeight.bold, fontSize: 16)),
         const SizedBox(height: 16),
         if (isUnlock) ...[
           _buildFilePreview(file, Icons.lock_open_rounded, isDark, () {}),
           const SizedBox(height: 16),
         ],
         SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: () => Share.shareXFiles([XFile(path)]), icon: const Icon(Icons.share), label: const Text("Share/Save"), style: ElevatedButton.styleFrom(backgroundColor: kColorTrueLock, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
         const SizedBox(height: 12),
         SizedBox(width: double.infinity, height: 50, child: VaultSaveButton(color: kColorTrueLock, onPressed: () => _saveToVault(path)))
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
        Icon(Icons.lock_rounded, size: 50, color: _iconColor(isDark)),
        const SizedBox(height: 16),
        Text("About TrueLock", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: _mainText(isDark))),
        const SizedBox(height: 12),
        Text("TrueLock ensures absolute privacy by encapsulating any file format into an AES-256-GCM authenticated wrapper. We implement zero-knowledge security; your original filename and contents are hidden until unlocked with your personal master key.", style: TextStyle(color: _subText(isDark), height: 1.5)),
        const SizedBox(height: 20),
        _featurePoint("Galois/Counter Mode", "Authenticated encryption for integrity verification.", Icons.security_rounded, isDark),
        _featurePoint("Key Stretching", "PBKDF2 derivation with high iteration counts.", Icons.password_rounded, isDark),
        _featurePoint("Format Cloaking", "Wraps files in .tmk format to hide original signatures.", Icons.hide_image_rounded, isDark),
      ]),
    );
  }

  Widget _featurePoint(String title, String desc, IconData icon, bool isDark) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _iconColor(isDark), size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: _mainText(isDark), fontWeight: FontWeight.bold)), Text(desc, style: TextStyle(color: _subText(isDark), fontSize: 13))]))]));
  }

  @override
  Widget build(BuildContext context) {
    const isDark = true;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(iconTheme: IconThemeData(color: _mainText(isDark)), title: Text("TrueLock Pro", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, foregroundColor: _mainText(isDark)),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight, 
                colors: [const Color(0xFF030D1C), const Color(0xFF00050D)] 
              )
            )
          ),
          SafeArea(child: Column(children: [_buildTabHeader(isDark), Expanded(child: TabBarView(controller: _tabController, children: [_buildEncryptTab(isDark), _buildDecryptTab(isDark), _buildAboutTab(isDark)]))])),
        ],
      ),
    );
  }
}
