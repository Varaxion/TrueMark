import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:oktoast/oktoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/vault_button.dart';
import '../utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

enum VaultState { loading, setupPin, confirmPin, enterPin, unlocked }

class TrueVaultScreen extends StatefulWidget {
  final bool isPicker;
  final bool pickImagesOnly;

  const TrueVaultScreen({
    super.key, 
    this.isPicker = false, 
    this.pickImagesOnly = false
  });

  @override
  State<TrueVaultScreen> createState() => _TrueVaultScreenState();
}

class _TrueVaultScreenState extends State<TrueVaultScreen> {
  // Authentication State
  VaultState _vaultState = VaultState.loading;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final TextEditingController _pinController = TextEditingController();
  
  String? _userId;
  String? _setupFirstPin; 
  String? _pinError;
  
  // File Explorer State
  List<File> _vaultFiles = [];
  bool _isLoading = false;
  bool _isGridView = true; 
  String _sortMode = 'Date (Newest)'; 
  String _filterMode = 'All'; // All, Images, Protected, Documents

  @override
  void initState() {
    super.initState();
    _initVaultAuth();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // --- AUTHENTICATION LOGIC ---

  Future<void> _initVaultAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showToast("Identity Authentication Required.");
      Navigator.pop(context);
      return;
    }
    _userId = user.uid;
    final existingPin = await _secureStorage.read(key: '${_userId}_vault_pin');
    
    if (mounted) {
      setState(() {
        if (existingPin == null) _vaultState = VaultState.setupPin;
        else _vaultState = VaultState.enterPin;
      });
    }
  }

  void _submitPin() async {
    final inputPin = _pinController.text;
    if (inputPin.length < 6) {
      setState(() => _pinError = "PIN must be exactly 6 digits.");
      return;
    }
    
    setState(() => _pinError = null); 

    if (_vaultState == VaultState.setupPin) {
      _setupFirstPin = inputPin;
      _pinController.clear();
      setState(() => _vaultState = VaultState.confirmPin);
      return;
    }

    if (_vaultState == VaultState.confirmPin) {
      if (inputPin == _setupFirstPin) {
        try {
          await _secureStorage.write(key: '${_userId}_vault_pin', value: inputPin);
          if (mounted) {
            showToast("Vault Locked and Secured", backgroundColor: kColorTrueVault);
            _pinController.clear();
            setState(() => _vaultState = VaultState.unlocked);
            _loadVaultFiles(); // Direct Load
          }
        } catch (e) {
          showToast("Storage Error: $e", backgroundColor: Colors.red);
        }
      } else {
        setState(() { _pinError = "PIN Mismatch. Restart Setup."; _vaultState = VaultState.setupPin; });
        _pinController.clear();
        _setupFirstPin = null;
      }
      return;
    }

    if (_vaultState == VaultState.enterPin) {
      try {
        final existingPin = await _secureStorage.read(key: '${_userId}_vault_pin');
        if (inputPin == existingPin) {
          _pinController.clear();
          if (mounted) {
            setState(() => _vaultState = VaultState.unlocked);
            _loadVaultFiles();
          }
        } else {
          setState(() { _pinError = "Incorrect PIN. Identification Failed."; });
          _pinController.clear();
        }
      } catch (e) {
        showToast("Secure Access Error", backgroundColor: Colors.red);
      }
    }
  }

  void _confirmResetPin() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Reset vault access?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("All your files remain safe, but you'll be prompted to set a new PIN immediately.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() { _vaultState = VaultState.setupPin; _pinController.clear(); });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Reset PIN"),
          )
        ],
      )
    );
  }

  // --- FILE EXPLORER LOGIC ---

  Future<Directory> _getVaultDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${root.path}/TrueVault_${_userId}');
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    return vaultDir;
  }

  Future<void> _loadVaultFiles({bool isPullToRefresh = false}) async {
    if (!mounted) return;
    if (!isPullToRefresh) setState(() => _isLoading = true);
    try {
      final dir = await _getVaultDirectory();
      List<File> files = dir.listSync().whereType<File>().where((file) {
        if (_filterMode == 'All') return true;
        final ext = p.extension(file.path).toLowerCase();
        if (_filterMode == 'Images') return ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext);
        if (_filterMode == 'Protected') return ext == '.tmk';
        if (_filterMode == 'Documents') return ['.pdf', '.txt', '.doc', '.docx', '.csv'].contains(ext);
        return true;
      }).toList();
      files.sort((a, b) {
        final statA = a.statSync(); final statB = b.statSync();
        if (_sortMode == 'Date (Newest)') return statB.modified.compareTo(statA.modified);
        if (_sortMode == 'Date (Oldest)') return statA.modified.compareTo(statB.modified);
        if (_sortMode == 'Size (Largest)') return statB.size.compareTo(statA.size);
        return p.basename(a.path).compareTo(p.basename(b.path));
      });
      if (mounted) setState(() { _vaultFiles = files; });
    } catch (e) {
      showToast("Vault Access Denied or Corrupt", backgroundColor: Colors.red);
    } finally {
      if (mounted && !isPullToRefresh) setState(() => _isLoading = false);
    }
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any); 
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final dir = await _getVaultDirectory();
      final newPath = '${dir.path}/${p.basename(file.path)}';
      try {
        await file.copy(newPath);
        showToast("File Securely Imported", backgroundColor: kColorTrueVault);
        _loadVaultFiles();
      } catch (e) {
        showToast("Import Failure", backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _exportFile(File file) async {
    Share.shareXFiles([XFile(file.path)], text: 'Exported from TrueVault');
  }

  Future<void> _deleteFile(File file) async {
    try {
      await file.delete();
      showToast("Asset Purged", backgroundColor: Colors.redAccent);
      _loadVaultFiles();
    } catch (e) {
      showToast("Deletion Error", backgroundColor: Colors.red);
    }
  }

  // --- UI BUILDERS ---

  Widget _buildAuthScreen() {
    String title = "TrueVault Locked";
    String subtitle = "Enter your 6-Digit Master PIN to unlock your secure vault.";

    IconData icon = kTrueVaultIcon;

    if (_vaultState == VaultState.setupPin) {
      title = "Configure Vault";
      subtitle = "Create a unique 6-Digit PIN to secure your private assets.";

    } else if (_vaultState == VaultState.confirmPin) {
      title = "Verify PIN";
      subtitle = "Confirm your 6-Digit PIN to ensure accuracy.";

    }

    return Expanded(
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(32), margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 80, color: kVaultPrimary), const SizedBox(height: 16),
               Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
               const SizedBox(height: 8),
               Text(subtitle, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
               const SizedBox(height: 24),
               if (_pinError != null) Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Text(_pinError!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13))),
               TextField(
                 controller: _pinController, obscureText: true, keyboardType: TextInputType.number,
                 style: const TextStyle(color: Colors.white, fontSize: 32, letterSpacing: 12),
                 textAlign: TextAlign.center, maxLength: 6,
                 onChanged: (val) { if (val.length == 6) _submitPin(); },
                 onSubmitted: (_) => _submitPin(),
                 decoration: InputDecoration(hintText: "••••••", hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 12), counterText: "", enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white30)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white))),
               ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildFileItem(File file) {
    final ext = p.extension(file.path).toLowerCase();
    final isImage = ['.jpg', '.jpeg', '.png', '.webp'].contains(ext);
    final isVideo = ['.mp4', '.mov', '.mkv', '.avi'].contains(ext);
    final isPdf = ext == '.pdf';
    final isTmk = ext == '.tmk';
    final stat = file.statSync();
    final sizeMb = (stat.size / 1024 / 1024).toStringAsFixed(2);
    final dateStr = DateFormat('yyyy-MM-dd').format(stat.modified);

    Widget buildTmkIcon({double size = 40}) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield, color: kColorTrueLock, size: size), const SizedBox(height: 4), const Text("TMK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5))]);

    void _onFileTapped(File file, bool isImage) {
      if (widget.isPicker) {
        if (widget.pickImagesOnly && !isImage) { showToast("Images Only Required", backgroundColor: Colors.red); return; }
        Navigator.pop(context, file); 
      } else { _showFileOptions(file); }
    }

    if (_isGridView) {
      return GestureDetector(onTap: () => _onFileTapped(file, isImage), child: Container(decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: isTmk ? kColorTrueLock.withOpacity(0.5) : Colors.white24)), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: isImage ? Image.file(file, fit: BoxFit.cover) : isTmk ? Container(color: Colors.black45, child: buildTmkIcon()) : isVideo ? const Center(child: Icon(Icons.video_file, color: Colors.blueAccent, size: 40)) : isPdf ? const Center(child: Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 40)) : const Center(child: Icon(Icons.insert_drive_file, color: Colors.white54, size: 40)))));
    } else {
      return Card(color: Colors.black45, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(side: BorderSide(color: isTmk ? kColorTrueLock.withOpacity(0.3) : Colors.white12), borderRadius: BorderRadius.circular(12)), child: ListTile(onTap: () => _onFileTapped(file, isImage), leading: Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)), child: isImage ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(file, fit: BoxFit.cover)) : isTmk ? buildTmkIcon(size: 20) : isVideo ? const Icon(Icons.video_file, color: Colors.blueAccent) : isPdf ? const Icon(Icons.picture_as_pdf, color: Colors.redAccent) : const Icon(Icons.insert_drive_file, color: Colors.white54)), title: Text(p.basename(file.path), style: TextStyle(color: isTmk ? kColorTrueLock : Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text("$dateStr  •  $sizeMb MB", style: const TextStyle(color: Colors.white60, fontSize: 11)), trailing: const Icon(Icons.more_vert, color: Colors.white70)));
    }
  }

  void _showFileOptions(File file) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E1E1E), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) {
      return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16.0), child: Text(p.basename(file.path), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        const Divider(color: Colors.white24),
        ListTile(leading: const Icon(Icons.share, color: kColorTrueVault), title: const Text('Export Outside', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _exportFile(file); }),
        ListTile(leading: const Icon(Icons.delete_forever, color: Colors.redAccent), title: const Text('Delete Permanently', style: TextStyle(color: Colors.redAccent)), onTap: () { Navigator.pop(context); _deleteFile(file); }),
        const SizedBox(height: 10),
      ]));
    });
  }

  Widget _buildVaultExplorer() {
    return Expanded(child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), color: Colors.black26, child: Row(children: [
        DropdownButtonHideUnderline(child: DropdownButton<String>(value: _sortMode, dropdownColor: const Color(0xFF1C2529), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), icon: const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.sort, color: Colors.white70)), items: ['Date (Newest)', 'Date (Oldest)', 'Name (A-Z)', 'Size (Largest)'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (val) { if (val != null) { setState(() => _sortMode = val); _loadVaultFiles(); } })),
        const Spacer(),
        IconButton(icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, color: Colors.white), onPressed: () => setState(() => _isGridView = !_isGridView)),
        IconButton(icon: const Icon(Icons.password_rounded, color: Colors.white70), onPressed: _confirmResetPin, tooltip: "Reset PIN"),
      ])),
      Container(
        height: 50, color: Colors.black12,
        child: ListView(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: ['All', 'Images', 'Protected', 'Documents'].map((f) => 
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
              label: Text(f, style: TextStyle(color: _filterMode == f ? Colors.black87 : Colors.white70)),
              selected: _filterMode == f,
              selectedColor: kColorTrueVault, backgroundColor: Colors.black45,
              onSelected: (val) { if (val) { setState(() => _filterMode = f); _loadVaultFiles(); } }
            ))
          ).toList(),
        ),
      ),
      Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${_vaultFiles.length} Secured Assets", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)), ElevatedButton.icon(onPressed: _importFile, icon: const Icon(Icons.add_box_rounded, size: 18), label: const Text("Import"), style: ElevatedButton.styleFrom(backgroundColor: kVaultPrimary.withOpacity(0.9), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))])),
      Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.white)) : RefreshIndicator(onRefresh: () => _loadVaultFiles(isPullToRefresh: true), color: kColorTrueVault, backgroundColor: Color(0xFF1E1E1E), child: _vaultFiles.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(kTrueVaultIcon, color: Colors.white24, size: 64), const SizedBox(height: 16), const Text("Vault is Empty", style: TextStyle(color: Colors.white24, fontSize: 18))])) : _isGridView ? GridView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: _vaultFiles.length, itemBuilder: (context, index) => _buildFileItem(_vaultFiles[index])) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _vaultFiles.length, itemBuilder: (context, index) => _buildFileItem(_vaultFiles[index])))),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    const isDark = true;
    return PopScope(
      canPop: _vaultState == VaultState.enterPin || _vaultState == VaultState.unlocked,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_vaultState == VaultState.setupPin || _vaultState == VaultState.confirmPin) {
          final existing = await _secureStorage.read(key: '${_userId}_vault_pin');
          if (existing != null) { setState(() => _vaultState = VaultState.unlocked); return; }
        }
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: isDark ? [const Color(0xFF000000), const Color(0xFF001F24)] : [const Color(0xFF006064), const Color(0xFF00838F)])),
          child: SafeArea(child: Column(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0), child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () async {
                if (_vaultState == VaultState.setupPin || _vaultState == VaultState.confirmPin) {
                  final existing = await _secureStorage.read(key: '${_userId}_vault_pin');
                  if (existing != null) { setState(() => _vaultState = VaultState.unlocked); return; }
                }
                Navigator.pop(context);
              }),
              Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(kTrueVaultIcon, color: kVaultPrimary, size: 24),
                const SizedBox(width: 8),
                Text("TrueVault", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ])),
              if (_vaultState == VaultState.unlocked) IconButton(icon: const Icon(Icons.lock_person_rounded, color: Colors.white), onPressed: () => setState(() { _vaultState = VaultState.enterPin; _pinController.clear(); _vaultFiles = []; }), tooltip: "Lock Vault") else const SizedBox(width: 48),
            ])),
            if (_vaultState == VaultState.loading) const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white)))
            else if (_vaultState == VaultState.unlocked) _buildVaultExplorer()
            else _buildAuthScreen()
          ])),
        ),
      ),
    );
  }
}
