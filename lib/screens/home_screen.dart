import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'true_sign_screen.dart';
import 'profile_setup_screen.dart';
import 'signup_screen.dart';
import 'about_screen.dart';
import 'true_hide_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'true_lock_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Fallback if user is null (shouldn't happen due to AuthWrapper)
    if (user == null) return const Scaffold(body: Center(child: Text("Authenticating...")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        String nameFromDb = 'User';
        String email = user.email ?? '';
        
        if (snapshot.connectionState == ConnectionState.waiting) {
           nameFromDb = 'Loading...';
        } else if (snapshot.hasData && snapshot.data!.exists) {
           final data = snapshot.data!.data() as Map<String, dynamic>?; // Nullable cast
           if (data != null) {
              nameFromDb = data['name'] ?? '';
           }
        }
        
        // Final fallback: derive from email if name is still empty/User
        if (nameFromDb.trim().isEmpty || nameFromDb == 'User') {
            if (email.isNotEmpty) {
               nameFromDb = email.split('@')[0]; // simple fallback
            } else {
               nameFromDb = 'TrueMark User';
            }
        }

        final fullDisplayText = '$nameFromDb ($email)';

        return Scaffold(
          extendBodyBehindAppBar: true, 
          appBar: AppBar(
            title: const Text('TrueMark Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4527A0), Color(0xFF5E35B1)], // Darker Bluish-Purple
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  accountName: Text(
                    nameFromDb, 
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    )
                  ),
                  accountEmail: Text(
                    user?.email ?? '', 
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    )
                  ),
                  currentAccountPicture: GestureDetector(
                    onTap: () {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: Colors.indigo),
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.indigo),
                  title: const Text('Profile'),
                  onTap: () {
                     Navigator.pop(context);
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                        (route) => false);
                  },
                ),
              ],
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.indigo, Colors.teal],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'Securing Digital Truth in a Synthetic World',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Protect your images with digital signatures or encrypt sensitive files with military-grade security.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 40),
                    
                  // ACTION GROUPS
                    Expanded(
                      child: ListView(
                        children: [
                          // GROUP 1: INTEGRITY
                          _DashboardGroupCard(
                            title: 'TrueSign',
                            subtitle: 'Digital Signature & Tamper Detection',
                            icon: Icons.verified_user,
                            color: Colors.indigo,
                            children: [
                              _ActionTile(
                                icon: Icons.shield,
                                title: 'Protect Image',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueSignScreen(isProtectMode: true))),
                              ),
                              _ActionTile(
                                icon: Icons.verified,
                                title: 'Verify Image',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueSignScreen(isProtectMode: false))),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // GROUP 2: PRIVACY
                          _DashboardGroupCard(
                            title: 'TrueLock',
                            subtitle: 'Military-Grade File Encryption',
                            icon: Icons.lock,
                            color: const Color(0xFF00897B), // Emerald Green to match TrueLock screen
                            children: [
                              _ActionTile(
                                icon: Icons.lock_outline,
                                title: 'Encrypt File',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueLockScreen(isEncryptMode: true))),
                              ),
                              _ActionTile(
                                icon: Icons.lock_open,
                                title: 'Decrypt File',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueLockScreen(isEncryptMode: false))),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // GROUP 3: STEGANOGRAPHY
                          _DashboardGroupCard(
                            title: 'TrueHide',
                            subtitle: 'Steganographic Image Concealment',
                            icon: Icons.visibility_off,
                            color: const Color(0xFF9C27B0), // Purple for mystery/concealment
                            children: [
                              _ActionTile(
                                icon: Icons.hide_image,
                                title: 'Hide Message',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueHideScreen())),
                              ),
                              _ActionTile(
                                icon: Icons.image_search,
                                title: 'Reveal Message',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueHideScreen())),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}

class _DashboardGroupCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _DashboardGroupCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          title: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          children: children,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
