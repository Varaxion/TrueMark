# TrueMark: Advanced Digital Forensics & Security Suite
**Version 2.0.0**

TrueMark is an academic-grade, comprehensive mobile security application engineered to deliver state-of-the-art cryptographic privacy, robust bit-level steganography, and forensic metadata manipulation. Developed to combat the rising tide of digital asset forgery, unauthorized deep-fakes, and privacy violations, TrueMark establishes a persistent, verifiable chain of custody for critical digital media while ensuring absolute confidentiality.

## 🔐 Core Architecture

TrueMark operates on a quad-module forensic architecture:

### 1. TrueSign (Identity Verification)
A sophisticated steganographic engine designed for establishing unforgeable ownership. 
*   **Bit-Level Watermarking:** Embeds invisible contextual metadata directly into the Least Significant Bits (LSB) of an image's pixel matrix. 
*   **Resiliency:** Modifies image encodings securely without degrading visual fidelity, surviving standard digital transmission.
*   **Cryptographic Wrapping:** All injected steganographic payloads are AES-encrypted to ensure the signature cannot be tampered with or intercepted.

### 2. TrueLock (Cryptographic Encapsulation)
The privacy and asset concealment mechanism.
*   **V9 Binary Engine:** Bypasses arbitrary platform channel constraints by operating purely inside the native Dart memory heap, utilizing AES-256 (CBC mode) with PKCS7 compliant padding.
*   **Absolute Encapsulation:** Transforms raw source files into unreadable `.tmk` forensic blocks, stripping visible headers and obscuring file type until a valid decryption key restores the precise bitstream.
*   **Legacy Fallback:** Designed for academic durability, seamlessly backward-compatible with historic (V1 `TMK01`) secure blocks.

### 3. TrueHide (Covert Communication)
Built for covert operations and secure physical-layer communication.
*   **Silent Embedding:** Allows the user to hide secondary files entirely inside native media files (e.g., hiding a text document inside a photograph).
*   **Zero-Knowledge Revelation:** Only operators possessing the exact 256-bit derived key can detect, let alone extract, the hidden payload.

### 4. TrueMeta (Exif Sanitization)
An operational security tool designed to neutralize metadata leakage.
*   **Forensic Scrubbing:** Identifies and purges latent geographical, timestamp, and device-camera signatures embedded inside image encodings.
*   **Chain of Custody UI:** Provides immediate, human-readable insight into the forensic fingerprint of any media file before sharing.

## 🗃️ TrueVault Secure Sandbox
All outputs flow seamlessly into **TrueVault**, an isolated, robust file explorer constrained safely within the Android application's `Documents` directory. 
*   Bypasses external Android Storage Access Framework (SAF) indexer bugs.
*   Maintains a strict, auditable forensic naming taxonomy for an unbroken paper trail: `[OriginalName]_[Feature]_[Operation]_[Timestamp].[Ext]`

## 📦 Technical Specifications
- **Framework:** Flutter (Dart)
- **Encryption Topology:** AES-256 (CBC) with explicit PKCS7 Padding (`encrypt` package)
- **Hash Derivation:** SHA-256 synchronized parity across modules
- **Database:** Firebase Firestore (Registry Sync)

---
© 2026 TrueMark. Engineered for Digital Truth.
