# TrueMark: The Professional Digital Integrity & Privacy Suite (v2.0.0)

**TrueMark** is a high-performance, cross-platform security application designed to establish "Digital Truth." It provides users with a comprehensive suite of tools for digital signatures, military-grade encryption, data steganography, and forensic metadata sanitization.

---

## 🚀 Feature Highlights

-   **TrueSign**: Embed invisible, encrypted digital signatures into images and PDFs. Verify creator identity and content integrity via a secure registry.
-   **TrueLock**: Military-grade AES-256-GCM encryption for universal file protection (.tmk wrapper). Uses PBKDF2 for high-entropy key derivation.
-   **TrueHide**: Advanced Least Significant Bit (LSB) steganography to conceal secret binary/text data within carrier images.
-   **TrueMeta**: Rapid forensic scans to extract and recursively purge identifying metadata from images, MP3s, and documents.
-   **TrueVault**: A sandboxed, PIN-protected environment for internal file management, isolated from public storage.

## 🛠️ Technical Methodology

| Methodology | Purpose | Technical Specification |
| :--- | :--- | :--- |
| **Cryptography** | Confidentiality & Authenticity | AES-256-GCM + PBKDF2 with SHA-256 |
| **Steganography** | Data Hiding | LSB Pixel Matrix Substitution (RGBA) |
| **Integrity** | Tamper Detection | SHA-256 Hashing |
| **Identification** | Ownership Proof | Firestore Digital Asset Registry |

## 💻 Tech Stack

-   **Language**: Dart 3.8.1+
-   **Framework**: Flutter
-   **Backend**: Firebase (Auth, Cloud Firestore)
-   **Cryptographic Core**: encrypt, pointycastle, crypto
-   **System Access**: path_provider, file_picker, share_plus

## 🔮 Future Roadmap

-   **AI Analysis**: TF-Lite based Deepfake detection for unverified media.
-   **Blockchain Layer**: Moving the signature registry to a decentralized, immutable ledger.
-   **Biometrics**: Native FaceID and Fingerprint integration for vault access.
-   **Extension Ecosystem**: Dedicated browser extensions for instant on-web verification.

---

**© 2026 TrueMark Security Labs. Engineered for Digital Truth.**
