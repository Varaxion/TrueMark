import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:oktoast/oktoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'true_vault_screen.dart';
import '../widgets/vault_button.dart';

class TrueMetaScreen extends StatefulWidget {
  const TrueMetaScreen({super.key});

  @override
  State<TrueMetaScreen> createState() => _TrueMetaScreenState();
}

class _TrueMetaScreenState extends State<TrueMetaScreen> {
  File? _selectedImage;
  Map<String, IfdTag>? _exifData;
  bool _isLoading = false;
  File? _scrubbedImage;
  bool _isScrubbing = false;

  // File Properties
  int? _fileSizeBytes;
  int? _imageWidth;
  int? _imageHeight;
  String? _fileExt;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      _processSelectedFile(File(result.files.single.path!));
    }
  }

  Future<void> _pickImageFromVault() async {
    final File? file = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrueVaultScreen(isPicker: true, pickImagesOnly: true)),
    );

    if (file != null) {
      _processSelectedFile(file);
    }
  }

  Future<void> _processSelectedFile(File file) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _selectedImage = file;
        _scrubbedImage = null;
        _exifData = null;
        _fileSizeBytes = null;
        _imageWidth = null;
        _imageHeight = null;
        _fileExt = null;
      });
    }

    try {
      final bytes = await _selectedImage!.readAsBytes();
      
      // Decode image to get bare minimum dimensions (works even if EXIF is stripped)
      final decoded = img.decodeImage(bytes);
      int? w = decoded?.width;
      int? h = decoded?.height;
      int size = await _selectedImage!.length();
      String ext = p.extension(_selectedImage!.path).toUpperCase().replaceAll('.', '');

      final data = await readExifFromBytes(bytes);

      if (mounted) {
        setState(() {
          _fileSizeBytes = size;
          _imageWidth = w;
          _imageHeight = h;
          _fileExt = ext;

          // Remove huge binary data blocks like Makernote or Thumbnail for cleaner display
          data.removeWhere((key, value) => key.contains('MakerNote') || key.contains('Thumbnail'));
          _exifData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
           _isLoading = false;
           _exifData = {};
        });
      }
      showToast("Error reading metadata.");
    }
  }

  Future<void> _scrubMetadata() async {
    if (_selectedImage == null) return;

    if (mounted) {
      setState(() {
        _isScrubbing = true;
      });
    }

    try {
      final bytes = await _selectedImage!.readAsBytes();
      
      // Use native C/Java/ObjC compression which explicitly drops EXIF headers
      // This is much faster and more reliable than Dart image decoding
      final scrubbedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 100, // Maintain absolute max visual quality 
        keepExif: false, // Explicitly DESTROY all location and camera metadata
      );
      
      if (scrubbedBytes.isNotEmpty) {
        // Save to temporary directory
        final directory = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final newPath = '${directory.path}/TrueMeta_Scrubbed_$timestamp.jpg';
        final newFile = File(newPath);
        await newFile.writeAsBytes(scrubbedBytes);

        if (mounted) {
          setState(() {
            _scrubbedImage = newFile;
            _isScrubbing = false;
          });
          showToast("Metadata successfully destroyed!", backgroundColor: Colors.green);
        }
      } else {
        throw Exception("Failed to compress and strip image.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScrubbing = false;
        });
      }
      showToast("Error scrubbing metadata: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _saveToVault() async {
    if (_scrubbedImage == null) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showToast("Error: Account not logged in.", backgroundColor: Colors.red);
        return;
      }
      
      final root = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${root.path}/TrueVault_${user.uid}');
      if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
      
      final newPath = '${vaultDir.path}/${p.basename(_scrubbedImage!.path)}';
      await _scrubbedImage!.copy(newPath);
      showToast(
        "Securely Stored in TrueVault!", 
        position: ToastPosition.bottom, 
        backgroundColor: Colors.green.shade800,
        radius: 10,
        dismissOtherToast: true
      );
    } catch (e) {
      showToast("Error saving to vault", backgroundColor: Colors.red);
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasExif = _exifData != null && _exifData!.isNotEmpty;
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF000000), const Color(0xFF211300)]
                : [const Color(0xFFE65100), const Color(0xFFFF8F00)],
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
                        "TrueMeta",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance for back button
                  ],
                ),
              ),

              // Header 
              const Padding(
                 padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                 child: Text(
                   "Analyze and purge sensitive metadata footprints from your documents and media before sharing.",
                   style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                   textAlign: TextAlign.center,
                 ),
              ),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        
                       // Mode Selector
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
                                onTap: _isScrubbing ? null : _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(Icons.perm_device_information_rounded, color: Colors.white70),
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
                                onTap: _isScrubbing ? null : _pickImageFromVault,
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

                       // Image Display Area
                       Container(
                          height: 220,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: _selectedImage == null
                             ? const Center(
                                 child: Column(
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                     Icon(Icons.zoom_in_rounded, size: 60, color: Colors.white24),
                                     SizedBox(height: 12),
                                     Text("Select file to examine", style: TextStyle(color: Colors.white38)),
                                   ],
                                 ),
                               )
                             : ClipRRect(
                                 borderRadius: BorderRadius.circular(14),
                                 child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity),
                                    Container(color: Colors.black12),
                                    Positioned(
                                      top: 8, right: 8,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                        onPressed: () => setState(() => _selectedImage = null),
                                      ),
                                    )
                                  ],
                                 ),
                               ),
                       ),

                       const SizedBox(height: 24),

                       if (_isLoading)
                         const Center(child: CircularProgressIndicator(color: Colors.white)),

                       // NEW FILE CATEGORY
                       if (_selectedImage != null && !_isLoading) ...[
                          const Text(
                            "File Information",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow("File Type", _fileExt ?? 'Unknown'),
                                _buildInfoRow("Dimensions", "${_imageWidth ?? '?'} x ${_imageHeight ?? '?'} px"),
                                _buildInfoRow("File Size", _fileSizeBytes != null ? "${(_fileSizeBytes! / 1024 / 1024).toStringAsFixed(2)} MB" : "? MB"),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                       ],

                       if (_exifData != null && !hasExif)
                         Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Colors.green.withOpacity(0.2),
                             borderRadius: BorderRadius.circular(12),
                             border: Border.all(color: Colors.greenAccent),
                           ),
                           child: const Text(
                             "This image's EXIF data is clean. No sensitive camera/location metadata found.",
                             style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                             textAlign: TextAlign.center,
                           ),
                         ),

                       if (hasExif) ...[
                          const SizedBox(height: 12),
                          
                          // Categorize Data
                          Builder(
                            builder: (context) {
                              Map<String, Map<String, String>> categories = {
                                'Device & Software': {},
                                'Location & GPS': {},
                                'Timestamps': {},
                                'Camera Settings': {},
                                'Advanced Data': {},
                              };

                              _exifData!.forEach((k, v) {
                                String key = k.replaceAll('Image ', '').replaceAll('EXIF ', '');
                                String val = v.toString();

                                if (key.contains('Make') || key.contains('Model') || key.contains('Software') || key.contains('Lens')) {
                                  categories['Device & Software']![key] = val;
                                } else if (key.contains('GPS')) {
                                  categories['Location & GPS']![key] = val;
                                } else if (key.contains('DateTime') || key.contains('Date') || key.contains('Time')) {
                                  categories['Timestamps']![key] = val;
                                } else if (key.contains('FNumber') || key.contains('ExposureTime') || key.contains('ISOSpeed') || key.contains('Flash') || key.contains('FocalLength') || key.contains('Resolution') || key.contains('Aperture')) {
                                  categories['Camera Settings']![key] = val;
                                } else {
                                  categories['Advanced Data']![key] = val;
                                }
                              });

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: categories.entries.where((e) => e.value.isNotEmpty).map((category) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: ExpansionTile(
                                        initiallyExpanded: category.key == 'Location & GPS' || category.key == 'Device & Software',
                                        iconColor: Colors.amberAccent,
                                        collapsedIconColor: Colors.white54,
                                        title: Text(
                                          category.key,
                                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                            child: Column(
                                              children: category.value.entries.map((entry) {
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          entry.key,
                                                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        flex: 3,
                                                        child: Text(
                                                          entry.value,
                                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            }
                          ),

                          const SizedBox(height: 24),

                          if (_scrubbedImage == null)
                            SizedBox(
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: _isScrubbing ? null : _scrubMetadata,
                                icon: _isScrubbing 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.auto_fix_high_rounded),
                                label: Text(_isScrubbing ? "STRIPPING..." : "STRIP METADATA", style: const TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 8,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C853).withOpacity(0.2), 
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.greenAccent),
                              ),
                              child: Column(
                                children: [
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.greenAccent),
                                      SizedBox(width: 10),
                                      Text("METADATA REMOVED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Share.shareXFiles(
                                          [XFile(_scrubbedImage!.path)], 
                                          text: 'Clean Image (TrueMeta)'
                                        );
                                      },
                                      icon: const Icon(Icons.share),
                                      label: const Text("SHARE / SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white, 
                                        foregroundColor: Colors.teal,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  VaultSaveButton(
                                     onPressed: _saveToVault,
                                   ),
                                ],
                              ),
                            ),
                       ],
                    ],
                  ),
                ),
              ),
             ],
          ),
        ),
      ),
    );
  }
}
