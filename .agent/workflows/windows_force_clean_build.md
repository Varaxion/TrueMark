---
description: Force clean a Flutter build on Windows when standard "flutter clean" fails due to file locks.
---

If `flutter clean` fails with "Access is denied" or "Unable to delete directory":

1. **Stop all running generic processes**
   ```powershell
   taskkill /F /IM java.exe /IM dart.exe /IM flutter.exe /IM adb.exe
   ```

2. **Attempt standard clean**
   ```powershell
   flutter clean
   ```

3. **If standard clean fails, Rename locked directories**
   Instead of trying to delete locked folders, rename them (Windows allows renaming locked parent folders sometimes, or the lock might be on a subfile).
   
   ```powershell
   // turbo
   Rename-Item build build_trash_$(Get-Date -Format "yyyyMMddHHmmss")
   ```
   
   If the `windows/flutter/ephemeral` folder is also locked:
   ```powershell
   // turbo
   Rename-Item windows/flutter/ephemeral windows/flutter/ephemeral_trash_$(Get-Date -Format "yyyyMMddHHmmss")
   ```

4. **Re-fetch dependencies**
   ```powershell
   flutter pub get
   ```

5. **Re-run the app**
   ```powershell
   flutter run
   ```

6. **Cleanup (Optional)**
   Later, you can try to delete the `_trash` folders when the system releases the locks (or after a reboot).
