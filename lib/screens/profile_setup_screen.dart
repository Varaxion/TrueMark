import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;
  String? _userEmail;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email;
        _nameController.text = user.displayName ?? '';
      });

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _userName = doc.data()?['name'] as String?;
          _nameController.text = _userName ?? '';
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final name = _nameController.text.trim();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email ?? '',
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(name);

      setState(() {
         _isEditing = false;
         _userName = name;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile identity verified and saved'), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to exit your secure session?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    String displayInitial = (_userName ?? _userEmail ?? 'U')[0].toUpperCase();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF000000), const Color(0xFF0F0C29)]
                : [const Color(0xFF3949AB), const Color(0xFF1A237E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    Expanded(
                      child: Text(
                        "Public Identity",
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white),
                      onPressed: _logout,
                      tooltip: 'Secure Exit',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Profile Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Premium Avatar
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Colors.indigoAccent, Colors.tealAccent],
                                  begin: Alignment.topLeft,
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 2),
                                ],
                                border: Border.all(color: Colors.white24, width: 3),
                              ),
                              child: Center(
                                child: Text(
                                  displayInitial,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Icon(Icons.verified_rounded, color: Colors.blue.shade700, size: 24),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Center(
                         child: Text(
                           _userEmail ?? "Loading...",
                           style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                         ),
                      ),

                      const SizedBox(height: 50),

                      // Form Identity Area
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                               "DISPLAY NAME",
                               style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
                             ),
                             const SizedBox(height: 12),
                             TextFormField(
                               controller: _nameController,
                               enabled: _isEditing || _userName == null,
                               style: const TextStyle(color: Colors.white, fontSize: 18),
                               decoration: InputDecoration(
                                 filled: true,
                                 fillColor: Colors.white12,
                                 hintText: "Enter your legal name",
                                 hintStyle: const TextStyle(color: Colors.white24),
                                 prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                 focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.tealAccent)),
                               ),
                               validator: (v) => v!.isEmpty ? "Identity required" : null,
                             ),
                             
                             const SizedBox(height: 40),

                             SizedBox(
                               width: double.infinity,
                               height: 55,
                               child: ElevatedButton(
                                 onPressed: (_isLoading) ? null : (_isEditing || _userName == null ? _saveProfile : () => setState(() => _isEditing = true)),
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: _isEditing || _userName == null ? Colors.teal : Colors.white10,
                                   foregroundColor: Colors.white,
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                   elevation: 4,
                                 ),
                                 child: _isLoading 
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                        _isEditing || _userName == null ? "Verify Identity" : "Update Profile",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                               ),
                             ),
                             
                             if (_isEditing) ...[
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    onPressed: () => setState(() => _isEditing = false),
                                    child: const Text("Cancel changes", style: TextStyle(color: Colors.white54)),
                                  ),
                                )
                             ]
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 60),

                      // Trust Indicator
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.tealAccent),
                            const SizedBox(width: 15),
                            const Expanded(
                              child: Text(
                                "Your verified identity is used across TrueSign to embed proof of ownership in your digital assets.",
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
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