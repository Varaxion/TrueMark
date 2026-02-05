import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mark_image_screen.dart';
import 'verification_screen.dart';
import 'profile_setup_screen.dart';
import 'signup_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

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
        
        if (snapshot.hasData && snapshot.data!.exists) {
           final data = snapshot.data!.data() as Map<String, dynamic>;
           nameFromDb = data['name'] ?? '';
           if (nameFromDb.trim().isEmpty) nameFromDb = 'User';
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
                      colors: [Colors.indigo, Colors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  accountName: Text(fullDisplayText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  accountEmail: const SizedBox.shrink(),
                  currentAccountPicture: GestureDetector(
                    onTap: () {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
                    },
                    child: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40, color: Colors.indigo),
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
                      'Secure Your Digital Assets',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Embed invisible proofs of ownership into your images or verify suspicious files.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 40),
                    
                    Expanded(
                      child: ListView(
                        children: [
                           _DashboardCard(
                            icon: Icons.shield,
                            title: 'Protect Image',
                            subtitle: 'Embed invisible signature & register ownership',
                            color: Colors.indigo,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const MarkImageScreen()));
                            },
                          ),
                          const SizedBox(height: 16),
                          _DashboardCard(
                            icon: Icons.verified,
                            title: 'Verify Image',
                            subtitle: 'Scan an image to reveal its creator',
                            color: Colors.teal,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationScreen()));
                            },
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

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }
}
