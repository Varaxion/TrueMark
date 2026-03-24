import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import 'true_sign_screen.dart';
import 'true_lock_screen.dart';
import 'true_hide_screen.dart';
import 'true_meta_screen.dart';
import 'true_vault_screen.dart';
import 'profile_setup_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, 
      body: PageView(
        controller: _pageController,
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        children: const [
          _DashboardTab(),
          ProfileSetupScreen(),
          AboutScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16, top: 8),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (idx) {
                setState(() => _currentIndex = idx);
                _pageController.animateToPage(idx, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white38,
              showSelectedLabels: true,
              showUnselectedLabels: false,
              selectedLabelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Identity'),
                BottomNavigationBarItem(icon: Icon(Icons.info_outline_rounded), label: 'Mission'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  String? _userName;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) setState(() => _userEmail = user.email);
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() => _userName = doc.data()?['name'] as String?);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF000000), Color(0xFF0D0D0D)],
            ),
          ),
        ),
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  'TrueMark',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                background: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.indigo.withOpacity(0.2), Colors.transparent],
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.fingerprint_rounded, size: 80, color: Colors.indigo.withOpacity(0.3)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
             SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                     Text(
                      "Secure Digital Truth in a Synthetic World",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 15,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    _buildFeatureCard(
                      context,
                      'TrueSign',
                      'Identity Signatures & Tamper Protection',
                      Icons.verified_user_rounded,
                      [kColorTrueSign, kColorTrueSign.withOpacity(0.7)],
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueSignScreen(isProtectMode: true))),
                    ),
                    _buildFeatureCard(
                      context,
                      'TrueLock',
                      'Universal AES-256-GCM Encryption',
                      Icons.lock_rounded,
                      [kColorTrueLock, kColorTrueLock.withOpacity(0.7)],
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueLockScreen(isEncryptMode: true))),
                    ),
                    _buildFeatureCard(
                      context,
                      'TrueHide',
                      'Military-Grade Pixel Steganography',
                      Icons.visibility_off_rounded,
                      [kColorTrueHide, kColorTrueHide.withOpacity(0.7)],
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueHideScreen(isHideMode: true))),
                    ),
                    _buildFeatureCard(
                      context,
                      'TrueMeta',
                      'Deep Analysis & Metadata Purging',
                      Icons.document_scanner_rounded,
                      [kColorTrueMeta, kColorTrueMeta.withOpacity(0.7)],
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueMetaScreen())),
                    ),
                    _buildFeatureCard(
                      context,
                      'TrueVault',
                      'Sandboxed PIN-Protected Explorer',
                      kTrueVaultIcon,
                      [kColorTrueVault, kColorTrueVault.withOpacity(0.7)],
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrueVaultScreen())),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String desc, IconData icon, List<Color> gradient, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(desc, style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
