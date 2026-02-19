import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConfig {
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (kIsWeb) {
      return 'http://localhost:5000';
    }

    // Default for Android is the machine's LAN IP which works for physical devices.
    // If you're running in the Android emulator, use 10.0.2.2 by passing a dart-define:
    // flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
    if (Platform.isAndroid) {
      return 'http://192.168.137.47:5000';
    }

    if (Platform.isIOS) {
      return 'http://localhost:5000';
    }

    // Other platforms: change if needed
    return 'http://192.168.137.47:5000';
  }
}
