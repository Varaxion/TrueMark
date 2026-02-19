
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userEmail = user.email;
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email ?? '',
        'name': _nameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
         _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully'), backgroundColor: Colors.green),
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
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // Navigate to login or initial route (assuming '/' or signup)
        Navigator.of(context).popUntil((route) => route.isFirst);
        // Or if you have named route:
        // Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4527A0), Color(0xFF5E35B1)], // Darker Bluish-Purple
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
                        "Profile",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _logout,
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Profile Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Icon
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // User Email
                      if (_userEmail != null)
                        Center(
                          child: Text(
                            _userEmail!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),

                      // Profile Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseAuth.instance.currentUser != null 
                              ? FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots()
                              : null,
                          builder: (context, snapshot) {
                            // Loading State
                            if (snapshot.connectionState == ConnectionState.waiting) {
                               return const Padding(
                                 padding: EdgeInsets.all(20.0),
                                 child: Center(child: CircularProgressIndicator(color: Colors.white)),
                               );
                            }
                            
                            // Initialize controller if not editing
                            if (!_isEditing) {
                                if (snapshot.hasData && snapshot.data!.exists) {
                                   final data = snapshot.data!.data() as Map<String, dynamic>;
                                   final name = data['name'] ?? '';
                                   // Only update if text is different to avoid cursor jumping if focused (though enabled=false prevents focus)
                                   if (_nameController.text != name) {
                                      _nameController.text = name;
                                   }
                                } else {
                                   // No doc yet
                                   _nameController.text = ''; 
                                }
                            }

                            return Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    "Personal Information",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Name Field
                                  TextFormField(
                                    controller: _nameController,
                                    enabled: _isEditing,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Full Name',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      prefixIcon: const Icon(Icons.person, color: Colors.white70),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(color: Colors.white30),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(color: Colors.white30),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(color: Colors.white),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (_isEditing && (value == null || value.trim().isEmpty)) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 30),

                                  // Action Button
                                  SizedBox(
                                    height: 50,
                                    child: _isEditing
                                        ? ElevatedButton.icon(
                                            onPressed: _isLoading ? null : _saveProfile,
                                            icon: _isLoading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Icon(Icons.save),
                                            label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor: Colors.white12,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          )
                                        : OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _isEditing = true;
                                              });
                                            },
                                            icon: const Icon(Icons.edit),
                                            label: const Text('Edit Profile'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              side: const BorderSide(color: Colors.white),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                  ),

                                  if (_isEditing) ...[
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = false;
                                          // Re-trigger build to fetch fresh data from stream logic
                                          // Or clear controller and let stream fill it?
                                          // The stream builder logic will refill it on next build!
                                        });
                                      },
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Account Actions
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Account",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(Icons.logout, color: Colors.redAccent),
                              title: const Text(
                                'Logout',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: _logout,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              tileColor: Colors.white.withOpacity(0.05),
                            ),
                          ],
                        ),
                      ),
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