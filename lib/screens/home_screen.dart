// lib/screens/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_service.dart';
import 'package:path_provider/path_provider.dart';
import '../services/steg_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'verification_screen.dart';
import 'signup_screen.dart';
import 'profile_setup_screen.dart';
import 'admin_dashboard_screen.dart';
import '../utils/admin_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;
  bool _loading = false;
  String? _error;

  // numbering fields
  String? _baseNumber;
  int _imageCount = 0;
  String? _lastGeneratedId;
  bool _processing = false;
  bool _processedSuccess = false;
  String? _processedLocalPath;

  @override
  void initState() {
    super.initState();
    _ensureSignedInAndMeta();
  }

  Future<void> _ensureSignedInAndMeta() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // false = do not fallback to anonymous (because you use AuthWrapper)
      final meta = await ImageService.ensureUserMeta(allowAnonymousFallback: false);
      setState(() {
        _baseNumber = meta['baseNumber'] as String?;
        _imageCount = meta['imageCount'] as int? ?? 0;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to prepare user meta: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (file == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      // generate id (atomically increments in Firestore)
      final generatedId = await ImageService.generateNextImageId(allowAnonymousFallback: false);

      setState(() {
        _pickedFile = file;
        _lastGeneratedId = generatedId;
        if (_baseNumber != null && generatedId.startsWith(_baseNumber!)) {
          final trailing = generatedId.substring(_baseNumber!.length);
          final parsed = int.tryParse(trailing);
          if (parsed != null) _imageCount = parsed;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated image id: $generatedId')),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (file == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final generatedId = await ImageService.generateNextImageId(allowAnonymousFallback: false);

      setState(() {
        _pickedFile = file;
        _lastGeneratedId = generatedId;
        if (_baseNumber != null && generatedId.startsWith(_baseNumber!)) {
          final trailing = generatedId.substring(_baseNumber!.length);
          final parsed = int.tryParse(trailing);
          if (parsed != null) _imageCount = parsed;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated image id: $generatedId')),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to capture image: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _pickedFile = null;
      _error = null;
      _lastGeneratedId = null;
    });
  }

  Future<void> _processPickedImage() async {
    if (_pickedFile == null || _lastGeneratedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick an image first and generate an id.')));
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
      _processedSuccess = false;
    });
    // small artificial delay to make processing feel realistic
    await Future.delayed(const Duration(seconds: 4));

    try {
      final inFile = File(_pickedFile!.path);
      final dir = await getTemporaryDirectory();
      final outPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.png';
      final outFile = File(outPath);
      final password = _lastGeneratedId!;

      final processedFile = await StegService.embedStringInImage(
        inputFile: inFile,
        plaintext: _lastGeneratedId!,
        password: password,
        outputFile: outFile,
      );

      final fileBytes = await processedFile.readAsBytes();
      final sha = sha256.convert(fileBytes).toString();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final metaRef = FirebaseFirestore.instance
            .collection('userMeta')
            .doc(user.uid)
            .collection('images')
            .doc(_lastGeneratedId);
        await metaRef.set({
          'imageId': _lastGeneratedId,
          'localPath': processedFile.path,
          'processedAt': FieldValue.serverTimestamp(),
          'sha256': sha,
          'baseNumber': _baseNumber ?? '',
          'count': _imageCount,
        });
      }

      setState(() {
        _pickedFile = XFile(processedFile.path);
        _processedLocalPath = processedFile.path;
        _processedSuccess = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Processed image saved at ${processedFile.path}')));
    } catch (e) {
      setState(() {
        _error = 'Processing failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Processing failed: $e')));
    } finally {
      setState(() {
        _processing = false;
      });
    }
  }

  // helper to humanize bytes
  String _filesize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _buildUploaderCard() {
    return GestureDetector(
      onTap: _loading ? null : () => _showPickOptions(),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo.shade200, width: 2),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _pickedFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.cloud_upload_outlined, size: 48),
                      SizedBox(height: 10),
                      Text('Tap to upload image', style: TextStyle(fontSize: 16)),
                      SizedBox(height: 6),
                      Text('or use the buttons below', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_pickedFile!.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: _removeImage,
                            tooltip: 'Remove image',
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pick from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            if (_pickedFile != null)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Remove image', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filename = _pickedFile?.name ?? 'No file chosen';
    final filesize = _pickedFile == null ? '—' : _filesize(File(_pickedFile!.path).lengthSync());
    final generatedIdDisplay = _lastGeneratedId ?? (_baseNumber != null ? 'Next id will start with $_baseNumber' : 'No id yet');
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user != null && user.email != null && adminEmails.map((e) => e.toLowerCase()).contains(user.email!.toLowerCase());

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: const Center(
                child: Text('TrueMark', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('Verify Image'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerificationScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileSetupScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.of(context).pop();
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SignupScreen()), (route) => false);
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Home',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 36,
            color: Colors.indigo,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.indigo,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Admin Dashboard',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                );
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildUploaderCard(),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 4,
                  ),
                  onPressed: _loading ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
                const SizedBox(width: 18),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 4,
                  ),
                  onPressed: _loading ? null : _pickFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                const SizedBox(width: 14),
                if (_pickedFile != null)
                  OutlinedButton.icon(
                    onPressed: _removeImage,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
            if (_pickedFile != null) ...[
              const SizedBox(height: 12),
              _processing
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _processing ? null : _processPickedImage,
                      child: const Text('Process the image'),
                    ),
              const SizedBox(height: 8),
              if (_processedSuccess) ...[
                const Text('Successfully done', style: TextStyle(color: Colors.green)),
                const SizedBox(height: 6),
                Text('Encryption password / image id: ${_lastGeneratedId ?? "—"}', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 18),
            _pickedFile == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(child: Text('No file chosen', style: TextStyle(fontSize: 16))),
                  )
                : Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    color: Colors.grey.shade50,
                    child: ListTile(
                      dense: true,
                      title: Text(filename, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Size: $filesize'),
                      trailing: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                  ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}