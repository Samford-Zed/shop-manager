import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Central API configuration. Picks the right base URL per platform.
/// - Web: http://localhost:5000
/// - Android physical device: default to your LAN IP (edit as needed)
/// - Android emulator: pass dart-define to use 10.0.2.2 when needed
/// - iOS simulator: http://localhost:5000
/// - Others: use API_BASE_URL define or fallback to a LAN IP (change as needed)
class ApiConfig {
  static String get baseUrl {
    // Prefer explicit override everywhere
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (kIsWeb) return 'http://localhost:5000';
    try {
      if (Platform.isAndroid) {
        // Default to your LAN IP for physical devices. Update if your IP changes.
        return 'http://192.168.137.152:5000';
      }
      if (Platform.isIOS) {
        return 'http://localhost:5000';
      }
    } catch (_) {}
    // Fallback for desktop or other platforms. Edit to your LAN IP if needed.
    return 'http://192.168.137.152:5000';
  }
}
