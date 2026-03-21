import 'package:flutter/material.dart';

const IconData kTrueVaultIcon = Icons.motion_photos_on_rounded; // Vault Combination Wheel

/// Consistent metal/slate colors for TrueVault.
const Color kVaultPrimary = Color(0xFF455A64); // Slate Gray 700 (Gunmetal)
const Color kVaultAccent = Color(0xFF607D8B);  // Slate Gray 500 (Steel)

/// A full-width styled button for loading a file from TrueVault.
/// Used in TrueMeta, TrueSign, TrueLock, TrueHide.
class VaultLoadButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const VaultLoadButton({
    super.key,
    required this.onPressed,
    this.label = 'Load from TrueVault',
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
          backgroundColor: kVaultPrimary,
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
/// Used in TrueMeta, TrueSign, TrueLock, TrueHide after a successful operation.
class VaultSaveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const VaultSaveButton({
    super.key,
    required this.onPressed,
    this.label = 'Save to TrueVault',
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
          backgroundColor: kVaultPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
      ),
    );
  }
}
