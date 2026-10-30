import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Environment { prod, qa }

class EnvConfig {
  static Environment _environment = Environment.prod;
  static bool _manuallyConfigured = false;

  static const String prodApiUrl = 'https://remaki-backend.onrender.com/graphql';
  static const String qaApiUrl = 'https://remaki-backend-qa.onrender.com/graphql';

  /// Call in main.dart or main_qa.dart to initialize environment
  static void initialize(Environment env) {
    _environment = env;
    _manuallyConfigured = true;
  }

  static Environment get environment {
    if (_manuallyConfigured) return _environment;

    // Detect from --dart-define=ENV=qa
    const envDefine = String.fromEnvironment('ENV', defaultValue: '');
    if (envDefine.toLowerCase() == 'qa') return Environment.qa;

    // Detect from Flutter app flavor (Android / iOS flavor)
    if (appFlavor == 'qa') return Environment.qa;

    // Detect from Web URL
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host.contains('qa') || host.contains('preview')) {
        return Environment.qa;
      }
    }

    return Environment.prod;
  }

  static bool get isQa => environment == Environment.qa;
  static bool get isProd => environment == Environment.prod;

  static String get appName => isQa ? 'Remaki QA' : 'Remaki';

  static String get apiUrl {
    // 1. Explicit override via --dart-define=API_URL=...
    const customUrl = String.fromEnvironment('API_URL');
    if (customUrl.isNotEmpty) return customUrl;

    // 2. Return URL based on current environment
    return isQa ? qaApiUrl : prodApiUrl;
  }

  static String get warmupUrl {
    return apiUrl.replaceAll('/graphql', '/');
  }
}
