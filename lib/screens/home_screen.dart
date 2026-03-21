import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'true_sign_screen.dart';
import 'profile_setup_screen.dart';
import 'signup_screen.dart';
import 'about_screen.dart';
import 'true_hide_screen.dart';
import 'true_meta_screen.dart';
import 'true_vault_screen.dart';
import 'settings_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'true_lock_screen.dart';
import '../widgets/vault_button.dart';
import '../providers/theme_provider.dart';

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

        final isDark = context.watch<ThemeProvider>().isDark;
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
                      colors: [Color(0xFF4527A0), Color(0xFF5E35B1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  accountName: Text(
                    nameFromDb, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)
                  ),
                  accountEmail: Text(user.email ?? '', style: const TextStyle(color: Colors.white70)),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      nameFromDb.isNotEmpty ? nameFromDb[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.person_outline, color: isDark ? Colors.white70 : Colors.indigo),
                  title: const Text('Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.settings_rounded, color: isDark ? Colors.white70 : Colors.indigo),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.info_outline, color: isDark ? Colors.white70 : Colors.black87),
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF000000), const Color(0xFF0D0D22)]
                    : [Colors.indigo, Colors.teal],
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.white : const Color(0xFF3949AB),
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Protect your media and documents with digital signatures or encrypt files with multi-format vault security.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
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
                            icon: Icons.verified_user_rounded,
                            color: Colors.indigo.shade700,
                            children: [
                              _ActionTile(
                                icon: Icons.shield_rounded,
                                title: 'Protect media',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueSignScreen(isProtectMode: true))),
                              ),
                              _ActionTile(
                                icon: Icons.verified_rounded,
                                title: 'Verify identity',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueSignScreen(isProtectMode: false))),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // GROUP 2: PRIVACY
                          _DashboardGroupCard(
                            title: 'TrueLock',
                            subtitle: 'AES-256 Military Grade Encryption',
                            icon: Icons.lock_rounded,
                            color: Colors.teal.shade700,
                            children: [
                              _ActionTile(
                                icon: Icons.enhanced_encryption_rounded,
                                title: 'Lock file',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueLockScreen(isEncryptMode: true))),
                              ),
                              _ActionTile(
                                icon: Icons.no_encryption_gmailerrorred_rounded,
                                title: 'Unlock file',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueLockScreen(isEncryptMode: false))),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // GROUP 3: STEGANOGRAPHY
                          _DashboardGroupCard(
                            title: 'TrueHide',
                            subtitle: 'Conceal Data Inside Carrier Images',
                            icon: Icons.visibility_off_rounded,
                            color: Colors.deepPurple.shade700,
                            children: [
                              _ActionTile(
                                icon: Icons.add_to_photos_rounded,
                                title: 'Hide secret',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueHideScreen(isHideMode: true))),
                              ),
                              _ActionTile(
                                icon: Icons.travel_explore_rounded,
                                title: 'Reveal secret',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueHideScreen(isHideMode: false))),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // GROUP 4: METADATA & PRIVACY
                          _DashboardGroupCard(
                            title: 'TrueMeta',
                            subtitle: 'Deep Metadata Analysis (EXIF/MP3/PDF)',
                            icon: Icons.info_rounded,
                            color: const Color(0xFFFF5722), // Reddish Orange
                            children: [
                              _ActionTile(
                                icon: Icons.analytics_outlined,
                                title: 'Analyze metadata',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueMetaScreen())),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // GROUP 5: SECURE STORAGE
                          _DashboardGroupCard(
                            title: 'TrueVault',
                            subtitle: 'Secure Multi-Format Universal Explorer',
                            icon: kTrueVaultIcon,
                            color: kVaultPrimary,
                            children: [
                              _ActionTile(
                                icon: kTrueVaultIcon,
                                title: 'Open secure vault',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueVaultScreen())),
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
      },
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
    final isDark = context.watch<ThemeProvider>().isDark;
    return Card(
      elevation: isDark ? 0 : 2,
      color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.indigo.withOpacity(0.1)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.18 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          title: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey[600])),
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
    final isDark = context.watch<ThemeProvider>().isDark;
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.white60 : Colors.grey[700]),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white38 : Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
