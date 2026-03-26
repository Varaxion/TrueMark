import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oktoast/oktoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';
import '../services/steg_service.dart';
import 'true_vault_screen.dart';
import '../widgets/vault_button.dart';
import '../widgets/password_strength_indicator.dart';
import '../utils/constants.dart';

class TrueHideScreen extends StatefulWidget {
  final bool isHideMode;

  const TrueHideScreen({super.key, required this.isHideMode});

  @override
  State<TrueHideScreen> createState() => _TrueHideScreenState();
}

class _TrueHideScreenState extends State<TrueHideScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _hidePasswordController = TextEditingController();
  final TextEditingController _revealPasswordController = TextEditingController();
  
  // Hide State
  File? _carrierImage;
  File? _secretFile;
  String _secretText = '';
  bool _isEmbeddingText = true;
  bool _hiding = false;
  String? _hiddenFilePath;
  StegCapacity? _carrierCapacity;
  bool _capacityLoading = false;

  // Reveal State
  File? _imageToReveal;
  bool _revealing = false;
  String? _revealedText;
  String? _revealedFilePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3, 
      vsync: this,
      initialIndex: widget.isHideMode ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hidePasswordController.dispose();
    _revealPasswordController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _pickFile({required bool isCarrier, bool fromVault = false}) async {
    File? picked;
    if (fromVault) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => TrueVaultScreen(isPicker: true, pickImagesOnly: isCarrier)));
      if (result != null && result is File) picked = result;
    } else {
      final result = await FilePicker.platform.pickFiles(type: isCarrier ? FileType.image : FileType.any, allowMultiple: false);
      if (result != null && result.files.single.path != null) picked = File(result.files.single.path!);
    }
    if (picked != null) {
      setState(() {
         if (isCarrier) { _carrierImage = picked; _hiddenFilePath = null; }
         else { _secretFile = picked; }
      });
      if (isCarrier) {
        await _updateCarrierCapacity();
      }
    }
  }

  Future<void> _pickReveal({bool fromVault = false}) async {
    File? picked;
    if (fromVault) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: true)));
      if (result != null && result is File) picked = result;
    } else {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (result != null && result.files.single.path != null) picked = File(result.files.single.path!);
    }
    if (picked != null) setState(() { _imageToReveal = picked; _revealedText = null; _revealedFilePath = null; });
  }

  Future<void> _performHide() async {
    final pswd = _hidePasswordController.text;
    if (_carrierImage == null || pswd.isEmpty) { showToast("Media/Key Required", backgroundColor: Colors.amber); return; }
    if (pswd.length < 8) { showToast("Key must be 8+ chars."); return; }
    if (_carrierCapacity == null) {
      await _updateCarrierCapacity();
    }
    if (_carrierCapacity == null) {
      showToast("Carrier Decode Failed", backgroundColor: Colors.red);
      return;
    }
    if (_carrierCapacity!.maxCipherBytes <= 0) {
      showToast("Carrier too small for any payload", backgroundColor: Colors.red);
      return;
    }
    
    setState(() => _hiding = true);
    try {
      final outDir = await getApplicationDocumentsDirectory();
      final originalBase = p.basenameWithoutExtension(_carrierImage!.path);
      final outFile = File('${outDir.path}/${originalBase}_TrueHide_Conceal_${DateTime.now().millisecondsSinceEpoch}.png');
      File result;

      if (_isEmbeddingText) {
        if (_secretText.isEmpty) throw Exception("Empty Secret String");
        final payloadBytes = _utf8Len(_secretText);
        if (!_fitsPlaintext(payloadBytes)) {
          throw Exception("Payload exceeds capacity");
        }
        result = await StegService.embedStringInImage(inputFile: _carrierImage!, plaintext: _secretText, password: pswd, outputFile: outFile);
      } else {
        if (_secretFile == null) throw Exception("Select Secret Binary");
        final secretLen = await _secretFile!.length();
        if (secretLen > _carrierCapacity!.maxFileBytes) {
          throw Exception("Binary payload exceeds capacity");
        }
        result = await StegService.embedFileInImage(carrierImage: _carrierImage!, secretFile: _secretFile!, password: pswd, outputFile: outFile);
      }
      setState(() { _hiddenFilePath = result.path; _hiding = false; });
      showToast("Data Effectively Concealed", backgroundColor: kColorTrueHide);
    } catch (e) {
      setState(() => _hiding = false);
      showToast("Concealment Failed: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _updateCarrierCapacity() async {
    if (_carrierImage == null) return;
    setState(() => _capacityLoading = true);
    try {
      final cap = await StegService.estimateCapacity(inputFile: _carrierImage!);
      if (mounted) setState(() => _carrierCapacity = cap);
    } catch (_) {
      if (mounted) setState(() => _carrierCapacity = null);
    } finally {
      if (mounted) setState(() => _capacityLoading = false);
    }
  }

  Future<void> _performReveal() async {
    final pswd = _revealPasswordController.text;
    if (_imageToReveal == null || pswd.isEmpty) return;

    setState(() => _revealing = true);
    try {
      final text = await StegService.extractStringFromImage(inputFile: _imageToReveal!, password: pswd);
      if (text != null && text.isNotEmpty) {
          if (text.startsWith('FILE:')) {
            final outDir = await getApplicationDocumentsDirectory();
            final originalBase = p.basenameWithoutExtension(_imageToReveal!.path);
            final outFile = File('${outDir.path}/${originalBase}_TrueHide_Reveal_${DateTime.now().millisecondsSinceEpoch}.bin');
            final success = await StegService.extractFileFromImage(carrierImage: _imageToReveal!, password: pswd, outputFilePath: outFile.path);
            if (success) {
              setState(() { _revealedFilePath = outFile.path; _revealing = false; });
            } else {
              throw Exception();
            }
         } else {
            setState(() { _revealedText = text; _revealing = false; });
         }
      } else {
         setState(() => _revealing = false);
         showToast("Invalid Master Key", backgroundColor: Colors.red);
      }
    } catch (e) {
      setState(() => _revealing = false);
      showToast("Extraction Failed", backgroundColor: Colors.red);
    }
  }

  Future<void> _saveToVault(String path) async {
     final user = FirebaseAuth.instance.currentUser; if (user == null) return;
     final root = await getApplicationDocumentsDirectory();
     final vaultDir = Directory('${root.path}/TrueVault_${user.uid}');
     if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
     await File(path).copy('${vaultDir.path}/${p.basename(path)}');
     showToast("Protected in Vault", backgroundColor: kColorTrueHide);
  }

  // --- THEME HELPERS ---
  Color _mainText(bool _) => Colors.white;
  Color _subText(bool _) => Colors.white70;
  Color _hintText(bool _) => Colors.white24;
  Color _glassBg(bool _) => Colors.white.withOpacity(0.05);
  Color _glassBorder(bool _) => Colors.white10;
  Color _iconColor(bool _) => kColorTrueHide;
  Color _activeColor(bool _) => kColorTrueHide.withOpacity(0.8);

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
        tabs: const [Tab(text: "Hide"), Tab(text: "Reveal"), Tab(icon: Icon(Icons.info_outline, size: 20))],
      ),
    );
  }

  Widget _buildSourcePicker({required bool isCarrier, required bool isDark, bool isReveal = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            _pickerBtn(Icons.upload_file_rounded, "From Device", () => isReveal ? _pickReveal(fromVault: false) : _pickFile(isCarrier: isCarrier, fromVault: false), isDark),
            const SizedBox(width: 4),
            _pickerBtn(kTrueVaultIcon, "From TrueVault", () => isReveal ? _pickReveal(fromVault: true) : _pickFile(isCarrier: isCarrier, fromVault: true), isDark),
          ]),
        ),
      ),
    );
  }

  Widget _pickerBtn(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(icon, color: _subText(isDark)), const SizedBox(height: 4), Text(label, style: TextStyle(color: _mainText(isDark), fontSize: 11, fontWeight: FontWeight.bold))]))));
  }

  Widget _buildHideTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Icon(Icons.add_to_photos_rounded, size: 70, color: kColorTrueHide),
        const SizedBox(height: 16),
        Text("Hide Secret", style: GoogleFonts.outfit(color: _mainText(isDark), fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Modulate pixel bits to conceal encrypted information.", textAlign: TextAlign.center, style: TextStyle(color: _subText(isDark), fontSize: 13)),
        const SizedBox(height: 32),

        _sectionTitle("1. Select Carrier Image", isDark),
        _buildSourcePicker(isCarrier: true, isDark: isDark),
        const SizedBox(height: 12),
        _buildImagePreview(_carrierImage, isDark),
        const SizedBox(height: 10),
        _buildCapacityInfo(isDark),

        const SizedBox(height: 24),
        _sectionTitle("2. Payload Definition", isDark),
        _modeSwitcher(isDark),
        const SizedBox(height: 16),
        if (_isEmbeddingText)
          _buildGlassTextField(hint: "Private Message Content", icon: Icons.text_fields_rounded, isDark: isDark, onChanged: (v) => _secretText = v, obscure: false)
        else ...[
          _buildSourcePicker(isCarrier: false, isDark: isDark),
          const SizedBox(height: 12),
          _buildFileNameBox(_secretFile, "Select Secret File", isDark),
        ],
        const SizedBox(height: 8),
        _buildPayloadInfo(isDark),

        const SizedBox(height: 24),
        _sectionTitle("3. Password", isDark),
        _buildGlassTextField(controller: _hidePasswordController, hint: "Password", icon: Icons.security_rounded, isDark: isDark, onChanged: (_) => setState(() {})),
        PasswordStrengthIndicator(password: _hidePasswordController.text),

        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: (_carrierImage == null || _hiding || _hidePasswordController.text.length < 8) ? null : _performHide, icon: _hiding ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _mainText(isDark))) : const Icon(Icons.visibility_off_rounded), label: const Text("Hide", style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: kColorTrueHide, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
        if (_hiddenFilePath != null) _buildResultCard(_hiddenFilePath!, "Concealment Finished", isDark),
      ]),
    );
  }

  Widget _buildRevealTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Icon(Icons.travel_explore_rounded, size: 70, color: kColorTrueHide),
        const SizedBox(height: 16),
        Text("Reveal Secret", style: GoogleFonts.outfit(color: _mainText(isDark), fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Identify and reconstruct bitstreams from carrier images.", textAlign: TextAlign.center, style: TextStyle(color: _subText(isDark), fontSize: 13)),
        const SizedBox(height: 32),
        
        _buildSourcePicker(isCarrier: true, isDark: isDark, isReveal: true),
        const SizedBox(height: 16),
        _buildImagePreview(_imageToReveal, isDark),
        
        const SizedBox(height: 24),
        _buildGlassTextField(controller: _revealPasswordController, hint: "Password", icon: Icons.key_rounded, isDark: isDark, onChanged: (_) => setState(() {})),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: (_imageToReveal == null || _revealing || _revealPasswordController.text.isEmpty) ? null : _performReveal, icon: _revealing ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _mainText(isDark))) : const Icon(Icons.search_rounded), label: const Text("Reveal", style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: kColorTrueHide, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
        
        if (_revealedText != null) ...[
          const SizedBox(height: 24),
          _buildGlassContainer(isDark, child: Column(children: [Text("Plaintext Extracted", style: TextStyle(color: _iconColor(isDark), fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(height: 12), Text(_revealedText!, style: TextStyle(color: _mainText(isDark), fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center)]))
        ],
        if (_revealedFilePath != null) ...[
          _buildResultCard(_revealedFilePath!, "Byte-stream Extracted & Decrypted", isDark),
        ],
      ]),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildImagePreview(File? f, bool isDark) {
    final isImg = f != null && ['.jpg', '.jpeg', '.png', '.webp'].contains(p.extension(f.path).toLowerCase());
    return Container(
      height: 160, width: double.infinity,
      decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: _glassBorder(isDark))),
      child: f == null
        ? Center(child: Text("Select Image to Process", style: TextStyle(color: _hintText(isDark), fontSize: 11)))
        : isImg
          ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.file(f, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
          : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.image_not_supported_rounded, color: Colors.redAccent, size: 36),
              const SizedBox(height: 8),
              Text(p.basename(f.path), style: TextStyle(color: _subText(isDark), fontSize: 11), overflow: TextOverflow.ellipsis),
              Text("Carrier must be an image file", style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 10)),
            ])),
    );
  }

  Widget _buildCapacityInfo(bool isDark) {
    if (_carrierImage == null) return const SizedBox.shrink();
    if (_capacityLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text("Calculating capacity...", style: TextStyle(color: _subText(isDark), fontSize: 11)),
      );
    }
    if (_carrierCapacity == null) {
      return Text("Capacity unavailable", style: TextStyle(color: Colors.redAccent, fontSize: 11));
    }
    final cap = _carrierCapacity!;
    final sizeText = "${cap.effectiveWidth}×${cap.effectiveHeight}";
    final resizedNote = cap.resized ? " (resized)" : "";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Capacity: ${_formatBytes(cap.maxPlaintextBytes)} text / ${_formatBytes(cap.maxFileBytes)} file", style: TextStyle(color: _subText(isDark), fontSize: 11)),
        Text("Carrier: $sizeText$resizedNote", style: TextStyle(color: _hintText(isDark), fontSize: 10)),
      ],
    );
  }

  Widget _buildPayloadInfo(bool isDark) {
    if (_carrierCapacity == null) return const SizedBox.shrink();
    if (_isEmbeddingText) {
      final payloadBytes = _utf8Len(_secretText);
      return Text(
        "Payload: ${_formatBytes(payloadBytes)} / ${_formatBytes(_carrierCapacity!.maxPlaintextBytes)}",
        style: TextStyle(color: _hintText(isDark), fontSize: 10),
      );
    }
    if (_secretFile == null) return const SizedBox.shrink();
    return FutureBuilder<int>(
      future: _secretFile!.length(),
      builder: (context, snapshot) {
        final size = snapshot.data ?? 0;
        return Text(
          "Payload: ${_formatBytes(size)} / ${_formatBytes(_carrierCapacity!.maxFileBytes)}",
          style: TextStyle(color: _hintText(isDark), fontSize: 10),
        );
      },
    );
  }

  Widget _buildFileHeadsUp(File f, bool isDark) {
    return Container(
      height: 100, width: double.infinity,
      decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: _glassBorder(isDark))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.insert_drive_file_rounded, color: _iconColor(isDark), size: 30),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(p.basename(f.path), style: TextStyle(color: _mainText(isDark), fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _buildFileNameBox(File? f, String placeholder, bool isDark) {
    return Container(
      height: 64, width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder(isDark))),
      child: Row(children: [
        Icon(f == null ? Icons.attach_file_rounded : Icons.insert_drive_file_rounded, color: f == null ? _hintText(isDark) : _iconColor(isDark), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(f == null ? placeholder : p.basename(f.path), style: TextStyle(color: f == null ? _hintText(isDark) : _mainText(isDark), fontSize: 12, fontWeight: f == null ? FontWeight.normal : FontWeight.bold), overflow: TextOverflow.ellipsis)),
        if (f != null) GestureDetector(onTap: () => setState(() => _secretFile = null), child: Icon(Icons.close, color: _subText(isDark), size: 18)),
      ]),
    );
  }

  int _utf8Len(String text) => text.isEmpty ? 0 : utf8.encode(text).length;

  bool _fitsPlaintext(int plaintextBytes) {
    final cap = _carrierCapacity;
    if (cap == null) return false;
    if (cap.maxCipherBytes <= 0) return false;
    final cipherBytes = ((plaintextBytes ~/ 16) + 1) * 16;
    return cipherBytes <= cap.maxCipherBytes;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    final kb = bytes / 1024;
    if (kb < 1024) return "${kb.toStringAsFixed(2)} KB";
    final mb = kb / 1024;
    return "${mb.toStringAsFixed(2)} MB";
  }

  Widget _sectionTitle(String t, bool isDark) {
     return Padding(padding: const EdgeInsets.only(bottom: 12), child: Align(alignment: Alignment.centerLeft, child: Text(t, style: GoogleFonts.outfit(color: _subText(isDark), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))));
  }

  Widget _modeSwitcher(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        _modeBtn(true, "String Payload", isDark), const SizedBox(width: 4), _modeBtn(false, "Binary Payload", isDark),
      ]),
    );
  }

  Widget _modeBtn(bool active, String t, bool isDark) {
    bool isSelected = _isEmbeddingText == active;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _isEmbeddingText = active), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isSelected ? _activeColor(isDark) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(t, style: TextStyle(color: isSelected ? Colors.white : _subText(isDark), fontSize: 12, fontWeight: FontWeight.bold))))));
  }

  Widget _buildGlassTextField({
    TextEditingController? controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    Function(String)? onChanged,
    bool obscure = true,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: TextField(
          controller: controller, obscureText: obscure, onChanged: onChanged,
          style: TextStyle(color: _mainText(isDark), fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint, hintStyle: TextStyle(color: _hintText(isDark), fontWeight: FontWeight.normal),
            filled: true, fillColor: _glassBg(isDark),
            prefixIcon: Icon(icon, color: _subText(isDark)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: _glassBorder(isDark))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: _glassBorder(isDark))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: kColorTrueHide)),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(String path, String msg, bool isDark) {
     final file = File(path);
     return Padding(
       padding: const EdgeInsets.only(top: 24),
       child: _buildGlassContainer(isDark, child: Column(children: [
         Text(msg, style: TextStyle(color: _iconColor(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
         const SizedBox(height: 16),
         _buildFileHeadsUp(file, isDark),
         const SizedBox(height: 16),
         SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: () => Share.shareXFiles([XFile(path)]), icon: const Icon(Icons.share), label: const Text("Share/Save"), style: ElevatedButton.styleFrom(backgroundColor: kColorTrueHide, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
         const SizedBox(height: 12),
         SizedBox(width: double.infinity, height: 50, child: VaultSaveButton(color: kColorTrueHide, onPressed: () => _saveToVault(path))),
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
        const Icon(Icons.visibility_off_rounded, size: 70, color: kColorTrueHide),
        const SizedBox(height: 16),
        Text("About TrueHide", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: _mainText(isDark))),
        const SizedBox(height: 12),
        Text("TrueHide implements advanced LSB pixel modulation. We weave encrypted bitstreams into the natural noise of photo data, creating a storage medium that is mathematically robust and visually undetectable. Your master password provides the entropy needed to recover the secret sequence.", style: TextStyle(color: _subText(isDark), height: 1.5)),
        const SizedBox(height: 20),
        _featurePoint("AES-256 Entropy", "Secrets are randomized and encrypted before concealment.", Icons.enhanced_encryption_rounded, isDark),
        _featurePoint("Least Significant Bit", "Modifies ONLY the zero-order bits for zero visual drift.", Icons.gradient_rounded, isDark),
        _featurePoint("Deterministic Extraction", "Precise reconstruction of payload strings and binaries.", Icons.find_in_page_rounded, isDark),
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
      appBar: AppBar(iconTheme: IconThemeData(color: _mainText(isDark)), title: Text("TrueHide", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, foregroundColor: _mainText(isDark)),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF130113), Color(0xFF030003)]))),
          SafeArea(child: Column(children: [_buildTabHeader(isDark), Expanded(child: TabBarView(controller: _tabController, children: [_buildHideTab(isDark), _buildRevealTab(isDark), _buildAboutTab(isDark)]))])),
        ],
      ),
    );
  }
}
