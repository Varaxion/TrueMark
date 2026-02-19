import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
                        "About TrueMark",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Logo/Icon
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
                            Icons.verified_user,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // App Name & Version
                      const Center(
                        child: Column(
                          children: [
                            Text(
                              "TrueMark",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Version 1.1.0",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Tagline
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Text(
                          "Securing Digital Truth in a Synthetic World",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Description
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "What is TrueMark?",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              "TrueMark is a cutting-edge digital security platform designed to combat image manipulation and verify content authenticity. In a world where synthetic media is becoming indistinguishable from reality, TrueMark provides the tools you need to prove authenticity and protect your digital assets.",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Features Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Core Features",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildFeatureItem(
                              icon: Icons.shield,
                              color: Colors.white,
                              title: "TrueSign",
                              subtitle: "Digital Signature & Tamper Detection",
                              description: "Embed invisible, encrypted signatures into your images. Create permanent, verifiable proof of ownership that's linked to your identity and stored in our secure cloud registry.",
                            ),
                            const SizedBox(height: 20),
                            _buildFeatureItem(
                              icon: Icons.lock,
                              color: Colors.white,
                              title: "TrueLock",
                              subtitle: "Military-Grade File Encryption",
                              description: "Protect sensitive files with AES-256-GCM encryption. Only you can decrypt them with your password. Perfect for securing confidential images before sharing.",
                            ),
                            const SizedBox(height: 20),
                            _buildFeatureItem(
                              icon: Icons.visibility_off,
                              color: Colors.white,
                              title: "TrueHide",
                              subtitle: "Steganographic Image Concealment (Coming Soon)",
                              description: "Hide encrypted images inside innocent-looking cover images. Dual-layer security combining encryption and steganography for covert communication.",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Technology Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Built with Security First",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              "• AES-256-GCM Authenticated Encryption\n• PBKDF2 Key Derivation (100,000 iterations)\n• LSB Steganography for Invisible Signatures\n• Cloud-Based Ownership Registry\n• Zero-Knowledge Architecture",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                height: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Mission Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.rocket_launch, color: Colors.amber, size: 28),
                                SizedBox(width: 12),
                                Text(
                                  "Our Mission",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Text(
                              "To empower creators, journalists, and individuals with the tools to prove authenticity in an increasingly synthetic digital world. We believe everyone deserves to protect their work and verify the truth.",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Footer
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              "Engineered with ❤️ for Digital Trust",
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "© ${DateTime.now().year} TrueMark. All rights reserved.",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
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

  Widget _buildFeatureItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
