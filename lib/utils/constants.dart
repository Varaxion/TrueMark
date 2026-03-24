import 'package:flutter/material.dart';

// lib/utils/constants.dart
const String kTrueMarkSharedKey = 'TrueMark-Shared-Verification-Key-2025';

// Set to TRUE to bypass native plugins (Picker/Firestore) on Windows causing crashes
// This enables "Manual Path" mode for Demo stability.
const bool kSafeModeWindows = false;

// UI Constants for v2.0.0 (Standardized)
const IconData kTrueVaultIcon = Icons.motion_photos_on_rounded; // Vault Combination Wheel

// Original Vault Primary (for fallback)
const Color kVaultPrimary = kColorTrueVault;
const Color kVaultAccent = Color(0xFF006064);

// Unified Feature Accent Colors
const Color kColorTrueSign = Color(0xFF00C853); // Emerald (Verified)
const Color kColorTrueLock = Color(0xFF00B0FF); // Vivid Electric Blue (Secured)
const Color kColorTrueHide = Color(0xFFAA00FF); // Deep Neon Purple (Cloaked)
const Color kColorTrueMeta = Color(0xFFFFD600); // Solar Gold (Analyzed)
const Color kColorTrueVault = Color(0xFF00E5FF); // Electric Cyan (Sandboxed)
