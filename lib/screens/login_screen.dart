import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oktoast/oktoast.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';
import '../utils/login_logger.dart';
import '../utils/user_utils.dart';
import '../widgets/custom_error_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void loginUser() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      showToast("Please enter email and password.", backgroundColor: Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null && mounted) {
        final uid = userCredential.user!.uid;
        await LoginLogger.logLoginAttempt(_emailController.text.trim(), success: true);
        final hasProfile = await UserUtils.hasProfile(uid);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => hasProfile ? const HomeScreen() : const ProfileSetupScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await LoginLogger.logLoginAttempt(_emailController.text.trim(), success: false, error: e.toString());
        showCustomError(context, "Login failed: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final resetController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
        title: Text("Recover Keys", style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enter your registered email to receive a secure recovery link.", style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: resetController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "user@truemark.com",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true, fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetPassword(resetController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
            child: const Text("Send Link", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _resetPassword(String email) async {
    if (email.isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      showToast("Recovery Link Sent", backgroundColor: Colors.indigoAccent);
    } catch (e) {
      showToast("Recovery Failed: ${e.toString()}", backgroundColor: Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    const isDark = true;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Blackout Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF000000), Color(0xFF0D0D0D)],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: !Platform.isWindows,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: _platformWrap(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    // Brand Icon
                    const Icon(Icons.fingerprint_rounded, size: 80, color: Colors.indigoAccent),
                    const SizedBox(height: 24),
                    Text(
                      'TrueMark',
                      style: GoogleFonts.outfit(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Secure Digital Truth in a Synthetic World',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.white38,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Glass Login Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  "Sign In",
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildTextField(
                                controller: _emailController,
                                hint: "Email",
                                icon: Icons.email_outlined,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _passwordController,
                                hint: "Password",
                                icon: Icons.lock_outline_rounded,
                                isDark: isDark,
                                obscure: true,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  child: Text("Forgot Password?", style: TextStyle(color: Colors.white24, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : loginUser,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigoAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading 
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text("Access", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("New to TrueMark?", style: TextStyle(color: Colors.white38)),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/signup'),
                          child: const Text("Initialize Account", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _platformWrap({required Widget child}) {
    if (!Platform.isWindows) return child;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontWeight: FontWeight.normal, fontSize: 14),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.indigoAccent),
        ),
      ),
    );
  }
}