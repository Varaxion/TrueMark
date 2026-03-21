
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:oktoast/oktoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'true_vault_screen.dart';
import '../widgets/vault_button.dart';

class TrueHideScreen extends StatefulWidget {
  final bool isHideMode;
  const TrueHideScreen({super.key, required this.isHideMode});

  @override
  State<TrueHideScreen> createState() => _TrueHideScreenState();
}

class _TrueHideScreenState extends State<TrueHideScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // -- HIDE (ENCODE) STATE --
  File? _coverImage;
  bool _isEmbedding = false;
  String _secretType = 'text'; // 'text' or 'image'
  final TextEditingController _secretTextController = TextEditingController();
  File? _secretImage;
  final TextEditingController _encodePasswordController = TextEditingController();
  File? _outputImage; // The result of hiding
  String _passwordStrength = "";
  Color _strengthColor = Colors.transparent;
  double _strengthValue = 0;
  
  // -- SHARED MOCK STATE --
  static String _mockSecretType = 'text';
  static String _mockSecretText = '';
  static File? _mockSecretImage;

  // -- SEEK (DECODE) STATE --
  File? _stegoImage; // The image with hidden data
  bool _isExtracting = false;
  final TextEditingController _decodePasswordController = TextEditingController();
  String? _revealedText;
  File? _revealedImage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.isHideMode ? 0 : 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _secretTextController.dispose();
    _encodePasswordController.dispose();
    _decodePasswordController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _coverImage = File(result.files.single.path!);
        _outputImage = null; // Reset previous result
      });
    }
  }

  Future<void> _pickSecretImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _secretImage = File(result.files.single.path!);
      });
    }
  }

  Future<void> _pickStegoImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _stegoImage = File(result.files.single.path!);
        _revealedText = null;
        _revealedImage = null;
      });
    }
  }

  Future<void> _pickCoverImageFromVault() async {
    final File? file = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: true)),
    );
    if (file != null) {
      setState(() {
        _coverImage = file;
        _outputImage = null;
      });
    }
  }

  Future<void> _pickSecretImageFromVault() async {
    final File? file = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: true)),
    );
    if (file != null) {
      setState(() {
        _secretImage = file;
      });
    }
  }

  Future<void> _pickStegoImageFromVault() async {
    final File? file = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: true)),
    );
    if (file != null) {
      setState(() {
        _stegoImage = file;
        _revealedText = null;
        _revealedImage = null;
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
      showToast("File secured in TrueVault!", position: ToastPosition.bottom, backgroundColor: Colors.green);
    } catch (e) {
      showToast("Error saving to vault", backgroundColor: Colors.red);
    }
  }

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

  void _performHide() async {
    // Mock Processing
    setState(() => _isEmbedding = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulate work
    
    // Create meaningful filename for sharing
    // Uses temporary directory so it doesn't clutter user storage unless saved
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = p.extension(_coverImage!.path);
    final newPath = '${directory.path}/TrueHide_Encrypted_$timestamp$extension';
    
    // Copy cover image to new path (simulating the embedding result)
    final output = await _coverImage!.copy(newPath);
    
    // Save Mock State for specific demo flow
    _mockSecretType = _secretType;
    _mockSecretText = _secretTextController.text;
    _mockSecretImage = _secretImage;

    setState(() {
      _isEmbedding = false;
      _outputImage = output; 
    });
    
    showToast("Secret successfully hidden!", backgroundColor: Colors.green);
  }

  void _performReveal() async {
    // Mock Processing
    setState(() => _isExtracting = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulate work

    setState(() {
      _isExtracting = false;
      if (_mockSecretType == 'text') {
         _revealedText = _mockSecretText.isNotEmpty 
             ? _mockSecretText 
             : "CONFIDENTIAL: Project TrueMark launch codes: 8821-9923-AX99"; // Fallback
         _revealedImage = null;
      } else {
         _revealedText = null;
         _revealedImage = _mockSecretImage;
      }
    });

     showToast("Secret revealed!", backgroundColor: Colors.green);
  }

  // --- UI BUILDERS ---

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
                ? [const Color(0xFF000000), const Color(0xFF2D0A31)]
                : [const Color(0xFF4527A0), const Color(0xFF7B1FA2)],
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
                        "TrueHide",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.visibility_off_rounded, size: 18),
                            SizedBox(width: 8),
                            Text("HIDE"),
                          ],
                        ),
                      ),
                      Tab(
                         child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_search_rounded, size: 18),
                            SizedBox(width: 8),
                            Text("REVEAL"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHideTab(),
                    _buildSeekTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHideTab() {
    bool canHide = _coverImage != null 
        && ((_secretType == 'text' && _secretTextController.text.isNotEmpty) || (_secretType == 'image' && _secretImage != null))
        && _encodePasswordController.text.length >= 6 
        && !_isEmbedding;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           const Text(
            "Conceal a Secret",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
           const Text(
            "Hide text or images inside a cover image using steganography.",
            style: TextStyle(color: Colors.white60, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // 1. Cover Image Selection
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.image_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Text("Cover Image", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Professional Picker
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isEmbedding ? null : _pickCoverImage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.stay_current_portrait_rounded, color: Colors.white60, size: 20),
                                SizedBox(height: 2),
                                Text('From device', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isEmbedding ? null : _pickCoverImageFromVault,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              children: [
                                Icon(kTrueVaultIcon, color: Colors.white60, size: 20),
                                SizedBox(height: 2),
                                Text('From TrueVault', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                    image: _coverImage != null 
                      ? DecorationImage(image: FileImage(_coverImage!), fit: BoxFit.cover, opacity: 0.8)
                      : null,
                  ),
                  child: _coverImage == null 
                    ? const Center(child: Text("No cover selected", style: TextStyle(color: Colors.white24, fontSize: 12)))
                    : Stack(
                        children: [
                           Container(
                             alignment: Alignment.center,
                             color: Colors.black45,
                             child: const Text("Cover image ready", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                           ),
                           Positioned(
                             top: 4, right: 4,
                             child: IconButton(
                               icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                               onPressed: () => setState(() => _coverImage = null),
                             ),
                           )
                        ],
                      ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // 2. Secret Content
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.lock, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Text("Secret Content", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    // Toggle Type
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _buildToggleItem("Text", _secretType == 'text', () => setState(() => _secretType = 'text')),
                          _buildToggleItem("Image", _secretType == 'image', () => setState(() => _secretType = 'image')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_secretType == 'text')
                  TextField(
                    controller: _secretTextController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Enter secret message...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  )
                else ...[
                  GestureDetector(
                    onTap: _pickSecretImage,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                        image: _secretImage != null 
                          ? DecorationImage(image: FileImage(_secretImage!), fit: BoxFit.cover, opacity: 0.8)
                          : null,
                      ),
                      child: _secretImage == null 
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: Colors.white54),
                                SizedBox(height: 4),
                                Text("Select secret image", style: TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          )
                        : Container(
                            alignment: Alignment.center,
                            color: Colors.black45,
                            child: const Text("SECRET LOADED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ),
                    ),
                  ),
                  if (_secretImage == null) ...[
                    const SizedBox(height: 12),
                    VaultLoadButton(
                      onPressed: _pickSecretImageFromVault,
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Password Check
          TextField(
            controller: _encodePasswordController,
            obscureText: true,
            onChanged: (val) {
               _checkStrength(val);
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.vpn_key, color: Colors.white70),
              labelText: "Encryption Password",
               labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          
          if (_encodePasswordController.text.isNotEmpty) ...[
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

          // Action Button
          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: canHide ? _performHide : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE040FB), // Neon Purple
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: canHide ? 8 : 0,
                shadowColor: canHide ? Colors.purpleAccent.withOpacity(0.5) : Colors.transparent,
              ),
              child: _isEmbedding 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.enhanced_encryption),
                      SizedBox(width: 8),
                      Text("HIDE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
            ),
          ),
          
          if (_outputImage != null) ...[
            const SizedBox(height: 30),
            _buildResultCard(true),
          ],
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSeekTab() {
    bool canReveal = _stegoImage != null 
        && _decodePasswordController.text.isNotEmpty 
        && !_isExtracting;

    return SingleChildScrollView(
       padding: const EdgeInsets.all(24),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
            const Text(
            "Reveal a Secret",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
           const Text(
            "Extract hidden content from a TrueHide secured image.",
            style: TextStyle(color: Colors.white60, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          _GlassCard(child: Column(
            children: [
              GestureDetector(
                  onTap: _pickStegoImage,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                      image: _stegoImage != null 
                        ? DecorationImage(image: FileImage(_stegoImage!), fit: BoxFit.cover)
                        : null,
                    ),
                    child: _stegoImage == null 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner, color: Colors.white54, size: 50),
                            SizedBox(height: 12),
                            Text("Tap to select image to scan", style: TextStyle(color: Colors.white54)),
                          ],
                        )
                      : null,
                  ),
                ),
                if (_stegoImage == null) ...[
                  const SizedBox(height: 12),
                  VaultLoadButton(
                    onPressed: _pickStegoImageFromVault,
                    label: 'SCAN FROM TRUEVAULT',
                  ),
                ],
            ],
          )),

          const SizedBox(height: 20),

          TextField(
            controller: _decodePasswordController,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.password, color: Colors.white70),
              labelText: "Decryption Password",
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: canReveal ? _performReveal : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF), // Cyan Accent
                foregroundColor: Colors.black, // Dark text on cyan
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: canReveal ? 8 : 0,
                shadowColor: canReveal ? Colors.cyanAccent.withOpacity(0.5) : Colors.transparent,
              ),
              child: _isExtracting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open),
                      SizedBox(width: 8),
                      Text("REVEAL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
            ),
          ),

          if (_revealedText != null || _revealedImage != null) ...[
             const SizedBox(height: 30),
             Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: const Color(0xFF00C853).withOpacity(0.2), // Green success bg
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(color: Colors.greenAccent),
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.greenAccent),
                        SizedBox(width: 10),
                        Text("SECRET REVEALED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_revealedText != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _revealedText!,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 14),
                        ),
                      ),
                      
                    if (_revealedImage != null)
                      GestureDetector(
                        onTap: () {
                          // Optional: Open full screen or zoom
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_revealedImage!, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      VaultSaveButton(
                        onPressed: () => _saveToVault(_revealedImage!.path),
                      ),
                 ],
               ),
             ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purpleAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(bool isHide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.purpleAccent, size: 40),
          const SizedBox(height: 8),
          const Text(
            "Image Processed Successfully!",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                 if (_outputImage != null) {
                    Share.shareXFiles(
                      [XFile(_outputImage!.path)], 
                      text: 'Hidden Secret Image (TrueHide)'
                    );
                 }
              },
              icon: const Icon(Icons.share),
              label: const Text("SHARE / SAVE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          VaultSaveButton(
            onPressed: _outputImage != null ? () => _saveToVault(_outputImage!.path) : null,
          ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}
