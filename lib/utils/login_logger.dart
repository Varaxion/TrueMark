import 'package:device_info_plus/device_info_plus.dart';

class LoginLogger {
  static Future<void> logLoginAttempt(
    String email, {
    required bool success,
    String? error,
  }) async {
    // No-op logger (kept for API compatibility). Re-enable logging if needed.
    // ignore: unused_local_variable
    final deviceInfoPlugin = DeviceInfoPlugin();
    if (email.isEmpty || success && error == null) {
      // keep method async without side effects
      await Future<void>.delayed(Duration.zero);
    }
  }
}