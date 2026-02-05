import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'package:truemark/widgets/custom_error_toast.dart';
import 'package:oktoast/oktoast.dart';
import 'signup_screen.dart';
import 'package:truemark/utils/login_logger.dart';
import 'package:truemark/screens/profile_setup_screen.dart';
import 'package:truemark/utils/user_utils.dart';

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
        print("Login Error: $e");
        try {
          showCustomError(
            context,
            "Login failed: ${e.toString()}",
          );
        } catch (_) {
          showToast(
            "Login failed: ${e.toString()}",
            position: ToastPosition.top,
            backgroundColor: Colors.red.shade600,
            textStyle: const TextStyle(fontSize: 15, color: Colors.white),
            duration: const Duration(seconds: 3),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            colors: [Colors.indigo, Colors.teal], 
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: Colors.white.withOpacity(0.95),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // LOGO / BRANDING
                    const Icon(Icons.shield, size: 60, color: Colors.indigo),
                    const SizedBox(height: 16),
                    const Text(
                      'TrueMark',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Secure Your Digital Assets',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 48),

                    // INPUTS
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.indigo),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.indigo),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                    ),

                    // FORGOT PASSWORD
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                           final email = _emailController.text.trim();
                           if (email.isEmpty) {
                             showToast("Please enter your email first");
                             return;
                           }
                           try {
                             await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                             showToast("Password reset email sent", backgroundColor: Colors.green);
                           } catch (e) {
                             showToast("Error: $e");
                           }
                        },
                        child: const Text('Forgot Password?', style: TextStyle(color: Colors.teal)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // LOGIN BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : loginUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SIGN UP LINK
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
                        GestureDetector(
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                          ),
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
    );
  }
}