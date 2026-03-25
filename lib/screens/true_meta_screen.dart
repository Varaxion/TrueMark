import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'true_vault_screen.dart';
import '../utils/constants.dart';
import '../widgets/vault_button.dart';
import 'package:oktoast/oktoast.dart';

class TrueMetaScreen extends StatefulWidget {
  const TrueMetaScreen({super.key});

  @override
  State<TrueMetaScreen> createState() => _TrueMetaScreenState();
}

class _TrueMetaScreenState extends State<TrueMetaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  File? _analyzeFile;
  File? _stripFile;
  Map<String, Map<String, String>> _categorizedMetadata = {};
  bool _isAnalyzing = false;
  bool _isPurging = false;
  String? _purgedFilePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickFile({required bool isAnalyze, bool fromVault = false}) async {
    File? picked;
    if (fromVault) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: false)));
      if (result != null && result is File) picked = result;
    } else {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
      if (result != null && result.files.single.path != null) picked = File(result.files.single.path!);
    }
    if (picked != null) {
      setState(() {
        if (isAnalyze) {
          _analyzeFile = picked;
          _categorizedMetadata = {};
          _analyzeMetadata();
        } else {
          _stripFile = picked;
          _purgedFilePath = null;
        }
      });
    }
  }

  Future<void> _analyzeMetadata() async {
    if (_analyzeFile == null) return;
    setState(() => _isAnalyzing = true);
    try {
      final fileBytes = await _analyzeFile!.readAsBytes();
      final Map<String, String> fileInfo = {
        'Filename': p.basename(_analyzeFile!.path),
        'Size': '${(fileBytes.length / (1024 * 1024)).toStringAsFixed(2)} MB',
        'Extension': p.extension(_analyzeFile!.path).toUpperCase(),
        'Last Modified': _analyzeFile!.lastModifiedSync().toString(),
      };

      final data = await readExifFromBytes(fileBytes);
      final Map<String, Map<String, String>> categories = {'General': fileInfo};

      if (data.isNotEmpty) {
        data.forEach((k, v) {
          String category = 'Miscellaneous';
          if (k.startsWith('EXIF')) category = 'EXIF Data';
          else if (k.startsWith('Image')) category = 'Image Parameters';
          else if (k.startsWith('GPS')) category = 'GPS Geodata';
          else if (k.startsWith('Thumbnail')) category = 'Thumbnail Info';

          if (!categories.containsKey(category)) categories[category] = {};
          categories[category]![k] = v.toString();
        });
      }
      setState(() { _categorizedMetadata = categories; _isAnalyzing = false; });
    } catch (e) {
      setState(() { _categorizedMetadata = {'Error': {'Details': e.toString()}}; _isAnalyzing = false; });
    }
  }

  Future<void> _purgeMetadata() async {
    if (_stripFile == null) return;
    final ext = p.extension(_stripFile!.path).toLowerCase();
    
    // Supported formats for bitstream stripping
    if (!['.jpg', '.jpeg', '.png'].contains(ext)) {
      showToast("Forensic Strip only supports JPG/PNG media.", backgroundColor: Colors.amber);
      return;
    }

    setState(() => _isPurging = true);
    try {
      showToast("Analyzing Bitstream...", backgroundColor: kColorTrueMeta, duration: const Duration(seconds: 1));
      
      final bytes = await _stripFile!.readAsBytes();
      // This decodes the pixel data
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw "Asset Decode Failed. File may be corrupted or unsupported.";
      }

      // EXPLICITLY WIPE ALL INTERNALLY PURGED METADATA
      image.exif = img.ExifData(); // Clear EXIF
      image.textData = null; // Clear Text Data (PNG/etc)

      showToast("Sanitizing Headers...", backgroundColor: kColorTrueMeta, duration: const Duration(seconds: 1));

      List<int> outBytes;
      if (ext == '.png') {
        outBytes = img.encodePng(image);
      } else {
        outBytes = img.encodeJpg(image, quality: 95);
      }

      final tempDir = await getTemporaryDirectory();
      final originalBase = p.basenameWithoutExtension(_stripFile!.path);
      // Applying mandatory naming taxonomy: [OriginalName]_[Feature]_[Operation]_[Timestamp]
      final outPath = '${tempDir.path}/${originalBase}_TrueMeta_Strip_${DateTime.now().millisecondsSinceEpoch}$ext';
      
      final outFile = File(outPath);
      await outFile.writeAsBytes(outBytes);

      if (mounted) {
        setState(() { 
          _purgedFilePath = outPath; 
          _isPurging = false; 
        });
      }
      showToast("Metadata Footprint Cleared", backgroundColor: kColorTrueMeta);
    } catch (e) {
      if (mounted) setState(() => _isPurging = false);
      showToast("Purge Aborted: $e", backgroundColor: Colors.red, duration: const Duration(seconds: 3));
      print("TrueMeta Error: $e");
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
    showToast("Purged Asset Secured", backgroundColor: kColorTrueMeta);
  }

  // --- THEME HELPERS ---
  Color _mainText(bool _) => Colors.white;
  Color _subText(bool _) => Colors.white70;
  Color _hintText(bool _) => Colors.white24;
  Color _glassBg(bool _) => Colors.white.withOpacity(0.05);
  Color _glassBorder(bool _) => Colors.white10;
  Color _iconColor(bool _) => kColorTrueMeta;

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
        tabs: const [Tab(text: "Analyze"), Tab(text: "Strip"), Tab(icon: Icon(Icons.info_outline, size: 20))],
      ),
    );
  }

  Widget _buildSourcePicker({required bool isAnalyze, required bool isDark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            _pickerBtn(Icons.upload_file_rounded, "From Device", () => _pickFile(isAnalyze: isAnalyze, fromVault: false), isDark),
            const SizedBox(width: 4),
            _pickerBtn(kTrueVaultIcon, "From TrueVault", () => _pickFile(isAnalyze: isAnalyze, fromVault: true), isDark),
          ]),
        ),
      ),
    );
  }

  Widget _pickerBtn(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(icon, color: _subText(isDark)), const SizedBox(height: 4), Text(label, style: TextStyle(color: _mainText(isDark), fontSize: 11, fontWeight: FontWeight.bold))]))));
  }

  // Shared media preview widget — shows image for images, file icon + name for others, clear button always
  Widget _buildMediaPreview(File? f, bool isDark, VoidCallback onClear) {
    return Container(
      height: 160, width: double.infinity,
      decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(24), border: Border.all(color: _glassBorder(isDark))),
      child: f == null
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_photo_alternate_rounded, size: 40, color: kColorTrueMeta),
            const SizedBox(height: 8),
            Text("Select a file to get started", style: TextStyle(color: _hintText(isDark), fontSize: 12)),
          ]))
        : Stack(children: [
            _isImage(f)
              ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.file(f, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
              : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_fileIcon(f), color: _iconColor(isDark), size: 48),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(p.basename(f.path), style: TextStyle(color: _mainText(isDark), fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ),
                ])),
            Positioned(top: 6, right: 6, child: GestureDetector(
              onTap: onClear,
              child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 18)),
            )),
          ]),
    );
  }

  bool _isImage(File f) => ['.jpg', '.jpeg', '.png', '.webp'].contains(p.extension(f.path).toLowerCase());

  IconData _fileIcon(File f) {
    final ext = p.extension(f.path).toLowerCase();
    if (ext == '.pdf') return Icons.picture_as_pdf;
    if (['.mp4', '.mov', '.mkv'].contains(ext)) return Icons.video_file;
    if (['.mp3', '.aac', '.wav'].contains(ext)) return Icons.audio_file;
    if (['.doc', '.docx'].contains(ext)) return Icons.description;
    return Icons.insert_drive_file_rounded;
  }

  Widget _buildAnalyzeTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Icon(Icons.document_scanner_rounded, size: 70, color: kColorTrueMeta),
        const SizedBox(height: 16),
        Text("Analyze Metadata", style: GoogleFonts.outfit(color: _mainText(isDark), fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Categorized forensic analysis and identity footprint detection.", textAlign: TextAlign.center, style: TextStyle(color: _subText(isDark), fontSize: 13)),
        const SizedBox(height: 32),
        _buildSourcePicker(isAnalyze: true, isDark: isDark),
        const SizedBox(height: 16),
        _buildMediaPreview(_analyzeFile, isDark, () => setState(() { _analyzeFile = null; _categorizedMetadata = {}; })),
        const SizedBox(height: 16),
        if (_isAnalyzing) Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: _iconColor(isDark))),
        if (_categorizedMetadata.isNotEmpty && !_isAnalyzing) ...[
          ..._categorizedMetadata.entries.map((cat) => _buildCategory(cat.key, cat.value, isDark)).toList(),
        ],
      ]),
    );
  }

  Widget _buildStripTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Icon(Icons.cleaning_services_rounded, size: 70, color: kColorTrueMeta),
        const SizedBox(height: 16),
        Text("Metadata Purger", style: GoogleFonts.outfit(color: _mainText(isDark), fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Strip EXIF, GPS, and device signatures from your media.", textAlign: TextAlign.center, style: TextStyle(color: _subText(isDark), fontSize: 13)),
        const SizedBox(height: 32),
        _buildSourcePicker(isAnalyze: false, isDark: isDark),
        const SizedBox(height: 16),
        _buildMediaPreview(_stripFile, isDark, () => setState(() { _stripFile = null; _purgedFilePath = null; })),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton.icon(
            onPressed: (_stripFile == null || _isPurging) ? null : _purgeMetadata,
            icon: _isPurging ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _mainText(isDark), strokeWidth: 2)) : const Icon(Icons.auto_fix_high_rounded),
            label: Text("Strip All Metadata", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: kColorTrueMeta, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ),
        if (_purgedFilePath != null) ...[
           const SizedBox(height: 24),
           _buildGlassContainer(isDark, child: Column(children: [
             const Text("Metadata Footprint Cleared", style: TextStyle(color: kColorTrueMeta, fontWeight: FontWeight.bold, fontSize: 16)),
             const SizedBox(height: 16),
             SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: () => Share.shareXFiles([XFile(_purgedFilePath!)], text: 'Cleaned Media'), icon: const Icon(Icons.share), label: const Text("Share/Save"), style: ElevatedButton.styleFrom(backgroundColor: kColorTrueMeta, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
             const SizedBox(height: 12),
             SizedBox(width: double.infinity, height: 50, child: VaultSaveButton(color: kColorTrueMeta, onPressed: () => _saveToVault(_purgedFilePath!))),
           ])),
        ],
      ]),
    );
  }

  Widget _buildCategory(String title, Map<String, String> items, bool isDark) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         const SizedBox(height: 24),
         Text(title, style: GoogleFonts.outfit(color: _iconColor(isDark), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
         const SizedBox(height: 12),
         _buildGlassContainer(isDark, child: Column(children: items.entries.map((e) => _metaRow(e.key, e.value, isDark)).toList())),
       ],
     );
  }

  Widget _metaRow(String k, String v, bool isDark) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: Text(k, style: TextStyle(color: _subText(isDark), fontSize: 10))), const SizedBox(width: 8), Expanded(flex: 3, child: Text(v, style: TextStyle(color: _mainText(isDark), fontSize: 11, fontWeight: FontWeight.bold)))]));
  }

  Widget _buildGlassContainer(bool isDark, {required Widget child}) {
     return ClipRRect(
       borderRadius: BorderRadius.circular(20),
       child: BackdropFilter(
         filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
         child: Container(
           padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _glassBg(isDark), borderRadius: BorderRadius.circular(20), border: Border.all(color: _glassBorder(isDark))),
           child: child,
         ),
       ),
     );
  }

  Widget _buildAboutTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.document_scanner_rounded, size: 50, color: _iconColor(isDark)),
        const SizedBox(height: 16),
        Text("Forensic Purity", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: _mainText(isDark))),
        const SizedBox(height: 12),
        Text("TrueMeta reveals and purges the digital DNA hidden within your files. From high-accuracy EXIF extraction to a zero-footprint metadata recycler, we ensure your assets are clinically clean before distribution.", style: TextStyle(color: _subText(isDark), height: 1.5)),
        const SizedBox(height: 20),
        _featurePoint("Recursive Stripping", "Deep-purges proprietary tags and identifiers.", Icons.recycling_rounded, isDark),
        _featurePoint("GPS Cloaking", "Permanently removes location geodata and maps.", Icons.wrong_location_rounded, isDark),
        _featurePoint("Format Agnostic", "Supports advanced forensic analysis for all media.", Icons.category_rounded, isDark),
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
      appBar: AppBar(iconTheme: IconThemeData(color: _mainText(isDark)), title: Text("TrueMeta", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, foregroundColor: _mainText(isDark)),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E1401), Color(0xFF0F0A00)]))),
          SafeArea(child: Column(children: [_buildTabHeader(isDark), Expanded(child: TabBarView(controller: _tabController, children: [_buildAnalyzeTab(isDark), _buildStripTab(isDark), _buildAboutTab(isDark)]))])),
        ],
      ),
    );
  }
}
