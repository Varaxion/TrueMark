import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            expandedHeight: 180,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                        ? [const Color(0xFF1E1E2C), const Color(0xFF0A0A0A)]
                        : [const Color(0xFF3949AB), const Color(0xFF1A237E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Image.asset('assets/images/logo.png', height: 60, errorBuilder: (_, __, ___) => const Icon(Icons.verified_user_rounded, size: 60, color: Colors.white)),
                      const SizedBox(height: 10),
                      Text(
                        'TrueMark v2.0.0',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('The Mission', isDark),
                  const SizedBox(height: 12),
                  Text(
                    'TrueMark is engineered to restore "Digital Truth" in an era of content manipulation. We provide a professional security suite that empowers creators and users to protect their media through advanced digital signatures and military-grade encryption.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Professional Security Suite', isDark),
                  const SizedBox(height: 20),
                  _buildFeatureItem(
                    'TrueSign',
                    'Digital Signatures & Tamper Detection for Media and PDFs.',
                    Icons.verified_user_rounded,
                    Colors.indigoAccent,
                    isDark,
                  ),
                  _buildFeatureItem(
                    'TrueLock',
                    'Universal AES-256-GCM Authenticated Encryption for all files.',
                    Icons.lock_rounded,
                    Colors.tealAccent,
                    isDark,
                  ),
                  _buildFeatureItem(
                    'TrueHide',
                    'High-capacity LSB Steganography to conceal secret data.',
                    Icons.visibility_off_rounded,
                    Colors.deepPurpleAccent,
                    isDark,
                  ),
                  _buildFeatureItem(
                    'TrueMeta',
                    'Recursive Forensic Cleaning & Privacy Sanitization.',
                    Icons.info_rounded,
                    Colors.orangeAccent,
                    isDark,
                  ),
                  _buildFeatureItem(
                    'TrueVault',
                    'Sandboxed PIN-protected Explorer with Secure Storage.',
                    kTrueVaultIcon,
                    kVaultPrimary,
                    isDark,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('The Methodology', isDark),
                  const SizedBox(height: 12),
                  _buildMethodologyCard(isDark),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Engineered with excellence',
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          '© 2026 TrueMark Security Labs.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }

  Widget _buildFeatureItem(String title, String desc, IconData icon, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
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
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodologyCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black10),
      ),
      child: Column(
        children: [
          _methodologyRow('Cryptography', 'AES-256-GCM / PBKDF2', isDark),
          const Divider(height: 24, color: Colors.white10),
          _methodologyRow('Steganography', 'LSB Pixel Substitution', isDark),
          const Divider(height: 24, color: Colors.white10),
          _methodologyRow('Verification', 'SHA-256 / Cloud Registry', isDark),
        ],
      ),
    );
  }

  Widget _methodologyRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(value, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'monospace')),
      ],
    );
  }
}
