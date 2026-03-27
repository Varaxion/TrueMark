import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_setup_screen.dart';
import '../utils/login_logger.dart';
import '../widgets/custom_error_toast.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await LoginLogger.logLoginAttempt(_emailController.text.trim(), success: true);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        await LoginLogger.logLoginAttempt(_emailController.text.trim(), success: false, error: e.toString());
        showCustomError(context, "Signup failed: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                    const SizedBox(height: 40),

                    // Glass Signup Card
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
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    "Initialize Account",
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
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
                                  validator: (v) => (v != null && v.contains('@')) ? null : "Invalid Identity Handle",
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _passwordController,
                                  hint: "Password",
                                  icon: Icons.lock_outline_rounded,
                                  isDark: isDark,
                                  obscure: true,
                                  onChanged: (v) => setState(() {}),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return "Required";
                                    if (v.length < 8) return "Min 8 Chars";
                                    if (!RegExp(r'[A-Z]').hasMatch(v)) return "Needs Caps";
                                    if (!RegExp(r'[0-9]').hasMatch(v)) return "Needs Numbers";
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildStrengthIndicator(_passwordController.text),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : registerUser,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigoAccent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      elevation: 0,
                                    ),
                                    child: _isLoading 
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text("Create", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already registered?", style: TextStyle(color: Colors.white38)),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/login'),
                          child: const Text("Login", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    ],
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

  Widget _buildStrengthIndicator(String password) {
    if (password.isEmpty) return const SizedBox.shrink();
    
    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#\$&*~]').hasMatch(password)) strength++;

    Color color = Colors.redAccent;
    String label = "Weak";
    double width = 0.25;

    if (strength == 2) { color = Colors.orangeAccent; label = "Fair"; width = 0.5; }
    else if (strength == 3) { color = Colors.yellowAccent; label = "Good"; width = 0.75; }
    else if (strength >= 4) { color = Colors.greenAccent; label = "Unbreakable"; width = 1.0; }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Strength: $label", style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
            Text("${(width * 100).toInt()}%", style: TextStyle(color: Colors.white24, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 4, width: double.infinity,
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: width,
            child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      onChanged: onChanged,
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
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
      ),
    );
  }
}