import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    double strength = _calculateStrength(password);
    Color color = _getColor(strength);
    String label = _getLabel(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Security Strength:", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: strength,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  double _calculateStrength(String p) {
    if (p.isEmpty) return 0;
    double s = 0;
    if (p.length >= 8) s += 0.25;
    if (p.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (p.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) s += 0.25;
    return s;
  }

  Color _getColor(double s) {
    if (s <= 0.25) return Colors.redAccent;
    if (s <= 0.5) return Colors.orangeAccent;
    if (s <= 0.75) return Colors.blueAccent;
    return Colors.greenAccent;
  }

  String _getLabel(double s) {
    if (s <= 0.25) return "WEAK";
    if (s <= 0.5) return "AVERAGE";
    if (s <= 0.75) return "STRONG";
    return "BULLETPROOF";
  }
}
