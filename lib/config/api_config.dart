import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Mindora FastAPI base URL.
///
/// Android emulator: host machine is [androidEmulatorHost].
/// Physical device: override via `--dart-define=MINDORA_API_HOST=<lan-ip>`.
class ApiConfig {
  ApiConfig._();

  static const String androidEmulatorHost = '10.0.2.2';
  static const int defaultPort = 8000;

  static String get baseUrl {
    const hostFromDefine = String.fromEnvironment('MINDORA_API_HOST');
    if (hostFromDefine.isNotEmpty) {
      return _buildUrl(hostFromDefine);
    }

    if (kIsWeb) {
      return _buildUrl('localhost');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _buildUrl(androidEmulatorHost);
      case TargetPlatform.iOS:
        return _buildUrl('localhost');
      default:
        return _buildUrl('localhost');
    }
  }

  static String _buildUrl(String host) {
    return 'http://$host:$defaultPort';
  }
}
