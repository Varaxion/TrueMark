import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class LoginLogger {
  static Future<void> logLoginAttempt(
    String email, {
    required bool success,
    String? error,
  }) async {
    final now = DateTime.now();
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceModel = '';
    String platform = Platform.operatingSystem;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceModel = '${iosInfo.name} ${iosInfo.model}';
      } else {
        deviceModel = 'Unknown Platform';
      }
    } catch (e) {
      deviceModel = 'Error retrieving device info';
    }

    final logEntry = {
      'email': email,
      'success': success,
      'error': error ?? '',
      'timestamp': Timestamp.fromDate(now),
      'device': deviceModel,
      'platform': platform,
    };

    try {
      await FirebaseFirestore.instance.collection('login_attempts').add(logEntry);
    } catch (e) {
      print('Failed to log login attempt: $e');
    }
  }
}