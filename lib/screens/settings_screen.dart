import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
             "Security",
             style: GoogleFonts.outfit(
               color: Colors.white38,
               fontSize: 12,
               fontWeight: FontWeight.bold,
               letterSpacing: 1.5,
             ),
          ),
          const SizedBox(height: 16),
          
          _SettingsActionItem(
            icon: Icons.lock_reset_rounded,
            title: 'Reset Vault PIN',
            color: Colors.redAccent,
            onTap: () {
               showDialog(
                 context: context,
                 builder: (context) => AlertDialog(
                   backgroundColor: const Color(0xFF1E1E1E),
                   title: const Text("Reset PIN", style: TextStyle(color: Colors.white)),
                   content: const Text("Please access TrueVault Settings directly to securely reset your PIN.", style: TextStyle(color: Colors.white70)),
                   actions: [
                     TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: Colors.indigoAccent))),
                   ],
                 ),
               );
            },
          ),
          
          const SizedBox(height: 40),
          

        ],
      ),
    );
  }
}

class _SettingsActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _SettingsActionItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: color, size: 28),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
      ),
    );
  }
}
