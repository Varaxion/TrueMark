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
  bool _isGridView = true; // Toggle between Grid and List
  String _sortMode = 'Date (Newest)'; // Sort options

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
      showToast("Authentication Error: user not logged in.");
      Navigator.pop(context);
      return;
    }
    _userId = user.uid;

    final existingPin = await _secureStorage.read(key: '${_userId}_vault_pin');
    
    setState(() {
      if (existingPin == null) {
        _vaultState = VaultState.setupPin;
      } else {
        _vaultState = VaultState.enterPin;
      }
    });
  }

  void _submitPin() async {
    final inputPin = _pinController.text;
    if (inputPin.length < 6) {
      setState(() => _pinError = "PIN must be exactly 6 digits.");
      showToast("PIN must be exactly 6 digits.", backgroundColor: Colors.red);
      return;
    }
    
    setState(() => _pinError = null); // Reset error on new valid length input

    if (_vaultState == VaultState.setupPin) {
      // Move to confirm state
      _setupFirstPin = inputPin;
      _pinController.clear();
      setState(() {
        _vaultState = VaultState.confirmPin;
      });
      return;
    }

    if (_vaultState == VaultState.confirmPin) {
      if (inputPin == _setupFirstPin) {
        try {
          // Save to secure storage
          await _secureStorage.write(key: '${_userId}_vault_pin', value: inputPin);
        } catch (e) {
          showToast("Storage Warning: $e", position: ToastPosition.bottom);
        }

        if (mounted) {
          showToast("Vault PIN Successfully Set!", backgroundColor: Colors.green);
          _pinController.clear();
          setState(() {
            _vaultState = VaultState.unlocked;
          });
          await _loadVaultFiles();
        }
      } else {
        setState(() => _pinError = "PINs do not match. Try again.");
        showToast("PINs do not match. Try again.", backgroundColor: Colors.red);
        _pinController.clear();
        _setupFirstPin = null;
        setState(() {
          _vaultState = VaultState.setupPin;
        });
      }
      return;
    }

    if (_vaultState == VaultState.enterPin) {
      try {
        final existingPin = await _secureStorage.read(key: '${_userId}_vault_pin');
        if (inputPin == existingPin) {
          _pinController.clear();
          if (mounted) {
            setState(() {
              _vaultState = VaultState.unlocked;
            });
            await _loadVaultFiles();
          }
        } else {
          setState(() => _pinError = "Incorrect PIN. Access Denied.");
          showToast("Incorrect PIN. Try again.", backgroundColor: Colors.red);
          _pinController.clear();
        }
      } catch (e) {
        setState(() => _pinError = "Error reading secure PIN.");
        showToast("Error reading secure PIN.", backgroundColor: Colors.red);
      }
    }
  }

  void _changePin() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF303030),
        title: const Text("Change PIN", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to completely erase your current TrueVault PIN? You will be prompted to create a new one immediately.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _secureStorage.delete(key: '${_userId}_vault_pin');
              setState(() {
                _vaultState = VaultState.setupPin;
                _vaultFiles.clear();
              });
              showToast("PIN has been reset.");
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
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  Future<void> _loadVaultFiles({bool isPullToRefresh = false}) async {
    if (!mounted) return;
    if (!isPullToRefresh) setState(() => _isLoading = true);
    
    // Hard thread halt to allow OS Index restructuring
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final dir = await _getVaultDirectory();
      
      // Explicitly construct brand new File objects from string paths to obliterate
      // Dart's under-the-hood FileSystemEntity pointer bindings that fail to trigger state invalidations.
      List<File> files = dir.listSync()
          .where((e) => e is File)
          .map((e) => File(e.path))
          .toList();
      
      // Sort logic
      files.sort((a, b) {
        final statA = a.statSync();
        final statB = b.statSync();
        if (_sortMode == 'Date (Newest)') return statB.modified.compareTo(statA.modified);
        if (_sortMode == 'Date (Oldest)') return statA.modified.compareTo(statB.modified);
        if (_sortMode == 'Size (Largest)') return statB.size.compareTo(statA.size);
        return p.basename(a.path).compareTo(p.basename(b.path)); // A-Z
      });

      if (mounted) {
        setState(() {
          _vaultFiles = List.from(files); // Force brand new pointer
        });
      }
    } catch (e) {
      showToast("Failed to load vault files.", backgroundColor: Colors.red);
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
        showToast("File secured in TrueVault", backgroundColor: Colors.green);
        await _loadVaultFiles();
      } catch (e) {
        showToast("Error importing file", backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _exportFile(File file) async {
    Share.shareXFiles([XFile(file.path)], text: 'Exported from TrueVault');
  }

  Future<void> _deleteFile(File file) async {
    try {
      await file.delete();
      showToast("File permanently deleted", backgroundColor: Colors.amber);
      await _loadVaultFiles();
    } catch (e) {
      showToast("Error deleting file", backgroundColor: Colors.red);
    }
  }

  // --- UI BUILDERS ---

  Widget _buildAuthScreen() {
    String title = "TrueVault Locked";
    String subtitle = "Enter your 6-Digit PIN to access your secure storage.";
    String buttonText = "UNLOCK VAULT";
    IconData icon = Icons.security;

    if (_vaultState == VaultState.setupPin) {
      title = "Setup TrueVault";
      subtitle = "Create a powerful 6-Digit PIN. This PIN is securely tied strictly to your account login via Secure Storage.";
      buttonText = "SET NEW PIN";
      icon = Icons.lock_person;
    } else if (_vaultState == VaultState.confirmPin) {
      title = "Confirm PIN";
      subtitle = "Re-enter your 6-Digit PIN to verify.";
      buttonText = "CONFIRM PIN";
      icon = Icons.domain_verification;
    }

    return Expanded(
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Icon(icon, size: 80, color: Colors.white),
                 const SizedBox(height: 16),
                 Text(
                   title,
                   style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                   textAlign: TextAlign.center,
                 ),
                 const SizedBox(height: 8),
                 Text(
                   subtitle,
                   style: const TextStyle(color: Colors.white70, fontSize: 13),
                   textAlign: TextAlign.center,
                 ),
                 const SizedBox(height: 24),
                 if (_pinError != null)
                   Padding(
                     padding: const EdgeInsets.only(bottom: 12.0),
                     child: Text(_pinError!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                   ),
                 TextField(
                   controller: _pinController,
                   obscureText: true,
                   keyboardType: TextInputType.number,
                   style: const TextStyle(color: Colors.white, fontSize: 32, letterSpacing: 12),
                   textAlign: TextAlign.center,
                   maxLength: 6,
                   onSubmitted: (_) => _submitPin(),
                   decoration: InputDecoration(
                     hintText: "••••••",
                     hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 12),
                     counterText: "",
                     enabledBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12),
                       borderSide: const BorderSide(color: Colors.white30),
                     ),
                     focusedBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12),
                       borderSide: const BorderSide(color: Colors.white),
                     ),
                   ),
                 ),
                 const SizedBox(height: 24),
                 SizedBox(
                   width: double.infinity,
                   height: 55,
                   child: ElevatedButton(
                     onPressed: _submitPin,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.white,
                       foregroundColor: const Color(0xFFD50000),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                     child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   ),
                 ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFileOptions(File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  p.basename(file.path),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.tealAccent),
                title: const Text('Export / Share Outside', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _exportFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text('Delete Permanently', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteFile(file);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      }
    );
  }

  Widget _buildFileItem(File file) {
    final ext = p.extension(file.path).toLowerCase();
    final isImage = ['.jpg', '.jpeg', '.png', '.webp'].contains(ext);
    final isTmk = ext == '.tmk';
    final stat = file.statSync();
    final sizeMb = (stat.size / 1024 / 1024).toStringAsFixed(2);
    final dateStr = "${stat.modified.year}-${stat.modified.month.toString().padLeft(2, '0')}-${stat.modified.day.toString().padLeft(2, '0')}";

    Widget buildTmkIcon({double size = 40, double fontSize = 14}) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield, color: Colors.greenAccent, size: size),
          const SizedBox(height: 4),
          Text("TMK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize, letterSpacing: 1.5)),
        ],
      );
    }

    void _onFileTapped(File file, bool isImage) {
      if (widget.isPicker) {
        if (widget.pickImagesOnly && !isImage) {
          showToast("Invalid Type: Please explicitly select an image file.", backgroundColor: Colors.red);
          return;
        }
        Navigator.pop(context, file); // Shoot the file back securely
      } else {
        _showFileOptions(file);
      }
    }

    if (_isGridView) {
      return GestureDetector(
        onTap: () => _onFileTapped(file, isImage),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isTmk ? Colors.green.withOpacity(0.5) : Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isImage 
               ? Image.file(file, fit: BoxFit.cover)
               : isTmk 
                   ? Container(color: Colors.black45, child: buildTmkIcon())
                   : const Center(child: Icon(Icons.insert_drive_file, color: Colors.white54, size: 40)),
          ),
        ),
      );
    } else {
      // List View UI
      return Card(
        color: Colors.black45,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(side: BorderSide(color: isTmk ? Colors.green.withOpacity(0.3) : Colors.white12), borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          onTap: () => _onFileTapped(file, isImage),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: isImage 
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(file, fit: BoxFit.cover))
                : isTmk 
                    ? buildTmkIcon(size: 20, fontSize: 10)
                    : const Icon(Icons.insert_drive_file, color: Colors.white54),
          ),
          title: Text(p.basename(file.path), style: TextStyle(color: isTmk ? Colors.greenAccent : Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text("$dateStr  •  $sizeMb MB", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.more_vert, color: Colors.white70),
        ),
      );
    }
  }

  Widget _buildVaultExplorer() {
    return Expanded(
      child: Column(
        children: [
          // Toolbar Hub
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: Colors.black26,
            child: Row(
              children: [
                // Sort Dropdown
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortMode,
                      dropdownColor: Colors.black87,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      icon: const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.sort, color: Colors.white70),
                      ),
                      items: ['Date (Newest)', 'Date (Oldest)', 'Name (A-Z)', 'Size (Largest)']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _sortMode = val);
                          _loadVaultFiles();
                        }
                      },
                    ),
                  ),
                ),
                // Toggle View (List vs Grid)
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, color: Colors.white),
                  onPressed: () {
                    setState(() => _isGridView = !_isGridView);
                  },
                ),
                // Change PIN Settings
                IconButton(
                  icon: const Icon(Icons.manage_accounts, color: Colors.white70),
                  onPressed: _changePin,
                  tooltip: "Vault Settings",
                ),
              ],
            ),
          ),
          
          // Secondary Import Banner
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_vaultFiles.length} Secured Items",
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _importFile,
                  icon: const Icon(Icons.add_to_drive, size: 18),
                  label: const Text("IMPORT"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          
          // Main Render Area
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : RefreshIndicator(
                  onRefresh: () => _loadVaultFiles(isPullToRefresh: true),
                  color: Colors.teal,
                  backgroundColor: Colors.white,
                  child: _vaultFiles.isEmpty 
                     ? SingleChildScrollView(
                         physics: const AlwaysScrollableScrollPhysics(),
                         child: SizedBox(
                           height: MediaQuery.of(context).size.height * 0.6,
                           child: const Center(
                             child: Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 Container(
                                   padding: EdgeInsets.all(20),
                                   decoration: BoxDecoration(
                                     color: Colors.white.withOpacity(0.1),
                                     shape: BoxShape.circle,
                                   ),
                                   child: Icon(Icons.lock_person_rounded, color: Colors.white, size: 64),
                                 ),
                                 SizedBox(height: 16),
                                 Text("Your TrueVault is empty.", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                                 SizedBox(height: 8),
                                 Padding(
                                   padding: EdgeInsets.symmetric(horizontal: 40.0),
                                   child: Text("Import raw images directly here, or save files strictly to your vault after processing them.", style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
                                 ),
                               ],
                             ),
                           ),
                         ),
                       )
                     : _isGridView
                        ? GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _vaultFiles.length,
                            itemBuilder: (context, index) => _buildFileItem(_vaultFiles[index]),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _vaultFiles.length,
                            itemBuilder: (context, index) => _buildFileItem(_vaultFiles[index]),
                          )
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB71C1C), Color(0xFFD50000)], // Deep Crimson Theme
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
                        "TrueVault",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_vaultState == VaultState.unlocked)
                       IconButton(
                         icon: const Icon(Icons.lock_outline, color: Colors.white),
                         onPressed: () {
                           setState(() {
                             _vaultState = VaultState.enterPin;
                             _pinController.clear();
                             _vaultFiles = []; // Clear memory/screen
                           });
                         },
                         tooltip: "Lock Vault",
                       )
                    else 
                       const SizedBox(width: 48), // Balance for back button
                  ],
                ),
              ),

              // Render Logic
              if (_vaultState == VaultState.loading)
                 const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white)))
              else if (_vaultState == VaultState.unlocked)
                 _buildVaultExplorer()
              else
                 _buildAuthScreen()
             ],
          ),
        ),
      ),
    );
  }
}
