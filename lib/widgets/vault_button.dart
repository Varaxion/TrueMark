import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// A full-width styled button for loading/importing from TrueVault.
class VaultLoadButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Color? color;

  const VaultLoadButton({
    super.key,
    required this.onPressed,
    this.label = 'Import from TrueVault',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(kTrueVaultIcon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? kVaultPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
      ),
    );
  }
}

/// A full-width styled button for saving a file to TrueVault.
class VaultSaveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Color? color;

  const VaultSaveButton({
    super.key,
    required this.onPressed,
    this.label = 'Save in TrueVault',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(kTrueVaultIcon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? kVaultPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
      ),
    );
  }
}
