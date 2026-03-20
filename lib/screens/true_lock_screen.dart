
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oktoast/oktoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;
import 'package:truemark/services/true_lock_service.dart';
import 'true_vault_screen.dart';

class TrueLockScreen extends StatefulWidget {
  final bool isEncryptMode; // Opens directly to Encrypt or Decrypt tab

  const TrueLockScreen({super.key, required this.isEncryptMode});

  @override
  State<TrueLockScreen> createState() => _TrueLockScreenState();
}

class _TrueLockScreenState extends State<TrueLockScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TrueLockService _vaultService = TrueLockService();
  
  // State variables for Encryption
  File? _fileToEncrypt;
  File? _encryptedResult; // Store result
  final _encryptPasswordController = TextEditingController();
  bool _isEncrypting = false;

  // State variables for Decryption
  File? _fileToDecrypt;
  final _decryptPasswordController = TextEditingController();
  bool _isDecrypting = false;
  File? _decryptedResultFile; 
  bool _isPreviewVisible = false; // Toggle for "View" option

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.isEncryptMode ? 0 : 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _encryptPasswordController.dispose();
    _decryptPasswordController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _pickFileToEncrypt() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _fileToEncrypt = File(result.files.single.path!);
        _encryptedResult = null; 
      });
    }
  }

  Future<void> _pickFileToDecrypt() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, 
        allowedExtensions: ['tmk'],
      );
      
      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        setState(() {
          _fileToDecrypt = File(path);
          _decryptedResultFile = null; 
          _isPreviewVisible = false;
        });
      }
    } catch (e) {
      // Fallback for some devices that might not support custom extension filtering well
       FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
       if (result != null && result.files.single.path != null) {
          if (!result.files.single.path!.toLowerCase().endsWith('.tmk')) {
            showToast("Please select a valid .tmk file", backgroundColor: Colors.orange);
            return;
          }
          setState(() {
            _fileToDecrypt = File(result.files.single.path!);
            _decryptedResultFile = null; 
            _isPreviewVisible = false;
          });
       }
    }
  }

  Future<void> _pickFileToEncryptFromVault() async {
    final File? file = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: true)),
    );
    if (file != null) {
      setState(() {
        _fileToEncrypt = file;
        _encryptedResult = null; 
      });
    }
  }

  Future<void> _pickFileToDecryptFromVault() async {
    final File? file = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: false)),
    );
    if (file != null) {
      if (!file.path.toLowerCase().endsWith('.tmk')) {
        showToast("Please pick a TrueLock (.tmk) archive file.", backgroundColor: Colors.red);
        return;
      }
      setState(() {
        _fileToDecrypt = file;
        _decryptedResultFile = null; 
        _isPreviewVisible = false;
      });
    }
  }

  Future<void> _saveToVault(String absolutePath) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showToast("Error: Account not logged in.", backgroundColor: Colors.red);
        return;
      }
      final root = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${root.path}/TrueVault_${user.uid}');
      if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
      
      final file = File(absolutePath);
      final newPath = '${vaultDir.path}/${p.basename(file.path)}';
      await file.copy(newPath);
      showToast("File instantly protected inside TrueVault!", position: ToastPosition.bottom, backgroundColor: Colors.green);
    } catch (e) {
      showToast("Error saving to vault", backgroundColor: Colors.red);
    }
  }


  // --- PASSWORD STRENGTH LOGIC ---
  
  String _passwordStrength = "";
  Color _strengthColor = Colors.transparent;
  double _strengthValue = 0;

  void _checkStrength(String pass) {
    if (pass.isEmpty) {
      setState(() {
        _passwordStrength = "";
        _strengthColor = Colors.transparent;
        _strengthValue = 0;
      });
      return;
    }

    int score = 0;
    if (pass.length >= 8) score++;
    if (pass.contains(RegExp(r'[A-Z]'))) score++;
    if (pass.contains(RegExp(r'[0-9]'))) score++;
    if (pass.contains(RegExp(r'[!@#\$&*~]'))) score++;

    String text;
    Color color;
    double val;

    if (pass.length < 6) {
      text = "Too Short";
      color = Colors.red;
      val = 0.2;
    } else if (score < 2) {
      text = "Weak";
      color = Colors.orange;
      val = 0.4;
    } else if (score < 4) {
      text = "Moderate";
      color = Colors.yellow;
      val = 0.7;
    } else {
      text = "Strong";
      color = Colors.green;
      val = 1.0;
    }

    setState(() {
      _passwordStrength = text;
      _strengthColor = color;
      _strengthValue = val;
    });
  }

  Future<void> _performEncryption() async {
    // ... existing encryption logic ...
    if (_fileToEncrypt == null) return;
    String pass = _encryptPasswordController.text;
    if (pass.length < 6) return; // Basic length check is absolute minimum

    setState(() => _isEncrypting = true);
    
    try {
      final bytes = await _fileToEncrypt!.readAsBytes();
      final encryptedBytes = await _vaultService.encryptData(bytes, pass);

      final tempDir = await getTemporaryDirectory();
      final originalName = _fileToEncrypt!.path.split(Platform.pathSeparator).last;
      final nameWithoutExt = originalName.split('.').first;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${tempDir.path}/encrypted_${nameWithoutExt}_$timestamp.tmk';
      
      final encryptedFile = File(newPath);
      await encryptedFile.writeAsBytes(encryptedBytes);

      setState(() {
        _isEncrypting = false;
        _encryptedResult = encryptedFile;
      });
      
      showToast("Encryption Successful! Ready to Share.", backgroundColor: Colors.green);

    } catch (e) {
      setState(() => _isEncrypting = false);
      showToast("Error: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _performDecryption() async {
    if (_fileToDecrypt == null) return;
    String pass = _decryptPasswordController.text;
    if (pass.isEmpty) return;

    setState(() => _isDecrypting = true);

    try {
      final bytes = await _fileToDecrypt!.readAsBytes();
      final decryptedBytes = await _vaultService.decryptData(bytes, pass);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${tempDir.path}/decrypted_$timestamp.png'; 
      
      final decryptedFile = File(newPath);
      await decryptedFile.writeAsBytes(decryptedBytes);

      setState(() {
        _isDecrypting = false;
        _decryptedResultFile = decryptedFile;
        _isPreviewVisible = false; 
      });

      showToast("Decryption Successful!", backgroundColor: Colors.green);

    } catch (e) {
      setState(() => _isDecrypting = false);
      String errorMsg = e.toString();
      // AES-GCM Auth Tag Mismatch typically means wrong password
      if (errorMsg.contains("MAC") || errorMsg.contains("auth") || errorMsg.contains("Incorrect")) {
        showToast("Incorrect Password or Corrupted File", backgroundColor: Colors.red, duration: const Duration(seconds: 3));
      } else {
         showToast("Decryption Failed: $errorMsg", backgroundColor: Colors.red);
      }
    }
  }
  
  Future<void> _shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'Secure File via TrueMark');
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Green gradient theme for TrueLock
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF00897B)], // Dark Green to Emerald
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
                        "TrueLock",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance back button
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
                      Tab(text: "ENCRYPT", icon: Icon(Icons.lock_rounded)),
                      Tab(text: "DECRYPT", icon: Icon(Icons.lock_open_rounded)),
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
                    _buildEncryptTab(),
                    _buildDecryptTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEncryptTab() {
    bool canEncrypt = _fileToEncrypt != null 
        && _encryptPasswordController.text.length >= 6 
        && !_isEncrypting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Feature Header
          const Icon(Icons.enhanced_encryption_rounded, size: 80, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            "Encrypt Your Files",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Protect your sensitive files with military-grade AES-256-GCM encryption. Only you can decrypt them with your password.",
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // File Picker Card
          _GlassCard(
            child: Column(
              children: [
                const Icon(Icons.description_rounded, size: 50, color: Colors.white70),
                const SizedBox(height: 10),
                if (_fileToEncrypt != null)
                  Text(
                    "Selected: ${_fileToEncrypt!.path.split(Platform.pathSeparator).last}",
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  )
                else
                  const Text("Select an image to encrypt", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickFileToEncrypt,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text("Device"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _pickFileToEncryptFromVault,
                      icon: const Icon(Icons.lock_person_rounded, size: 18),
                      label: const Text("TrueVault"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Password Field
          TextField(
            controller: _encryptPasswordController,
            obscureText: true,
            onChanged: (val) {
               _checkStrength(val);
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Set Password (Min 6 chars)",
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.vpn_key, color: Colors.white70),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white30), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white), borderRadius: BorderRadius.circular(12)),
            ),
          ),
          
          // STRENGTH INDICATOR
          if (_encryptPasswordController.text.isNotEmpty) ...[
             const SizedBox(height: 8),
             Row(
               children: [
                 Expanded(
                   child: LinearProgressIndicator(
                     value: _strengthValue,
                     color: _strengthColor,
                     backgroundColor: Colors.white12,
                     minHeight: 4,
                   ),
                 ),
                 const SizedBox(width: 10),
                 Text(_passwordStrength, style: TextStyle(color: _strengthColor, fontWeight: FontWeight.bold, fontSize: 12)),
               ],
             ),
          ],
          
          const SizedBox(height: 30),
          
          // Encrypt Button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: canEncrypt ? _performEncryption : null,
              icon: const Icon(Icons.enhanced_encryption),
              label: _isEncrypting ? 
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : 
                const Text("ENCRYPT"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853), // Bright Green
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          
          // Success area
          if (_encryptedResult != null) ...[
            const SizedBox(height: 30),
            const Divider(color: Colors.white24),
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
                       Text("Encryption Successful!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     ],
                   ),
                   const SizedBox(height: 16),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton.icon(
                        onPressed: () => _shareFile(_encryptedResult!),
                        icon: const Icon(Icons.share),
                        label: const Text("SHARE / SAVE FILE"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
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

  Widget _buildDecryptTab() {
    bool canDecrypt = _fileToDecrypt != null 
        && _decryptPasswordController.text.isNotEmpty 
        && !_isDecrypting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Feature Header
          const Icon(Icons.lock_open_rounded, size: 80, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            "Decrypt Your Files",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Unlock your encrypted .tmk files. Enter the correct password to reveal the original content.",
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // File Picker Card
          _GlassCard(
            child: Column(
              children: [
                const Icon(Icons.description_rounded, size: 50, color: Colors.white70),
                const SizedBox(height: 10),
                if (_fileToDecrypt != null)
                  Text(
                    "Selected: ${_fileToDecrypt!.path.split(Platform.pathSeparator).last}",
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  )
                else
                  const Text("Select a .tmk file to decrypt", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickFileToDecrypt,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text("Device"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _pickFileToDecryptFromVault,
                      icon: const Icon(Icons.lock_person_rounded, size: 18),
                      label: const Text("TrueVault"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Password Field
          TextField(
            controller: _decryptPasswordController,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Enter Password",
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.password, color: Colors.white70),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white30), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white), borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 30),
          
          // Decrypt Button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: canDecrypt ? _performDecryption : null,
              icon: const Icon(Icons.lock_open),
              label: _isDecrypting ? 
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : 
                const Text("DECRYPT"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853), // Bright Green
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
           
          // SUCCESS ACTIONS
          if (_decryptedResultFile != null) ...[
            const SizedBox(height: 30),
            const Divider(color: Colors.white24),
            const Text("Decryption Successful!", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _isPreviewVisible = true),
                    icon: const Icon(Icons.image),
                    label: const Text("VIEW FILE"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _shareFile(_decryptedResultFile!),
                    icon: const Icon(Icons.save_alt),
                    label: const Text("SAVE / SHARE"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveToVault(_decryptedResultFile!.path),
                icon: const Icon(Icons.security),
                label: const Text("STORE SECURELY IN VAULT", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            // PREVIEW AREA
            if (_isPreviewVisible) ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_decryptedResultFile!),
              ),
            ],
          ]
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}
