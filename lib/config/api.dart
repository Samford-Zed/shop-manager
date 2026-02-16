import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Central API configuration. Picks the right base URL per platform.
/// - Web: http://localhost:5000
/// - Android emulator: http://10.0.2.2:5000
/// - iOS simulator: http://localhost:5000
/// - Others: use API_BASE_URL define or fallback to a LAN IP (change as needed)
class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000';
    try {
      if (Platform.isAndroid) {
        // For physical devices, you can override at build time:
        // flutter run --dart-define=API_BASE_URL=http://<LAN_IP>:5000
        return const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:5000',
        );
      }
      if (Platform.isIOS) {
        return const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://localhost:5000',
        );
      }
    } catch (_) {}
    // Fallback for desktop or other platforms. Edit to your LAN IP if needed.
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://192.168.1.2:5000',
    );
  }
}

