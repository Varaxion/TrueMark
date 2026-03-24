import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oktoast/oktoast.dart';
import 'home_screen.dart';
import '../utils/constants.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  
  bool _saving = false;
  bool _isEditing = false;
  final User? _user = FirebaseAuth.instance.currentUser;
  
  String? _currentName;
  String? _currentUsername;

  Timer? _debounce;
  bool? _usernameAvailable;
  bool _checkingUsername = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final username = _usernameController.text.trim().toLowerCase();
    final regex = RegExp(r'^[a-zA-Z0-9_\-\.]+$');
    
    if (username.isEmpty || !regex.hasMatch(username)) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }

    if (username == _currentUsername) {
      setState(() {
        _usernameAvailable = true;
        _checkingUsername = false;
      });
      return;
    }

    setState(() => _checkingUsername = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _checkUsernameAvailability(username));
  }

  Future<void> _checkUsernameAvailability(String username) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: username).get();
      if (mounted) {
        setState(() {
          _usernameAvailable = doc.docs.isEmpty;
          _checkingUsername = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingUsername = false);
    }
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _currentName = doc.data()?['name'] as String?;
        _currentUsername = doc.data()?['username'] as String?;
        _nameController.text = _currentName ?? '';
        _usernameController.text = _currentUsername ?? '';
        if (_currentUsername != null) _usernameAvailable = true;
      });
    } else {
       setState(() {
         _currentName = _user?.displayName;
         _nameController.text = _currentName ?? '';
       });
    }
  }

  Future<void> _updateProfile() async {
    final newName = _nameController.text.trim();
    String newUsername = _usernameController.text.trim().toLowerCase();
    
    if (newName.isEmpty || newUsername.isEmpty) {
      showToast("Identity Name & Username Required", backgroundColor: Colors.amber);
      return;
    }
    
    if (_usernameAvailable == false) {
      showToast("Username is already taken.", backgroundColor: Colors.red);
      return;
    }

    setState(() => _saving = true);
    try {
      if (_user != null) {
         try { await _user!.updateDisplayName(newName).timeout(const Duration(seconds: 3)); } catch (_) {}
      }

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'name': newName,
        'username': newUsername,
        'email': _user!.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
      
      showToast("Identity Synchronized", backgroundColor: kColorTrueVault);
      
      if (mounted) {
        setState(() {
          _currentName = newName;
          _currentUsername = newUsername;
          _isEditing = false;
          _saving = false;
        });
      }

      if (context.mounted && !Navigator.canPop(context)) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        });
      }
    } catch (e) {
      if (mounted) {
        showToast("Sync Error: ${e.toString()}", backgroundColor: Colors.red);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = (_currentName ?? _user?.email ?? 'U')[0].toUpperCase();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text("Digital Identity", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF0D0D0D), Color(0xFF000000)],
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                   const SizedBox(height: 32),
                   _buildGlassAvatar(initial),
                   const SizedBox(height: 48),
                   _isEditing ? _buildEditCard() : _buildViewCard(),
                   const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAvatar(String initial) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kColorTrueVault.withOpacity(0.2), width: 1),
            ),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(65),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.outfit(fontSize: 52, color: kColorTrueVault, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
             right: 4, bottom: 4,
             child: Container(
               padding: const EdgeInsets.all(6),
               decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
               child: Icon(Icons.verified_rounded, color: kColorTrueVault, size: 28),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewCard() {
    return _buildGlassContainer(
      child: Column(
        children: [
          Text(
            _currentName ?? 'Set Display Name',
            style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            _currentUsername != null ? '@$_currentUsername' : 'No Username',
            style: GoogleFonts.outfit(fontSize: 16, color: kColorTrueVault.withOpacity(0.8), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.email_outlined, color: kColorTrueVault.withOpacity(0.4), size: 16),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _user?.email ?? 'No email linked', 
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A1A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
                        title: Row(children: [const Icon(Icons.info_outline, color: kColorTrueVault), const SizedBox(width: 10), Text("Security Info", style: GoogleFonts.outfit(color: Colors.white))]),
                        content: Text("This email address is permanently linked to your digital identity and cannot be modified to ensure account integrity.", style: GoogleFonts.inter(color: Colors.white70)),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Understood", style: TextStyle(color: kColorTrueVault)))],
                      ),
                    );
                  },
                  child: Icon(Icons.info_outline_rounded, color: kColorTrueVault.withOpacity(0.5), size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildActionButton(
            label: "Edit",
            icon: Icons.edit_note_rounded,
            color: Colors.white.withOpacity(0.05),
            onPressed: () => setState(() {
               _isEditing = true;
               _nameController.text = _currentName ?? '';
               _usernameController.text = _currentUsername ?? '';
               _usernameAvailable = (_currentUsername != null) ? true : null;
            }),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            label: "Sign Out",
            icon: Icons.logout_rounded,
            color: Colors.red.withOpacity(0.08),
            labelColor: Colors.redAccent,
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditCard() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text("Synchronize Profile", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
               IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.white54), onPressed: () => setState(() => _isEditing = false)),
            ],
          ),
          const SizedBox(height: 24),
          _buildGlassField(
            controller: _nameController,
            hint: "Full Identity Name",
            icon: Icons.person_pin_rounded,
          ),
          const SizedBox(height: 16),
          _buildGlassField(
            controller: _usernameController,
            hint: "Public Username",
            icon: Icons.alternate_email_rounded,
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_\-\.]'))],
            suffix: _checkingUsername 
              ? SizedBox(width: 20, height: 20, child: Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: kColorTrueVault)))
              : _usernameAvailable == null 
                ? null 
                : Icon(_usernameAvailable! ? Icons.check_circle_rounded : Icons.cancel_rounded, color: _usernameAvailable! ? Colors.greenAccent : Colors.redAccent),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: (_saving || _checkingUsername || _usernameAvailable != true) ? null : _updateProfile,
              icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.sync_rounded),
              label: Text("Sync", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorTrueVault.withOpacity(0.8),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, Color labelColor = Colors.white, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: labelColor),
        label: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: labelColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: labelColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: labelColor.withOpacity(0.1))),
        ),
      ),
    );
  }

  Widget _buildGlassField({required TextEditingController controller, required String hint, required IconData icon, List<TextInputFormatter>? formatters, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        inputFormatters: formatters,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white24, fontWeight: FontWeight.normal),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: kColorTrueVault.withOpacity(0.5)),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}