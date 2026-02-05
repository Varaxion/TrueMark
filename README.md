# 🛡️ TrueMark

### **Securing Digital Truth in a Synthetic World**

TrueMark is a powerful, multi-platform security suite designed to combat image manipulation, verify content authenticity, and provide military-grade file protection. In an era of synthetic media and deepfakes, TrueMark empowers creators and users to reclaim ownership of their digital assets.

---

## 🚀 The "True" Suite

TrueMark is built around three core pillars of digital security, each with a distinct focus and visual identity:

### 🛡️ **TrueSign** (Blue Theme)
*Digital Signature & Ownership Verification*
- **Purpose**: Create permanent, verifiable proof of ownership.
- **Mechanism**: Uses LSB steganography to embed an invisible, encrypted signature (User ID + Timestamp + Image Hash) directly into the image pixels.
- **Verification**: Cross-references extraction data with a secure cloud registry to detect tampering or identity mismatches.

### 🔒 **TrueLock** (Green Theme)
*Military-Grade File Encryption*
- **Purpose**: Protect sensitive files before storage or transmission.
- **Mechanism**: Implements **AES-256-GCM** authenticated encryption.
- **Security**: PBKDF2 key derivation with 100,000 iterations for password protection.
- **Format**: Outputs secure `.tmk` files that only the owner can unlock.

### 🎭 **TrueHide** (Purple Theme) — *Under Development*
*Steganographic Concealment*
- **Purpose**: Enable covert communication through "Double-Layer" security.
- **Mechanism**: Encrypts target images using dynamic hash-based passwords, then hides the resulting cipher-text inside innocent cover images.
- **Status**: UI implemented; backend logic currently in development.

---

## 🛠️ Technology Stack

- **Framework**: [Flutter](https://flutter.dev/) (Cross-platform Dart)
- **Backend/Auth**: [Firebase](https://firebase.google.com/) (Authentication & NoSQL Firestore)
- **Cryptography**: AES-GCM (Authenticated Encryption), SHA-256 Hashing, PBKDF2.
- **Steganography**: Least Significant Bit (LSB) Pixel Manipulation.
- **Platform Strategy**: Focused on Mobile (Android) and Desktop (Windows).

---

## 📱 Platform Status

| Platform | Status | Version |
| :--- | :--- | :--- |
| **Android** | ✅ Production Ready | 1.0.0 |
| **Windows** | 🚧 Under Development | Beta |
| **iOS / macOS** | ❌ Not Supported | N/A |
| **Web** | ❌ Not Supported | N/A |

*Note: The Windows application is currently undergoing plugin compatibility optimization.*

---



## 🎨 Design Philosophy

TrueMark follows a **Premium Dark Aesthetic**, utilizing:
- **Glassmorphic** UI components for depth and transparency.
- **Vibrant Gradients** to differentiate feature zones.
- **Minimalist Typography** for a clean, professional security-focused experience.

---

## 📝 License

Engineered with ❤️ for Digital Trust.
© 2026 TrueMark. All rights reserved.
