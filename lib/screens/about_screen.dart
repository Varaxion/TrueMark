import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Deep immersive background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D0D0D), Color(0xFF000000)],
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                expandedHeight: 220,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    'TrueMark',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  background: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Icon(Icons.fingerprint_rounded, size: 60, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildSectionTitle('The Mission'),
                      const SizedBox(height: 16),
                      Text(
                        'TrueMark is engineered to restore "Digital Truth" in an era of content manipulation. We provide a professional security suite that empowers creators and users to protect their media through advanced digital signatures and military-grade encryption.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 48),
                      _buildSectionTitle('Professional Security Suite'),
                      const SizedBox(height: 28),
                      _buildFeatureItem(
                        'TrueSign',
                        'Identity Signatures & Hybrid Tamper Detection for Media and documents.',
                        Icons.verified_user_rounded,
                        kColorTrueSign,
                      ),
                      _buildFeatureItem(
                        'TrueLock',
                        'Universal AES-256-GCM Authenticated Encryption for all binary assets.',
                        Icons.lock_rounded,
                        kColorTrueLock,
                      ),
                      _buildFeatureItem(
                        'TrueHide',
                        'Integrated AES-256 Encryption with LSB Steganography to conceal data.',
                        Icons.visibility_off_rounded,
                        kColorTrueHide,
                      ),
                      _buildFeatureItem(
                        'TrueMeta',
                        'Categorized Forensic Analysis & Recursive Metadata Purging.',
                        Icons.document_scanner_rounded,
                        kColorTrueMeta,
                      ),
                      _buildFeatureItem(
                        'TrueVault',
                        'Sandboxed PIN-protected Explorer with Cross-Platform Security.',
                        kTrueVaultIcon,
                        kColorTrueVault,
                      ),
                      const SizedBox(height: 60),
                      Text(
                        'v2.0.0 Stable Build',
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Engineered with Excellence',
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '© 2026 TrueMark. All Rights Reserved.',
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Center(
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: Colors.white24,
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String desc, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
